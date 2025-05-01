dofile "../util.lua"

---@class MinerCharacter : CharacterClass
---@field animations table
---@field isLocal boolean
---@field swinging boolean
---@field graphicsLoaded boolean
---@field animationsLoaded boolean
---@field koEffect Effect
---@field glowEffect Effect
---@field blendSpeed number
MinerCharacter = class()

local defaultAnims = "$CONTENT_DATA/Characters/char_miner_hammerAnims.rend"
local drillRenderables = {
	"$CONTENT_DATA/Characters/DemolitionDrill/char_demolitiondrill_animlist.rend",
	"$CONTENT_DATA/Characters/DemolitionDrill/char_demolitiondrill_base.rend",
	"$CONTENT_DATA/Characters/DemolitionDrill/char_demolitiondrill_anim.rend",
}
local glowstickRenderable = "$SURVIVAL_DATA/Character/Char_Glowstick/char_glowstick.rend"
local classRenderables = {
	[MINERCLASS.DEMOLITION] = {
		character = {
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_demolition_backpack/char_shared_outfit_demolition_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_demolition_gloves/char_male_outfit_demolition_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_demolition_hat/char_shared_outfit_demolition_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_demolition_jacket/char_male_outfit_demolition_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_demolition_pants/char_male_outfit_demolition_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_demolition_shoes/char_male_outfit_demolition_shoes.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Hair/Male/char_male_hair_01/char_male_hair_01.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Head/Male/char_male_head01/char_male_head01.rend"
		},
		tool = {
			"$CONTENT_DATA/Characters/char_miner_demolitiondrillAnims.rend",
			unpack(drillRenderables)
		}
	},
	[MINERCLASS.SCOUT] = {
		character = {
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_delivery_backpack/char_shared_outfit_delivery_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_delivery_gloves/char_male_outfit_delivery_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_delivery_hat/char_male_outfit_delivery_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_delivery_jacket/char_male_outfit_delivery_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_delivery_pants/char_male_outfit_delivery_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_delivery_shoes/char_male_outfit_delivery_shoes.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Head/Male/char_male_head01/char_male_head01.rend"
		},
		tool = {
			defaultAnims,
			"$GAME_DATA/Character/Char_Tools/Char_sledgehammer/char_sledgehammer.rend"
		}
	},
	[MINERCLASS.STUNTMAN] = {
		character = {
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_stuntman_backpack/char_shared_outfit_stuntman_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_stuntman_gloves/char_male_outfit_stuntman_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_stuntman_hat/char_male_outfit_stuntman_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_stuntman_jacket/char_male_outfit_stuntman_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_stuntman_pants/char_male_outfit_stuntman_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_stuntman_shoes/char_male_outfit_stuntman_shoes.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Head/Male/char_male_head01/char_male_head01.rend"
		},
		tool = {
			defaultAnims,
			"$GAME_DATA/Character/Char_Tools/Char_sledgehammer/char_sledgehammer.rend"
		}
	}
}

function MinerCharacter:sv_init(args)
	self.owner = args.owner
	self.network:sendToClients("cl_init", args)
end

function MinerCharacter:sv_throwDynamite()
	sm.event.sendToScriptableObject(
        g_projectileManager, "sv_fireProjectile",
        {
			scriptClass = "Dynamite",
            damage = 0,
            damageType = DAMAGETYPES.FIRE,
            bounceLimit = 5,
            pierceLimit = 0,
            gravity = 0.5,
            drag = 0,
            bounceAxes = VEC3_ONE,
            collisionMomentumLoss = 0.25,
            renderable = { uuid = blk_plastic, color = sm.color.new(1,0,0) },
            position = self.character.worldPosition + VEC3_UP,
            projectileVelocity = 10,
            spreadAngle = 0,
            sliceAngle = 0,
            pelletCount = 1,
            aimDir = (VEC3_UP * 2 + self.character.direction):normalize()
        }
    )

	sm.event.sendToUnit(self.character:getUnit(), "sv_onDynamiteThrow")
end



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
		weight = 0,
		speed = 1
	}
	self.animations.sledgehammer_attack2 = {
		info = self.character:getAnimationInfo( "sledgehammer_attack2" ),
		time = 0,
		weight = 0,
		speed = 1
	}
	self.animations.sledgehammer_guard_idle = {
		info = self.character:getAnimationInfo( "sledgehammer_guard_idle" ),
		time = 0,
		weight = 0,
		speed = 1
	}
	self.animations.spudgun_shoot1 = {
		info = self.character:getAnimationInfo( "spudgun_shoot1" ),
		time = 0,
		weight = 0,
		speed = 1
	}
	self.animations.spudgun_shoot2 = {
		info = self.character:getAnimationInfo( "spudgun_shoot2" ),
		time = 0,
		weight = 0,
		speed = 1
	}
	self.animations.throw = {
		info = self.character:getAnimationInfo( "throw" ),
		time = 0,
		weight = 0,
		speed = 2
	}

	if sm.isHost then
		self.character:bindAnimationCallback("throw", 1, "cl_throwDynamite")
	end

	self.swing = 1

	self.currentAnimation = ""
	self.blendSpeed = 5.0

	self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	self.koEffect = sm.effect.createEffect( "Mechanic - KoLoop", self.character, "jnt_head" )

	self.glowEffect = sm.effect.createEffect( "Glowstick - Hold", self.character )
	self.glowEffect:start()
	sm.event.sendToCharacter(self.character, "cl_initGlow")

	self.graphicsLoaded = true
	self.animationsLoaded = true
