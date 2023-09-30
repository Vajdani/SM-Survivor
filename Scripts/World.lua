---@class World : WorldClass
---@field sv_spawnData table
World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -2
World.cellMaxX = 1
World.cellMinY = -2
World.cellMaxY = 1
World.worldBorder = true

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
local types = {
    { type = "gold", health = 5 },
    { type = "nitra", health = 4 },
}
local rockRot = sm.quat.angleAxis(math.rad(90), sm.vec3.new(1,0,0))
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

    for x = self.cellMinX + 1, self.cellMaxX - 1 do
        for y = self.cellMinY + 1, self.cellMaxY - 1 do
            table.insert(self.sv_spawnData.chunks, { x = x, y = y })
        end
    end

    --self:spawnInChunk(0, 0, seed, mineralSeed)

    sm.player.getAllPlayers()[1].character:setWorldPosition(sm.vec3.new(0,0,10))
    --self.network:sendToClient(sm.player.getAllPlayers()[1], "cl_generateTerrain", { rock = seed, mineral = mineralSeed })
end

function World:cl_generateTerrain(seeds)
    if not self.cl_fx then
        self.cl_fx = {}
    end

    for k, v in pairs(self.cl_fx) do
        if sm.exists(v) then
            v:destroy()
        end
    end
    self.cl_fx = {}

    local cell_x, cell_y = 0, 0
    local seed, mineralSeed = seeds.rock, seeds.mineral
    local uuid = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")
    local corner = sm.vec3.new(64 * cell_x, 64 * cell_y, 0)
    local divide = 8
    local scale = sm.vec3.one() * 0.25 * divide * 0.5
    for x = 0, 63 do
        for y = 0, 63 do
            local final_x, final_y = (cell_x + x) / divide, (cell_y + y) / divide
            local noise_rock = math.abs(sm.noise.perlinNoise2d(final_x, final_y, seed))

            local effect = sm.effect.createEffect("ShapeRenderable")
            effect:setParameter("uuid", uuid)
            effect:setParameter("color", sm.color.new(noise_rock, noise_rock, noise_rock))
            effect:setPosition(corner + sm.vec3.new(x, y, 0))
            effect:setScale(scale)
            effect:start()

            self.cl_fx[#self.cl_fx+1] = effect
        end
    end
end

local noise = sm.noise.perlinNoise2d
local abs = math.abs
function World:spawnInChunk(cell_x, cell_y, seed, mineralSeed)
    local corner = sm.vec3.new(64 * cell_x, 64 * cell_y, 0)
    for x = 0, 63 do
        for y = 0, 63 do
            local final_x, final_y = (cell_x + x) / 8, (cell_y + y) / 8
            if abs(noise(final_x, final_y, seed)) > 0.15 then
                local rock = sm.harvestable.create(rockId, corner + sm.vec3.new(x, y, 0.75), rockRot)

                if abs(noise(final_x, final_y, mineralSeed)) < 0.01 then
                    rock:setParams(types[math.random(#types)])
                end

                table.insert(self.sv_rocks, rock)
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