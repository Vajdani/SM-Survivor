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
---@field spreadAngle number
---@field level number
---@field renderable { uuid: Uuid, color: Color }
---@field icon string
---@field id number
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
Weapon.spreadAngle = 0
Weapon.level = 1

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
    local angleSlice, halfAngle = self.spreadAngle / pelletCount, self.spreadAngle * 0.5
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
                velocity = velocity:rotate(math.rad(angleSlice * i - halfAngle), VEC3_UP)
            }
        )
    end
end



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
Shotgun.spreadAngle = 30