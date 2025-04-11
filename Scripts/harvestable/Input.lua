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
        return false
    end

    if not state then return false end

    if action == 20 then
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_increaseZoom")
    elseif action == 21 then
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_decreaseZoom")
    elseif action == sm.interactable.actions.item0 then
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setControlMethod", 0)
    elseif action == sm.interactable.actions.item1 then
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setControlMethod", 1)
    elseif action == sm.interactable.actions.item2 then
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setControlMethod", 2)
    end

    return false
end

function Input:sv_onMove(data, player)
    sm.event.sendToPlayer(player, "sv_onMove", data)
end