MINERALDROPS = MINERALDROPS or {}

ROCKTYPES = {
    [0] = { 0,  3 }, --Rock
    [1] = { 1     }, --Border
    [2] = { 2,  5 }, --Gold
    [3] = { 3,  4 }, --Nitra
}

ROCKTYPE = {
    ROCK    = 0,
    BORDER  = 1,
    GOLD    = 2,
    NITRA   = 3,
}

MINERALS = {
    [ROCKTYPE.GOLD]  = "gold",
    [ROCKTYPE.NITRA] = "nitra",
}

VEC3_X = sm.vec3.new(1,0,0)
VEC3_Y = sm.vec3.new(0,1,0)
VEC3_UP = sm.vec3.new(0,0,1)

RAD90 = math.rad(90)

unit_miner = sm.uuid.new("eb3d1c56-e2c0-4711-9c8d-218b36d5380b")

table_insert = table.insert
perlin = sm.noise.perlinNoise2d
random = math.random
abs = math.abs
angleAxis = sm.quat.angleAxis
vec3 = sm.vec3.new

function GetYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end