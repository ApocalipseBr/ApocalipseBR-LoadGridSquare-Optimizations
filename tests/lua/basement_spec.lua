local client, server = true, false
isClient = function() return client end
isServer = function() return server end
aparosa_BD_Rooms = { log = function() end }
aparosa_BD_Check = { BOTTOM = -32 }
local function load(name)
    load_patch("apocalipsebr_basementdig_fix", "media/lua/shared/aparosa_BasementDig/aparosa_BD_" .. name .. ".lua")
end
local dependencies = {
    Edge = true, Lights = true, Layout = true, Rooms = true, Check = true,
    ZExtent = true, Build = true, Expand = true, SwitchMove = true, Sync = true,
    Sandbox = true, Owner = true,
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

-- The real command keeps the full network snapshot and mirrors only the surviving record.
server = true
local host = saved[1]
local merged = { ax = 17, ay = 0, z = -1 }
local unrelated = { ax = 24, ay = 0, z = -1 }
saved[2], saved[3] = merged, unrelated
local recalcs, transmissions, frozen = 0, 0, 0
local lookup = getCell().getGridSquare
expansion.RecalcAllWithNeighbours = function() recalcs = recalcs + 1 end
expansion.getFloor = function() return true end
getCell = function() return { getGridSquare = lookup } end
getWorld = function()
    return { getMetaGrid = function() return { getRoomAt = function() return nil end } end }
end
getTimestampMs = function() return 1234 end
aparosa_BD_Rooms.MODDATA_KEY = "basement-records"
aparosa_BD_Rooms.growRecord = function(record, tiles)
    assert(record == host and #tiles == 1 and tiles[1].x == 16 and tiles[1].y == 0)
    return true
end
aparosa_BD_Expand.findHost = function() return host end
aparosa_BD_Expand.othersAround = function() return { merged } end
aparosa_BD_Expand.joinOthers = function(record, others)
    assert(record == host and others[1] == merged)
    record.joined = others
    table.remove(saved, 2)
end
aparosa_BD_Expand.localEdges = function() return {} end
aparosa_BD_Expand.withFrozenIndex = function(fn, ...)
    frozen = frozen + 1
    return fn(...)
end
local copied = {}
aparosa_BD_Expand.tilesOf = function(record)
    copied[#copied + 1] = record
    return record.extra or {}
end
aparosa_BD_Sandbox = {
    modEnabled = function() return true end,
    allowAdopt = function() return true end,
}
local player = {}
local nearby, withinLimit, notice = false, false, nil
local limitNotice = "IGUI_aparosa_BasementDig_Reason_LimitTiles"
aparosa_BD_Owner = { canGrow = function(character, record)
    assert(character == player and record == host)
    return withinLimit, limitNotice
end }
aparosa_BD_Check.isBasementLevel = function(z) return z == -1 end
aparosa_BD_Check.requesterNear = function() return nearby, "far" end
aparosa_BD_Check.notifyFailure = function(character, key)
    assert(character == player)
    notice = key
end
aparosa_BD_Build.SPRITE.dirt.wall = {}
ModData = { transmit = function(name)
    assert(name == aparosa_BD_Rooms.MODDATA_KEY and #saved == 2 and saved[2] == unrelated)
    transmissions = transmissions + 1
end }
load("Sync")
load("Adopt")
local command = { x = 16, y = 0, z = -1 }
fire("OnClientCommand", "aparosa_BasementDig", "adopt", player, command)
assert(not host.extra and transmissions == 0 and #copied == 0 and notice == "IGUI_aparosa_BasementAdopt_Far")
nearby = true
fire("OnClientCommand", "aparosa_BasementDig", "adopt", player, command)
assert(not host.extra and #saved == 3 and transmissions == 0 and #copied == 0 and notice == limitNotice,
    "a floor rejected by the owner limit cannot be merged, published or mirrored")
withinLimit = true
fire("OnClientCommand", "aparosa_BasementDig", "adopt", player, command)
assert(transmissions == 1 and #copied == 1 and copied[1] == host and frozen == 2 and recalcs == 1)
assert(host.extra[1].adopted and anchor:getModData()[key].mirrorVer == 1234)
assert(expansion:getModData()[key].joined[1].ax == merged.ax and unrelated.mirrorVer == nil)
assert(notice == "IGUI_aparosa_BasementAdopt_Done")
aparosa_BD_Sync.publish()
assert(transmissions == 2 and #copied == 2 and copied[2] == unrelated, "other publishers still scan all records")
