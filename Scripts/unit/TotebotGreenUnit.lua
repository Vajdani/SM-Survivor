dofile "$CONTENT_DATA/Scripts/Timer.lua"
dofile "$CONTENT_DATA/Scripts/unit/PathingState.lua"

---@class TotebotGreenUnit : UnitClass
---@field forgetTimer Timer
---@field attackTimer Timer
---@field target Character?	
---@field lastTargetPosition Vec3
---@field isPathing boolean
TotebotGreenUnit = class()

local attackUuid = sm.uuid.new( "7315c96b-c3bc-4e28-9294-36cb0082d8e4" )
local Damage = 5

local targetForgetTime = 4 * 8
local attackTime = 0.75 * 8
local stopDistance = 2.5

function TotebotGreenUnit:server_onCreate()
	print("totebot create")

	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.stats == nil then
		self.saved.stats = { hp = 60, maxhp = 60 }
	end

	self.unit.eyeHeight = self.unit.character:getHeight() * 0.75
	self.unit.visionFrustum = {
		{ 3.0, math.rad( 80.0 ), math.rad( 80.0 ) },
		{ 20.0, math.rad( 40.0 ), math.rad( 35.0 ) },
		{ 40.0, math.rad( 20.0 ), math.rad( 20.0 ) }
	}
	-- self.unit:setWhiskerData( 3, math.rad( 60.0 ), 1.5, 5.0 )
	self.unit:setWhiskerData( 0, 0, 0, 0 )

	self.forgetTimer = Timer()
	self.forgetTimer:start( targetForgetTime )
	self.shouldForget = false

	self.attackTimer = Timer()
	self.attackTimer:start( attackTime )
	self.attackTimer:complete()

	self.pathingState = PathingState()
	self.pathingState:sv_onCreate( self.unit )
	self.pathingState:sv_setTolerance( 1.0 )
	self.pathingState:sv_setMovementType( "sprint" )
	self.pathingState:sv_setWaterAvoidance( false )
	self.pathingState.debugName = "pathingState"
	self.pathingState:start()

	self.target = (self.params or {}).target
	if self.target then
		self.lastTargetPosition = self.target.worldPosition
	end

	self.destroyed = false
end

function TotebotGreenUnit.server_onUnitUpdate( self, dt )
	if self.shouldForget then
		self.forgetTimer:tick()
		if self.forgetTimer:done() then
			print("totebot forgor", self.target)
			self.target = nil
			self.shouldForget = false
			self.lastTargetPosition = nil
			self.forgetTimer:reset()
		end
	end

	self.attackTimer:tick()

	local player = sm.ai.getClosestVisibleCharacterType( self.unit, unit_miner )
	if player ~= self.target then
		if player then
			print("totebot found target", player)
			self.target = player
			self.shouldForget = false

			--self.unit:sendCharacterEvent("alerted")

			self.forgetTimer:reset()
		else
			-- if self.target:isDowned() then
			-- 	self.target = nil
			-- 	self.unit:setMovementType("stand")
			-- else
			-- 	self.shouldForget = true
			-- end
		end
	end

	self.pathingState:sv_setConditions({
		{ variable = sm.pathfinder.conditionProperty.target, value = ( self.lastTargetPosition and 1 or 0 ) }
	})
	self.pathingState:sv_setDestination( self.lastTargetPosition )
	self.pathingState:onUnitUpdate( dt )

	if self.target and self.attackTimer:done() then
		if not self.shouldForget then
			self.lastTargetPosition = self.target.worldPosition
		end

		local ownPos = self.unit.character.worldPosition
		local toLastTargetPos = self.lastTargetPosition - ownPos
		if (self.target.worldPosition - ownPos):length2() < stopDistance then
			self.unit:setMovementType("stand")

			local dir = toLastTargetPos:normalize()
			self.unit:setFacingDirection(dir)

			sm.melee.meleeAttack(attackUuid, Damage, ownPos, dir * 2, self.unit, 0, 10)

			self.unit:sendCharacterEvent("melee")

			self.attackTimer:reset()
			self.isPathing = false
		elseif (toLastTargetPos):length2() < stopDistance then
			self.unit:setMovementType("stand")
			self.isPathing = false
		else
			-- local dir = toLastTargetPos:normalize()
			-- self.unit:setFacingDirection(dir)
			-- self.unit:setMovementDirection(dir)
			-- self.unit:setMovementType("sprint")
			self.isPathing = true
		end
	end
end

function TotebotGreenUnit:server_onFixedUpdate(dt)
	if self.isPathing and self.pathingState.destination then
		self.pathingState:onFixedUpdate( dt )
		self.unit:setMovementDirection( self.pathingState:getMovementDirection() )
		self.unit:setMovementType( self.pathingState:getMovementType() )
		self.unit:setFacingDirection( self.pathingState:getFacingDirection() )
		-- print(self.pathingState:getMovementType())
	end
end






function TotebotGreenUnit.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end

	local impact = hitVelocity:normalize() * 6
	self:sv_takeDamage( damage, impact, hitPos )
end

function TotebotGreenUnit.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end

	local impact = hitDirection * 6
	self:sv_takeDamage( damage, impact, hitPos )
end

function TotebotGreenUnit.server_onExplosion( self, center, destructionLevel )
	if not sm.exists( self.unit ) then
		return
	end
	local impact = ( self.unit:getCharacter().worldPosition - center ):normalize() * 6
	self:sv_takeDamage( self.saved.stats.maxhp * ( destructionLevel / 10 ), impact, self.unit:getCharacter().worldPosition )
end

function TotebotGreenUnit:sv_onHit(data)
	self:sv_takeDamage(data.damage, sm.vec3.zero(), data.hitPos)
end

function TotebotGreenUnit.sv_takeDamage( self, damage, impact, hitPos )
	if self.saved.stats.hp > 0 then
		self.saved.stats.hp = self.saved.stats.hp - damage
		self.saved.stats.hp = math.max( self.saved.stats.hp, 0 )
		print( "'TotebotGreenUnit' received:", damage, "damage.", self.saved.stats.hp, "/", self.saved.stats.maxhp, "HP" )

		local effectRotation = sm.quat.identity()
		if hitPos and impact and impact:length() >= FLT_EPSILON then
			effectRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), impact:normalize() * -1 )
		end
		sm.effect.playEffect( "ToteBot - Hit", hitPos, nil, effectRotation )

		if self.saved.stats.hp <= 0 then
			self:sv_onDeath( impact )
		else
			self.storage:save( self.saved )
		end
	end
end

function TotebotGreenUnit.sv_onDeath( self, impact )
	local character = self.unit:getCharacter()
	if not self.destroyed then
		self.unit:sendCharacterEvent( "death" )
		g_unitManager:sv_addDeathMarker( character.worldPosition )
		self.saved.stats.hp = 0
		self.unit:destroy()
		print("'TotebotGreenUnit' killed!")

		self.destroyed = true
	end
end