---@class Slider
---@field gui GuiInterface
---@field name string
---@field steps number
---@field steps_reloading number
---@field colour Color
---@field colours Color[]
Slider = class()

local path = "$CONTENT_DATA/Gui/Slider/%s.png"

---Creates the slider.
---@param gui GuiInterface
---@param name string
---@param steps number
---@param steps_reloading number
---@param colours Color[]
---@return Slider
function Slider:init(gui, name, steps, steps_reloading, colours)
    self.gui = gui
    self.name = name
    self.steps, self.steps_reloading = steps, steps_reloading

    self.colours = colours
    self.colour = colours[1]

    self:setColour(self.colour)
    self:update_shooting(steps)

    return self
end

---@param value number
function Slider:update_shooting(value)
    if self.colour == self.colours[2] then
        self:setColour(self.colours[1])
    end

    self:update(value / self.steps * 100)
end

---@param value number
function Slider:update_reloading(value)
    if self.colour == self.colours[1] then
        self:setColour(self.colours[2])
    end

    self:update(100 - value / self.steps_reloading * 100)
end

---@param value number
function Slider:update(value)
    self.gui:setImage(self.name, path:format(sm.util.clamp(round(value), 0, 100)))
end

---@param colour Color
function Slider:setColour(colour)
    self.gui:setColor(self.name, colour)
    self.colour = colour
end