end

function MinerCharacter:cl_fixDrill()
	if self.drillFixDelay > 0 then
		self.drillFixDelay = self.drillFixDelay - 1
		sm.event.sendToCharacter(self.character, "cl_fixDrill")
		return
	end

	self.character:updateAnimation( "drill_rotate", 0, 1 )
end

function MinerCharacter:cl_initGlow()
	self.glowEffect:setOffsetPosition(VEC3_Y * 2)
	self.glowEffect:setParameter("radius", 4)
	self.glowEffect:setParameter("intensity", 1.25)
end

function MinerCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
	if self.koEffect then
		self.koEffect:destroy()
		self.koEffect = nil
	end

	if self.glowEffect then
		self.glowEffect:destroy()
		self.glowEffect = nil
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
			animation.time = animation.time + deltaTime * animation.speed

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
						if self.currentAnimation == "throw" then
							self:cl_removeRenderables({ glowstickRenderable, defaultAnims })
							self:cl_applyRenderables(self.toolRenderables)
						end

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

local blockSwings = {
	throw = true,
	jump = true,
	land = true
}
function MinerCharacter.client_onEvent( self, event )
	if not self.animationsLoaded or blockSwings[self.currentAnimation] and event:match("swing_") then
		return
	end

	if event == "swing_start" then
		self.swinging = true

		if swingAnims[self.currentAnimation] == nil then
			self:initSwing()
		end
	elseif event == "swing_end" then
		self.swinging = false
	elseif event == "throw" then
		self.currentAnimation = "throw"
		self.animations.throw.time = 0

		for k, v in pairs({
			"sledgehammer_attack1",
			"sledgehammer_attack2",
			"spudgun_shoot1",
			"spudgun_shoot2"
		}) do
			self.animations[v].weight = 0
			self.animations[v].time = 0
		end

		self.swinging = false
		self.swing = 1

		self:cl_removeRenderables(self.toolRenderables)
		self:cl_applyRenderables({ glowstickRenderable, defaultAnims })
	elseif event == "jump" then
		self.currentAnimation = "sledgehammer_guard_idle"
		self.animations.sledgehammer_guard_idle.time = 0
	elseif event == "land" then
		self.currentAnimation = "sledgehammer_attack1"
		self.animations.sledgehammer_attack1.time = 0
	end
end

function MinerCharacter:initSwing()
	if self.swing % 2 == 0 then
		self.currentAnimation = self.classId == MINERCLASS.DEMOLITION and "spudgun_shoot2" or "sledgehammer_attack2"
	else
		self.currentAnimation = self.classId == MINERCLASS.DEMOLITION and "spudgun_shoot1" or "sledgehammer_attack1"
	end

	self.animations[self.currentAnimation].time = 0
	self.swing = self.swing + 1
end



function MinerCharacter:cl_init(args)
	if self.classId then
		local added = {}
		for rendType, renderables in pairs(classRenderables[args.classId]) do
			for k, renderable in pairs(renderables) do
				added[renderable] = true
			end
		end

		for rendType, renderables in pairs(classRenderables[self.classId]) do
			for k, renderable in pairs(renderables) do
				if not added[renderable] then
					self.character:removeRenderable(renderable)
				end
			end
		end
	end

	self.classId = args.classId
	if self.classId == MINERCLASS.DEMOLITION then
		self.drillFixDelay = 5
		sm.event.sendToCharacter(self.character, "cl_fixDrill")
	end

	local renderables = classRenderables[self.classId]
	self:cl_applyRenderables(renderables.character)

	self.toolRenderables = renderables.tool
	self:cl_applyRenderables(self.toolRenderables)
end

function MinerCharacter:cl_applyRenderables(renderables)
	for k, v in pairs(renderables) do
		self.character:addRenderable(v)
	end
end

function MinerCharacter:cl_removeRenderables(renderables)
	for k, v in pairs(renderables) do
		self.character:removeRenderable(v)
	end
end

function MinerCharacter:cl_throwDynamite()
	self.network:sendToServer("sv_throwDynamite")
end