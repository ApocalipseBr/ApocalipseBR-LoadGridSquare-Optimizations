local reporters = {
    { "ApocalipseBR_LiuDingTiles_fix", "ApocalipseBR_LiuDingTilesStartup.lua" },
    { "ApocalipseBR_TrueSwimming_fix", "ApocalipseBR_TrueSwimmingStartup.lua" },
    { "minidoracatbuilderfix", "MinidoracatBuilderFix/Startup.lua" },
    { "apocalipsebr_basementdig_fix", "ApocalipseBR_BasementDigStartup.lua" },
}
local checks = {
    { "ApocalipseBR_LiuDingTilesSpriteHookReady", "LiuDing3DItem.lua" },
    { "ApocalipseBR_TrueSwimmingSpriteHookReady", "TrueSwimmingShared.lua" },
    { "ApocalipseBR_BuilderChunkHookReady", "Place.lua" },
    { "ApocalipseBR_BuilderMigrationCacheReady", "MigrationCache.lua" },
    { "ApocalipseBR_BasementChunkHookReady", "aparosa_BD_Build.lua" },
    { "ApocalipseBR_BasementLadderHookReady", "aparosa_BD_Ladder.lua" },
    { "ApocalipseBR_BasementRecoveryReady", "aparosa_BD_Mirror.lua" },
}

local messages = {}
print = function(message) table.insert(messages, message) end
for _, reporter in ipairs(reporters) do
    load_patch(reporter[1], "media/lua/server/" .. reporter[2])
end
assert(#messages == 0, "report only on server startup")
fire("OnServerStarted")
assert(#messages == #checks)
for i, check in ipairs(checks) do
    assert(messages[i]:find("startup ERROR " .. check[2], 1, true))
    _G[check[1]] = true
end
messages = {}
fire("OnServerStarted")
assert(#messages == #checks)
for i, check in ipairs(checks) do
    assert(messages[i]:find("startup OK " .. check[2], 1, true))
end
