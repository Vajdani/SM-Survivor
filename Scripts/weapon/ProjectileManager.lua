dofile "weaponUtil.lua"

---@class ProjectileRenderable
---@field uuid Uuid The uuid of the part
---@field color? Color The desired colour

---@class ProjectileParams
---@field scriptClass string The name of the projectile's script class
---@field damage number The damage that the projectile deals to enemies
---@field damageType number The damage type that the projectile has
---@field bounceLimit number How many times the can projectile bounce before dying
---@field pierceLimit number How many times the projectiles can pierce through enemies
---@field gravity number The amount of gravity the projectile recieves
---@field renderable ProjectileRenderable|string|EffectName Describes how the projectile will look
---@field position Vec3 The projectile's position
---@field velocity Vec3 The projectile's velocity(m/s)
---@field aimDir Vec3 The projectile's starting direction
---@field direction Vec3 The projectile's direction
---@field pelletCount number The amount of pellets fired
---@field sliceAngle number The angle of the slice
---@field spreadAngle number The angle of the spread
---@field drag number
---@field bounceAxes Vec3
---@field collisionMomentumLoss number
---@field projectileVelocity number

---@class ProjectileManager : ScriptableObjectClass
ProjectileManager = class()

function ProjectileManager:server_onCreate()
    g_projectileManager = self.scriptableObject
end

---@param data ProjectileParams
function ProjectileManager:sv_fireProjectile(data)
    self.network:sendToClients("cl_addProjectile", data)
end

function ProjectileManager:sv_projectileNetwork(args)
    local projectile = self.projectiles[args.id]
    projectile[args.callback](projectile, args.params)
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
            self:cl_destroyProjectile(k)
        end
    end
end

function ProjectileManager:cl_destroyProjectile(id)
    self.projectiles[id].effect:destroy()
    self.projectiles[id] = nil
end

---@param data ProjectileParams
function ProjectileManager:cl_addProjectile(data)
    local dir, sliceAngle, spreadAngle, pellets = data.aimDir, data.sliceAngle, data.spreadAngle, data.pelletCount
    local angleSlice, halfAngle = sliceAngle / pellets, sliceAngle * 0.5
    local scriptClass = data.scriptClass and _G[data.scriptClass] or Projectile
    for i = 1, pellets do
        data.direction = dir:rotate(math.rad(angleSlice * i - halfAngle + math.random(-spreadAngle, spreadAngle)), VEC3_UP)

        local id = #self.projectiles + 1
        local projectile = scriptClass():init(data)
        projectile.id = id
        function projectile.sendToServer(pSelf, callback, args)
            self.network:sendToServer("sv_projectileNetwork", { callback = callback, params = args, id = pSelf.id })
        end

        function projectile.sendToClients(pSelf, callback, args)
            self.network:sendToClients("cl_projectileNetwork", { callback = callback, params = args, id = pSelf.id })
        end

        function projectile.sendToClient(pSelf, client, callback, args)
            self.network:sendToClient(client, "cl_projectileNetwork", { callback = callback, params = args, id = pSelf.id })
        end

        function projectile.destroy(pSelf)
            if not sm.isServerMode() then return end

            self.network:sendToClients("cl_destroyProjectile", pSelf.id)
        end

        self.projectiles[id] = projectile
    end

end

function ProjectileManager:cl_fireProjectile(data)
    self.network:sendToServer("sv_fireProjectile", data)
end

function ProjectileManager:cl_projectileNetwork(args)
    local projectile = self.projectiles[args.id]
    projectile[args.callback](projectile, args.params)
end



---@class Projectile : ProjectileParams
---@field lifeTime number The projectile's lifetime 
---@field effect Effect The projectile's effect
---@field direction Vec3
---@field sendToServer fun(self:Projectile, callback: string, args: any)
---@field sendToClients fun(self:Projectile, callback: string, args: any)
---@field sendToClient fun(self:Projectile, client: Player, callback: string, args: any)
---@field destroy fun()
---@field init fun(self:Projectile, data:ProjectileParams, headless:boolean) : Projectile
Projectile = class()
Projectile.lifeTime = 10


---Sets up the projectile
function Projectile:init(data, headless)
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

    if headless then
        ---@diagnostic disable-next-line:missing-fields
        self.effect = {
            setPosition = function() end,
            setRotation = function() end,
            stop = function() end,
            destroy = function() end,
        }
    else
        local effect
        if type(data.renderable) == "string" then
            effect = sm.effect.createEffect(data.renderable --[[@as string]])
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
    end

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

        if result.type == "limiter" or self.pierceLimit < 0 or hitTerrain and self.bounceLimit < 0 then
            self.effect:stop()
            return true
        end
    end

    self.position = hitTerrain and result.pointWorld + result.normalWorld * 0.1 or newPos
    self.effect:setPosition(newPos)
    self.effect:setRotation(getRotation(VEC3_UP, self.direction))

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



---@class Dynamite : Projectile
Dynamite = class(Projectile)

function Dynamite:init(data, headless)
    Projectile.init(self, data, headless)

    self.attached = false
    self.detonateTime = 2
    self.detonated = false

    return self
end

function Dynamite:update(manager, dt)
    if self.attached then
        self.detonateTime = self.detonateTime - dt
        if self.detonateTime <= 0 and not self.detonated then
            if sm.isHost then
                self:sendToServer("sv_detonate")
            end

            self.detonated = true
        end

        return false
    end

    return Projectile.update(self, manager, dt)
end

---@param manager ProjectileManager
---@param hitTerrain boolean
---@param result RaycastResult
function Dynamite:onHit(manager, hitTerrain, result)
    Projectile.onHit(self, manager, hitTerrain, result)

    if not result:getCharacter() then
        self.attached = true
    end
end

function Dynamite:sv_detonate()
    sm.physics.explode( self.position, 7, 4, 12, 40, "PropaneTank - ExplosionBig" )
    self:destroy()
end