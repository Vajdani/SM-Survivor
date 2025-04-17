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
---@field aimDir Vec3 The projectile's starting direction
---@field direction Vec3 The projectile's direction
---@field pelletCount number The amount of pellets fired
---@field sliceAngle number The angle of the slice
---@field spreadAngle number The angle of the spread

---@class ProjectileManager : ScriptableObjectClass
ProjectileManager = class()

function ProjectileManager:server_onCreate()
    g_projectileManager = self.scriptableObject
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
    local dir, sliceAngle, spreadAngle, pellets = data.aimDir, data.sliceAngle, data.spreadAngle, data.pelletCount
    local angleSlice, halfAngle = sliceAngle / pellets, sliceAngle * 0.5
    for i = 1, pellets do
        data.direction = dir:rotate(math.rad(angleSlice * i - halfAngle + math.random(-spreadAngle, spreadAngle)), VEC3_UP)
        self.projectiles[#self.projectiles+1] = Projectile():init(data)
    end

end

function ProjectileManager:cl_fireProjectile(data)
    self.network:sendToServer("sv_fireProjectile", data)
end


---@class Projectile : ProjectileParams
---@field lifeTime number The projectile's lifetime 
---@field effect Effect The projectile's effect
---@field direction Vec3
Projectile = class()
Projectile.lifeTime = 10


---Sets up the projectile
---@param data table The projectile data
function Projectile:init(data)
    self.damage = data.damage
    self.damageType = data.damageType
    self.bounceLimit = data.bounceLimit
    self.pierceLimit = data.pierceLimit
    self.gravity = data.gravity
    self.drag = data.drag
    self.bounceAxes = data.bounceAxes
    self.collisionMomentumLoss = data.collisionMomentumLoss
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

    return self
end

local terrainTypes = {
    terrainSurface = true,
    terrainAsset = true,
    harvestable = true
}

function Projectile:update(manager, dt)
    self.lifeTime = self.lifeTime - dt
    if self.lifeTime <= 0 or self.position.z < 0 then
        self.effect:stop()
        return true
    end

    if self.drag ~= 0 then
        self.projectileVelocity = self.projectileVelocity - self.projectileVelocity * self.drag * dt
    end

    if self.gravity ~= 0 then
        self.direction = (self.direction - GRAVITY * self.gravity * dt):normalize()
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

    local hitTerrain = terrainTypes[result.type] == true
    if hit then
        self:onHit(manager, hitTerrain, result)

        if self.pierceLimit < 0 or hitTerrain and self.bounceLimit < 0 then
            self.effect:stop()
            return true
        end
    end

    self.position = hitTerrain and result.pointWorld + result.normalWorld * 0.1 or newPos
    self.effect:setPosition(newPos)

    self.effect:setRotation(sm.vec3.getRotation(VEC3_UP, self.direction))

    return false
end

---@param manager ProjectileManager
---@param hitTerrain boolean
---@param result RaycastResult
function Projectile:onHit(manager, hitTerrain, result)
    if hitTerrain and self.bounceLimit > 0 then
        local normal = result.normalWorld
        local newDir = self.direction + normal * 2
        newDir.x = newDir.x * self.bounceAxes.x
        newDir.y = newDir.y * self.bounceAxes.y
        newDir.z = newDir.z * self.bounceAxes.z

        self.direction = newDir:normalize()

        self.projectileVelocity = self.projectileVelocity * (1 - self.collisionMomentumLoss)

        -- if (normal - self.direction):length2() > 0.1 then
        --     local cross = normal:cross(self.direction)
        --     self.direction = self.direction:rotate(cross.z, cross)
        -- end

        self.bounceLimit = self.bounceLimit - 1

        return
    end

    self.pierceLimit = self.pierceLimit - 1

    local char = result:getCharacter()
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