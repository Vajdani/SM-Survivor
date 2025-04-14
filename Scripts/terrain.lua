dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )
dofile "util.lua"

local rockMin = 0
local rockMax = 64

local rockId = uuid("0c01f246-0090-43e4-8453-c1390322a7e4")
local mineralId = uuid("e731dede-34df-467f-8beb-315985179860")
local plasticId = uuid( "628b2d61-5ceb-43e9-8334-a4135566df7a" )

local rockRot = angleAxis(RAD90, VEC3_X)

local function GetRockType(val)
    if val > 0.3 and val < 0.31 then
        return ROCKTYPE.GOLD
    elseif val > 0.33 and val < 0.35 then
        return ROCKTYPE.NITRA
    end

    return ROCKTYPE.ROCK
end

local function IsBorder(cellX, cellY, x, y)
	return
		cellX == g_xMax and x == rockMax or
		cellX == g_xMin and x == rockMin or
		cellY == g_yMax and y == rockMax or
		cellY == g_yMin and y == rockMin
end

local function DisplayNoise(cellX, cellY, x, y, noise)
	table_insert(g_cellData.gridData[cellY][cellX].nodes, {
		pos = vec3(cellX + x, cellY + y, 25),
		rot = QUAT_IDENTITY,
		scale = VEC3_ONE,
		params = {
			effect = {
				name = "ShapeRenderable",
				params = {
					"uuid",
					plasticId,
					"color",
					colour(noise, noise, noise)
				},
			}
		},
		tags = { "EFFECT" },
	})
end

local function AddRock(cellX, cellY, x, y, noise_x, noise_y, corner, mineralSeed)
	local rock = {
		rockType = GetRockType(abs(perlin(noise_x, noise_y, mineralSeed))),
		pos = corner + vec3(x, y, 0.75),
		rot = random(0, 3),
	}

	table_insert(g_cellData.gridData[cellY][cellX].rocks, rock)
end

local function AddWaypoint(cellX, cellY, x, y)
	table_insert(g_cellData.gridData[cellY][cellX].nodes, {
		pos = vec3(cellX + x, cellY + y, 0),
		tags = { "WAYPOINT" },
	})
end

local function AddGridItems(cellX, cellY, x, y, seed, mineralSeed, corner)
	if IsBorder(cellX, cellY, x, y) then
		local rock = {
			rockType = ROCKTYPE.BORDER,
			pos = corner + vec3(x, y, 0.75),
			rot = random(0, 3),
		}

		table_insert(g_cellData.gridData[cellY][cellX].rocks, rock)

		return
	end

	local final_x, final_y = (cellX * 64 + x) * 0.125, (cellY * 64 + y) * 0.125
	local rockNoise = abs(perlin(final_x, final_y, seed))
	-- DisplayNoise(cellX, cellY, x, y, rockNoise)

	if rockNoise > 0.15 then
		AddRock(cellX, cellY, x, y, final_x, final_y, corner, mineralSeed)
	else
		AddWaypoint(cellX, cellY, x, y)

		if rockNoise > 0.14 then
			-- g_cellData.gridData[cellY][cellX].water[x.."_"..y] = true
			-- table_insert(g_cellData.gridData[cellY][cellX].nodes, {
			-- 	pos = vec3(cellX + x, cellY + y, 0.5),
			-- 	params = {
			-- 		guaranteed = true
			-- 	},
			-- 	tags = { "TOTEBOT_GREEN" },
			-- })
		end
	end
end

local function AssembleGrid(cellX, cellY, seed, mineralSeed)
	local corner = vec3(cellX, cellY, 0)
	for x = rockMin, rockMax do
		for y = rockMin, rockMax do
			-- local rock = {
			-- 	rockType = ROCKTYPE.ROCK,
			-- 	pos = corner + vec3(x, y, 0.75),
			-- 	rot = random(0, 3),
			-- }

			-- table_insert(g_cellData.gridData[cellY][cellX].rocks, rock)

			AddGridItems(cellX, cellY, x, y, seed, mineralSeed, corner)
		end
	end
end



function Init()
	print( "Init terrain" )
end

