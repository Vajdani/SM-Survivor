dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua" )

---@class Game : GameClass
---@field sv table
Game = class( nil )

function Game.server_onCreate( self )
	print("Game.server_onCreate")
    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
		self.storage:save( self.sv.saved )
	end

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( self.sv.saved.overworld )
end

function Game:server_onFixedUpdate()
	g_unitManager:sv_onFixedUpdate()
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
    if isNewPlayer then
        if not sm.exists( self.sv.saved.world ) then
            sm.world.loadWorld( self.sv.saved.world )
        end
        self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
    end

	g_unitManager:sv_onPlayerJoined( player )
end

function Game:sv_createPlayerCharacter( world, x, y, player, params )
	local pos = sm.vec3.new( 0, 0, 0 )
    local character = sm.character.createCharacter( player, world, pos - VEC3_UP * 10, 0, 0 )
	player:setCharacter( character )
	sm.event.sendToPlayer(player, "sv_createMiner", pos)
end

function Game:sv_recreate(data, player)
	self.sv.saved.world:destroy()
	self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
	self.storage:save( self.sv.saved )

	if not sm.exists( self.sv.saved.world ) then
		sm.world.loadWorld( self.sv.saved.world )
	end
	self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
end


function Game:client_onCreate()
    self:initCMD()
    --self:setLighting(0.5)

	if g_unitManager == nil then
		assert( not sm.isHost )
		g_unitManager = UnitManager()
	end
	g_unitManager:cl_onCreate()

	g_effectManager = EffectManager()
	g_effectManager:cl_onCreate()
end

function Game.client_onLoadingScreenLifted( self )
	g_effectManager:cl_onLoadingScreenLifted()
end

function Game:setLighting(time)
	sm.game.setTimeOfDay( time )

	-- Update lighting values
	local index = 1
	while index < #DAYCYCLE_LIGHTING_TIMES and time >= DAYCYCLE_LIGHTING_TIMES[index + 1] do
		index = index + 1
	end
	assert( index <= #DAYCYCLE_LIGHTING_TIMES )

	local light = 0.0
	if index < #DAYCYCLE_LIGHTING_TIMES then
		local p = ( time - DAYCYCLE_LIGHTING_TIMES[index] ) / ( DAYCYCLE_LIGHTING_TIMES[index + 1] - DAYCYCLE_LIGHTING_TIMES[index] )
		light = sm.util.lerp( DAYCYCLE_LIGHTING_VALUES[index], DAYCYCLE_LIGHTING_VALUES[index + 1], p )
	else
		light = DAYCYCLE_LIGHTING_VALUES[index]
	end
	sm.render.setOutdoorLighting( light )
end

function Game:initCMD()
    sm.game.bindChatCommand("/cam", {}, "cl_cam", "Switch camera mode")
    sm.game.bindChatCommand("/render", {}, "cl_render", "Switch render mode")
    sm.game.bindChatCommand("/recreate", {}, "cl_recreate", "Recreate terrain")
end

function Game:cl_render()
    World.renderMode = World.renderMode == "warehouse" and "indoor" or "warehouse"
end

function Game:cl_cam()
    sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_cam")
end

function Game:cl_recreate()
	self.network:sendToServer("sv_recreate")
end