dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )

local RAD90 = math.rad(90)
local VEC3_X = sm.vec3.new(1,0,0)
local VEC3_Y = sm.vec3.new(0,1,0)
local VEC3_UP = sm.vec3.new(0,0,1)

local table_insert = table.insert
local perlin = sm.noise.perlinNoise2d
local random = math.random
local abs = math.abs
local angleAxis = sm.quat.angleAxis
local vec3 = sm.vec3.new

function Init()
	print( "Init terrain" )
end

function Create( xMin, xMax, yMin, yMax, seed, data )
	math.randomseed( seed )

	g_uuidToPath = {}
	g_cellData = {
		bounds = { xMin = xMin, xMax = xMax, yMin = yMin, yMax = yMax },
		seed = seed,
		-- Per Cell
		uid = {},
		xOffset = {},
		yOffset = {},
		rotation = {},

		mineralSeed = seed + math.random() * 500,
		rocks = {},
	}

	for cellY = yMin, yMax do
		g_cellData.uid[cellY] = {}
		g_cellData.xOffset[cellY] = {}
		g_cellData.yOffset[cellY] = {}
		g_cellData.rotation[cellY] = {}

		g_cellData.rocks[cellY] = {}

		for cellX = xMin, xMax do
			g_cellData.uid[cellY][cellX] = sm.uuid.getNil()
			g_cellData.xOffset[cellY][cellX] = 0
			g_cellData.yOffset[cellY][cellX] = 0
			g_cellData.rotation[cellY][cellX] = 0

			g_cellData.rocks[cellY][cellX] = {}
		end
	end

	local jWorld = sm.json.open( "$CONTENT_DATA/Terrain/Worlds/rockFloor.world")
	for _, cell in pairs( jWorld.cellData ) do
		if cell.path ~= "" then
			local uid = sm.terrainTile.getTileUuid( cell.path )
			g_cellData.uid[cell.y][cell.x] = uid
			g_cellData.xOffset[cell.y][cell.x] = cell.offsetX
			g_cellData.yOffset[cell.y][cell.x] = cell.offsetY
			g_cellData.rotation[cell.y][cell.x] = cell.rotation

			g_uuidToPath[tostring(uid)] = cell.path
		end
	end

	sm.terrainData.save( { g_uuidToPath, g_cellData } )
end

function Load()
	if sm.terrainData.exists() then
		local data = sm.terrainData.load()
		g_uuidToPath = data[1]
		g_cellData = data[2]
		return true
	end
	return false
end

function GetTilePath( uid )
	if not uid:isNil() then
		return g_uuidToPath[tostring(uid)]
	end
	return ""
end

function GetCellTileUidAndOffset( cellX, cellY )
	if InsideCellBounds( cellX, cellY ) then
		return	g_cellData.uid[cellY][cellX],
				g_cellData.xOffset[cellY][cellX],
				g_cellData.yOffset[cellY][cellX]
	end
	return sm.uuid.getNil(), 0, 0
end

function GetTileLoadParamsFromWorldPos( x, y, lod )
	local cellX, cellY = GetCell( x, y )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	local rx, ry = InverseRotateLocal( cellX, cellY, x - cellX * CELL_SIZE, y - cellY * CELL_SIZE )
	if lod then
		return  uid, tileCellOffsetX, tileCellOffsetY, lod, rx, ry
	else
		return  uid, tileCellOffsetX, tileCellOffsetY, rx, ry
	end
end

function GetTileLoadParamsFromCellPos( cellX, cellY, lod )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if lod then
		return  uid, tileCellOffsetX, tileCellOffsetY, lod
	else
		return  uid, tileCellOffsetX, tileCellOffsetY
	end
end

function GetHeightAt( x, y, lod )
	return sm.terrainTile.getHeightAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
end

function GetColorAt( x, y, lod )
	return 0.242, 0.423, 0.512 --sm.terrainTile.getColorAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
end

function GetMaterialAt( x, y, lod )
	return 1, 0, 0, 0, 0, 0, 0, 0 --sm.terrainTile.getMaterialAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
end

function GetClutterIdxAt( x, y )
	return sm.terrainTile.getClutterIdxAt( GetTileLoadParamsFromWorldPos( x, y ) )
end

function GetAssetsForCell( cellX, cellY, lod )
	local assets = sm.terrainTile.getAssetsForCell( GetTileLoadParamsFromCellPos( cellX, cellY, lod ) )
	for _, asset in ipairs( assets ) do
		local rx, ry = RotateLocal( cellX, cellY, asset.pos.x, asset.pos.y )
		asset.pos = sm.vec3.new( rx, ry, asset.pos.z )
		asset.rot = GetRotationQuat( cellX, cellY ) * asset.rot
	end
	return assets
end

function GetNodesForCell( cellX, cellY )
	local nodes = sm.terrainTile.getNodesForCell( GetTileLoadParamsFromCellPos( cellX, cellY ) )
	local hasReflectionProbe = false
	for _, node in ipairs( nodes ) do
		local rx, ry = RotateLocal( cellX, cellY, node.pos.x, node.pos.y )
		node.pos = sm.vec3.new( rx, ry, node.pos.z )
		node.rot = GetRotationQuat( cellX, cellY ) * node.rot

		hasReflectionProbe = hasReflectionProbe or ValueExists( node.tags, "REFLECTION" )
	end

	if not hasReflectionProbe then
		local x = ( cellX + 0.5 ) * CELL_SIZE
		local y = ( cellY + 0.5 ) * CELL_SIZE
		table_insert(nodes, {
			pos = sm.vec3.new( 32, 32, 32 ),
			rot = sm.quat.new( 0.707107, 0, 0, 0.707107 ),
			scale = sm.vec3.new( 64, 64, 64 ),
			tags = { "REFLECTION" }
		})
	end

	return nodes
