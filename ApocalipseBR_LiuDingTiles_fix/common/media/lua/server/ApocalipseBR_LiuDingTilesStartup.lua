Events.OnServerStarted.Add(function()
    local prefix = "[ApocalipseBR_LiuDingTiles_fix] "
    if ApocalipseBR_LiuDingTilesSpriteHookReady then
        print(prefix .. "startup OK LiuDing3DItem.lua - sledgehammer sprite hook registered")
    else
        print(prefix .. "startup ERROR LiuDing3DItem.lua - sledgehammer sprite hook did not register")
    end
end)
