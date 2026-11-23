local mod = "minidoracatbuilderfix"
MinidoracatBuilder = { Entry = {}, Rules = {}, Cost = {} }
IsoFlagType, IsoObjectType, GridSquareEdgeFacingDirection = {}, {}, {}
local client = true
isClient = function() return client end
local cache = load_patch(mod, "media/lua/shared/MinidoracatBuilderFix/MigrationCache.lua")
require = function(name)
    if name == "MinidoracatBuilderFix/MigrationCache" then return cache end
    assert(name == "MinidoracatBuilder/Entry" or name == "MinidoracatBuilder/Cost", name)
end
load_patch(mod, "media/lua/shared/MinidoracatBuilder/Place.lua")
assert(#Events.LoadGridsquare.callbacks == 0)
assert(#Events.LoadChunk.callbacks == 1 and ApocalipseBR_BuilderChunkHookReady)
assert(#Events.OnObjectAdded.callbacks == 1 and #Events.OnObjectAboutToBeRemoved.callbacks == 1)
assert(#Events.OnTick.callbacks == 0)

local chunk = {
    getMinLevel = function() return 0 end,
    getMaxLevel = function() return 0 end,
}
fire("LoadChunk", chunk)
fire("LoadChunk", chunk)
assert(#Events.OnTick.callbacks == 1, "repeated chunk loads share the deferred worker")

assert(not ApocalipseBR_BuilderMigrationCacheReady)
client = false
ModData = { getOrCreate = function() return {} end }
getModInfoByID = function() return nil end
fire("OnInitGlobalModData")
assert(ApocalipseBR_BuilderMigrationCacheReady and type(cache.index()) == "table")

local Place = MinidoracatBuilder.Place
local Entry, Rules, Cost = MinidoracatBuilder.Entry, MinidoracatBuilder.Rules, MinidoracatBuilder.Cost
Entry.settings = function() return {} end
getTimestampMs = function() return 10 end
ZombRand = function() return 17 end
isServer = function() return true end
instanceof = function(object, kind) return object.kind == kind end
chunk.getGridSquare = function() return nil end
getCell = function() return {} end
fire("OnTick")
assert(#Events.OnTick.callbacks == 0, "empty scan detaches the worker")

local data, materials = {}, { ["Base.Plank"] = 2 }
local square = {}
local floor = {
    kind = "IsoThumpable",
    getSquare = function() return square end,
    hasModData = function() return true end,
    getModData = function() return { builderEntry = "floor" } end,
    getName = function() return "floor" end,
    getSprite = function() return { getName = function() return "floor" end } end,
    isFloor = function() return true end,
    getThumpDmg = function() return 8 end,
    getContainerCount = function() return 0 end,
    isDismantable = function() return true end,
    setIsDismantable = function() end,
    hasBuildMaterials = function() return materials["Base.Plank"] ~= nil end,
    getBuildMaterials = function() return materials end,
}
local objects = javaList({ floor })
objects.contains = function(_, object) return object == floor end
square.getX = function() return 8 end
square.getY = function() return 8 end
square.getZ = function() return 0 end
square.has = function() return false end
square.getChunk = function() return chunk end
square.getModData = function() return data end
square.hasModData = function() return data.ApocalipseBR_MinidoracatBuilderMigrationStamp ~= nil end
square.getObjects = function() return objects end
square.getSpecialObjects = square.getObjects
local visits = 0
chunk.getGridSquare = function(_, x, y, z)
    visits = visits + 1
    if x == 0 and y == 0 and z == 0 then return square end
end
getCell = function()
    return { getGridSquare = function(_, x, y, z)
        if x == 8 and y == 8 and z == 0 then return square end
    end }
end
local rechecks = 0
Place.recheck = function(x, y, z)
    assert(x == 8 and y == 8 and z == 0)
    rechecks = rechecks + 1
end
Cost.refund = function() return "builder" end

fire("LoadChunk", chunk)
assert(visits == 1 and rechecks == 0, "LoadChunk only checks the cache anchor")
fire("OnTick")
assert(rechecks == 1 and materials["Base.Plank"] == 2, "keep the refund before the ledger loads")
assert(not cache.lookup(cache.index(), square, 0, 0), "unfinished migrations cannot become cache hits")

local ledger
MinidoracatBuilder.Floors = {
    instance = true,
    get = function() return ledger end,
    put = function(_, refund) ledger = { s = "floor", i = { ["Base.Plank"] = refund["Base.Plank"] } } end,
}
fire("OnTick")
assert(ledger.i["Base.Plank"] == 2 and not materials["Base.Plank"], "transfer the deferred refund exactly once")
assert(#Events.OnTick.callbacks == 0)
fire("LoadChunk", chunk)
fire("OnTick")
assert(#cache.lookup(cache.index(), square, 0, 0) == 1 and rechecks == 2, "index the migrated square")
visits = 0
fire("LoadChunk", chunk)
fire("OnTick")
assert(visits == 2 and rechecks == 3, "cache hits visit only the anchor and candidate and still recheck regions")

-- Builder 1.3.0 treats the wall overlay as the sliding door's only frame.
IsoFlagType.cutN, IsoFlagType.WallSE = "cutN", "WallSE"
Rules.SLIDING_FRAME = "sliding"
local prop = {
    has = function(_, flag) return flag == "cutN" end,
    get = function(_, key) return key == "WindowShape" and "sliding" end,
}
local frame = { getProperties = function() return prop end }
local frameSquare = {
    has = function() return false end,
    getDoor = function() return true end,
    getObjects = function() return javaList({ frame }) end,
}
assert(Place.framesDoor(frame, frameSquare), "the only sliding frame must stay attached")
frameSquare.getObjects = function() return javaList({ frame, { getProperties = frame.getProperties } }) end
assert(not Place.framesDoor(frame, frameSquare), "a second matching frame allows teardown")
