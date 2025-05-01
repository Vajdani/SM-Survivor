---@class EventManager : ScriptableObjectClass
EventManager = class()

function EventManager:server_onCreate()
    g_eventManager = self

    self.sv_events = {}
end

function EventManager:subscribeToEvent(object, callback, eventName)
    local events = sm.isServerMode() and self.sv_events or self.cl_events
    if not events[eventName] then
        events[eventName] = {}
    end

    table_insert(events[eventName], { object, callback })
end

function EventManager:unSubscribeFromEvent(object, eventName)
    local events = (sm.isServerMode() and self.sv_events or self.cl_events)[eventName]
    for k, v in pairs(events) do
        if v[1] == object then
            table.remove(events, k)
            return
        end
    end
end

function EventManager:invoke(eventName, args)
    for k, v in pairs((sm.isServerMode() and self.sv_events or self.cl_events)[eventName] or {}) do
        if sm.exists(v[1]) then
            local type = type(v[1])
            local func = sm.event["sendTo"..type]
            if func then
                func(v[1], v[2], args)
            else
                sm.log.error("CANNOT SEND EVENT TO OBJECT OF TYPE", type)
            end
        end
    end
end



function EventManager:client_onCreate()
    if not g_eventManager then
        g_eventManager = self
    end

    self.cl_events = {}
end



function EventManager.SubscribeToEvent(object, callback, eventName)
    if g_eventManager then
        g_eventManager:subscribeToEvent(object, callback, eventName)
    else
        sm.log.error("EVENTMANAGER DOESNT EXIST, CANNOT SUBSCRIBE TO EVENT", eventName)
    end
end

function EventManager.UnSubscribeFromEvent(object, eventName)
    if g_eventManager then
        g_eventManager:unSubscribeFromEvent(object, eventName)
    else
        sm.log.error("EVENTMANAGER DOESNT EXIST, CANNOT UNSUBSCRIBE FROM EVENT", eventName)
    end
end

function EventManager.Invoke(eventName, args)
    if g_eventManager then
        g_eventManager:invoke(eventName, args)
    else
        sm.log.error("EVENTMANAGER DOESNT EXIST, CANNOT INVOKE EVENT", eventName)
    end
end