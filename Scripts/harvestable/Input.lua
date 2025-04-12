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
    elseif action == 5 then --Straight
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setControlMethod", 0)
    elseif action == 6 then --Angled
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setControlMethod", 1)
    elseif action == 7 then --Mouselook
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setControlMethod", 2)
    -- dev
    elseif action == 8 then --Toggle weapons
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_toggleWeapons")
    elseif action == 9 then --Reapply upgrades
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_reapplyUpgrades")
    end

    return false
end

function Input:sv_onMove(data, player)
    sm.event.sendToPlayer(player, "sv_onMove", data)
end