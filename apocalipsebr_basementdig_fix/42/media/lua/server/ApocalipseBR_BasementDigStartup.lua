local function report(ready, filename, check)
    local result = ready and "OK" or "ERROR"
    local detail = ready and " ready" or " did not initialize"
    print("[apocalipsebr_basementdig_fix] startup " .. result .. " " .. filename .. " - " .. check .. detail)
end

Events.OnServerStarted.Add(function()
    report(ApocalipseBR_BasementChunkHookReady, "aparosa_BD_Build.lua", "chunk hook")
    report(ApocalipseBR_BasementLadderHookReady, "aparosa_BD_Ladder.lua", "ladder sprite hooks")
    report(ApocalipseBR_BasementRecoveryReady, "aparosa_BD_Mirror.lua", "record recovery timer")
end)
