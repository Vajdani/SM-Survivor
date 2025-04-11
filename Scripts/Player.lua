dofile "util.lua"
dofile "weapon/Weapon.lua"
dofile "gui/Slider.lua"

---@class Player : PlayerClass
---@field input Harvestable
---@field controlled Unit
---@field cl_controlled Character
---@field weapons Weapon[]
---@field xpBar Slider
Player = class( nil )

local verticalOffset = 10
local moveDirs = {
	[0] = {
		[1] = function() return -VEC3_X end,
		[2] = function() return VEC3_X end,
		[3] = function() return VEC3_Y end,
		[4] = function() return -VEC3_Y end,
	},
	[1] = {
		[1] = function() return -VEC3_X:rotate(math.rad(-30), VEC3_UP) end,
		[2] = function() return VEC3_X:rotate(math.rad(-30), VEC3_UP) end,
		[3] = function() return VEC3_Y:rotate(math.rad(-30), VEC3_UP) end,
		[4] = function() return -VEC3_Y:rotate(math.rad(-30), VEC3_UP) end,
	},
	[2] = {
		[1] = function(char)
			return char.direction:rotate(math.rad(90), VEC3_UP)
		end,
		[2] = function(char)
			return char.direction:rotate(math.rad(-90), VEC3_UP)
		end,
		[3] = function(char)
			return char.direction
		end,
		[4] = function(char)
			return -char.direction
		end,
	},
}

function Player:server_onCreate()
	print("Player.server_onCreate")
	self.moveKeys = {}
	self.controlMethod = 0

	self.level = 0
	self.collectCharges = 0

	self.health = 100
	self.maxHealth = 100
	self.network:setClientData({ health = self.health, maxHealth = self.maxHealth }, 1)

	self.player.publicData = {}

	self:sv_initMaterials()
end

function Player:sv_takeDamage(damage)
	self.health = self.health - damage
	print(self.player, self.health, "/", self.maxHealth)

	if self.health <= 0 then
		print(self.player, "died")
		local char = self.controlled.character
		char:setTumbling(true)
		char:setDowned(true)
	end

	self.network:setClientData({ health = self.health, maxHealth = self.maxHealth }, 1)
end

