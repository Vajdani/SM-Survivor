dofile "util.lua"
dofile "survival_spawns.lua"

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

local spawnDelay = 5 * 40

function World:server_onCreate()
    print("World.server_onCreate")
end

function World:server_onCellCreated(x, y)
    local tags = sm.cell.getTags( x, y )
	local cell = { x = x, y = y, worldId = self.world.id, isStartArea = false, isPoi = false }

	SpawnFromNodeOnCellLoaded( cell, "TOTEBOT_GREEN" )
end

function World:server_onFixedUpdate()
    if #sm.unit.getAllUnits() >= 200 then return end

    for k, v in pairs(sm.player.getAllPlayers()) do
        if (sm.game.getCurrentTick() % (spawnDelay + 20 * v.id)) == 0 then
            self:sv_spawnEnemies(v.publicData.miner)
        end
    end
end

function World:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
    if projectileName == "mineral" then
        local drop = sm.harvestable.create(hvs_mineralDrop, position, angleAxis(math.rad(math.random(1, 360)), VEC3_UP))
        drop:setParams(customData)
    end
end



function World:client_onUpdate( dt )
	g_effectManager:cl_onWorldUpdate( self )
end

function World:client_onCellLoaded( x, y )
	g_effectManager:cl_onWorldCellLoaded( self, x, y )
end

function World:client_onCellUnloaded( x, y )
	g_effectManager:cl_onWorldCellUnloaded( self, x, y )
end



---@param miner Unit
function World:sv_spawnEnemies(miner)
    if not miner or not sm.exists(miner) then return end

	local char = miner.character
    if not char or not sm.exists(char) or char:isDowned() then return end

	local pos = char.worldPosition
	local dir = VEC3_Y

    local cycles = 30
    local anglePerCycle = 360 / cycles
    local distance = function() return math.random(10, 20) end
	for i = 1, cycles do
		local _dir = dir:rotate(math.rad(anglePerCycle * i), VEC3_UP) * distance()
        local spawnPos = pos + _dir
        local hit, result = sm.physics.raycast(spawnPos + VEC3_UP * 2.5, spawnPos - VEC3_UP)
        if result.type == "terrainSurface" then
            local yaw = GetYawPitch(-_dir)
            sm.unit.createUnit(unit_totebot_green, spawnPos, yaw, { target = char })
        end
	end
end