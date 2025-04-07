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
	[1] = -VEC3_X,
    [2] = VEC3_X,
    [3] = VEC3_Y,
    [4] = -VEC3_Y,
}

function Player:server_onCreate()
	print("Player.server_onCreate")
	self.moveKeys = {}

	self.level = 0

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

	local moveDir = self:getMoveDir()
	self.controlled:setMovementDirection(moveDir)

	local moving = moveDir:length2() > 0
	if moving then
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
		self.network:sendToClient(self.player, "cl_updateLevelCount", self.level)
	end
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

	self.healthSlider = Slider():init(self.hud, "healthBar", 100, 100, { sm.color.new("#ff0000") })

	self.hud:open()

	self:cl_cam()

	self.weapons = {}
	self:cl_updateWeaponHud()

	self.isDead = false

	self:cl_updateLevelCount(0)
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
			Gatling
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
			local iconType = type(icon)
			if iconType == "table" then
				self.hud:setItemIcon(widget.."_icon", icon[1], icon[2], icon[3])
			elseif iconType == "Uuid" then
				self.hud:setIconImage(widget.."_icon", icon)
			else
				self.hud:setImage(widget.."_icon", weapon.icon --[[@as string]])
				-- self.hud:playEffect(widget.."_icon", "Weapon")
			end

			self.hud:setText(widget.."_level", tostring(weapon.level))
		end
	end
end

function Player:client_onInteract(char, state)
	if not state then return end
	self.network:sendToServer("sv_revive")
	return true
end

function Player:sv_revive()
	local char = self.controlled.character
	if char:isDowned() then
		char:setTumbling(false)
		char:setDowned(false)
		self.health = self.maxHealth
		self.network:setClientData({ health = self.health, maxHealth = self.maxHealth }, 1)
		return
	end
end

local camOffset = sm.vec3.new(-0.75,-1.25,1.75) * 10
function Player:client_onUpdate(dt)
	local char = self.player.character
	if not self.isLocal or not char then return end

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
		v:update(dt, controlledPos, target and (target.worldPosition - controlledPos):normalize())
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

function Player:cl_updateLevelCount(level)
	self.cl_level = level
	self.hud:setText("level", ("Level %s"):format(level))
end



function Player:getMoveDir()
	local moveDir = sm.vec3.zero()
	for k, v in pairs(self.moveKeys) do
		if v then
			moveDir = moveDir + moveDirs[k]
		end
	end

	return moveDir
end