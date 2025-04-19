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

local camOffset = sm.vec3.new(-0.75,-1.25,1.75) * 10
local verticalOffset = 10
local moveDirs = {
	[0] = {
		[1] = -VEC3_X,
		[2] =  VEC3_X,
		[3] =  VEC3_Y,
		[4] = -VEC3_Y,
	},
	[1] = {
		[1] =  VEC3_X:rotate(math.atan2(camOffset.y, camOffset.x) - math.pi * 0.5, VEC3_UP),
		[2] = -VEC3_X:rotate(math.atan2(camOffset.y, camOffset.x) - math.pi * 0.5, VEC3_UP),
		[3] = -VEC3_Y:rotate(math.atan2(camOffset.y, camOffset.x) - math.pi * 0.5, VEC3_UP),
		[4] =  VEC3_Y:rotate(math.atan2(camOffset.y, camOffset.x) - math.pi * 0.5, VEC3_UP),
	},
	[2] = {
		[1] = function(char)
			return char.direction:rotate(RAD90, VEC3_UP)
		end,
		[2] = function(char)
			return char.direction:rotate(-RAD90, VEC3_UP)
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

	local saved = self.storage:load()
	local minerData
	if saved then
		self.level = saved.level
		self.collectCharges = saved.collectCharges
		self.controlled = saved.controlled
		self.health = saved.hp
		self.maxHealth = saved.maxHp
		self.classId = saved.classId
		self.minerals = saved.minerals
		self.selectedUpgrades = saved.selectedUpgrades

		minerData = MINERDATA[self.classId]

		self:sv_loadMiner()

		if #self.selectedUpgrades > 0 then
			self.network:sendToClient(self.player, "cl_reapplyUpgrades", self.selectedUpgrades)
		end

		self.network:sendToClient(self.player, "cl_updateLevelCount", { self.level, 0, self.collectCharges })
	else
		self.level = 0
		self.collectCharges = 0
		self.classId = MINERCLASS.DEMOLITION

		minerData = MINERDATA[self.classId]
		self.health = minerData.hp
		self.maxHealth = minerData.hp
	end

	self.network:setClientData({ health = self.health, maxHealth = self.maxHealth, classId = self.classId }, 1)

	self.player.publicData = {
		runSpeedMultiplier = minerData.runSpeedMultiplier,
		mineSpeedMultiplier = minerData.mineSpeedMultiplier,
		mineDamage = minerData.mineDamage
	}

	self:sv_initMaterials()
	self:sv_save()
end

function Player:sv_save()
	self.storage:save({
		level = self.level,
		collectCharges = self.collectCharges,
		controlled = self.controlled,
		hp = self.health,
		maxHp = self.maxHealth,
		classId = self.classId,
		minerals = self.minerals,
		selectedUpgrades = self.selectedUpgrades
	})
end

function Player:sv_saveUpgrades(upgrades)
	self.selectedUpgrades = upgrades
	self:sv_save()
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

function Player:server_onFixedUpdate()
	if self.speedBoostTime and sm.game.getServerTick() > self.speedBoostTime then
		self.speedBoostTime = nil
	end

	local pChar = self.player.character
	if not pChar or not sm.exists(pChar) then return end
	if not self.input or not sm.exists(self.input) then return end

	local cChar = self.controlled.character
	if not cChar or not sm.exists(cChar) then return end

	local pos = cChar.worldPosition
	if pos.z < -5 then
		pos = vec3(pos.x, pos.y, 0.5)
		cChar:setWorldPosition(pos)
	end

	self.input:setPosition(sm.vec3.new(pos.x, pos.y, -verticalOffset))

	if self.isJumping and sm.game.getServerTick() - self.jumpTick >= 5 and cChar.velocity.z < 0 then
		local hit, result = sm.physics.spherecast(pos, pos - VEC3_UP, 0.5, cChar)
		if hit and result.type ~= "limiter" then
			local contacts = sm.physics.getSphereContacts(pos, 3.5)
			for k, v in pairs(contacts.harvestables) do
				if not MINERALDROPS[v.id] then
					sm.event.sendToHarvestable(v, "sv_onHit", 100)
				end
			end

			for k, v in pairs(contacts.characters) do
				if not v:isPlayer() and v ~= cChar then
					sm.event.sendToUnit(v:getUnit(), "sv_onHit", { damage = 1000, impact = (v.worldPosition - pos):normalize() * 10, hitPos = v.worldPosition })
				end
			end

			self.isJumping = false
			self.controlled:sendCharacterEvent("land")
			sm.event.sendToUnit(self.controlled, "sv_setMiningEnabled", true)
		end
	end

	local moveDir = self:GetMoveDir()
	self.controlled:setMovementDirection(moveDir)

	local moving = moveDir:length2() > 0
	if self.controlMethod == 2 then
		local dir = pChar.direction
		dir.z = 0
		self.controlled:setFacingDirection(dir:normalize())
	elseif moving then
		self.controlled:setFacingDirection(moveDir)
	end

	local moveType = "stand"
	if moving then
		if self.speedBoostTime then
			moveType = "sprint"
		else
			moveType = "walk"
		end
	end

	self.controlled:setMovementType(moveType)
end

function Player:sv_createMiner(pos)
	--Thank Axolot for this mess
	if not sm.exists(self.player.character) then
		sm.event.sendToPlayer(self.player, "sv_createMiner", pos)
		return
	end

	self:sv_initMaterials()

	self.input = sm.harvestable.create(hvs_input, pos)
	self.controlled = sm.unit.createUnit(unit_miner, pos, 0, { classId = self.classId, owner = self.player })
	self.controlled.publicData = { owner = self.player }
	self.player.publicData.miner = self.controlled
	self:sv_seat()

	self:sv_save()
end

function Player:sv_loadMiner()
	if not sm.exists(self.player.character) then
		sm.event.sendToPlayer(self.player, "sv_loadMiner")
		return
	end

	self.input = sm.harvestable.create(hvs_input, -VEC3_UP * verticalOffset)
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
	if not self.minerals then
		self.minerals = {}
		for k, v in pairs(MINERALS) do
			self.minerals[k] = 0
		end
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
			if self.level % 5 == 0 then
				self.collectCharges = self.collectCharges + 1
			end
		end
	end

	self.minerals[type] = newAmount
	self.network:sendToClient(self.player, "cl_updateMineralCount", self.minerals)

	self:sv_save()

	if self.level ~= lastLevel then
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
		local xp = 0
		local contacts = sm.physics.getSphereContacts(pos, 100)
		for k, v in pairs(contacts.harvestables) do
			if MINERALDROPS[v.id] == true then
				xp = xp + v.publicData.amount
				v:destroy()
			end
		end

		if xp > 0 then
			sm.effect.playEffect("Part - Upgrade", pos)

			self.collectCharges = self.collectCharges - 1
			if not self:sv_collectMineral({ type = ROCKTYPE.XP, amount = xp }) then
				self.network:sendToClient(self.player, "cl_updateLevelCount", { self.level, 0, self.collectCharges })
			end
		end

		-- local contacts = sm.physics.getSphereContacts(pos, 100)
		-- for k, v in pairs(contacts.harvestables) do
		-- 	if MINERALDROPS[v.id] == true then
		-- 		sm.event.sendToHarvestable(v, "sv_onCollect", char)
		-- 	end
		-- end

		self:sv_save()
	end
end

function Player:sv_setControlMethod(method)
	self.controlMethod = method
end

function Player:sv_refreshClass()
	local minerData = MINERDATA[self.classId]
	self.health = minerData.hp
	self.maxHealth = minerData.hp
	self.player.publicData = {
		runSpeedMultiplier = minerData.runSpeedMultiplier,
		mineSpeedMultiplier = minerData.mineSpeedMultiplier,
		mineDamage = minerData.mineDamage,
		miner = self.controlled
	}
	self.network:setClientData({ health = self.health, maxHealth = self.maxHealth, classId = self.classId, hipleaserefresh = math.random() }, 1)
end

function Player:sv_newClass()
	self.classId = (self.classId % #MINERDATA) + 1
	self:sv_refreshClass()
	self.network:setClientData({ health = self.health, maxHealth = self.maxHealth, classId = self.classId }, 1)
    sm.event.sendToCharacter(self.controlled.character, "sv_init", { classId = self.classId, owner = self.player })
end


function Player:sv_useAbility()
	if self.controlled.character:isDowned() then return end

	if self.classId == MINERCLASS.DEMOLITION then
		self.controlled:sendCharacterEvent("throw")
		sm.event.sendToUnit(self.controlled, "sv_setMiningEnabled", false)
	elseif self.cl_classId == MINERCLASS.SCOUT then
		self.speedBoostTime = sm.game.getServerTick() + 500 * 40
		--self.player.publicData.runSpeedMultiplier = 3
	elseif self.cl_classId == MINERCLASS.STUNTMAN then
		local char = self.controlled.character
		local jumpDir = self:GetMoveDir()
		-- if jumpDir == VEC3_ZERO then
		-- 	jumpDir = char.direction
		-- end

		sm.physics.applyImpulse(char, (VEC3_UP * 2 + jumpDir * 2) * char.mass * 10)
		self.isJumping = true
		self.jumpTick = sm.game.getServerTick()

		sm.effect.playEffect("Stuntman - Jump", char.worldPosition)
		self.controlled:sendCharacterEvent("jump")
		sm.event.sendToUnit(self.controlled, "sv_setMiningEnabled", false)
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
	self.hud:setImage("icon_magnet", "$GAME_DATA/Gui/Editor/ed_icon_transform_origin.png")
	self.hud:open()

	self:cl_cam()

	self.weapons = {}
	self:cl_initWeapons()
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

	self.cl_selectedUpgrades = {}

	self.abilityRecharge = 0
	self.abilityUses = 0
	self.abilityMaxUses = 0

	self:cl_updateLevelCount({ 0, 0, 0 })
end

function Player:client_onClientDataUpdate(data, channel)
	if not self.isLocal then return end

	if channel == 1 then
		local health = data.health
		local maxHealth = data.maxHealth
		self.hud:setText("healthText", ("%sHP %s/%s       "):format(("   "):rep(#tostring(maxHealth) - #tostring(health)), math.max(health, 0), maxHealth))
		if not self.healthSlider then
			self.healthSlider = Slider():init(self.hud, "healthBar", maxHealth, maxHealth, { sm.color.new("#ff0000") })
		end
		self.healthSlider.steps, self.healthSlider.steps_reloading = maxHealth, maxHealth
		self.healthSlider:update_shooting(math.max(health, 0))

		self.isDead = health <= 0

		if data.classId then
			self.cl_classId = data.classId

			local ability = MINERDATA[self.cl_classId].ability
			self.abilityCooldown = ability.cooldown
			self.abilityCooldownTimer = nil
			self.abilityRecharge = ability.recharge
			self.abilityRechargeTimer = nil
			self.abilityUses = ability.uses
			self.abilityMaxUses = ability.uses

			SetGuiIcon(self.hud, "icon_ability", ability.icon)
			self:cl_updateAbilityHud()
		end
	else
		self.cl_controlled = data.controlled
		self.enemyTrigger = sm.areaTrigger.createBox(vec3(20, 20, 1), VEC3_ZERO, QUAT_IDENTITY, sm.areaTrigger.filter.character)
	end
end

function Player:client_onReload()
	if self.cl_controlled:isDowned() or
	   self.abilityRechargeTimer or
	   self.abilityCooldownTimer or
	   self.cl_classId == MINERCLASS.STUNTMAN and not self.cl_controlled:isOnGround() then
		return true
	end

	self.network:sendToServer("sv_useAbility")

	self.abilityUses = self.abilityUses - 1
	if self.abilityUses <= 0 then
		self.abilityRechargeTimer = self.abilityRecharge
	else
		self.abilityCooldownTimer = self.abilityCooldown
	end

	self:cl_updateAbilityHud()

	return true
end

function Player:cl_initWeapons()
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

function Player:cl_updateAbilityHud()
	self.hud:setText("amount_ability", tostring(self.abilityUses))

	if self.abilityRechargeTimer then
		SetGuiIcon(self.hud, "icon_abilityCooldown", { "Rotation", "remove", tostring(math.floor((1 - self.abilityRechargeTimer/self.abilityRecharge) * 360)) })
	elseif self.abilityCooldownTimer then
		SetGuiIcon(self.hud, "icon_abilityCooldown", { "Rotation", "remove", tostring(math.floor((1 - self.abilityCooldownTimer/self.abilityCooldown) * 360)) })
	else
		SetGuiIcon(self.hud, "icon_abilityCooldown", { "Rotation", "remove", "360" })
	end
end

function Player:client_onInteract(char, state)
	if not state then return end
	self.network:sendToServer("sv_interact")
	return true
end

function Player:client_onUpdate(dt)
	local char = self.cl_controlled
	if not self.isLocal then return end

	if not char or not sm.exists(char) then
		if self.trajectory then
			self.trajectory:destroy()
			self.trajectory = nil
		end

		return
	end

	if self.isDead then
		sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true), "Revive", "")
	elseif self.cl_collectCharges > 0 then
		sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true), "Attract XP orbs", "")
	end

	-- if self.cl_classId == MINERCLASS.DEMOLITION and false then
	if self.cl_classId == MINERCLASS.DEMOLITION then
		self:cl_drawDynamiteTrajectory(dt)
	elseif self.trajectory then
		self.trajectory:destroy()
		self.trajectory = nil
	end

	if g_cl_freecam then
		local moveSpeed = dt * (g_cl_freecamKeys[16] == true and 50 or 10)
        local fwd = 0
        if g_cl_freecamKeys[3] then fwd = fwd + moveSpeed end
        if g_cl_freecamKeys[4] then fwd = fwd - moveSpeed end

        local right = 0
        if g_cl_freecamKeys[2] then right = right + moveSpeed end
        if g_cl_freecamKeys[1] then right = right - moveSpeed end

        local up = 0
        if g_cl_freecamKeys[21] then up = up + moveSpeed end
        if g_cl_freecamKeys[20] then up = up - moveSpeed end

        local playerDir = self.player.character.direction
        g_cl_camPosition = g_cl_camPosition + playerDir * fwd + CalculateRightVector(playerDir) * right + VEC3_UP * up

        local lerp = dt * 10
        local lerpedPos = sm.vec3.lerp(sm.camera.getPosition(), g_cl_camPosition, lerp)

        sm.camera.setPosition(lerpedPos)
        sm.camera.setDirection(sm.vec3.lerp(sm.camera.getDirection(), playerDir, lerp))
	else
		if self.cam ~= 3 then return end
		local charPos = char.worldPosition
		local newPos = charPos + camOffset * self.zoom
		sm.camera.setPosition(sm.vec3.lerp(sm.camera.getPosition(), newPos, dt * 15))
		sm.camera.setDirection(charPos - newPos)
		-- sm.camera.setFov(sm.camera.getDefaultFov())

		-- sm.camera.setPosition(char.worldPosition + VEC3_UP * (verticalOffset + char:getHeight() * 1.5))
		-- sm.camera.setDirection(char.direction)
	end
end

function Player:client_onFixedUpdate(dt)
	if not self.isLocal or self.isDead then return end

	if self.abilityCooldownTimer then
		self.abilityCooldownTimer = max(self.abilityCooldownTimer - dt, 0)
		if self.abilityCooldownTimer <= 0 then
			self.abilityCooldownTimer = nil
		end
	end

	if self.abilityRechargeTimer then
		self.abilityRechargeTimer = max(self.abilityRechargeTimer - dt, 0)
		if self.abilityRechargeTimer <= 0 then
			self.abilityRechargeTimer = nil
			self.abilityUses = self.abilityMaxUses
		end
	end

	self:cl_updateAbilityHud()

	local controlledChar = self.cl_controlled
	if not controlledChar or not sm.exists(controlledChar) then return end

	local controlledPos = controlledChar.worldPosition + controlledChar.velocity * dt
	self.enemyTrigger:setWorldPosition(controlledPos)

	local enemies = self.enemyTrigger:getContents()
	if #enemies == 1 then --Only self
		for k, v in pairs(self.weapons) do
			v:update(dt)
			-- v:update(dt, controlledPos, controlledChar.direction)
			-- v:update(dt, controlledPos, k == 4 and controlledChar.direction or nil)
		end

		return
	end

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
			v:update(dt)
		end
	end
end

function Player:cl_drawDynamiteTrajectory(dt)
	if not self.trajectory then
		self.trajectory = CurvedLine():init(0.05, colour(1,1,1), 50, 0)
		self.trajectorySim = Dynamite():init({
			damage = 0,
			damageType = DAMAGETYPES.FIRE,
			bounceLimit = 0,
			pierceLimit = 0,
			gravity = 0.5,
			drag = 0,
			projectileVelocity = 10,
		}, true)
	end

	-- if self.abilityRechargeTimer then
	-- 	self.trajectory:stop()
	-- 	return
	-- end

	local startPos = self.cl_controlled.worldPosition + VEC3_UP
	self.trajectorySim.position = startPos
	self.trajectorySim.startPosition = startPos
	self.trajectorySim.direction = (VEC3_UP * 2 + self.cl_controlled:getSmoothViewDirection()):normalize()
	self.trajectorySim.lifeTime = 10
	self.trajectorySim.detonateTime = 2
	self.trajectorySim.attached = false

	local points = {}
	while(true) do
		local quit = self.trajectorySim:update(nil, dt)
		table_insert(points, self.trajectorySim.position)

		if quit or self.trajectorySim.attached then
			break
		end
	end

	local sum = 0
	for i = 1, #points do
		sum = sum + (points[i] - (i == 1 and startPos or points[i - 1])):length2()
	end

	local spacing = sum / 30
	local sampled = {}
	local sum2 = 0
	for i = 1, #points do
		local prev = i == 1 and startPos or points[i - 1]
		local distance = (points[i] - prev):length2()
		sum2 = sum2 + distance
		if sum2 >= spacing then
			table_insert(sampled, vec3_lerp(prev, points[i], (spacing - distance) / distance))
			sum2 = 0
		end
	end

	self.trajectory.steps = #sampled - 1
	self.trajectory:update(startPos, points[#points], sampled)
end

function Player:cl_cam()
	g_cl_freecam = false

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
	-- if method == 3 then
	-- 	sm.localPlayer.setLockedControls(true)
	-- 	sm.localPlayer.setDirection(self.cl_controlled.direction)
	-- 	sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setLockedControls", false)
	-- end

	self.network:sendToServer("sv_setControlMethod", method)
end

function Player:cl_toggleWeapons()
	if #self.weapons > 0 then
		self.weapons = {}
	else
		self:cl_reapplyUpgrades()
	end

	self:cl_updateWeaponHud()
end

function Player:cl_reapplyUpgrades(upgrades)
	self:cl_initWeapons()

	if upgrades then
		self.cl_selectedUpgrades = upgrades
	end

	for k, data in ipairs(self.cl_selectedUpgrades) do
		local upgradeId = data[1]
		local upgrade = UPGRADES[upgradeId]
		if upgrade.weaponUpgrade then
			upgrade:upgradeWeapon(self.weapons[data[3]], data[2])
		else

		end
	end

	self:cl_updateWeaponHud()
end

function Player:cl_refreshClass()
	self.network:sendToServer("sv_refreshClass")
end

function Player:cl_newClass()
	self.network:sendToServer("sv_newClass")
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
	if #self.weapons == 0 then
		self:cl_initWeapons()
		self:cl_updateWeaponHud()
	end

	self.hud:close()

	local weaponsByRestriction = self:GetWeaponRestrictionList()

	self.rolledUpgrades = {}
	local rolledUpgradeTypes = {}
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

					local rollId = upgradeId.."_"..(weapon and weapon.id)
					if not rolledUpgradeTypes[rollId] then
						upgrade = rolled

						rolledUpgradeTypes[rollId] = true
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
	table_insert(self.cl_selectedUpgrades, data)

	local upgradeId = data[1]
	local upgrade = UPGRADES[upgradeId]
	if upgrade.weaponUpgrade then
		local weaponId = data[3]
		upgrade:upgradeWeapon(self.weapons[weaponId], data[2])

		-- local lastLevel = self.weapons[weaponId].level
		-- if math.floor(lastLevel / 6) ~= math.floor(self.weapons[weaponId].level / 6) then
		-- 	print("overclock")
		-- 	for i = 1, math.floor(self.weapons[weaponId].level / 6) do
		-- 		self.weapons[weaponId].level = self.weapons[weaponId].level - 6
		-- 		print("overclock")
		-- 	end
		-- end
	else

	end

	self.upgradeQueue = self.upgradeQueue - 1
	if self.upgradeQueue == 0 then
		self:cl_updateWeaponHud()

		self.upgradesGui:close()
		self.hud:open()

		self.network:sendToServer("sv_saveUpgrades", self.cl_selectedUpgrades)
	else
		self:cl_processUpgradeQueue()
	end
end

function Player:cl_upgradeClosed()
	if not self.hud:isActive() then
		self.hud:open()
	end
end

function Player:cl_setLockedControls(state)
	sm.localPlayer.setLockedControls(state)
end



function Player:GetMoveDir()
	local char = self.controlled.character
	local moveDir = VEC3_ZERO
	local moveDirSet = moveDirs[self.controlMethod]
	for k, v in pairs(self.moveKeys) do
		if v then
			local dir = moveDirSet[k]
			moveDir = moveDir + (type(dir) == "function" and dir(char) or dir)
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