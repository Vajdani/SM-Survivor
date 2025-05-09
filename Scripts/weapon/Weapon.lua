dofile "weaponUtil.lua"
dofile "../gui/Slider.lua"

---@class Weapon
---@field type WEAPONTYPE
---@field fireCooldown number How many seconds pass between each shot
---@field damageType number The damage type, inflicts various effects
---@field damage number The amount of damage the projectile deals
---@field gravityForce number How much gravity affects the projectile
---@field airDrag number How much drag affects the projectile
---@field collisionMomentumLoss number How much momentum the projectile loses on collision
---@field bounceLimit number How many times the can projectile bounce before dying
---@field pierceLimit number The amount of targets the projecitle pierces before dying
---@field projectileVelocity number The velocity of the projectile
---@field clipSize number The amount of bullets stored in the gun
---@field reloadTime number How long reloading takes
---@field pelletCount number How many bullets the gun fires per shot
---@field sliceAngle number The cone in which the pellets will be fired
---@field spreadAngle number The spread applied to each pellet
---@field level number The base level of the gun
---@field renderable ProjectileRenderable|string The projectile's look
---@field icon string|Uuid|string[] The icon of the gun (Path to the image/Uuid of the item/ItemIcon definition)
---@field id number The id of the gun
---@field targetFunctionId number The targeting function's id
---@field sliderColours Color[] A 2 element array that defines the colours that will be used for the gun's progressbar
Weapon = class()
Weapon.type = WEAPONTYPE.PROJECTILE
Weapon.fireCooldown = 0
Weapon.damageType = DAMAGETYPES.KINETIC
Weapon.damage = 0
Weapon.bounceLimit = 0
Weapon.bounceAxes = sm.vec3.new(1,1,0)
Weapon.gravityForce = 0
Weapon.airDrag = 0
Weapon.collisionMomentumLoss = 0
Weapon.pierceLimit = 0
Weapon.projectileVelocity = 25
Weapon.clipSize = 1
Weapon.reloadTime = 1
Weapon.pelletCount = 1
Weapon.sliceAngle = 0
Weapon.spreadAngle = 0
Weapon.level = 1
Weapon.targetFunctionId = 0

Weapon.renderable = { uuid = blk_plastic, color = sm.color.new(1,1,0) }
Weapon.icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png"
Weapon.sliderColours = { sm.color.new("#df7f00"), sm.color.new("#ff0000") }

function Weapon:init(id, hud)
    self.id = id
    self.slider = Slider():init(hud, "weapon"..id.."_ammo", self.clipSize, self.reloadTime, self.sliderColours)

    self.fireCooldownTimer = self.fireCooldown
    self.clip = self.clipSize
    self.reloadTimer = self.reloadTime

    return self
end

---@param dt number
---@param pos? Vec3
---@param dir? Vec3
function Weapon:update(dt, pos, dir)
    self.fireCooldownTimer = math.max(self.fireCooldownTimer - dt, 0)

    if not ProjectileManager.CanFireProjectile(self.pelletCount) then
        return
    end

    if self.clip == 0 then
        self.reloadTimer = self.reloadTimer - dt
        self.slider:update_reloading(self.reloadTimer)

        if self.reloadTimer <= 0 then
            self.reloadTimer = self.reloadTime
            self.clip = self.clipSize
            self.slider:update_shooting(self.clip)
        end

        return
    end

    if not dir or self.fireCooldownTimer > 0 then return end

    self.fireCooldownTimer = self.fireCooldown
    self.clip = self.clip - 1
    self.slider:update_shooting(self.clip)

    local spawnPos = pos + dir * 0.15
    sm.event.sendToScriptableObject(
        g_projectileManager, "cl_fireProjectile",
        {
            damage = self.damage,
            damageType = self.damageType,
            bounceLimit = self.bounceLimit,
            pierceLimit = self.pierceLimit,
            gravity = self.gravityForce,
            drag = self.airDrag,
            bounceAxes = self.bounceAxes,
            collisionMomentumLoss = self.collisionMomentumLoss,
            renderable = self.renderable,
            position = spawnPos,
            projectileVelocity = self.projectileVelocity,
            spreadAngle = self.spreadAngle,
            sliceAngle = self.sliceAngle,
            pelletCount = self.pelletCount,
            aimDir = dir
        }
    )
end


---@alias WeaponTargetFunction fun(enemies: Character[], position: Vec3, owner: Character): Character

