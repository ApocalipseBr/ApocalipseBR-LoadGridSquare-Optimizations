Events.OnServerStarted.Add(function()
    local prefix = "[ApocalipseBR_TrueSwimming_fix] "
    if ApocalipseBR_TrueSwimmingSpriteHookReady then
        print(prefix .. "startup OK TrueSwimmingShared.lua - orphan-pontoon sprite hook registered")
    else
        print(prefix .. "startup ERROR TrueSwimmingShared.lua - generated orphan-pontoon sprite hook did not register")
    end
end)
