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
World.renderMode = "warehouse"

function World.server_onCreate( self )
    print("World.server_onCreate")
    self.sv_rocks = {}
    self.sv_spawnData = {
        chunks = {},
        seed = 0,
        mineralSeed = 0
    }
end

local rockId = sm.uuid.new("0c01f246-0090-43e4-8453-c1390322a7e4")
local mineralId = sm.uuid.new("e731dede-34df-467f-8beb-315985179860")
local types = {
    { type = "gold", health = 5 },
    { type = "nitra", health = 4 },
}
local rockRot = sm.quat.angleAxis(RAD90, VEC3_X)
function World:sv_generateTerrain()
    for k, v in pairs(self.sv_rocks) do
        if sm.exists(v) then
            v:destroy()
        end
    end
    self.sv_rocks = {}

    local seed = os.clock() * 0.5 * math.random()
    local mineralSeed = seed + math.random() * 500
    self.sv_spawnData.seed = seed
    self.sv_spawnData.mineralSeed = mineralSeed
    print(seed, mineralSeed)

    for x = self.cellMinX, self.cellMaxX do
        for y = self.cellMinY, self.cellMaxY do
            table_insert(self.sv_spawnData.chunks, { x = x, y = y })
        end
    end
end

local function getMinreal(val)
    if val > 0.3 and val < 0.31 then
        return true, 2
    elseif val > 0.33 and val < 0.35 then
        return true, 1
    end

    return false, -1
end

local function newRock(self, uuid, pos, rot)
    local rock = sm.harvestable.create(uuid, pos, rot)
    table_insert(self.sv_rocks, rock)
    return rock
end

function World:spawnInChunk(cell_x, cell_y, seed, mineralSeed)
    local offset_x, offset_y = 64 * cell_x, 64 * cell_y
    local corner = vec3(offset_x, offset_y, 0)
    for x = 0, 63 do
        for y = 0, 63 do
            local final_x, final_y = (offset_x + x) / 8, (offset_y + y) / 8
            if abs(perlin(final_x, final_y, seed)) > 0.15 then
                local mineralNoise = abs(perlin(final_x, final_y, mineralSeed))
                local isMineral, mineralType = getMinreal(mineralNoise)
                if isMineral then
                    newRock(self, mineralId, corner + vec3(x, y, 0.75), rockRot * angleAxis(RAD90 * random(0, 3), VEC3_Y)):setParams(types[mineralType])
                else
                    newRock(self, rockId, corner + vec3(x, y, 0.75), rockRot * angleAxis(RAD90 * random(0, 3), VEC3_Y))
                end
            end
        end
    end
end

function World:server_onFixedUpdate()
    local data = self.sv_spawnData
    local chunks = data.chunks
    if #chunks > 0 and sm.game.getCurrentTick() % 20 == 0 then
        local coords = chunks[1]
        self:spawnInChunk(coords.x, coords.y, data.seed, data.mineralSeed)
        table.remove(self.sv_spawnData.chunks, 1)
    end
end

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