function Player:server_onFixedUpdate(dt)
	-- print(#sm.unit.getAllUnits())
	local char = self.player.character
	if not char or not sm.exists(char) then return end

	if not self.input or not sm.exists(self.input) then return end

	local pos = self.controlled.character.worldPosition
	self.input:setPosition(sm.vec3.new(pos.x, pos.y, -verticalOffset))

	local moveDir = self:GetMoveDir()
	self.controlled:setMovementDirection(moveDir)

	local moving = moveDir:length2() > 0
	if self.controlMethod == 2 then
		local dir = char.direction
		dir.z = 0
		self.controlled:setFacingDirection(dir:normalize())
	elseif moving then
		self.controlled:setFacingDirection(moveDir)
	end

	self.controlled:setMovementType(moving and "walk" or "stand")
end

function Player:sv_createMiner(pos)
	--Thank Axolot for this mess
	if not sm.exists(self.player.character) then
		sm.event.sendToPlayer(self.player, "sv_createMiner", pos)
		return
	end

	self:sv_initMaterials()

	self.input = sm.harvestable.create(sm.uuid.new("7ebb9c69-3e14-4b4a-83b4-2a8e0b2e8952"), pos)
	self.controlled = sm.unit.createUnit(sm.uuid.new("eb3d1c56-e2c0-4711-9c8d-218b36d5380b"), pos)
	self.controlled.publicData = { owner = self.player }
	self.player.publicData.miner = self.controlled
	self:sv_seat()
end

function Player:sv_seat()
	if not sm.exists(self.input) then
		sm.event.sendToPlayer(self.player, "sv_seat")
		return
	end

	self.input:setSeatCharacter(self.player.character)
	self.network:setClientData({ controlled = self.controlled.character }, 2)
end

function Player:sv_onMove(data)
	self.moveKeys[data.key] = data.state
end

function Player:sv_initMaterials()
	self.minerals = {}
	for k, v in pairs(MINERALS) do
		self.minerals[k] = 0
	end
	self.network:sendToClient(self.player, "cl_updateMineralCount", self.minerals)
end

function Player:sv_collectMineral(data)
	local type = data.type
	local newAmount = self.minerals[type] + data.amount
	local lastLevel = self.level
	if type == ROCKTYPE.XP and newAmount >= 100 then
		for i = 1, math.floor(newAmount / 100) do
			newAmount = newAmount - 100
			self.level = self.level + 1
		end
	end

	self.minerals[type] = newAmount
	self.network:sendToClient(self.player, "cl_updateMineralCount", self.minerals)

	if self.level ~= lastLevel then
		if self.level % 5 == 0 then
			self.collectCharges = self.collectCharges + 1
		end

		self.network:sendToClient(self.player, "cl_updateLevelCount", { self.level, self.level - lastLevel, self.collectCharges })
		return true
	end

	return false
end

function Player:sv_interact()
	local char = self.controlled.character
	if char:isDowned() then
		char:setTumbling(false)
		char:setDowned(false)
		self.health = self.maxHealth
		self.network:setClientData({ health = self.health, maxHealth = self.maxHealth }, 1)
		return
	end

	if self.collectCharges > 0 then
		local pos = char.worldPosition
		sm.effect.playEffect("Part - Upgrade", pos)

		self.collectCharges = self.collectCharges - 1

		-- local xp = 0
		-- local contacts = sm.physics.getSphereContacts(pos, 100)
		-- for k, v in pairs(contacts.harvestables) do
		-- 	if MINERALDROPS[v.id] == true then
		-- 		xp = xp + v.publicData.amount
		-- 		v:destroy()
		-- 	end
		-- end

		-- if not self:sv_collectMineral({ type = ROCKTYPE.XP, amount = xp }) then
		-- 	self.network:sendToClient(self.player, "cl_updateLevelCount", { self.level, 0, self.collectCharges })
		-- end

		local contacts = sm.physics.getSphereContacts(pos, 100)
		for k, v in pairs(contacts.harvestables) do
			if MINERALDROPS[v.id] == true then
				sm.event.sendToHarvestable(v, "sv_onCollect", char)
			end
		end
	end
end

function Player:sv_setControlMethod(method)
	self.controlMethod = method
end



function Player:client_onCreate()
	self.isLocal = self.player == sm.localPlayer.getPlayer()
	if not self.isLocal then return end

	self.hud = sm.gui.createGuiFromLayout(
		"$CONTENT_DATA/Gui/hud.layout", false,
		{
			isHud = true,
			isInteractive = false,
			needsCursor = false,
			hidesHotbar = true,
			isOverlapped = false,
			backgroundAlpha = 0,
		}
	)

	for k, v in pairs(MINERALS) do
		if k ~= ROCKTYPE.XP then
			self.hud:setImage("icon_"..v, string.format("$CONTENT_DATA/Gui/MineralIcons/%s.png",v))
		end
	end
	self.hud:setImage("icon_magnet", "$GAME_DATA/Gui/Editor/ed_icon_transform_origin.png")
	self.healthSlider = Slider():init(self.hud, "healthBar", 100, 100, { sm.color.new("#ff0000") })
	self.hud:open()

	self:cl_cam()

	self.weapons = {}
	self:cl_updateWeaponHud()

	self.isDead = false

	self.cl_collectCharges = 0
	self.upgradeQueue = 0
	self.upgradesGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/upgrades.layout", false, {
		isHud = false,
		isInteractive = true,
		needsCursor = true,
		hidesHotbar = true,
		isOverlapped = true,
		backgroundAlpha = 0.5,
	})

	self.upgradesGui:setOnCloseCallback("cl_upgradeClosed")
	for i = 1, 5 do
		self.upgradesGui:setButtonCallback("card"..i, "cl_upgradeSelected")
	end

	self:cl_updateLevelCount({ 0, 0, 0 })
end

function Player:client_onClientDataUpdate(data, channel)
	if not self.isLocal then return end

	if channel == 1 then
		local health = data.health
		self.hud:setText("healthText", ("HP %s/%s"):format(math.max(health, 0), data.maxHealth))
		self.healthSlider:update(math.max(health - 1, 0))
		self.isDead = health <= 0
	else
		self.cl_controlled = data.controlled
		self.enemyTrigger = sm.areaTrigger.createBox(sm.vec3.new(20, 20, 1), sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.character)
	end
end

function Player:client_onReload()
	if #self.weapons > 0 then
		self.weapons = {}
	else
		local weapons = {
			Spudgun,
			Shotgun,
			Gatling,
			WeldTool
		}

		for k, v in pairs(weapons) do
			self.weapons[k] = v():init(k, self.hud)
		end
	end

	self:cl_updateWeaponHud()

	return true
