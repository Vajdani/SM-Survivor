---@class MineralDrop : HarvestableClass
---@field destination Character
MineralDrop = class()

function MineralDrop:server_onCreate()
    local params = self.params
    if params then
        self.storage:save(params)
    else
        local data = self.storage:load()
        if data then
            self.network:sendToClients("cl_load", data)
        end
    end

    self.mineralId = self.harvestable.id
    MINERALDROPS[self.mineralId] = true
end

function MineralDrop:server_onDestroy()
    MINERALDROPS[self.mineralId] = nil
end

function MineralDrop:sv_onCollect(char)
    self.network:sendToClients("cl_onCollect", char)
end

function MineralDrop:sv_hitDestination(data)
    sm.event.sendToPlayer(self.destination:getUnit().publicData.owner, "sv_collectMineral", data)
    self.harvestable:destroy()
end



function MineralDrop:client_onCreate()
    local params = self.params
    if params then
        self:cl_load(params)
    end
end

function MineralDrop:client_onUpdate(dt)
    if not self.destination or self.destroyed then return end

    local destination = self.destination.worldPosition
    local newPos = sm.vec3.lerp(self.harvestable.worldPosition, destination, dt * 10)
    self.harvestable:setPosition(newPos)
    if (destination - newPos):length2() < 0.1 then
        if sm.isHost then
            self.network:sendToServer("sv_hitDestination", self.mineralData)
        end

        self.destroyed = true
    end
end

local fxId = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")
local fxScale = sm.vec3.one() * 0.25
function MineralDrop:cl_load(data)
    local _type = data.type
    self.effect = sm.effect.createEffect("ShapeRenderable", self.harvestable)
    self.effect:setScale(fxScale)
    self.effect:setParameter("uuid", fxId)
    self.effect:setParameter("color", MineralFormation.colours[_type])
    self.effect:start()

    self.mineralData = data
end

function MineralDrop:cl_onCollect(char)
    self.destination = char
end