function resetEvents()
    Events = setmetatable({}, { __index = function(events, name)
        local callbacks = {}
        local event = { callbacks = callbacks }
        function event.Add(callback)
            table.insert(callbacks, callback)
        end
        function event.Remove(callback)
            for i, registered in ipairs(callbacks) do
                if registered == callback then
                    table.remove(callbacks, i)
                    return
                end
            end
        end
        rawset(events, name, event)
        return event
    end })
end

function fire(name, ...)
    for _, callback in ipairs(Events[name].callbacks) do callback(...) end
end

function javaList(items)
    return {
        size = function() return #items end,
        get = function(_, index) return items[index + 1] end,
    }
end

resetEvents()
