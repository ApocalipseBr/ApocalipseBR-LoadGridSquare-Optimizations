local _, companion, patched = ...
local function load(path)
    return load_patch(companion, "media/lua/" .. path)
end

isClient = function() return false end
isServer = function() return true end
instanceof = function() return false end
getTimestampMs = function() return 0 end
ZombRand = function() return 1 end
ModData = { getOrCreate = function() return {} end }
getModInfoByID = function() return nil end
local sprites = {}
MapObjects = { OnLoadWithSprite = function(names, callback)
    for _, name in ipairs(type(names) == "table" and names or { names }) do
        sprites[name] = callback
    end
end }

if companion == "ApocalipseBR_LiuDingTiles_fix" then
    load("server/Items/LiuDing3DItem.lua")
elseif companion == "ApocalipseBR_TrueSwimming_fix" then
    IsoSpriteManager, CharacterTrait, MoodleType = {}, {}, {}
    load("shared/TrueSwimmingShared.lua")
elseif companion == "minidoracatbuilderfix" then
    MinidoracatBuilder = { Entry = { settings = function() return {} end }, Rules = {}, Cost = {} }
    IsoFlagType, IsoObjectType, GridSquareEdgeFacingDirection = {}, {}, {}
    local cache = patched and load("shared/MinidoracatBuilderFix/MigrationCache.lua")
    require = function(name)
        if name == "MinidoracatBuilderFix/MigrationCache" then return assert(cache) end
        assert(name == "MinidoracatBuilder/Entry" or name == "MinidoracatBuilder/Cost", name)
    end
    load("shared/MinidoracatBuilder/Place.lua")
else
    assert(companion == "apocalipsebr_basementdig_fix")
    aparosa_BD_Rooms = { log = function() end, saved = function() return {} end }
    aparosa_BD_Check = { BOTTOM = -32 }
    IsoFlagType = {}
    local dependencies = {
        Edge = true, Lights = true, Layout = true, Rooms = true, Check = true,
        ZExtent = true, Build = true, Expand = true, SwitchMove = true, Sync = true,
    }
    require = function(name)
        assert(dependencies[name:match("^aparosa_BasementDig/aparosa_BD_(%w+)$")], name)
    end
    for _, name in ipairs({ "Build", "Ladder", "Mirror" }) do
        load("shared/aparosa_BasementDig/aparosa_BD_" .. name .. ".lua")
    end
end
fire("OnInitGlobalModData")
local spriteProperties = { set = function() end, CreateKeySet = function() end }
local sprite = { setName = function() end, getProperties = function() return spriteProperties end }
fire("OnLoadedTileDefinitions", { AddSprite = function() return sprite end })
if patched and companion ~= "minidoracatbuilderfix" then
    assert(next(sprites), "the patched sprite callback must be registered during startup")
end

local empty = javaList({})
local level = companion == "apocalipsebr_basementdig_fix" and -1 or 0
local data, squares = {}, {}
local chunk = {
    getMinLevel = function() return level end,
    getMaxLevel = function() return level end,
    getGridSquare = function(_, x, y, z)
        if z == level then return squares[x * 8 + y + 1] end
    end,
}
getCell = function() return chunk end
for x = 0, 7 do
    for y = 0, 7 do
        squares[#squares + 1] = {
            getX = function() return x end, getY = function() return y end, getZ = function() return level end,
            getChunk = function() return chunk end, getFloor = function() return nil end,
            getObjects = function() return empty end, getSpecialObjects = function() return empty end,
            hasModData = function() return next(data) ~= nil end, getModData = function() return data end,
        }
    end
end

local function dispatch(event, argument)
    local count = 0
    for _, callback in ipairs(Events[event].callbacks) do
        callback(argument)
        count = count + 1
    end
    return count
end

if companion == "ApocalipseBR_TrueSwimming_fix" then
    -- Both routes remove a real candidate before the timed empty-chunk workload.
    local square, removals = {}, 0
    local pontoon = { getName = function() return "TrueSwimming_ponton" end, getSquare = function() return square end }
    local dock = { getName = function() return "wooden_dock" end, getSquare = function() return square end }
    local objects = { dock, pontoon }
    square.getObjects = function() return javaList(objects) end
    square.RemoveTileObject = function(_, object)
        assert(object == pontoon, "orphan cleanup must leave ordinary dock tiles alone")
        table.remove(objects, 2)
        removals = removals + 1
    end
    for _, object in ipairs(objects) do
        local callback = sprites[object:getName()]
        if callback then callback(object) end
    end
    dispatch("LoadGridsquare", square)
    assert(removals == 1 and #objects == 1 and objects[1] == dock, "both variants must remove the orphan pontoon")
end

local function streamChunk()
    local squareCalls = 0
    for _, square in ipairs(squares) do
        squareCalls = squareCalls + dispatch("LoadGridsquare", square)
    end
    local chunkCalls = dispatch("LoadChunk", chunk)
    local tickCalls = dispatch("OnTick")
    return squareCalls, chunkCalls, tickCalls
end

-- Prime one empty chunk so the Builder measurement includes reuse of the verified cache entry.
if companion == "apocalipsebr_basementdig_fix" then
    fire("OnServerStarted")
    for _ = 1, 120 do fire("OnTick") end
end
streamChunk()
local expected = {
    ApocalipseBR_LiuDingTiles_fix = { { 64, 0, 0 }, { 0, 0, 0 } },
    ApocalipseBR_TrueSwimming_fix = { { 128, 0, 0 }, { 64, 0, 0 } },
    minidoracatbuilderfix = { { 64, 0, 0 }, { 0, 1, 0 } },
    apocalipsebr_basementdig_fix = { { 128, 1, 2 }, { 0, 1, 1 } },
}
local counts = expected[companion][patched and 2 or 1]
return function(chunks)
    local squareCalls, chunkCalls, tickCalls = 0, 0, 0
    for _ = 1, chunks do
        local s, c, t = streamChunk()
        squareCalls, chunkCalls, tickCalls = squareCalls + s, chunkCalls + c, tickCalls + t
    end
    assert(squareCalls == chunks * counts[1] and chunkCalls == chunks * counts[2] and tickCalls == chunks * counts[3],
        string.format("expected per chunk %d square, %d chunk, %d tick callbacks; got %.2f, %.2f, %.2f",
            counts[1], counts[2], counts[3], squareCalls / chunks, chunkCalls / chunks, tickCalls / chunks))
    return { square = squareCalls, chunk = chunkCalls, tick = tickCalls }
end
