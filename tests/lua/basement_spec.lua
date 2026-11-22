local client = true
isClient = function() return client end
aparosa_BD_Rooms = {}
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
assert(not onLadder, "clients must leave ladder discovery to the server")
fire("LoadChunk", {}) -- A client must never inspect this chunk.
client = false
fire("OnInitGlobalModData")
assert(onLadder and #Events.LoadGridsquare.callbacks == 0)

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
