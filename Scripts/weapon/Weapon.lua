dofile "weaponUtil.lua"
dofile "../gui/Slider.lua"

---@class Weapon
---@field fireCooldown number How many seconds pass between each shot
---@field damageType number The damage type, inflicts various effects
---@field damage number The amount of damage the projectile deals
---@field gravityForce number How much gravity affects the projectile
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
Weapon.fireCooldown = 0
Weapon.damageType = DAMAGETYPES.kinetic
Weapon.damage = 0
Weapon.gravityForce = 0
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
---@param pos Vec3
---@param dir Vec3
function Weapon:update(dt, pos, dir)
    self.fireCooldownTimer = math.max(self.fireCooldownTimer - dt, 0)

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
    local velocity = dir * self.projectileVelocity
    local pelletCount = self.pelletCount
    local angleSlice, halfAngle = self.sliceAngle / pelletCount, self.sliceAngle * 0.5
    for i = 1, pelletCount do
        sm.event.sendToTool(
            g_projectileManager, "cl_fireProjectile",
            {
                damage = self.damage,
                damageType = self.damageType,
                pierceLimit = self.pierceLimit,
                gravity = self.gravityForce,
                renderable = self.renderable,
                position = spawnPos,
                velocity = velocity:rotate(math.rad(angleSlice * i - halfAngle + math.random(-self.spreadAngle, self.spreadAngle)), VEC3_UP)
            }
        )
    end
end


---@alias WeaponTargetFunction fun(enemies: Character[], position: Vec3, owner: Character): Character

---@type WeaponTargetFunction[]
WeaponTargetFunctions = {
    ---Shoot at the closest enemy
    ---@param enemies Character[]
    ---@param position Vec3
    ---@param owner Character
    ---@return Character
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
    ---@return Character
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
Shotgun.gravityForce = 0.5
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