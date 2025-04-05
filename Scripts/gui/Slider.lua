Slider = class()

local path = "$CONTENT_DATA/Gui/Slider/%s.png"
local colour_normal = sm.color.new("#df7f00")
local colour_reloading = sm.color.new("#ff0000")

function Slider:init(gui, name, steps, steps_reloading)
    self.gui = gui
    self.name = name
    self.steps, self.steps_reloading = steps, steps_reloading
    self.colour = colour_normal

    self:setColour(colour_normal)
    self:update_shooting(steps)

    return self
end

function Slider:update_shooting(value)
    if self.colour == colour_reloading then
        self:setColour(colour_normal)
    end

    self:update(value / self.steps * 100)
end

function Slider:update_reloading(value)
    if self.colour == colour_normal then
        self:setColour(colour_reloading)
    end

    self:update(100 - value / self.steps_reloading * 100)
end

function Slider:update(value)
    self.gui:setImage(self.name, path:format(round(value)))
end

function Slider:setColour(colour)
    self.gui:setColor(self.name, colour)
    self.colour = colour
end