end

function Player:cl_updateWeaponHud()
	for i = 1, 4 do
		local widget = "weapon"..i
		local weapon = self.weapons[i]
		local display = weapon ~= nil
		self.hud:setVisible(widget, display)

		if display then
			local icon = weapon.icon
			SetGuiIcon(self.hud, widget.."_icon", icon)
			self.hud:setText(widget.."_level", tostring(weapon.level))
		end
	end
end

function Player:client_onInteract(char, state)
	if not state then return end
	self.network:sendToServer("sv_interact")
	return true
end

local camOffset = sm.vec3.new(-0.75,-1.25,1.75) * 10
function Player:client_onUpdate(dt)
	-- print(self.weapons[2].fireCooldown)
	local char = self.player.character
	if not self.isLocal or not char then return end

	if self.cl_collectCharges > 0 then
		sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true), "Attract XP orbs", "")
	end

	if self.cam ~= 3 then return end
	local charPos = char.worldPosition + VEC3_UP * verticalOffset
	local newPos = charPos + camOffset * self.zoom
	sm.camera.setPosition(sm.vec3.lerp(sm.camera.getPosition(), newPos, dt * 15))
	sm.camera.setDirection(charPos - newPos)

	-- sm.camera.setPosition(char.worldPosition + VEC3_UP * (verticalOffset + char:getHeight() * 1.5))
	-- sm.camera.setDirection(char.direction)
end

function Player:client_onFixedUpdate(dt)
	if not self.isLocal or self.isDead then return end

	local controlledChar = self.cl_controlled
	if not controlledChar or not sm.exists(controlledChar) then return end

	local controlledPos = controlledChar.worldPosition + controlledChar.velocity * dt
	self.enemyTrigger:setWorldPosition(controlledPos)

	local enemies = self.enemyTrigger:getContents()
	local targets = {}
	--local velocity = target and target.velocity
	for k, v in pairs(self.weapons) do
		local funcId = v.targetFunctionId
		if targets[funcId] == nil then
			targets[funcId] = { WeaponTargetFunctions[funcId](enemies, controlledPos, controlledChar) }
		end

		local target = targets[funcId][1]
		-- local distance = sm.vec3.zero()
		-- if target then
		-- 	distance = target.worldPosition + velocity * dt - controlledPos
		-- 	distance = distance + velocity * v.projectileVelocity / distance:length() * dt
		-- 	sm.particle.createParticle("paint_smoke",  target.worldPosition + velocity * dt)
		-- end

		-- v:update(dt, controlledPos, target and distance:normalize())
		-- v:update(dt, controlledPos, controlledChar.direction)
		if target then
			local dir = target.worldPosition - controlledPos
			dir.z = 0
			v:update(dt, controlledPos, dir:normalize())
		else
			v:update(dt, controlledPos)
		end
	end
end

function Player:cl_cam()
	self.zoom = 1
	self.cam = self.cam == 3 and 0 or 3
	sm.camera.setCameraState(self.cam)
	sm.camera.setFov(45)
end

function Player:cl_increaseZoom()
	self.zoom = self.zoom > 1 and self.zoom - 1 or 1
end

function Player:cl_decreaseZoom()
	self.zoom = self.zoom < 100 and self.zoom + 1 or 100
end

function Player:cl_setControlMethod(method)
	self.cl_controlMethod = method
	self.network:sendToServer("sv_setControlMethod", method)
end

function Player:cl_updateMineralCount(data)
	for k, v in pairs(data) do
		if k == ROCKTYPE.XP then
			if not self.xpBar then
				self.xpBar = Slider():init(self.hud, "icon_xp", 100, 100, { MINERALCOLOURS[ROCKTYPE.XP] })
			end

			self.xpBar:update(v)
			self.hud:setText("amount_"..MINERALS[k], ("%s%%"):format(v))
		else
			self.hud:setText("amount_"..MINERALS[k], tostring(v))
		end
	end
end

function Player:cl_updateLevelCount(data)
	local level, diff = data[1], data[2]
	self.cl_level = level
	self.hud:setText("level",			("Level %s"):format(level))

	self.cl_collectCharges = data[3]
	self.hud:setText("amount_magnet",	tostring(data[3]))

	if diff == 0 then return end

	self.upgradeQueue = self.upgradeQueue + diff
	if self.upgradesGui:isActive() then return end

	self:cl_processUpgradeQueue()