function Create( xMin, xMax, yMin, yMax, seed, data )
	math.randomseed( seed )

	g_uuidToPath = {}
	g_cellData = {
		bounds = { xMin = xMin, xMax = xMax, yMin = yMin, yMax = yMax },
		seed = seed,

		mineralSeed = seed + math.random() * 500,
		gridData = {},
		cellLoaded = {}
	}

	g_xMax = g_cellData.bounds.xMax
	g_xMin = g_cellData.bounds.xMin
	g_yMax = g_cellData.bounds.yMax
	g_yMin = g_cellData.bounds.yMin

	for cellY = yMin, yMax do
		g_cellData.gridData[cellY] = {}
		g_cellData.cellLoaded[cellY] = {}

		for cellX = xMin, xMax do
			g_cellData.gridData[cellY][cellX] = {
				rocks = {},
				water = {},
				nodes = {}
			}
			g_cellData.cellLoaded[cellY][cellX] = false

		    AssembleGrid(cellX, cellY, g_cellData.seed, g_cellData.mineralSeed)
		end
	end

	sm.terrainData.save( g_cellData )
end

function Load()
	-- if sm.terrainData.exists() then
	-- 	local data = sm.terrainData.load()
	-- 	g_uuidToPath = data[1]
	-- 	g_cellData = data[2]
	-- 	return true
	-- end
	return false
end

function GetTilePath( uid )
	return ""
end

function GetHeightAt( x, y, lod )
	local height = 0

	-- local cellX, cellY = GetCell( x, y )
	-- if InsideCellBounds( cellX, cellY ) then
	-- 	local water = g_cellData.gridData[cellY][cellX].water
	-- 	if water[x.."_"..y] == true then
	-- 		height = -1
	-- 	end
	-- end

	return height --sm.terrainTile.getHeightAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
end

function GetColorAt( x, y, lod )
	local r, g , b = 0.242, 0.423, 0.512
	-- local cellX, cellY = GetCell( x, y )
	-- if InsideCellBounds( cellX, cellY ) then
	-- 	local water = g_cellData.gridData[cellY][cellX].water
	-- 	if water[x.."_"..y] == true then
	-- 		r, g, b = 0, 0, 1
	-- 	end
	-- end

	return r, g, b --sm.terrainTile.getColorAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
end

function GetMaterialAt( x, y, lod )
	return 1, 0, 0, 0, 0, 0, 0, 0 --sm.terrainTile.getMaterialAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
end

function GetClutterIdxAt( x, y )
	return -1
end

function GetAssetsForCell( cellX, cellY, lod )
	return {}
end



local defaultNodes = {
	{
		pos = vec3( 32, 32, 32 ),
		rot = sm.quat.new( 0.707107, 0, 0, 0.707107 ),
		scale = vec3( 64, 64, 64 ),
		tags = { "REFLECTION" }
	}
}

local amount = 3
for i = 1, amount do
	for j = 1, amount do
		table_insert(defaultNodes, {
			pos = vec3(i * 16, j * 16, 0),
			rot = QUAT_IDENTITY,
			scale = VEC3_ONE,
			params = {
				effect = {
					name = "Smoke - GroundSmokeMassive",
					params = {},
				}
			},
			tags = { "EFFECT" },
		})
	end
end

function GetNodesForCell( cellX, cellY )
	if not InsideCellBounds(cellX, cellY) then
		return {}
	end

	local nodes = defaultNodes
	for k, v in pairs(g_cellData.gridData[cellY][cellX].nodes) do
		table_insert(nodes, {
			pos = v.pos,
			rot = v.rot or QUAT_IDENTITY,
			scale = v.scale or VEC3_ONE,
			params = v.params,
			tags = v.tags
		})
	end

	return nodes
end

function GetCreationsForCell( cellX, cellY )
	return {}
end

function GetHarvestablesForCell( cellX, cellY, lod )
	if g_cellData.cellLoaded[cellY][cellX] == true then
		return {}
	end

	local rocks = {}
	for k, v in pairs(g_cellData.gridData[cellY][cellX].rocks) do
		local rockType = v.rockType
		local isMineral = MINERALS[rockType] ~= nil

		local rot = rockRot
		if v.rot ~= 0 then
			rot = rot * angleAxis(RAD90 * v.rot, VEC3_Y)
		end

		table_insert(rocks, {
			uuid = isMineral and mineralId or rockId,
			pos = v.pos,
			rot = rot,
			params = isMineral and ROCKTYPES[rockType] or nil
		})
	end

	g_cellData.cellLoaded[cellY][cellX] = true

	return rocks
end

function GetKinematicsForCell( cellX, cellY, lod )
	return {}
end

function GetDecalsForCell( cellX, cellY, lod )
	return {}
end