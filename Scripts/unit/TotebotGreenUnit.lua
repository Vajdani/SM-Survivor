---@class TotebotGreenUnit : UnitClass
TotebotGreenUnit = class()

function TotebotGreenUnit:server_onCreate()
	print("totebot create")

	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.stats == nil then
		self.saved.stats = { hp = 60, maxhp = 60 }
	end

	self.destroyed = false
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
			effectRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), -impact:normalize() )
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