dofile "util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/worlds/BaseWorld.lua"

---@class SpawnData
---@field chunks table
---@field seed number
---@field mineralSeed number

---@class World : WorldClass
---@field sv_spawnData SpawnData
World = class()
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.groundMaterialSet = "$GAME_DATA/Terrain/Materials/gnd_flat_materialset.json"
World.cellMinX = -1
World.cellMaxX = 0
World.cellMinY = -1
World.cellMaxY = 0
World.worldBorder = true
-- World.renderMode = "warehouse"

function World.server_onCreate( self )
    print("World.server_onCreate")
end

-- function World:server_onFixedUpdate()

-- end

local mineralDrop = sm.uuid.new("a09539ba-95d3-4f65-989d-83d1e9c32d0f")
function World:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
    if projectileName == "mineral" then
        local drop = sm.harvestable.create(mineralDrop, position, angleAxis(math.rad(math.random(1, 360)), VEC3_UP))
        drop:setParams(customData)
    end
end



function World.client_onUpdate( self, dt )
	g_effectManager:cl_onWorldUpdate( self )
end

function World.client_onCellLoaded( self, x, y )
	g_effectManager:cl_onWorldCellLoaded( self, x, y )
end

function World.client_onCellUnloaded( self, x, y )
	g_effectManager:cl_onWorldCellUnloaded( self, x, y )
end