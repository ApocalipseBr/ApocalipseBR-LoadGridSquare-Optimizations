Events.OnServerStarted.Add(function()
    local prefix = "[minidoracatbuilderfix] "
    if ApocalipseBR_BuilderChunkHookReady then
        print(prefix .. "startup OK Place.lua - chunk migration hook registered")
    else
        print(prefix .. "startup ERROR Place.lua - chunk migration hook did not register")
    end
    if ApocalipseBR_BuilderMigrationCacheReady then
        print(prefix .. "startup OK MigrationCache.lua - migration index initialized")
    else
        print(prefix .. "startup ERROR MigrationCache.lua - migration index did not initialize")
    end
end)
