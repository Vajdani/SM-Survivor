MINERALDROPS = MINERALDROPS or {}
MINERALS = {
    "gold",
    "nitra"
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



---@class VisualizedTrigger
---@field trigger AreaTrigger
---@field effect Effect
---@field setPosition function
---@field setRotation function
---@field setScale function
---@field destroy function
---@field setVisible function
---@field show function
---@field hide function

---Create an AreaTrigger that has a visualization
---@param position Vec3
---@param scale Vec3
---@return VisualizedTrigger
function CreateVisualizedTrigger(position, scale)
    local effect = sm.effect.createEffect("ShapeRenderable")
    effect:setParameter("uuid", blk_glass)
    effect:setParameter("visualization", true)
    effect:setScale(scale)
    effect:setPosition(position)
    effect:start()

    return {
        trigger = sm.areaTrigger.createBox(scale * 0.5, position),
        effect = effect,
        setPosition = function(self, position)
            self.trigger:setWorldPosition(position)
            self.effect:setPosition(position)
        end,
        setRotation = function(self, rotation)
            self.trigger:setWorldRotation(rotation)
            self.effect:setRotation(rotation)
        end,
        setScale = function(self, scale)
            self.trigger:setScale(scale * 0.5)
            self.effect:setScale(scale)
        end,
        destroy = function(self)
            sm.areaTrigger.destroy(self.trigger)
            self.effect:destroy()
        end,
        setVisible = function(self, state)
            if state then
                self.effect:start()
            else
                self.effect:stop()
            end
        end,
        show = function(self)
            self.effect:start()
        end,
        hide = function(self)
            self.effect:stop()
        end
    }
end