local client = true
isClient = function() return client end
aparosa_BD_Rooms = { log = function() end }
aparosa_BD_Check = { BOTTOM = -32 }
local function load(name)
    load_patch("apocalipsebr_basementdig_fix", "media/lua/shared/aparosa_BasementDig/aparosa_BD_" .. name .. ".lua")
end
local dependencies = {
    Edge = true, Lights = true, Layout = true, Rooms = true, Check = true,
    ZExtent = true, Build = true, Expand = true, SwitchMove = true, Sync = true,
}
require = function(name)
    local module = name:match("^aparosa_BasementDig/aparosa_BD_(%w+)$")
    assert(dependencies[module], name)
end

local onLadder
MapObjects = { OnLoadWithSprite = function(sprites, callback, priority)
    assert(#sprites == 4 and priority == 17)
    local expected = { carpentry_02_84 = true, carpentry_02_85 = true, carpentry_02_86 = true, carpentry_02_87 = true }
    for _, sprite in ipairs(sprites) do
        assert(expected[sprite], sprite)
        expected[sprite] = nil
    end
    onLadder = callback
end }

load("Build")
load("Ladder")
load("Mirror")
fire("OnInitGlobalModData")
assert(not onLadder and not ApocalipseBR_BasementLadderHookReady, "clients must leave ladder discovery to the server")
fire("LoadChunk", {}) -- A client must never inspect this chunk.
client = false
fire("OnInitGlobalModData")
assert(onLadder and ApocalipseBR_BasementLadderHookReady and #Events.LoadGridsquare.callbacks == 0)
assert(ApocalipseBR_BasementChunkHookReady and not ApocalipseBR_BasementRecoveryReady)

local existingWorkers = #Events.OnTick.callbacks
local chunk = { getMinLevel = function() return 0 end }
fire("LoadChunk", chunk) -- A surface-only chunk needs no basement scan.
assert(#Events.OnTick.callbacks == existingWorkers)
local square = { getZ = function() return -1 end, getX = function() return 12 end, getY = function() return 20 end }
local ladder = { getSquare = function() return square end }
onLadder(ladder)
onLadder(ladder)
assert(#Events.OnTick.callbacks == existingWorkers + 1, "ladder discovery must defer repair")
local lookups = 0
getCell = function()
    return { getGridSquare = function(_, x, y, z)
        assert(x == 12 and y == 20 and z == -1)
        lookups = lookups + 1
        return nil -- The candidate unloaded before the worker ran.
    end }
end
fire("OnTick")
assert(lookups == 1 and #Events.OnTick.callbacks == existingWorkers, "discard a duplicate stale candidate and detach")

fire("OnServerStarted")
assert(ApocalipseBR_BasementRecoveryReady, "the server startup callback armed record recovery")

local key = "aparosa_BD_record"
local saved, batches, publishes, retries = {}, 0, 0, 0
aparosa_BD_Rooms.saved = function() return saved end
aparosa_BD_Rooms.registerRecordsBatch = function(changed)
    assert(#changed == 1 and changed[1] == saved[1])
    batches = batches + 1
    return 1
end
aparosa_BD_Expand = {
    findRecordAt = function() return saved[1] end,
    tilesOf = function() return {} end,
}
aparosa_BD_Sync = { publish = function() publishes = publishes + 1 end }
aparosa_BD_Ladder.retryRestoredRecord = function(_, record)
    assert(record == saved[1])
    retries = retries + 1
end

local anchor, expansion
local function makeSquare(x, record, floor)
    local data = { [key] = record }
    return {
        getX = function() return x end,
        getY = function() return 0 end,
        getFloor = function() return floor end,
        getObjects = function() return { isEmpty = function() return false end } end,
        hasModData = function() return data[key] ~= nil end,
        getModData = function() return data end,
    }
end
local function chunkFor(square)
    return {
        getMinLevel = function() return -1 end,
        getMaxLevel = function() return 0 end,
        getGridSquare = function(_, x, y, z)
            if x == 0 and y == 0 and z == -1 then return square end
        end,
    }
end
getCell = function()
    return {
        getGridSquare = function(_, x, y, z)
            if y == 0 and z == -1 then
                if x == 8 then return anchor end
                if x == 16 then return expansion end
            end
        end,
        getChunkForGridSquare = function() return anchor and true end,
    }
end
local function tick(times)
    for _ = 1, times do fire("OnTick") end
end
local function copyAt(version, variant)
    return { ax = 8, ay = 0, z = -1, kind = "dug", orient = "N", mirrorVer = version, variant = variant }
end

expansion = makeSquare(16, copyAt(1, "initial"))
fire("LoadChunk", chunkFor(expansion))
tick(120)
assert(#saved == 0 and aparosa_BD_Mirror.hasWaitingAnchors(), "wait for an unloaded anchor")
anchor = makeSquare(8, nil, true)
-- This case isolates recovery from the existing, independent level marker path.
aparosa_BD_Check.BOTTOM = -1
fire("LoadChunk", chunkFor(anchor))
tick(30)
assert(#saved == 1 and saved[1].mirrorVer == 1 and not aparosa_BD_Mirror.hasWaitingAnchors())
assert(anchor:getModData()[key].mirrorVer == 1 and batches == 1 and publishes == 1 and retries == 1)

expansion = makeSquare(16, copyAt(2, "expanded"))
fire("LoadChunk", chunkFor(expansion))
tick(30)
assert(#saved == 1 and saved[1].mirrorVer == 2 and saved[1].variant == "expanded")
assert(batches == 2 and publishes == 2 and retries == 2 and #Events.OnTick.callbacks == existingWorkers)
