dofile "weaponUtil.lua"
dofile "../gui/Slider.lua"

---@class Weapon
---@field fireCooldown number
---@field damageType number
---@field damage number
---@field piercing boolean
---@field pierceLimit number
---@field projectileVelocity number
---@field clipSize number
---@field reloadTime number
---@field pelletCount number
---@field sliceAngle number
---@field spreadAngle number
---@field level number
---@field renderable ProjectileRenderable|string
---@field icon string
---@field id number
---@field targetFunctionId number
Weapon = class()
Weapon.fireCooldown = 0
Weapon.damageType = DAMAGETYPES.kinetic
Weapon.damage = 0
Weapon.piercing = false
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

function Weapon:init(id, hud)
    self.id = id
    self.slider = Slider():init(hud, "weapon"..id.."_ammo", self.clipSize, self.reloadTime)

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
                piercing = self.piercing,
                pierceLimit = self.pierceLimit,
                gravity = false,
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
    [0] = function(enemies, position, owner) --[[@as WeaponTargetFunction]]
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
    end
}



Spudgun = class(Weapon)
Spudgun.fireCooldown = 0.25
Spudgun.clipSize = 25
Spudgun.reloadTime = 2
Spudgun.damage = 25

Shotgun = class(Weapon)
Shotgun.fireCooldown = 0.75
Shotgun.clipSize = 5
Shotgun.reloadTime = 2.5
Shotgun.damage = 50
Shotgun.pelletCount = 5
Shotgun.sliceAngle = 30
Shotgun.renderable = { uuid = blk_plastic, color = sm.color.new(0,1,0) }

Gatling = class(Weapon)
Gatling.fireCooldown = 0.1
Gatling.clipSize = 50
Gatling.reloadTime = 3
Gatling.damage = 35
Gatling.pelletCount = 1
Gatling.spreadAngle = 10
Gatling.renderable = { uuid = blk_plastic, color = sm.color.new(1,0,0) }