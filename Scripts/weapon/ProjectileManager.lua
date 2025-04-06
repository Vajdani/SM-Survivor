dofile "weaponUtil.lua"

---@class ProjectileRenderable
---@field uuid Uuid The uuid of the part
---@field color? Color The desired colour

---@class ProjectileParams
---@field damage number The damage that the projectile deals to enemies
---@field damageType number The damage type that the projectile has
---@field piercing boolean Whether the projectile can go through enemies 
---@field pierceLimit number How many times the projectiles can pierce through enemies
---@field gravity boolean Whether the projectile has gravity
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
    proj:init(
        data.damage,
        data.damageType,
        data.piercing,
        data.pierceLimit,
        data.gravity,
        data.renderable,
        data.position,
        data.velocity
    )

    self.projectiles[#self.projectiles+1] = proj
end

function ProjectileManager:cl_fireProjectile(data)
    self.network:sendToServer("sv_fireProjectile", data)
end


---@class Projectile : ProjectileParams
---@field lifeTime number The projectile's lifetime 
---@field effect Effect The projectile's effect
Projectile = class()
Projectile.damage = 0
Projectile.damageType = DAMAGETYPES.kinetic
Projectile.piercing = false
Projectile.pierceLimit = 0
Projectile.gravity = false
Projectile.lifeTime = 10


---Sets up the projectile
---@param damage number The damage that the projectile deals to enemies
---@param damageType number The damage type that the projectile has
---@param piercing boolean Whether the projectile can go through enemies 
---@param pierceLimit number How many times the projectiles can pierce through enemies
---@param renderable ProjectileRenderable|string Describes how the projectile will look
---@param position Vec3 The projectile's initial position
---@param velocity Vec3 The projectile's initial velocity
function Projectile:init(damage, damageType, piercing, pierceLimit, gravity, renderable, position, velocity)
    self.damage = damage
    self.damageType = damageType
    self.piercing = piercing
    self.pierceLimit = pierceLimit
    self.gravity = gravity

    local effect
    if type(renderable) == "string" then
        effect = sm.effect.createEffect(renderable)
    else
        effect = sm.effect.createEffect("ShapeRenderable")
        effect:setParameter("uuid", renderable.uuid)
        effect:setParameter("color", renderable.color or sm.color.new(1,1,1))
        effect:setScale(sm.vec3.one() * 0.25)
    end

    effect:setPosition(position)
    effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0,0,1), velocity))
    effect:start()
    self.effect = effect

    self.position = position
    self.velocity = velocity
end

function Projectile:update(manager, dt)
    self.lifeTime = self.lifeTime - dt

    if self.gravity then
        self.velocity = self.velocity * 0.99 - GRAVITY * dt
    end

    local newPos = self.position + self.velocity * dt
    local hit, result = sm.physics.raycast(self.position, newPos)
    if hit or self.lifeTime <= 0 then
        self:onHit(manager, result)

        if self.piercing then
            self.pierceLimit = self.pierceLimit - 1
        else
            self.effect:stop()
            return true
        end
    end

    self.position = newPos
    self.effect:setPosition(newPos)
    self.effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0,0,1), self.velocity))

    return false
end

function Projectile:onHit(manager, result)
    local char = result:getCharacter()
    if not char or not sm.exists(char) then return end

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