---@class Input : HarvestableClass
Input = class()

local movementKeys = {
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
}

local freecamKeys = {
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
    [16] = true,
    [20] = true,
    [21] = true,
}

function Input:client_onAction(action, state)
    if g_cl_freecam and action == 5 and state then
        g_cl_freecamModifier = not g_cl_freecamModifier
    end

    if g_cl_freecam and freecamKeys[action] == true and not g_cl_freecamModifier then
        g_cl_freecamKeys[action] = state
        return false
    end

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
    elseif action == 10 then --Refresh class
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_refreshClass")
    elseif action == 11 then --New class
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_newClass")
    end

    return false
end

function Input:sv_onMove(data, player)
    sm.event.sendToPlayer(player, "sv_onMove", data)
end