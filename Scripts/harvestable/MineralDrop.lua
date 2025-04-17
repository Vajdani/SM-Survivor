---@class MineralDrop : HarvestableClass
---@field destination Character
MineralDrop = class()

function MineralDrop:server_onCreate()
    self.sv_data = self.params or self.storage:load()
    -- self.harvestable.publicData = self.sv_data

    self.mineralId = self.harvestable.id
    MINERALDROPS[self.mineralId] = true

    self.network:sendToClients("cl_load", self.sv_data.type)
end

function MineralDrop:server_onDestroy()
    MINERALDROPS[self.mineralId] = nil
end

function MineralDrop:sv_onCollect(char)
    self.network:sendToClients("cl_onCollect", char)
end

function MineralDrop:sv_hitDestination()
    sm.event.sendToPlayer(self.destination:getUnit().publicData.owner, "sv_collectMineral", self.sv_data)
    self.harvestable:destroy()
end



function MineralDrop:client_onUpdate(dt)
    if not self.destination or self.destroyed then return end

    local destination = self.destination.worldPosition
    local newPos = sm.vec3.lerp(self.harvestable.worldPosition, destination, dt * 10 * self.destination.movementSpeedFraction)
    self.harvestable:setPosition(newPos)
    if (destination - newPos):length2() < 0.1 then
        if sm.isHost then
            self.network:sendToServer("sv_hitDestination")
        end

        self.destroyed = true
    end
end


function MineralDrop:cl_load(type)
    self.harvestable:setColor(MINERALCOLOURS[type])
end

function MineralDrop:cl_onCollect(char)
    self.destination = char
end