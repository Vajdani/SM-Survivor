---@diagnostic disable:lowercase-global

MINERALDROPS = MINERALDROPS or {}

---@enum ROCKTYPES
ROCKTYPES = {
    [0] = { 0,  3 }, --Rock
    [1] = { 1     }, --Border
    [2] = { 2,  5 }, --Gold
    [3] = { 3,  4 }, --Nitra
    --[4] = { 4     }, --XP
}

---@enum ROCKTYPE
ROCKTYPE = {
    ROCK    = 0,
    BORDER  = 1,
    GOLD    = 2,
    NITRA   = 3,
    XP      = 4,
}

---@enum MINERALS
MINERALS = {
    [ROCKTYPE.GOLD]  = "gold",
    [ROCKTYPE.NITRA] = "nitra",
    [ROCKTYPE.XP]    = "xp",
}

---@enum MINERALCOLOURS
MINERALCOLOURS = {
    [ROCKTYPE.GOLD]  = sm.color.new(1,1,0),
    [ROCKTYPE.NITRA] = sm.color.new(1,0,0),
    [ROCKTYPE.XP]    = sm.color.new("#149dff"),
}

---@enum UPGRADETIER
UPGRADETIER = {
    COMMON    = 1,
    UNCOMMON  = 2,
    RARE      = 3,
    EPIC      = 4,
    LEGENDARY = 5,
}

---@enum UPGRADETIERDATA
UPGRADETIERDATA = {
    [UPGRADETIER.COMMON]    = { "COMMON",       sm.color.new(0.4, 0.4, 0.4) },
    [UPGRADETIER.UNCOMMON]  = { "UNCOMMON",     sm.color.new(0, 1, 0)       },
    [UPGRADETIER.RARE]      = { "RARE",         sm.color.new("#149dff")     },
    [UPGRADETIER.EPIC]      = { "EPIC",         sm.color.new("#8E00D6")     },
    [UPGRADETIER.LEGENDARY] = { "LEGENDARY",    sm.color.new(1, 0, 0)       },
}

---@enum UPGRADETYPE
UPGRADETYPE = {
    DAMAGE   = 1,
    RELOAD   = 2,
    PIERCE   = 3,
    RANGE    = 4,
    LEVEL    = 5,
    FIRERATE = 6,
    CLIPSIZE = 7,
    BOUNCE   = 8,
    PELLETS  = 9,
}

