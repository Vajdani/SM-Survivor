---@class MinerCharacter : CharacterClass
---@field animations table
---@field isLocal boolean
---@field swinging boolean
---@field graphicsLoaded boolean
---@field animationsLoaded boolean
---@field koEffect Effect
---@field blendSpeed number
---@field blendTime number
MinerCharacter = class()

function MinerCharacter.client_onCreate( self )
	self.animations = {}
	self.isLocal = false
	self.swinging = false
	print( "-- MinerCharacter created --" )
end

function MinerCharacter.client_onGraphicsLoaded( self )
	self.animations.sledgehammer_attack1 = {
		info = self.character:getAnimationInfo( "sledgehammer_attack1" ),
		time = 0,
		weight = 0
	}
	self.animations.sledgehammer_attack2 = {
		info = self.character:getAnimationInfo( "sledgehammer_attack2" ),
		time = 0,
		weight = 0
	}

	self.swing = 1

	self.currentAnimation = ""
	self.blendSpeed = 5.0
	self.blendTime = 0.2

	self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	self.koEffect = sm.effect.createEffect( "Mechanic - KoLoop", self.character, "jnt_head" )

	self.graphicsLoaded = true
	self.animationsLoaded = true
end

function MinerCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
	if self.koEffect then
		self.koEffect:destroy()
		self.koEffect = nil
	end
end

local swingAnims = {
	sledgehammer_attack1 = true,
	sledgehammer_attack2 = true,
}
function MinerCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

	if self.character:isDowned() and not self.koEffect:isPlaying() then
		sm.effect.playEffect( "Mechanic - Ko", self.character.worldPosition )
		self.koEffect:start()
	elseif not self.character:isDowned() and self.koEffect:isPlaying() then
		self.koEffect:stop()
	end

	-- Third person animations
	for name, animation in pairs(self.animations) do
		if animation.info then
			animation.time = animation.time + deltaTime

			if animation.info.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end

			if name == self.currentAnimation then
				animation.weight = math.min(animation.weight+(self.blendSpeed * deltaTime), 1.0)
				if animation.time >= animation.info.duration then
					if swingAnims[self.currentAnimation] == true and self.swinging then
						self:initSwing()
					else
						self.currentAnimation = ""
					end
				end
			else
				animation.weight = math.max(animation.weight-(self.blendSpeed * deltaTime ), 0.0)
			end

			self.character:updateAnimation( animation.info.name, animation.time, animation.weight )
		end
	end
end

function MinerCharacter.client_onEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if event == "swing_start" then
		self.swinging = true

		if swingAnims[self.currentAnimation] == nil then
			self:initSwing()
		end
	elseif event == "swing_end" then
		self.swinging = false
	end
end

function MinerCharacter:initSwing()
	if self.swing % 2 == 0 then
		self.currentAnimation = "sledgehammer_attack2"
		self.animations.sledgehammer_attack2.time = 0
	else
		self.currentAnimation = "sledgehammer_attack1"
		self.animations.sledgehammer_attack1.time = 0
	end

	self.swing = self.swing + 1
end