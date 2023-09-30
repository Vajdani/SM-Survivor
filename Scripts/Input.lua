---@class Input : HarvestableClass
Input = class()

local movementKeys = {
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
}

function Input:client_onAction(action, state)
    if movementKeys[action] == true then
        self.network:sendToServer("sv_onMove", { key = action, state = state })
    end

    return false
end

function Input:sv_onMove(data, player)
    sm.event.sendToPlayer(player, "sv_onMove", data)
end