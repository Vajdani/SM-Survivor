dofile "weaponUtil.lua"

---@class ProjectileRenderable
---@field uuid Uuid The uuid of the part
---@field color? Color The desired colour

---@class ProjectileParams
---@field damage number The damage that the projectile deals to enemies
---@field damageType number The damage type that the projectile has
---@field bounceLimit number How many times the can projectile bounce before dying
---@field pierceLimit number How many times the projectiles can pierce through enemies
---@field gravity number The amount of gravity the projectile recieves
---@field renderable ProjectileRenderable|string Describes how the projectile will look
---@field position Vec3 The projectile's position
---@field velocity Vec3 The projectile's velocity(m/s)

---@class ProjectileManager : ToolClass
ProjectileManager = class()

function ProjectileManager:server_onCreate()
    g_projectileManager = self.tool
end

---@param data ProjectileParams
function ProjectileManager:sv_fireProjectile(data)
    self.network:sendToClients("cl_addProjectile", data)
end

function ProjectileManager:sv_onHit(data)
    local char = data.char
    if not sm.exists(char) then return end

    local unit = char:getUnit()
    if not sm.exists(unit) then return end

    sm.event.sendToUnit(unit, "sv_onHit", data.stats)
end

function ProjectileManager:client_onCreate()
    self.projectiles = {}
end

function ProjectileManager:client_onUpdate(dt)
    for k, projectile in pairs(self.projectiles) do
        local delete = projectile:update(self, dt)
        if delete then
            self.projectiles[k] = nil
        end
    end
end

---@param data ProjectileParams
function ProjectileManager:cl_addProjectile(data)
    local proj = Projectile()
    proj:init(data)

    self.projectiles[#self.projectiles+1] = proj
end

function ProjectileManager:cl_fireProjectile(data)
    self.network:sendToServer("sv_fireProjectile", data)
end


---@class Projectile : ProjectileParams
---@field lifeTime number The projectile's lifetime 
---@field effect Effect The projectile's effect
---@field direction Vec3
Projectile = class()
Projectile.damage = 0
Projectile.damageType = DAMAGETYPES.KINETIC
Projectile.bounceLimit = 0
Projectile.pierceLimit = 0
Projectile.gravity = 0
Projectile.lifeTime = 10


---Sets up the projectile
---@param data table The projectile data
function Projectile:init(data)
    self.damage = data.damage
    self.damageType = data.damageType
    self.bounceLimit = data.bounceLimit
    self.pierceLimit = data.pierceLimit
    self.gravity = data.gravity
    self.projectileVelocity = data.projectileVelocity
    self.direction = data.direction

    local effect
    if type(data.renderable) == "string" then
        effect = sm.effect.createEffect(data.renderable)
    else
        effect = sm.effect.createEffect("ShapeRenderable")
        effect:setParameter("uuid", data.renderable.uuid)
        effect:setParameter("color", data.renderable.color or sm.color.new(1,1,1))
        effect:setScale(sm.vec3.one() * 0.25)
    end

    effect:setPosition(data.position)
    effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0,0,1), self.direction))
    effect:start()
    self.effect = effect

    self.position = data.position

    self.hitObjs = {}
end

function Projectile:update(manager, dt)
    self.lifeTime = self.lifeTime - dt

    if self.gravity ~= 0 then
        self.direction = self.direction * 0.99 - GRAVITY * self.gravity * dt
    end

    local newPos = self.position + self.direction * self.projectileVelocity * dt
    local hit, result
    for i = 1, max(#self.hitObjs, 1) do
        local obj = self.hitObjs[i]
        hit, result = sm.physics.spherecast(self.position, newPos, 0.05, sm.exists(obj) and obj or nil)
        if result.type == "character" then
            break
        end
    end

    if hit or self.lifeTime <= 0 then
        self:onHit(manager, result)

        -- print(self.pierceLimit, self.bounceLimit)
        if self.pierceLimit <= 0 or result.type ~= "character" and self.bounceLimit < 0 then
            -- print("kill")
            self.effect:stop()
            return true
        end
    end

    self.position = newPos
    self.effect:setPosition(newPos)

    local dir = self.direction:safeNormalize(VEC3_UP)
    if (VEC3_UP - dir):length2() > 0.1 then
        self.effect:setRotation(sm.vec3.getRotation(VEC3_UP, dir))
    end

    return false
end

---@param manager ProjectileManager
---@param result RaycastResult
function Projectile:onHit(manager, result)
    local char = result:getCharacter()
    if not char or not sm.exists(char) and self.bounceLimit > 0 then
        local normal = result.normalWorld
        -- print(normal, self.direction)
        -- if (normal - self.direction):length2() > 0.1 then
            -- local cross = normal:cross(self.direction)
            -- self.direction = self.direction:rotate(cross.z, cross)
            self.direction = normal
            self.bounceLimit = self.bounceLimit - 1
        -- end

        return
    end

    self.pierceLimit = self.pierceLimit - 1
    table_insert(self.hitObjs, char)

    if sm.isHost then
        manager.network:sendToServer("sv_onHit",
            {
                char = char,
                stats = {
                    damage = self.damage,
                    damageType = self.damageType,
                    hitPos = result.pointWorld
                }
            }
        )
    end
end