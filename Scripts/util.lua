---@diagnostic disable:lowercase-global

MINERALDROPS = MINERALDROPS or {}

---@enum ROCKTYPE
ROCKTYPE = {
    ROCK    = 0,
    BORDER  = 1,
    GOLD    = 2,
    NITRA   = 3,
    XP      = 4,
    MORKITE = 5,
}

---@enum ROCKTYPES
ROCKTYPES = {
    [ROCKTYPE.ROCK] =    { 0,  3 },
    [ROCKTYPE.BORDER] =  { 1     },
    [ROCKTYPE.GOLD] =    { 2,  5 },
    [ROCKTYPE.NITRA] =   { 3,  4 },
    --[ROCKTYPE.XP] =    { 4     },
    [ROCKTYPE.MORKITE] = { 5,  6 },
}

---@enum MINERALS
MINERALS = {
    [ROCKTYPE.GOLD]    = "gold",
    [ROCKTYPE.NITRA]   = "nitra",
    [ROCKTYPE.XP]      = "xp",
    [ROCKTYPE.MORKITE] = "morkite",
}

---@enum MINERALCOLOURS
MINERALCOLOURS = {
    [ROCKTYPE.GOLD]    = sm.color.new(1, 1, 0),
    [ROCKTYPE.NITRA]   = sm.color.new(1, 0, 0),
    [ROCKTYPE.XP]      = sm.color.new("#149dff"),
    [ROCKTYPE.MORKITE] = sm.color.new(0, 0, 1),
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
    -- DAMAGE   = 1,
    -- RELOAD   = 2,
    -- PIERCE   = 3,
    -- RANGE    = 4,
    -- LEVEL    = 5,
    -- FIRERATE = 6,
    -- CLIPSIZE = 7,
    -- BOUNCE   = 8,
    -- PELLETS  = 9,
    DAMAGE   = 1,
    RELOAD   = 2,
    PIERCE   = 3,
    FIRERATE = 4,
    CLIPSIZE = 5,
    BOUNCE   = 6,
    PELLETS  = 7,
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
    -- [UPGRADETYPE.RANGE] = {
    --     cardTitle = "Range",
    --     icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
    --     rarities = {
    --         [UPGRADETIER.COMMON]    = { 0.75, 0.10 },
    --         [UPGRADETIER.UNCOMMON]  = { 0.50, 0.15 },
    --         [UPGRADETIER.RARE]      = { 0.25, 0.25 },
    --         [UPGRADETIER.EPIC]      = { 0.15, 0.35 },
    --         [UPGRADETIER.LEGENDARY] = { 0.00, 0.50 },
    --     },
    --     bonusTitle = function(amount)
    --         return ("+%s%% #149dffRANGE"):format(amount * 100)
    --     end,
    --     bonusDescription = "Increase Weapon Level by 1",
    --     restriction = -1,
    --     weaponUpgrade = true,
    --     upgradeWeapon = function(self, weapon, rarity)
    --         weapon.level = weapon.level + 1
    --         -- weapon.damage = weapon.damage * (1 + self.rarities[rarity][2])
    --     end
    -- },
    -- [UPGRADETYPE.LEVEL] = {
    --     cardTitle = "Level",
    --     icon = "$CONTENT_DATA/Gui/WeaponIcons/spudgun.png",
    --     rarities = {
    --         [UPGRADETIER.COMMON]    = { 0.75, 1 },
    --         [UPGRADETIER.UNCOMMON]  = { 0.50, 2 },
    --         [UPGRADETIER.RARE]      = { 0.25, 3 },
    --         [UPGRADETIER.EPIC]      = { 0.15, 4 },
    --         [UPGRADETIER.LEGENDARY] = { 0.00, 5 },
    --     },
    --     bonusTitle = function(amount)
    --         return ("+%s #149dffWEAPON LEVELS"):format(amount)
    --     end,
    --     bonusDescription = "Lets you imagine your weapon is now a lot prettier",
    --     restriction = -1,
    --     weaponUpgrade = true,
    --     upgradeWeapon = function(self, weapon, rarity)
    --         weapon.level = weapon.level + self.rarities[rarity][2]
    --     end
    -- },
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

MINERCLASS = {
    DEMOLITION = 1,
    SCOUT      = 2,
    STUNTMAN   = 3,
}

MINERDATA = {
    [MINERCLASS.DEMOLITION] = {
        hp = 100,
        runSpeedMultiplier = 1,
        mineSpeedMultiplier = 1,
        mineDamage = 3,
        ability = {
            recharge = 10,
            cooldown = 2,
            uses = 2,
            icon = "$CONTENT_DATA/Gui/obj_interactive_propanetank_small.png"
            --{ "ItemIconsSet0", "ItemIcons", "8d3b98de-c981-4f05-abfe-d22ee4781d33" }
        }
    },
    [MINERCLASS.SCOUT] = {
        hp = 50,
        runSpeedMultiplier = 1.5,
        mineSpeedMultiplier = 1,
        mineDamage = 1,
        ability = {
            recharge = 30,
            uses = 1,
            icon = "$CONTENT_DATA/Gui/gui_icon_speed.png"
        }
    },
    [MINERCLASS.STUNTMAN] = {
        hp = 25,
        runSpeedMultiplier = 1.25,
        mineSpeedMultiplier = 1,
        mineDamage = 1,
        ability = {
            recharge = 60,
            cooldown = 15,
            uses = 2,
            icon = "gui_icon_upgrade.png"
        }
    }
}

SIDEMISSION = {
    COLLECTMORKITE = 1
}

SIDEMISSIONDATA = {
    [SIDEMISSION.COLLECTMORKITE] = {
        sobId = sm.uuid.new("085ed313-eb34-4330-a64e-20128dbf61da"),
        title = "COLLECT MORKITE",
        icon = "$CONTENT_DATA/Gui/MineralIcons/morkite.png",
        data = {
            mineralId = ROCKTYPE.MORKITE,
            goal = 40
        }
    }
}



MAXPROJECTILECOUNT = 1000
PROJECTILERANGELIMIT = 50^2

VEC3_X = sm.vec3.new(1,0,0)
VEC3_Y = sm.vec3.new(0,1,0)
VEC3_UP = sm.vec3.new(0,0,1)
VEC3_ONE = sm.vec3.one()
VEC3_ZERO = sm.vec3.zero()

RAD90 = math.rad(90)
RAD30 = math.rad(30)

QUAT_IDENTITY = sm.quat.identity()

unit_miner = sm.uuid.new("eb3d1c56-e2c0-4711-9c8d-218b36d5380b")

hvs_mineralDrop = sm.uuid.new("a09539ba-95d3-4f65-989d-83d1e9c32d0f")
hvs_xpDrop = sm.uuid.new("24b899a3-a663-4da5-b1bf-670ea4bf16a2")
hvs_input = sm.uuid.new("7ebb9c69-3e14-4b4a-83b4-2a8e0b2e8952")

sob_projectileManager = sm.uuid.new("9c287602-9061-4bf5-8db5-58516c348bf0")
sob_eventManager = sm.uuid.new("03ee1a0d-7d6e-4fef-b5c2-71b2cff004bb")

table_insert = table.insert
perlin = sm.noise.perlinNoise2d
random = math.random
abs = math.abs
angleAxis = sm.quat.angleAxis
vec3 = sm.vec3.new
uuid = sm.uuid.new
colour = sm.color.new
getRotation = sm.vec3.getRotation
bezier2 = sm.vec3.bezier2
vec3_lerp = sm.vec3.lerp

function GetYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end

function CalculateRightVector(vector)
    local yaw = math.atan2(vector.y, vector.x) - math.pi / 2
    return vec3(math.cos(yaw), math.sin(yaw), 0)
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



Line = class()
function Line:init( thickness, colour )
    self.effect = sm.effect.createEffect("ShapeRenderable")
	self.effect:setParameter("uuid", blk_plastic)
    self.effect:setParameter("color", colour)
    self.effect:setScale( VEC3_ONE * thickness )

    self.thickness = thickness
	self.spinTime = 0

    return self
end

function Line:update( startPos, endPos, dt, spinSpeed )
	local delta = endPos - startPos
    local length = delta:length()

    if length < 0.0001 then
        sm.log.warning("Line:update() | Length of 'endPos - startPos' must be longer than 0.")
        return
	end

	local rot = getRotation(VEC3_UP, delta)
	local speed = spinSpeed or 1
	self.spinTime = self.spinTime + dt * speed
	rot = rot * angleAxis( math.rad(self.spinTime), VEC3_UP )

	local distance = vec3(self.thickness, self.thickness, length)

	self.effect:setPosition(startPos + delta * 0.5)
	self.effect:setScale(distance)
	self.effect:setRotation(rot)

    if not self.effect:isPlaying() then
        self.effect:start()
    end
end

function Line:stop()
    if self.effect:isPlaying() then
	    self.effect:stop()
    end
end


CurvedLine = class()
function CurvedLine:init( thickness, colours, steps, bendStart, soundEffect )
	self.effects = {}
	for i = 1, steps do
		self.effects[#self.effects+1] = Line():init( thickness, type(colours) == "table" and colours[i] or colours )
	end

	self.thickness = thickness
	self.colours = colours
	self.steps = steps
	self.bendStart = bendStart or 1
	self.activeTime = 0

	if soundEffect then
		self.sound = sm.effect.createEffect( soundEffect )
	end

    return self
end


function CurvedLine:update(startPos, endPos, points)
    for k, v in ipairs(self.effects) do
        if k <= self.steps then
            self.effects[k]:update(k == 1 and startPos or points[k - 1], k == self.steps and endPos or points[k], 0, 0)
        else
            self.effects[k]:stop()
        end
    end
end

function CurvedLine:stop()
    if not self.effects[1].effect:isPlaying() then return end

    for k, v in ipairs(self.effects) do
        self.effects[k]:stop()
    end
end

function CurvedLine:destroy()
    for k, v in ipairs(self.effects) do
        self.effects[k].effect:destroy()
    end
    self.effects = {}
end