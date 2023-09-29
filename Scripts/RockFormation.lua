---@class RockFormation : ShapeClass
RockFormation = class()
RockFormation.colours = {
    gold = sm.color.new(1,1,0),
    nitra = sm.color.new(1,0,0),
}

function RockFormation:server_onCreate()
    local params = self.params
    self.sv_type = params.type
    self.sv_health = params.health
end



local fxId = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")
local fxScale = sm.vec3.one() * 0.25
function RockFormation:client_onCreate()
    local rockType = self.params.type
    local startPos = sm.vec3.new(0,0,1)

    self.effects = {}
    for i = 1, 2 do
        for j = 1, 2 do
            local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
            effect:setParameter("uuid", fxId)
            effect:setParameter("color", self.colours[rockType])
            effect:setScale(fxScale)
            effect:setPosition(startPos)
            effect:start()

            self.effects[#self.effects+1] = effect
        end
    end
end