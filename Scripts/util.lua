MINERALDROPS = MINERALDROPS or {}

ROCKTYPES = {
    [0] = { 0,  3 }, --Rock
    [1] = { 1     }, --Border
    [2] = { 2,  5 }, --Gold
    [3] = { 3,  4 }, --Nitra
    --[4] = { 4     }, --XP
}

ROCKTYPE = {
    ROCK    = 0,
    BORDER  = 1,
    GOLD    = 2,
    NITRA   = 3,
    XP      = 4,
}

MINERALS = {
    [ROCKTYPE.GOLD]  = "gold",
    [ROCKTYPE.NITRA] = "nitra",
    [ROCKTYPE.XP]    = "xp",
}

MINERALCOLOURS = {
    [ROCKTYPE.GOLD]  = sm.color.new(1,1,0),
    [ROCKTYPE.NITRA] = sm.color.new(1,0,0),
    [ROCKTYPE.XP]    = sm.color.new("#149dff"),
}

VEC3_X = sm.vec3.new(1,0,0)
VEC3_Y = sm.vec3.new(0,1,0)
VEC3_UP = sm.vec3.new(0,0,1)
VEC3_ONE = sm.vec3.one()

RAD90 = math.rad(90)

QUAT_IDENTITY = sm.quat.identity()

unit_miner = sm.uuid.new("eb3d1c56-e2c0-4711-9c8d-218b36d5380b")

hvs_mineralDrop = sm.uuid.new("a09539ba-95d3-4f65-989d-83d1e9c32d0f")
hvs_xpDrop = sm.uuid.new("24b899a3-a663-4da5-b1bf-670ea4bf16a2")

table_insert = table.insert
perlin = sm.noise.perlinNoise2d
random = math.random
abs = math.abs
angleAxis = sm.quat.angleAxis
vec3 = sm.vec3.new

function GetYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end

---@param position Vec3
function DropXP(position)
    local drop = sm.harvestable.create(hvs_xpDrop, vec3(position.x, position.y, 0.1), angleAxis(math.rad(math.random(1, 360)), VEC3_UP))
    drop:setParams({ type = ROCKTYPE.XP, amount = math.random(1, 2) })
end