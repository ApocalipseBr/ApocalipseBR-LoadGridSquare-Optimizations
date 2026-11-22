local mod = "minidoracatbuilderfix"
MinidoracatBuilder = { Entry = {}, Rules = {}, Cost = {} }
IsoFlagType, IsoObjectType, GridSquareEdgeFacingDirection = {}, {}, {}
isClient = function() return true end
local cache = load_patch(mod, "media/lua/shared/MinidoracatBuilderFix/MigrationCache.lua")
require = function(name)
    if name == "MinidoracatBuilderFix/MigrationCache" then return cache end
    assert(name == "MinidoracatBuilder/Entry" or name == "MinidoracatBuilder/Cost", name)
end
load_patch(mod, "media/lua/shared/MinidoracatBuilder/Place.lua")
assert(#Events.LoadGridsquare.callbacks == 0)
assert(#Events.LoadChunk.callbacks == 1)
assert(#Events.OnObjectAdded.callbacks == 1 and #Events.OnObjectAboutToBeRemoved.callbacks == 1)
assert(#Events.OnTick.callbacks == 0)

local chunk = {
    getMinLevel = function() return 0 end,
    getMaxLevel = function() return 0 end,
}
fire("LoadChunk", chunk)
fire("LoadChunk", chunk)
assert(#Events.OnTick.callbacks == 1, "repeated chunk loads share the deferred worker")
