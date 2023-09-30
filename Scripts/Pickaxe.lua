---@class VisualizedTrigger
---@field trigger AreaTrigger
---@field effect Effect
---@field setPosition function
---@field setRotation function
---@field setScale function
---@field destroy function
---@field setVisible function
---@field show function
---@field hide function

---Create an AreaTrigger that has a visualization
---@param position Vec3
---@param scale Vec3
---@return VisualizedTrigger
function CreateVisualizedTrigger(position, scale)
    local effect = sm.effect.createEffect("ShapeRenderable")
    effect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
    effect:setParameter("visualization", true)
    effect:setScale(scale)
    effect:setPosition(position)
    effect:start()

    return {
        trigger = sm.areaTrigger.createBox(scale * 0.5, position, sm.quat.identity(), sm.areaTrigger.filter.harvestable),
        effect = effect,
        setPosition = function(self, position)
            self.trigger:setWorldPosition(position)
            self.effect:setPosition(position)
        end,
        setRotation = function(self, rotation)
            self.trigger:setWorldRotation(rotation)
            self.effect:setRotation(rotation)
        end,
        setScale = function(self, scale)
            self.trigger:setSize(scale * 0.5)
            self.effect:setScale(scale)
        end,
        destroy = function(self)
            sm.areaTrigger.destroy(self.trigger)
            self.effect:destroy()
        end,
        setVisible = function(self, state)
            if state then
                self.effect:start()
            else
                self.effect:stop()
            end
        end,
        show = function(self)
            self.effect:start()
        end,
        hide = function(self)
            self.effect:stop()
        end
    }
end


dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

---@class Pickaxe : ToolClass
---@field isLocal boolean
---@field animationsLoaded boolean
---@field equipped boolean
---@field swingCooldowns table
---@field fpAnimations table
---@field tpAnimations table
Pickaxe = class()

local renderables = {
	"$GAME_DATA/Character/Char_Tools/Char_sledgehammer/char_sledgehammer.rend"
}

local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_sledgehammer.rend", "$GAME_DATA/Character/Char_Tools/Char_sledgehammer/char_sledgehammer_tp_animlist.rend"}
local renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_sledgehammer/char_sledgehammer_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

Pickaxe.swingCount = 2
Pickaxe.mayaFrameDuration = 1.0/30.0
Pickaxe.freezeDuration = 0.075

Pickaxe.swings = { "sledgehammer_attack1", "sledgehammer_attack2" }
Pickaxe.swingFrames = { 4.2 * Pickaxe.mayaFrameDuration, 4.2 * Pickaxe.mayaFrameDuration }
Pickaxe.swingExits = { "sledgehammer_exit1", "sledgehammer_exit2" }

function Pickaxe:client_onCreate()
	self.isLocal = self.tool:isLocal()
	self:init()

	if not self.isLocal then return end

	self.mineBox = CreateVisualizedTrigger(self.tool:getPosition(), sm.vec3.new(2, 2, 2)) --sm.areaTrigger.createBox(sm.vec3.new(1.25, 1.25, 1), self.tool:getPosition())
	--self.mineBox:hide()
end

function Pickaxe:client_onDestroy()
	self.mineBox:destroy()
end

function Pickaxe.client_onRefresh( self )
	self:init()
	self:loadAnimations()
end

function Pickaxe:init()
	self.attackCooldownTimer = 0.0
	self.freezeTimer = 0.0
	self.pendingRaycastFlag = false
	self.nextAttackFlag = false
	self.currentSwing = 1

	self.swingCooldowns = {}
	for i = 1, self.swingCount do
		self.swingCooldowns[i] = 0.0
	end

	self.dispersionFraction = 0.001

	self.blendTime = 0.2
	self.blendSpeed = 10.0

	self.sharedCooldown = 0.0
	self.hitCooldown = 1.0
	self.blockCooldown = 0.5
	self.swing = false
	self.block = false

	self.wantBlockSprint = false

	if self.animationsLoaded == nil then
		self.animationsLoaded = false
	end
end