---@type WeaponTargetFunction[]
WeaponTargetFunctions = {
    ---Shoot at the closest enemy
    ---@param enemies Character[]
    ---@param position Vec3
    ---@param owner Character
    ---@return Character?
    [0] = function(enemies, position, owner)
        local closest, target
        for k, v in pairs(enemies) do
            if sm.exists(v) and v ~= owner then
                local enemyPos = v.worldPosition
                local hit, result = sm.physics.raycast(position, enemyPos)
                if result:getCharacter() == v then
                    local distance = (enemyPos - position):length2()
                    if not target or distance < closest then
                        closest = distance
                        target = v
                    end
                end
            end
        end

        return target
    end,
    ---Shoot at the closest enemy behind the player
    ---@param enemies Character[]
    ---@param position Vec3
    ---@param owner Character
    ---@return Character?
    [1] = function(enemies, position, owner)
        local lookDir = owner.direction
        local closest, target
        for k, v in pairs(enemies) do
            if sm.exists(v) and v ~= owner then
                local enemyPos = v.worldPosition
                local hit, result = sm.physics.raycast(position, enemyPos)
                if result:getCharacter() == v then
                    local toEnemy = enemyPos - position
                    local distance = toEnemy:length2()
                    if (not target or distance < closest) and lookDir:dot(toEnemy:normalize()) < -0.707107 then
                        closest = distance
                        target = v
                    end
                end
            end
        end

        return target
    end,
    ---Shoot in the direction of the most dense area
    ---@param enemies Character[]
    ---@param position Vec3
    ---@param owner Character
    ---@return Character?
    [2] = function(enemies, position, owner)
        local maxDistance = 4^2
        local points = {}
        for k, v in ipairs(enemies) do
            if sm.exists(v) and v ~= owner then
                local pos = v.worldPosition
                local isClustered = false
                for _k, _v in ipairs(points) do
                    if (_v.averagePosition - pos):length2() <= maxDistance --[[and sm.physics.raycastTarget(_v.averagePosition, pos, v)]] then
                        isClustered = true
                        break
                    end
                end

                if not isClustered then
                    local positions = {}
                    for _k, _v in ipairs(enemies) do
                        if sm.exists(_v) and (_v.worldPosition - pos):length2() < maxDistance --[[and sm.physics.raycastTarget(pos, _v.worldPosition, _v)]] then
                            table_insert(positions, pos)
                        end
                    end

                    if #positions > 0 then
                        local avg = VEC3_ZERO
                        for _k, _v in ipairs(positions) do
                            avg = avg + _v
                        end

                        table_insert(points, {
                            averagePosition = avg / #positions,
                            count = #positions
                        })
                    end
                end
            end
        end

        local i = 1
        local last = #points
        while i < last do
            local hit, result = sm.physics.raycast(position, points[i].averagePosition, owner)
            if result.type ~= "character" then
                table.remove(points, i)
                last = #points + 1
            else
                i = i + 1
            end
        end

        if #points > 0 then
            table.sort(points, function(a, b)
                return a.count > b.count and (a.averagePosition - position):length2() < (b.averagePosition - position):length2()
            end)

            -- sm.particle.createParticle("paint_smoke", points[1].averagePosition, QUAT_IDENTITY, colour(0,1,0))
            local hit, result = sm.physics.raycast(position, points[1].averagePosition, owner)
            if result.type ~= "harvestable" then
                return { worldPosition = points[1].averagePosition }
            end
        end

        return nil
    end
}



Spudgun = class(Weapon)
Spudgun.fireCooldown = 0.25
Spudgun.clipSize = 25
Spudgun.reloadTime = 2
Spudgun.damage = 25
Spudgun.icon = { "ItemIconsSetSurvival0", "ItemIcons", "c5ea0c2f-185b-48d6-b4df-45c386a575cc" }

Shotgun = class(Weapon)
Shotgun.fireCooldown = 0.75
Shotgun.clipSize = 5
Shotgun.reloadTime = 2.5
Shotgun.damage = 50
Shotgun.pelletCount = 5
Shotgun.sliceAngle = 30
Shotgun.renderable = { uuid = blk_plastic, color = sm.color.new(0,1,0) }
Shotgun.icon = { "ItemIconsSetSurvival0", "ItemIcons", "f6250bf4-9726-406f-a29a-945c06e460e5" }

Gatling = class(Weapon)
Gatling.fireCooldown = 0.1
Gatling.clipSize = 50
Gatling.reloadTime = 3
Gatling.damage = 35
Gatling.spreadAngle = 7.5
Gatling.renderable = { uuid = blk_plastic, color = sm.color.new(1,0,0) }
Gatling.pierceLimit = 3
Gatling.targetFunctionId = 1
Gatling.icon = { "ItemIconsSetSurvival0", "ItemIcons", "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b" }

WeldTool = class(Weapon)
WeldTool.projectileVelocity = 50
WeldTool.fireCooldown = 0.75
WeldTool.clipSize = 3
WeldTool.reloadTime = 3
WeldTool.damage = 100
WeldTool.renderable = { uuid = blk_plastic, color = sm.color.new(0,0,1) }
WeldTool.pierceLimit = 100
WeldTool.bounceLimit = 5
WeldTool.targetFunctionId = 2
WeldTool.icon = { "ItemIconsSet0", "ItemIcons", "fdb8b8be-96e7-4de0-85c7-d2f42e4f33ce" }
WeldTool.sliderColours = { sm.color.new("#4287f5"), sm.color.new("#4f2eb3") }