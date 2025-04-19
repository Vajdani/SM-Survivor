dofile "$CONTENT_DATA/Scripts/Timer.lua"
dofile "$CONTENT_DATA/Scripts/unit/PathingState.lua"

---@class TotebotGreenUnit : UnitClass
---@field forgetTimer Timer
---@field attackTimer Timer
---@field target? Character
---@field lastTargetPosition Vec3
---@field isPathing boolean
---@field path NodePathNode[]
TotebotGreenUnit = class()

local attackUuid = sm.uuid.new( "7315c96b-c3bc-4e28-9294-36cb0082d8e4" )
local Damage = 5

local targetForgetTime = 4 * 40 --8
local attackTime = 0.75 * 40 --8
local stopDistance = 2 ^ 2

function TotebotGreenUnit:server_onCreate()
	-- print("totebot create")

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

	if self.params then
		self.target = self.params.target
	else
		self.target = GetClosestPlayer(self.unit.character.worldPosition, 1000, self.unit.character:getWorld()).publicData.miner.character
	end

	self.path = {}
	self.pathIndex = 1

	self.tickOffset = math.floor(math.random() * 8)

	self.destroyed = false
end

function TotebotGreenUnit:server_onFixedUpdate()
	self.attackTimer:tick()
	if not self.attackTimer:done() then return end

	local curNode = self.path[self.pathIndex]
	if curNode then
		local dist = curNode.toNode:getPosition() - self.unit.character.worldPosition
		if dist:length2() > 2 then
			local dir = dist:normalize()
			self.unit:setMovementDirection(dir)
			self.unit:setMovementType("sprint")
			self.unit:setFacingDirection(dir)
		else
			self.pathIndex = min(self.pathIndex + 1, #self.path)
		end
	else
		self.unit:setMovementType("stand")
	end

	if not self.target:isDowned() then
		local ownPos = self.unit.character.worldPosition
		local toLastTargetPos = self.target.worldPosition - ownPos
		if (self.target.worldPosition - ownPos):length2() < stopDistance then
			self.unit:setMovementType("stand")

			local dir = toLastTargetPos:normalize()
			self.unit:setFacingDirection(dir)

			sm.melee.meleeAttack(attackUuid, Damage, ownPos, dir * 2, self.unit, 5, 10)
			self.unit:sendCharacterEvent("melee")

			self.attackTimer:reset()
		end
	end
end

local filter = sm.physics.filter.default - sm.physics.filter.character
function TotebotGreenUnit:server_onUnitUpdate()
	if not self.attackTimer:done() then return end

	local pos = self.target.worldPosition
	local char = self.unit.character
	if self.target:isDowned() then
		self.path = {}
		self.pathIndex = 1
		return
	end

	local hit, result = sm.physics.raycast(char.worldPosition, pos, nil, filter)
	if not hit then
		---@diagnostic disable-next-line:missing-fields
		self.path = { { toNode = { getPosition = function() return pos end } } }
		self.pathIndex = 1
	elseif (sm.game.getServerTick() + self.tickOffset) % 8 == 0 then
		self.path = sm.pathfinder.getPath(char, vec3(pos.x, pos.y, 0), true)
		self.pathIndex = 1
	end
end






function TotebotGreenUnit:server_onProjectile(hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid)
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end

	local impact = hitVelocity:normalize() * 6
	self:sv_takeDamage( damage, impact, hitPos )
end

function TotebotGreenUnit:server_onMelee(hitPos, attacker, damage, power, hitDirection)
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end

	local impact = hitDirection * 6
	self:sv_takeDamage( damage, impact, hitPos )
end

function TotebotGreenUnit:server_onExplosion(center, destructionLevel)
	if not sm.exists( self.unit ) then
		return
	end

	local impact = ( self.unit:getCharacter().worldPosition - center ):normalize() * 6
	self:sv_takeDamage( self.saved.stats.maxhp * ( destructionLevel / 10 ), impact, self.unit:getCharacter().worldPosition )
end

function TotebotGreenUnit:sv_onHit(data)
	self:sv_takeDamage(data.damage, data.impact or VEC3_ZERO, data.hitPos)
end

function TotebotGreenUnit:sv_takeDamage(damage, impact, hitPos)
	if self.saved.stats.hp > 0 then
		self.saved.stats.hp = self.saved.stats.hp - damage
		self.saved.stats.hp = math.max( self.saved.stats.hp, 0 )
		-- print( "'TotebotGreenUnit' received:", damage, "damage.", self.saved.stats.hp, "/", self.saved.stats.maxhp, "HP" )

		local effectRotation = QUAT_IDENTITY
		if hitPos and impact and impact:length() >= FLT_EPSILON then
			effectRotation = getRotation( VEC3_UP, impact:normalize() * -1 )
		end
		sm.effect.playEffect( "ToteBot - Hit", hitPos, nil, effectRotation )

		if self.saved.stats.hp <= 0 then
			self:sv_onDeath()
		else
			self.storage:save( self.saved )
		end
	end
end

function TotebotGreenUnit:sv_onDeath()
	local character = self.unit:getCharacter()
	if not self.destroyed then
		self.unit:sendCharacterEvent( "death" )

		local pos = character.worldPosition
		g_unitManager:sv_addDeathMarker( pos )

		DropXP(pos)

		self.saved.stats.hp = 0
		self.unit:destroy()
		-- print("'TotebotGreenUnit' killed!")

		self.destroyed = true
	end
end