function Pickaxe.loadAnimations( self )
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			equip = { "sledgehammer_pickup", { nextAnimation = "idle" } },
			unequip = { "sledgehammer_putdown" },
			idle = {"sledgehammer_idle", { looping = true } },
			idleRelaxed = {"sledgehammer_idle_relaxed", { looping = true } },

			sledgehammer_attack1 = { "sledgehammer_attack1", { nextAnimation = "sledgehammer_exit1" } },
			sledgehammer_attack2 = { "sledgehammer_attack2", { nextAnimation = "sledgehammer_exit2" } },
			sledgehammer_exit1 = { "sledgehammer_exit1", { nextAnimation = "idle" } },
			sledgehammer_exit2 = { "sledgehammer_exit2", { nextAnimation = "idle" } },
		}
	)
	local movementAnimations = {
		idle = "sledgehammer_idle",
		--idleRelaxed = "sledgehammer_idle_relaxed",

		runFwd = "sledgehammer_run_fwd",
		runBwd = "sledgehammer_run_bwd",

		sprint = "sledgehammer_sprint",

		jump = "sledgehammer_jump",
		jumpUp = "sledgehammer_jump_up",
		jumpDown = "sledgehammer_jump_down",

		land = "sledgehammer_jump_land",
		landFwd = "sledgehammer_jump_land_fwd",
		landBwd = "sledgehammer_jump_land_bwd",

		crouchIdle = "sledgehammer_crouch_idle",
		crouchFwd = "sledgehammer_crouch_fwd",
		crouchBwd = "sledgehammer_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "sledgehammer_pickup", { nextAnimation = "idle" } },
				unequip = { "sledgehammer_putdown" },				
				idle = { "sledgehammer_idle",  { looping = true } },

				sprintInto = { "sledgehammer_sprint_into", { nextAnimation = "sprintIdle" } },
				sprintIdle = { "sledgehammer_sprint_idle", { looping = true } },
				sprintExit = { "sledgehammer_sprint_exit", { nextAnimation = "idle" } },

				sledgehammer_attack1 = { "sledgehammer_attack1", { nextAnimation = "sledgehammer_exit1" } },
				sledgehammer_attack2 = { "sledgehammer_attack2", { nextAnimation = "sledgehammer_exit2" } },
				sledgehammer_exit1 = { "sledgehammer_exit1", { nextAnimation = "idle" } },
				sledgehammer_exit2 = { "sledgehammer_exit2", { nextAnimation = "idle" } }
			}
		)
		setFpAnimation( self.fpAnimations, "idle", 0.0 )
	end
	--self.swingCooldowns[1] = self.fpAnimations.animations["sledgehammer_attack1"].info.duration
	self.swingCooldowns[1] = 0.6
	--self.swingCooldowns[2] = self.fpAnimations.animations["sledgehammer_attack2"].info.duration
	self.swingCooldowns[2] = 0.6

	self.animationsLoaded = true
end

function Pickaxe.client_onUpdate( self, dt )
	if not self.animationsLoaded then
		return
	end

	dt = dt * 10

	--synchronized update
	self.attackCooldownTimer = math.max( self.attackCooldownTimer - dt, 0.0 )

	--standard third person updateAnimation
	updateTpAnimations( self.tpAnimations, self.equipped, dt )

	--update
	if self.isLocal then
		if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
			self:updateFreezeFrame(self.swings[self.currentSwing], dt)
		end

		local preAnimation = self.fpAnimations.currentAnimation

		updateFpAnimations( self.fpAnimations, self.equipped, dt )
		if preAnimation ~= self.fpAnimations.currentAnimation then
			-- Ended animation - re-evaluate what next state is

			local endedSwing = preAnimation == self.swings[self.currentSwing] and self.fpAnimations.currentAnimation == self.swingExits[self.currentSwing]
			if self.nextAttackFlag == true and endedSwing == true then
				-- Ended swing with next attack flag

				-- Next swing
				self.currentSwing = self.currentSwing + 1
				if self.currentSwing > self.swingCount then
					self.currentSwing = 1
				end
				local params = { name = self.swings[self.currentSwing] }
				self.network:sendToServer( "server_startEvent", params )
				sm.audio.play( "Sledgehammer - Swing" )
				self.pendingRaycastFlag = true
				self.nextAttackFlag = false
				self.attackCooldownTimer = self.swingCooldowns[self.currentSwing]
			end
		end

		local isSprinting =  self.tool:isSprinting() 
		if isSprinting and self.fpAnimations.currentAnimation == "idle" and self.attackCooldownTimer <= 0 and not isAnyOf( self.fpAnimations.currentAnimation, { "sprintInto", "sprintIdle" } ) then
			local params = { name = "sprintInto" }
			self:client_startLocalEvent( params )
		end

		if ( not isSprinting and isAnyOf( self.fpAnimations.currentAnimation, { "sprintInto", "sprintIdle" } ) ) and self.fpAnimations.currentAnimation ~= "sprintExit" then
			local params = { name = "sprintExit" }
			self:client_startLocalEvent( params )
		end

		self.tool:setBlockSprint(true)
	end
end

function Pickaxe.updateFreezeFrame( self, state, dt )
	local p = 1 - math.max( math.min( self.freezeTimer / self.freezeDuration, 1.0 ), 0.0 )
	local playRate = p * p * p * p
	self.fpAnimations.animations[state].playRate = playRate
	self.freezeTimer = math.max( self.freezeTimer - dt, 0.0 )
end

function Pickaxe.server_startEvent( self, params )
	self.network:sendToClients( "client_startLocalEvent", params )
end