end

function Player:cl_processUpgradeQueue()
	self.hud:close()

	local weaponsByRestriction = self:GetWeaponRestrictionList()

	self.rolledUpgrades = {}
	for i = 1, 5 do
		local weapon, upgrade, upgradeId, rarity
		repeat
			upgradeId = math.random(#UPGRADES)
			local rolled = UPGRADES[upgradeId]
			local weapons = weaponsByRestriction[rolled.restriction]
			if not rolled.weaponUpgrade or weapons and #weapons > 0 then
				local chance = math.random()
				for k, v in ipairs( rolled.rarities ) do
					if chance >= v[1] then
						rarity = k
						break
					end
				end

				if rarity then
					upgrade = rolled

					if rolled.weaponUpgrade then
						weapon = self.weapons[weapons[math.random(#weapons)]]
					end
				end
			end
		until (upgrade ~= nil)

		local widget = "card"..i
		self.rolledUpgrades[widget] = { upgradeId, rarity, weapon and weapon.id }

		self.upgradesGui:setText(widget.."_title", 				upgrade.cardTitle)

		local isWeaponUpgrade = upgrade.weaponUpgrade
		self.upgradesGui:setVisible(widget.."_weaponIcon", 		isWeaponUpgrade)
		self.upgradesGui:setVisible(widget.."_icon_weapon",		isWeaponUpgrade)
		self.upgradesGui:setVisible(widget.."_icon_general", 	not isWeaponUpgrade)
		if isWeaponUpgrade then
			SetGuiIcon(self.upgradesGui, widget.."_weaponIcon",		weapon.icon)
			SetGuiIcon(self.upgradesGui, widget.."_icon_weapon",	upgrade.icon)
		else
			SetGuiIcon(self.upgradesGui, widget.."_icon_general",	upgrade.icon)
		end

		SetGuiIcon(self.upgradesGui, widget.."_icon", 			upgrade.icon)

		local tier = UPGRADETIERDATA[rarity]
		self.upgradesGui:setColor(widget.."_tierColour", 		tier[2])
		self.upgradesGui:setText(widget.."_tierTitle", 			tier[1])

		self.upgradesGui:setText(widget.."_bonusTitle", 		upgrade.bonusTitle(upgrade.rarities[rarity][2]))
		self.upgradesGui:setText(widget.."_bonusDescription", 	upgrade.bonusDescription)
	end

	self.upgradesGui:open()
end

function Player:cl_upgradeSelected(button)
	local data = self.rolledUpgrades[button]
	local upgradeId = data[1]
	local upgrade = UPGRADES[upgradeId]
	if upgrade.weaponUpgrade then
		local weaponId = data[3]
		local lastLevel = self.weapons[weaponId].level
		upgrade:upgradeWeapon(self.weapons[weaponId], data[2])

		if math.floor(lastLevel / 6) ~= math.floor(self.weapons[weaponId].level / 6) then
			print("overclock")
			-- for i = 1, math.floor(self.weapons[weaponId].level / 6) do
			-- 	self.weapons[weaponId].level = self.weapons[weaponId].level - 6
			-- 	print("overclock")
			-- end
		end
	else

	end

	self.upgradeQueue = self.upgradeQueue - 1
	if self.upgradeQueue == 0 then
		self:cl_updateWeaponHud()

		self.upgradesGui:close()
		self.hud:open()
	else
		self:cl_processUpgradeQueue()
	end
end

function Player:cl_upgradeClosed()
	if not self.hud:isActive() then
		self.hud:open()
	end
end



function Player:GetMoveDir()
	local char = self.controlled.character
	local moveDir = sm.vec3.zero()
	local moveDirSet = moveDirs[self.controlMethod]
	for k, v in pairs(self.moveKeys) do
		if v then
			moveDir = moveDir + moveDirSet[k](char)
		end
	end

	return moveDir
end

function Player:GetWeaponRestrictionList()
	local weaponsByRestriction = {
		[-1] = {}
	}
	for k, v in pairs(self.weapons) do
		local type = v.damageType
		weaponsByRestriction[type] = weaponsByRestriction[type] or {}

		table_insert(weaponsByRestriction[type], v.id)
		table_insert(weaponsByRestriction[-1], v.id)
	end

	return weaponsByRestriction
end