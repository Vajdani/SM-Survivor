dofile "util.lua"
dofile "survival_spawns.lua"

dofile( "$GAME_DATA/Scripts/game/managers/CreativePathNodeManager.lua")

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

local spawnDelay = 7 * 40

function World:server_onCreate()
    print("World.server_onCreate")

    self.pathNodeManager = CreativePathNodeManager()
	self.pathNodeManager:sv_onCreate( self )
end

function World:server_onCellCreated(x, y)
    local tags = sm.cell.getTags( x, y )
	local cell = { x = x, y = y, worldId = self.world.id, isStartArea = false, isPoi = false }

	SpawnFromNodeOnCellLoaded( cell, "TOTEBOT_GREEN" )

	self.pathNodeManager:sv_loadPathNodesOnCell( x, y )
end

function World:server_onFixedUpdate()
    if not g_spawnEnemies or #sm.unit.getAllUnits() >= 200 then return end

    for k, v in pairs(sm.player.getAllPlayers()) do
        if (sm.game.getCurrentTick() % (spawnDelay + 40 * v.id)) == 0 then
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

    if not g_enableWaypointEffects then return end

    if not self.effects then
        self.effects = {}
    end

    local nodes = sm.cell.getNodesByTag(x, y, "WAYPOINT")
    local list = {}
    for k, v in pairs(nodes) do
        list[v.params.connections.id] = k
    end

    for k, v in pairs(nodes) do
        local effectId = "ShapeRenderable"..math.floor(#self.effects/4096)

        local effect = sm.effect.createEffect(effectId)
        effect:setParameter("uuid", blk_plastic)
        effect:setScale(VEC3_ONE * 0.25)
        effect:setPosition(v.position)
        effect:start()

        table_insert(self.effects, effect)

        for _k, _v in pairs(v.params.connections.otherIds) do
            local node = nodes[list[_v]]
            if node then
                local pos = node.position

                effectId = "ShapeRenderable"..math.floor(#self.effects/4096)
                local _effect = sm.effect.createEffect(effectId)
                _effect:setParameter("uuid", blk_plastic)

                local dir = pos - v.position
                _effect:setPosition(v.position + dir * 0.5)
                _effect:setRotation(sm.vec3.getRotation(VEC3_UP, dir:safeNormalize(VEC3_UP)))
                _effect:setScale(vec3(0.15, 0.15, dir:length()))
                _effect:start()

                table_insert(self.effects, _effect)
            else
                -- sm.log.warning("sus node")
            end
        end
    end
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