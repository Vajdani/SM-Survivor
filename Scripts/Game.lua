dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua" )

---@class Game : GameClass
---@field sv table
Game = class( nil )

if g_spawnEnemies == nil then
	g_spawnEnemies = true
end

g_enableWaypointEffects = false

function Game.server_onCreate( self )
	print("Game.server_onCreate")
    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
		self.storage:save( self.sv.saved )
	end

	sm.scriptableObject.createScriptableObject(sm.uuid.new("9c287602-9061-4bf5-8db5-58516c348bf0"), nil, self.sv.saved.world)

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( self.sv.saved.overworld )
end

function Game:server_onFixedUpdate()
	g_unitManager:sv_onFixedUpdate()
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
	if not sm.exists( self.sv.saved.world ) then
		sm.world.loadWorld( self.sv.saved.world )
	end
	self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )

	g_unitManager:sv_onPlayerJoined( player )
end

function Game:sv_createPlayerCharacter( world, x, y, player, params )
	local pos = sm.vec3.new( 0, 0, 0 )
    local character = sm.character.createCharacter( player, world, pos - VEC3_UP * 10, 0, 0 )
	player:setCharacter( character )
	sm.event.sendToPlayer(player, "sv_createMiner", pos)
end

function Game:sv_onRockHit(rock)
	self.network:sendToClients("cl_onRockHit", rock)
end

function Game:sv_recreate(data, player)
	self.sv.saved.world:destroy()
	self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
	sm.scriptableObject.createScriptableObject(sm.uuid.new("9c287602-9061-4bf5-8db5-58516c348bf0"), nil, self.sv.saved.world)

	self.storage:save( self.sv.saved )

	if not sm.exists( self.sv.saved.world ) then
		sm.world.loadWorld( self.sv.saved.world )
	end

	for k, v in pairs(sm.player.getAllPlayers()) do
		self.sv.saved.world:loadCell( 0, 0, v, "sv_createPlayerCharacter" )
	end
end

function Game:sv_enemies()
	g_spawnEnemies = not g_spawnEnemies
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

	self.cl_rockAnims = {}
end

function Game:client_onFixedUpdate(dt)
	local speed = dt * 5
	for k, v in pairs(self.cl_rockAnims) do
		if sm.exists(v.rock) and v.time > 0 then
			v.time = v.time - speed
			v.rock:setPoseWeight(0, v.time)
		else
			self.cl_rockAnims[k] = nil
		end
	end
end

function Game.client_onLoadingScreenLifted( self )
	g_effectManager:cl_onLoadingScreenLifted()
end

function Game:cl_onRockHit(rock)
	table_insert(self.cl_rockAnims, { rock = rock, time = math.random(50, 100) * 0.01 })
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
    sm.game.bindChatCommand("/enemies", {}, "cl_enemies", "Toggle enemy spawning")
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

function Game:cl_enemies()
	self.network:sendToServer("sv_enemies")
end