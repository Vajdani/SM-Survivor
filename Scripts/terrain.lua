dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )
dofile "util.lua"

local rockMin = 0
local rockMax = 63

local rockId = uuid("0c01f246-0090-43e4-8453-c1390322a7e4")
local mineralId = uuid("e731dede-34df-467f-8beb-315985179860")
local plasticId = uuid( "628b2d61-5ceb-43e9-8334-a4135566df7a" )

local rockRot = angleAxis(RAD90, VEC3_X)

local function GetGridKey(x, y)
	-- return tonumber(("%s%s"):format(x, y))
	return ("%s_%s"):format(x, y)
end

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

local function AddRock(cellX, cellY, x, y, noise_x, noise_y, mineralSeed, rockType)
	local rock = {
		rockType = rockType or GetRockType(abs(perlin(noise_x, noise_y, mineralSeed))),
		pos = { x, y },
		rot = random(0, 3),
	}

	table_insert(g_cellData.gridData[cellY][cellX].rocks, rock)
end

local function AddWaypoint(cellX, cellY, x, y)
	table_insert(g_cellData.gridData[cellY][cellX].nodes, {
		pos = { x, y },
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

local function AddGridItems(cellX, cellY, x, y, seed, mineralSeed)
	if IsBorder(cellX, cellY, x, y) then
		AddRock(cellX, cellY, x, y, nil, nil, nil, 1)
		return
	end

	local noise_x, noise_y = (cellX * 64 + x) * 0.125, (cellY * 64 + y) * 0.125
	local rockNoise = abs(perlin(noise_x, noise_y, seed))
	-- DisplayNoise(cellX, cellY, x, y, rockNoise)

	if rockNoise > 0.15 then
		AddRock(cellX, cellY, x, y, noise_x, noise_y, mineralSeed)
	else
		AddWaypoint(cellX, cellY, x, y)

		-- if rockNoise > 0.14 then
		-- 	g_cellData.gridData[cellY][cellX].water[x.."_"..y] = true
		-- 	table_insert(g_cellData.gridData[cellY][cellX].nodes, {
		-- 		pos = vec3(cellX + x, cellY + y, 0.5),
		-- 		params = {
		-- 			guaranteed = true
		-- 		},
		-- 		tags = { "TOTEBOT_GREEN" },
		-- 	})
		-- end
	end
end

local function AssembleGrid(cellX, cellY, seed, mineralSeed)
	for x = rockMin, rockMax do
		for y = rockMin, rockMax do
			-- table_insert(g_cellData.gridData[cellY][cellX].rocks, {
			-- 	rockType = ROCKTYPE.ROCK,
			-- 	pos = { x, y },
			-- 	rot = random(0, 3),
			-- })

			AddGridItems(cellX, cellY, x, y, seed, mineralSeed)
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
		gridData = {}
	}

	g_cellLoaded = {}

	g_xMax = g_cellData.bounds.xMax
	g_xMin = g_cellData.bounds.xMin
	g_yMax = g_cellData.bounds.yMax
	g_yMin = g_cellData.bounds.yMin

	g_wayPointCounter = 1

	for cellY = yMin, yMax do
		g_cellData.gridData[cellY] = {}
		g_cellLoaded[cellY] = {}

		for cellX = xMin, xMax do
			g_cellData.gridData[cellY][cellX] = {
				rocks = {},
				nodes = {}
			}
			g_cellLoaded[cellY][cellX] = false

		    AssembleGrid(cellX, cellY, g_cellData.seed, g_cellData.mineralSeed)
		end
	end

	local waypointPositionToIndex = {}
	local rockPositionToIndex = {}
	for cellY = yMin, yMax do
		waypointPositionToIndex[cellY] = {}
		rockPositionToIndex[cellY] = {}

		for cellX = xMin, xMax do
			waypointPositionToIndex[cellY][cellX] = {}
			rockPositionToIndex[cellY][cellX] = {}

			for k, node in pairs(g_cellData.gridData[cellY][cellX].nodes) do
				if node.tags[1] == "WAYPOINT" then
					waypointPositionToIndex[cellY][cellX][GetGridKey(node.pos[1], node.pos[2])] = k
				end
			end

			for k, node in pairs(g_cellData.gridData[cellY][cellX].rocks) do
				rockPositionToIndex[cellY][cellX][GetGridKey(node.pos[1], node.pos[2])] = k
			end
		end
	end

	local directions = {
		[1] = { 1,  0 },
		[2] = { -1, 0 },
		[3] = { 0,  1 },
		[4] = { 0, -1 }
	}

	for cellY = yMin, yMax do
		for cellX = xMin, xMax do
			local nodes = g_cellData.gridData[cellY][cellX].nodes --[[ @as TerrainNode[] ]]
			for k, node in pairs(nodes) do
				if node.tags[1] == "WAYPOINT" then
					local pos = node.pos
					for i = 1, 4 do
						local dir = directions[i]
						local offset = { pos[1] + dir[1], pos[2] + dir[2] }
						local nextNode = waypointPositionToIndex[cellY][cellX][GetGridKey(offset[1], offset[2])]
						if nextNode then
							table_insert(node.params.connections.otherIds, nodes[nextNode].params.connections.id)
						elseif
							rockPositionToIndex[cellY][cellX][GetGridKey(offset[1], offset[2])] == nil and
							(pos[1] == rockMin or pos[1] == rockMax or pos[2] == rockMin or pos[2] == rockMax) then
							-- and not (offset[1] == rockMin or offset[1] >= rockMax or offset[1] == rockMin or offset[1] >= rockMax) then
							local _cellX, _cellY = cellX + dir[1], cellY + dir[2]
							if InsideCellBounds( _cellX, _cellY ) then
								local pos_x, pos_y = -1, -1
								if i == 1 then
									pos_x, pos_y = rockMin, pos[2]
								elseif i == 2 then
									pos_x, pos_y = rockMax, pos[2]
								elseif i == 3 then
									pos_x, pos_y = pos[1], rockMin
								elseif i == 4 then
									pos_x, pos_y = pos[1], rockMax
								end

								nextNode = waypointPositionToIndex[_cellY][_cellX][GetGridKey(pos_x, pos_y)]
								if nextNode then
									local foreign = g_cellData.gridData[_cellY][_cellX].nodes[nextNode].params.connections
									table_insert(node.params.connections.otherIds, {
										id = foreign.id,
										cell = { dir[1], dir[2] },
										dir = dir
									})

									g_cellData.gridData[_cellY][_cellX].nodes[nextNode].params.connections.ccount = (foreign.ccount or 0) + 1
								end
							end
						end
					end
				end
			end
		end
	end

	waypointPositionToIndex = nil
	rockPositionToIndex = nil

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
	return 0
end

function GetColorAt( x, y, lod )
	return 0.242, 0.423, 0.512
end

function GetMaterialAt( x, y, lod )
	return 1, 0, 0, 0, 0, 0, 0, 0
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
			pos = vec3(v.pos[1], v.pos[2], 0),
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
	if g_cellLoaded[cellY][cellX] == true then
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
			pos = vec3(v.pos[1], v.pos[2], 0.75),
			rot = rot,
			params = ROCKTYPES[rockType]
		})
	end

	-- local seed, mineralSeed = g_cellData.seed, g_cellData.mineralSeed
	-- for x = rockMin, rockMax do
	-- 	for y = rockMin, rockMax do
	-- 		if IsBorder(cellX, cellY, x, y) then
	-- 			table_insert(rocks, {
	-- 				uuid = rockId,
	-- 				pos = vec3(x, y, 0.75),
	-- 				rot = rockRot * angleAxis(RAD90 * math.random(0, 3), VEC3_Y),
	-- 				params = ROCKTYPES[1]
	-- 			})
	-- 		else
	-- 			local noise_x, noise_y = (cellX * 64 + x) * 0.125, (cellY * 64 + y) * 0.125
	-- 			local rockNoise = abs(perlin(noise_x, noise_y, seed))
	-- 			if rockNoise > 0.15 then
	-- 				local rockType = GetRockType(abs(perlin(noise_x, noise_y, mineralSeed)))

	-- 				table_insert(rocks, {
	-- 					uuid = MINERALS[rockType] ~= nil and mineralId or rockId,
	-- 					pos = vec3(x, y, 0.75),
	-- 					rot = rockRot * angleAxis(RAD90 * math.random(0, 3), VEC3_Y),
	-- 					params = ROCKTYPES[rockType]
	-- 				})
	-- 			end
	-- 		end
	-- 	end
	-- end

	g_cellLoaded[cellY][cellX] = true

	return rocks
end

function GetKinematicsForCell( cellX, cellY, lod )
	return {}
end

function GetDecalsForCell( cellX, cellY, lod )
	return {}
end