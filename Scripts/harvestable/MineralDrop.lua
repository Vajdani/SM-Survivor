---@class MineralDrop : HarvestableClass
---@field destination Character
MineralDrop = class()

function MineralDrop:server_onCreate()
    local data = self.params or self.storage:load()
    self.harvestable.publicData = data

    self.mineralId = self.harvestable.id
    MINERALDROPS[self.mineralId] = true

    self.storage:save(data)
    self.network:sendToClients("cl_load", data.type)
end

function MineralDrop:server_onDestroy()
    MINERALDROPS[self.mineralId] = nil
end



function MineralDrop:cl_load(type)
    self.harvestable:setColor(MINERALCOLOURS[type])
end