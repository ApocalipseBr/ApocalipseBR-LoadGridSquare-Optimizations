local companion = "apocalipsebr_basementdig_fix"
local function load(name)
    load_patch(companion, "media/lua/shared/aparosa_BasementDig/aparosa_BD_" .. name .. ".lua")
end
require = function(name) assert(name:find("^aparosa_BasementDig/")) end

local now, deadline = 0, 0
function isServer() return true end
function getTimestampMs() return now end
local function checkpoint() return now >= deadline end

local host = { kind = "map", z = -1, extra = { { x = 4, y = 5 } } }
local neighbor = { kind = "map", z = -1, extra = { { x = 6, y = 5 } } }
local saved = { host, neighbor }
local markerRemovals, floors, registrations, spoil, publications = 0, 0, 0, 0, 0
local diffs = {}
local character = {}
local floor = {
    addFloor = function() floors = floors + 1 end,
    RecalcAllWithNeighbours = function() end,
}
function getCell() return { getGridSquare = function() return floor end } end
aparosa_BD_Rooms = {
    log = function() end,
    saved = function() return saved end,
    rectsOf = function(record)
        now = now + 4
        local rects = {}
        for _, t in ipairs(record.extra) do
            rects[#rects + 1] = { x = t.x, y = t.y, w = 1, h = 1 }
        end
        return rects
    end,
    growRecord = function()
        now = now + 100
        registrations = registrations + 1
        return true
    end,
}
aparosa_BD_Build = {
    SPRITE = { tier = { dirt = { floor = "floor" } } },
    squareAt = function() return floor end,
    removeEarth = function() end,
}
aparosa_BD_Layout = { expandDiff = function(tiles)
    now = now + 4
    diffs[#diffs + 1] = #tiles
    return { add = {}, remove = {} }
end }
aparosa_BD_Types = { tier = function() return {} end }
local refusals = 0
aparosa_BD_Check = { notifyFailure = function(actor, reason)
    assert(actor == character and reason == "owner limit")
    refusals = refusals + 1
end }
local canGrow = true
aparosa_BD_Owner = { canGrow = function(actor)
    assert(actor == character)
    return canGrow, "owner limit"
end }
aparosa_BD_Spoil = {
    canExpand = function(actor) assert(actor == character) return true end,
    onExpanded = function() spoil = spoil + 1 end,
}
local queued, accept = {}, true
local library = { Jobs = { forMod = function(owner)
    assert(owner == "aparosa_BasementDig")
    return { start = function(step)
        if not accept then return nil end
        local ticket = { step = step, status = "pending" }
        queued[#queued + 1] = ticket
        return ticket
    end }
end } }
aparosa_BD_Sync = {
    deferredLibrary = function() return library end,
    publish = function() publications = publications + 1 end,
}

load("Expand")
local expand = aparosa_BD_Expand
expand.touchesMap = function() return false end
expand.validate = function()
    assert(aparosa_BD_Check.buildCharacter == character)
    return true
end
local frozenDepth = 0
local withFrozenIndex = expand.withFrozenIndex
expand.withFrozenIndex = function(...)
    frozenDepth = frozenDepth + 1
    local a, b, c, d = withFrozenIndex(...)
    frozenDepth = frozenDepth - 1
    return a, b, c, d
end
local function run(budget)
    deadline = now + budget
    local done = queued[1].step(nil, function()
        assert(frozenDepth == 0 and aparosa_BD_Check.buildCharacter == nil)
        return checkpoint()
    end)
    if done then table.remove(queued, 1) end
    return done
end

load("Entity")
local function enqueue(x)
    local markerSquare = {
        transmitRemoveItemFromSquare = function() markerRemovals = markerRemovals + 1 end,
        getX = function() return x end,
        getY = function() return 5 end,
        getZ = function() return -1 end,
    }
    local params = { character = character, thumpable = { getSquare = function() return markerSquare end } }
    assert(aparosa_BD_Entity.OnCreateExpandDirt(params).objectAlreadyTransmitted)
    return markerSquare
end

local printed = {}
print = function(line) printed[#printed + 1] = line end
local pendingSquare = enqueue(5)
assert(not aparosa_BD_Entity.isValidExpand({ square = pendingSquare }, "dirt"))
enqueue(3)
assert(#queued == 2 and markerRemovals == 2 and floors == 0)
assert(not run(4) and #queued == 2 and #diffs == 0) -- cold lookup
now = now + 1000
assert(not run(4) and #diffs == 0) -- host tiles
assert(not run(4) and #diffs == 0) -- neighbor tiles
assert(not run(4) and diffs[1] == 2 and floors == 0) -- wall diff
assert(run(4) and #queued == 1)
assert(#diffs == 1 and floors == 1 and registrations == 1 and spoil == 1 and publications == 1)
assert(printed[1]:find("searchMs=8 geometryMs=12 finishMs=100 pauses=4 result=true", 1, true))

assert(not run(12) and diffs[2] == 2 and floors == 1)
host.extra[#host.extra + 1] = { x = 4, y = 6 } -- An unrelated callback changes the record.
assert(run(100) and #queued == 0)
assert(diffs[3] == 3 and floors == 2 and registrations == 2 and publications == 2)

accept = false
enqueue(2)
assert(#queued == 0 and floors == 3 and publications == 3)
local queuedLibrary = library
library = nil
enqueue(1)
assert(#queued == 0 and floors == 4 and publications == 4)

library, accept = queuedLibrary, true
canGrow = false
enqueue(0)
assert(run(100) and refusals == 1 and floors == 4 and publications == 4)