end

function GetCreationsForCell( cellX, cellY )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local cellCreations = sm.terrainTile.getCreationsForCell( uid, tileCellOffsetX, tileCellOffsetY )
		for i,creation in ipairs( cellCreations ) do
			local rx, ry = RotateLocal( cellX, cellY, creation.pos.x, creation.pos.y )

			creation.pos = sm.vec3.new( rx, ry, creation.pos.z )
			creation.rot = GetRotationQuat( cellX, cellY ) * creation.rot
		end

		return cellCreations
	end

	return {}
end



local rockId = sm.uuid.new("0c01f246-0090-43e4-8453-c1390322a7e4")
local mineralId = sm.uuid.new("e731dede-34df-467f-8beb-315985179860")
local types = {
    { type = "gold", health = 5 },
    { type = "nitra", health = 4 },
}
local rockRot = sm.quat.angleAxis(RAD90, VEC3_X)

local function getMineral(val)
    if val > 0.3 and val < 0.31 then
        return true, 2
    elseif val > 0.33 and val < 0.35 then
        return true, 1
    end

    return false, -1
end

local rockMin = 0
local rockMax = 65

local function IsBorder(cellX, cellY, x, y)
	-- if x == y and (x == rockMin or x == rockMax or x == rockMin + 1 or x == rockMax - 1) then
	-- 	return false
	-- end

	if cellX == g_cellData.bounds.xMax and x == rockMax then
		return true
	end

	if cellX == g_cellData.bounds.xMin and x == rockMin then
		return true
	end

	if cellY == g_cellData.bounds.yMax and y == rockMax then
		return true
	end

	if cellY == g_cellData.bounds.yMin and y == rockMin then
		return true
	end

	return false
end

function GetHarvestablesForCell( cellX, cellY, lod )
	-- local harvestables = sm.terrainTile.getHarvestablesForCell( GetTileLoadParamsFromCellPos( cellX, cellY, lod ) )
	-- for _, harvestable in ipairs( harvestables ) do
	-- 	local rx, ry = RotateLocal( cellX, cellY, harvestable.pos.x, harvestable.pos.y )
	-- 	harvestable.pos = sm.vec3.new( rx, ry, harvestable.pos.z )
	-- 	harvestable.rot = GetRotationQuat( cellX, cellY ) * harvestable.rot
	-- end
	-- return harvestables

	-- if true then return {} end

	if #g_cellData.rocks[cellY][cellX] > 0 then return {} end

	local seed, mineralSeed = g_cellData.seed, g_cellData.mineralSeed

	---@type TerrainHarvestable[]
	local rocks = {}

	sm.log.info(cellX, cellY)
    local corner = vec3(cellX, cellY, 0)
    for x = rockMin, rockMax do
        for y = rockMin, rockMax do
			if IsBorder(cellX, cellY, x, y) then
				local rock = {
					uuid = rockId,
					pos = corner + vec3(x, y, 0.75),
					rot = rockRot * angleAxis(RAD90 * random(0, 3), VEC3_Y),
					color = sm.color.new(0,0,0),
					tags = {},
					params = { type = "border", health = 0 }
				}

				table_insert(rocks, rock)
			elseif false then
				local final_x, final_y = (cellX + x) / 8, (cellY + y) / 8
				if abs(perlin(final_x, final_y, seed)) > 0.15 then
					local mineralNoise = abs(perlin(final_x, final_y, mineralSeed))
					local isMineral, mineralType = getMineral(mineralNoise)

					---@type TerrainHarvestable
					local rock = {
						uuid = isMineral and mineralId or rockId,
						pos = corner + vec3(x, y, 0.75),
						rot = rockRot * angleAxis(RAD90 * random(0, 3), VEC3_Y),
						color = sm.color.new(0,0,0),
						tags = {},
						params = isMineral and types[mineralType] or nil
					}

					table_insert(rocks, rock)
				end
			end
        end
    end

	g_cellData.rocks[cellY][cellX] = rocks

	return rocks
end

function GetKinematicsForCell( cellX, cellY, lod )
	local kinematics = sm.terrainTile.getKinematicsForCell( GetTileLoadParamsFromCellPos( cellX, cellY, lod ) )
	for _, kinematic in ipairs( kinematics ) do
		local rx, ry = RotateLocal( cellX, cellY, kinematic.pos.x, kinematic.pos.y )
		kinematic.pos = sm.vec3.new( rx, ry, kinematic.pos.z )
		kinematic.rot = GetRotationQuat( cellX, cellY ) * kinematic.rot
	end
	return kinematics
end

function GetDecalsForCell( cellX, cellY, lod )
	local decals = sm.terrainTile.getDecalsForCell( GetTileLoadParamsFromCellPos( cellX, cellY, lod ) )
	for _, decal in ipairs( decals ) do
		local rx, ry = RotateLocal( cellX, cellY, decal.pos.x, decal.pos.y )
		decal.pos = sm.vec3.new( rx, ry, decal.pos.z )
		decal.rot = GetRotationQuat( cellX, cellY ) * decal.rot
	end
	return decals
end