function Pickaxe.client_startLocalEvent( self, params )
	self:client_handleEvent( params )
end

function Pickaxe.client_handleEvent( self, params )
	-- Setup animation data on equip
	if params.name == "equip" then
		self.equipped = true
		--self:loadAnimations()
	elseif params.name == "unequip" then
		self.equipped = false
	end

	if not self.animationsLoaded then
		return
	end

	--Maybe not needed
-------------------------------------------------------------------

	-- Third person animations
	local tpAnimation = self.tpAnimations.animations[params.name]
	if tpAnimation then
		local isSwing = false
		for i = 1, self.swingCount do
			if self.swings[i] == params.name then
				self.tpAnimations.animations[self.swings[i]].playRate = 1
				isSwing = true
			end
		end

		local blend = not isSwing
		setTpAnimation( self.tpAnimations, params.name, blend and 0.2 or 0.0 )
	end

	-- First person animations
	if self.isLocal then
		local isSwing = false

		for i = 1, self.swingCount do
			if self.swings[i] == params.name then
				self.fpAnimations.animations[self.swings[i]].playRate = 1
				isSwing = true
			end
		end

		if params.name == "guardInto" then
			swapFpAnimation( self.fpAnimations, "guardExit", "guardInto", 0.2 )
		elseif params.name == "guardExit" then
			swapFpAnimation( self.fpAnimations, "guardInto", "guardExit", 0.2 )
		elseif params.name == "sprintInto" then
			swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.2 )
		elseif params.name == "sprintExit" then
			swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.2 )
		else
			local blend = not ( isSwing or isAnyOf( params.name, { "equip", "unequip" } ) )
			setFpAnimation( self.fpAnimations, params.name, blend and 0.2 or 0.0 )
		end
	end
end

local y, z = sm.vec3.new(0,1,0), sm.vec3.new(0,0,1)
function Pickaxe:client_onEquippedUpdate()
	local char = self.tool:getOwner().character
	local fwd = z:cross(char.direction:cross(z):normalize())
	local charPos = char.worldPosition

	--self.mineBox:setWorldPosition(self.tool:getPosition() + fwd)
	--self.mineBox:setWorldRotation(sm.vec3.getRotation(sm.vec3.new(0,1,0), fwd))
	self.mineBox:setPosition(charPos + fwd)
	self.mineBox:setRotation(sm.vec3.getRotation(y, fwd))

	if self.pendingRaycastFlag then
		local time = 0.0
		local frameTime = 0.0
		if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
			time = self.fpAnimations.animations[self.swings[self.currentSwing]].time
			frameTime = self.swingFrames[self.currentSwing]
		end
		if time >= frameTime and frameTime ~= 0 then
			self.pendingRaycastFlag = false
			self.network:sendToServer("sv_attack", self.mineBox.trigger:getContents())
		end
	end


	if #self.mineBox.trigger:getContents() > 0 then
		if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
			if self.attackCooldownTimer < 0.125 then
				self.nextAttackFlag = true
			end
		else
			if self.attackCooldownTimer <= 0 then
				self.currentSwing = 1
				local params = { name = self.swings[self.currentSwing] }
				self.network:sendToServer( "server_startEvent", params )
				sm.audio.play( "Sledgehammer - Swing" )
				self.pendingRaycastFlag = true
				self.nextAttackFlag = false
				self.attackCooldownTimer = self.swingCooldowns[self.currentSwing]
			end
		end
	end

	return true, false
end

---@param objs Harvestable[]
function Pickaxe:sv_attack(objs)
	local start = self.tool:getOwner().character.worldPosition
	for k, obj in pairs(objs) do
		if sm.exists(obj) then
			local hit, result = sm.physics.raycast(start, obj.worldPosition)
			sm.effect.playEffect(
				"Sledgehammer - Hit", result.pointWorld, nil, nil, nil,
				{ Material = obj.materialId }
			)

			sm.event.sendToHarvestable(obj, "sv_onHit")
		end
	end
end

function Pickaxe.client_onEquip( self, animate )

	if animate then
		sm.audio.play( "Sledgehammer - Equip", self.tool:getPosition() )
	end

	self.equipped = true

	for k,v in pairs( renderables ) do renderablesTp[#renderablesTp+1] = v end
	for k,v in pairs( renderables ) do renderablesFp[#renderablesFp+1] = v end

	self.tool:setTpRenderables( renderablesTp )

	self:init()
	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "equip", 0.0001 )

	if self.isLocal then
		self.tool:setFpRenderables( renderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function Pickaxe.client_onUnequip( self, animate )
	self.equipped = false
	if sm.exists( self.tool ) then
		if animate then
			sm.audio.play( "Sledgehammer - Unequip", self.tool:getPosition() )
		end
		setTpAnimation( self.tpAnimations, "unequip" )
		if self.isLocal and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end
end