---@enum UPGRADES
UPGRADES = {
    [UPGRADETYPE.DAMAGE] = {
        cardTitle = "Damage",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 0.10 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 0.15 },
            [UPGRADETIER.RARE]      = { 0.25, 0.25 },
            [UPGRADETIER.EPIC]      = { 0.15, 0.35 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 0.50 },
        },
        bonusTitle = function(amount)
            return ("+%s%% #149dffDAMAGE"):format(amount * 100)
        end,
        bonusDescription = "Increase Weapon Level by 1",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + 1
            weapon.damage = weapon.damage * (1 + self.rarities[rarity][2])
        end
    },
    [UPGRADETYPE.RELOAD] = {
        cardTitle = "Reload speed",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 0.10 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 0.15 },
            [UPGRADETIER.RARE]      = { 0.25, 0.25 },
            [UPGRADETIER.EPIC]      = { 0.15, 0.35 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 0.50 },
        },
        bonusTitle = function(amount)
            return ("+%s%% #149dffRELOAD SPEED"):format(amount * 100)
        end,
        bonusDescription = "Increase Weapon Level by 1",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + 1
            weapon.reloadTime = weapon.reloadTime * self.rarities[rarity][2]
            weapon.reloadTimer = weapon.reloadTime
            weapon.clip = weapon.clipSize
            weapon.slider.steps_reloading = weapon.reloadTime
        end
    },
    [UPGRADETYPE.PIERCE] = {
        cardTitle = "Piercing",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 1 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 2 },
            [UPGRADETIER.RARE]      = { 0.25, 3 },
            [UPGRADETIER.EPIC]      = { 0.15, 4 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 5 },
        },
        bonusTitle = function(amount)
            return ("+%s #149dffTARGETS PIERCED"):format(amount)
        end,
        bonusDescription = "Increase Weapon Level by 1",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + 1
            weapon.pierceLimit = weapon.pierceLimit  + self.rarities[rarity][2]
        end
    },
    [UPGRADETYPE.RANGE] = {
        cardTitle = "Range",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 0.10 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 0.15 },
            [UPGRADETIER.RARE]      = { 0.25, 0.25 },
            [UPGRADETIER.EPIC]      = { 0.15, 0.35 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 0.50 },
        },
        bonusTitle = function(amount)
            return ("+%s%% #149dffRANGE"):format(amount * 100)
        end,
        bonusDescription = "Increase Weapon Level by 1",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + 1
            -- weapon.damage = weapon.damage * (1 + self.rarities[rarity][2])
        end
    },
    [UPGRADETYPE.LEVEL] = {
        cardTitle = "Level",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 1 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 2 },
            [UPGRADETIER.RARE]      = { 0.25, 3 },
            [UPGRADETIER.EPIC]      = { 0.15, 4 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 5 },
        },
        bonusTitle = function(amount)
            return ("+%s #149dffWEAPON LEVELS"):format(amount)
        end,
        bonusDescription = "Lets you imagine your weapon is now a lot prettier",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + self.rarities[rarity][2]
        end
    },
    [UPGRADETYPE.FIRERATE] = {
        cardTitle = "Fire rate",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 0.10 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 0.15 },
            [UPGRADETIER.RARE]      = { 0.25, 0.25 },
            [UPGRADETIER.EPIC]      = { 0.15, 0.35 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 0.50 },
        },
        bonusTitle = function(amount)
            return ("+%s%% #149dffFIRING RATE"):format(amount * 100)
        end,
        bonusDescription = "Increase Weapon Level by 1",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + 1
            weapon.fireCooldown = weapon.fireCooldown * self.rarities[rarity][2]
        end
    },
    [UPGRADETYPE.CLIPSIZE] = {
        cardTitle = "Clipsize",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 1 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 3 },
            [UPGRADETIER.RARE]      = { 0.25, 6 },
            [UPGRADETIER.EPIC]      = { 0.15, 9 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 12 },
        },
        bonusTitle = function(amount)
            return ("+%s #149dffCLIPSIZE"):format(amount)
        end,
        bonusDescription = "Increase Weapon Level by 1",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + 1
            weapon.clipSize = weapon.clipSize + self.rarities[rarity][2]
            weapon.slider.steps = weapon.clipSize
        end
    },
    [UPGRADETYPE.BOUNCE] = {
        cardTitle = "Bouncing",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 1 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 2 },
            [UPGRADETIER.RARE]      = { 0.25, 3 },
            [UPGRADETIER.EPIC]      = { 0.15, 4 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 5 },
        },
        bonusTitle = function(amount)
            return ("+%s #149dffTIMES BOUNCED"):format(amount)
        end,
        bonusDescription = "Increase Weapon Level by 1",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + 1
            weapon.bounceLimit = weapon.bounceLimit + self.rarities[rarity][2]
        end
    },
    [UPGRADETYPE.PELLETS] = {
        cardTitle = "Pellets",
        icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
        rarities = {
            [UPGRADETIER.COMMON]    = { 0.75, 1 },
            [UPGRADETIER.UNCOMMON]  = { 0.50, 2 },
            [UPGRADETIER.RARE]      = { 0.25, 3 },
            [UPGRADETIER.EPIC]      = { 0.15, 4 },
            [UPGRADETIER.LEGENDARY] = { 0.00, 5 },
        },
        bonusTitle = function(amount)
            return ("+%s #149dffPELLETS FIRED"):format(amount)
        end,
        bonusDescription = "Increase Weapon Level by 1",
        restriction = -1,
        weaponUpgrade = true,
        upgradeWeapon = function(self, weapon, rarity)
            weapon.level = weapon.level + 1

            local pellets = self.rarities[rarity][2]
            weapon.pelletCount = weapon.pelletCount + pellets
            weapon.spreadAngle = weapon.spreadAngle + pellets / 2
        end
    },
}

VEC3_X = sm.vec3.new(1,0,0)
VEC3_Y = sm.vec3.new(0,1,0)
VEC3_UP = sm.vec3.new(0,0,1)
VEC3_ONE = sm.vec3.one()

RAD90 = math.rad(90)
RAD30 = math.rad(30)

QUAT_IDENTITY = sm.quat.identity()

unit_miner = sm.uuid.new("eb3d1c56-e2c0-4711-9c8d-218b36d5380b")

hvs_mineralDrop = sm.uuid.new("a09539ba-95d3-4f65-989d-83d1e9c32d0f")
hvs_xpDrop = sm.uuid.new("24b899a3-a663-4da5-b1bf-670ea4bf16a2")

table_insert = table.insert
perlin = sm.noise.perlinNoise2d
random = math.random
abs = math.abs
angleAxis = sm.quat.angleAxis
vec3 = sm.vec3.new
uuid = sm.uuid.new
colour = sm.color.new

function GetYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end

---@param position Vec3
function DropXP(position)
    local drop = sm.harvestable.create(hvs_xpDrop, vec3(position.x, position.y, 0), angleAxis(math.rad(math.random(1, 360)), VEC3_UP))
    drop:setParams({ type = ROCKTYPE.XP, amount = math.random(1, 2) })
end

---@param gui GuiInterface
---@param widget string
---@param icon string|Uuid|string[]
function SetGuiIcon(gui, widget, icon)
    local iconType = type(icon)
    if iconType == "table" then
        gui:setItemIcon(widget, icon[1], icon[2], icon[3])
    elseif iconType == "Uuid" then
        gui:setIconImage(widget, icon)
    else
        gui:setImage(widget, icon)
    end
end