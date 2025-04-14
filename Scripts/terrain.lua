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
		params = {
			connections = {
				id = g_wayPointCounter,
				otherIds = {}
			}
		},
		tags = { "WAYPOINT" },
	})

	g_wayPointCounter = g_wayPointCounter + 1
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

	local noise_x, noise_y = (cellX * 64 + x) * 0.125, (cellY * 64 + y) * 0.125
	local rockNoise = abs(perlin(noise_x, noise_y, seed))
	-- DisplayNoise(cellX, cellY, x, y, rockNoise)

	if rockNoise > 0.15 then
		AddRock(cellX, cellY, x, y, noise_x, noise_y, corner, mineralSeed)
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

	g_wayPointCounter = 1

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

	local waypointPositionToIndex = {}
	for cellY = yMin, yMax do
		waypointPositionToIndex[cellY] = {}

		for cellX = xMin, xMax do
			waypointPositionToIndex[cellY][cellX] = {}

			local nodes = g_cellData.gridData[cellY][cellX].nodes
			for k, node in pairs(nodes) do
				if node.tags[1] == "WAYPOINT" then
					waypointPositionToIndex[cellY][cellX][("%s_%s"):format(node.pos.x, node.pos.y)] = k
				end
			end
		end
	end

	local directions = {
		[1] = vec3(1, 0, 0),
		[2] = vec3(-1, 0, 0),
		[3] = vec3(0, 1, 0),
		[4] = vec3(0, -1, 0)
	}

	for cellY = yMin, yMax do
		for cellX = xMin, xMax do
			local nodes = g_cellData.gridData[cellY][cellX].nodes --[[ @as TerrainNode[] ]]
			for k, node in pairs(nodes) do
				if node.tags[1] == "WAYPOINT" then
					local pos = node.pos
					for i = 1, 4 do
						local offset = pos + directions[i]
						local nextNode = waypointPositionToIndex[cellY][cellX][("%s_%s"):format(offset.x, offset.y)]
						if nextNode then
							table_insert(node.params.connections.otherIds, nodes[nextNode].params.connections.id)
						end
					end
				end
			end
		end
	end

	-- if nextNode then
	-- 	local con_self, con_foreign = node.params.connections, nodes[nextNode].params.connections
	-- 	if not isAnyOf(con_self.id, con_foreign.otherIds) then
	-- 	-- 	and not
	-- 	--    isAnyOf(con_foreign.id, con_self.otherIds) then
	-- 		table_insert(con_self.otherIds, con_foreign.id)
	-- 	end
	-- else
	-- 	-- local dir = directions[i]
	-- 	-- local _cellX, _cellY = cellX + dir.x, cellY + dir.y
	-- 	-- if (cellX < _cellX or cellY < _cellY) and InsideCellBounds( _cellX, _cellY ) then
	-- 	-- 	local offset_x, offset_y = -1, -1
	-- 	-- 	if i == 1 then
	-- 	-- 		offset_x, offset_y = 0, pos.y
	-- 	-- 	elseif i == 2 then
	-- 	-- 		offset_x, offset_y = 64, offset.y
	-- 	-- 	elseif i == 3 then
	-- 	-- 		offset_x, offset_y = offset.x, 0
	-- 	-- 	elseif i == 4 then
	-- 	-- 		offset_x, offset_y = offset.x, 64
	-- 	-- 	end

	-- 	-- 	nextNode = waypointPositionToIndex[_cellY][_cellX][("%s_%s"):format(offset_x, offset_y)]
	-- 	-- end

	-- 	-- if nextNode then
	-- 	-- 	local con_self, con_foreign = node.params.connections, g_cellData.gridData[_cellY][_cellX].nodes[nextNode].params.connections
	-- 	-- 	if not isAnyOf(con_self.id, con_foreign.otherIds) then
	-- 	-- 		table_insert(con_self.otherIds, {
	-- 	-- 			id = con_foreign.id,
	-- 	-- 			cell = { _cellX, _cellY }
	-- 	-- 		})
	-- 	-- 	end
	-- 	-- end
	-- end

	sm.terrainData.save( g_cellData )
end

function Load()
	-- if sm.terrainData.exists() then
	-- 	g_cellData = sm.terrainData.load()
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
			params = ROCKTYPES[rockType]
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