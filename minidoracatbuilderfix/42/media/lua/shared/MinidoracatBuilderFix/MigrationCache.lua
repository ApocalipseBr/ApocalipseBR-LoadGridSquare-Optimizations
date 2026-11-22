local Cache = {}
local DATA = "ApocalipseBR.MinidoracatBuilderMigration"
local STAMP = "ApocalipseBR_MinidoracatBuilderMigrationStamp"
local REVISION = 1
local SIZE = 8
local EMPTY = {}
local data

local function version(modId)
    local info = getModInfoByID(modId)
    return info and info:getModVersion() or ""
end

local function initialize()
    if isClient() then
        data = nil
        return
    end
    data = ModData.getOrCreate(DATA)
    local upstream = version("MinidoracatBuilderFor42")
    local patch = version("minidoracatbuilderfix")
    if data.revision ~= REVISION or data.upstream ~= upstream or data.patch ~= patch
        or type(data.chunks) ~= "table" then
        data.chunks = {}
        data.revision, data.upstream, data.patch = REVISION, upstream, patch
    end
end

function Cache.index()
    return data and data.chunks
end

function Cache.anchor(chunk)
    return chunk:getGridSquare(0, 0, 0)
end

local function key(x, y)
    return math.floor(x / SIZE) .. ":" .. math.floor(y / SIZE)
end

function Cache.key(square)
    return key(square:getX(), square:getY())
end

function Cache.lookup(index, anchor, firstZ, maxZ)
    if not (index and anchor and anchor:hasModData()) then return end
    local entry = index[Cache.key(anchor)]
    if type(entry) == "table" and type(entry.stamp) == "string"
        and entry.firstZ == firstZ and entry.maxZ == maxZ and anchor:getModData()[STAMP] == entry.stamp then
        if entry.squares == false then return EMPTY end
        if type(entry.squares) == "table" then return entry.squares end
    end
end

local stampSequence = 0
function Cache.complete(index, anchor, firstZ, maxZ, squares)
    stampSequence = stampSequence + 1
    local stamp = getTimestampMs() .. ":" .. ZombRand(1000000000) .. ":" .. stampSequence
    anchor:getModData()[STAMP] = stamp
    index[Cache.key(anchor)] = { stamp = stamp, firstZ = firstZ, maxZ = maxZ, squares = #squares > 0 and squares or false }
end

function Cache.invalidate(square)
    local index = Cache.index()
    if index then index[Cache.key(square)] = nil end
    -- A chunk can save before GlobalModData does, including just after a reset.
    -- Clear even a stamp whose index entry is only present in the previous save.
    local chunk = square:getChunk()
    local anchor = chunk and Cache.anchor(chunk)
    if anchor and anchor:hasModData() then anchor:getModData()[STAMP] = nil end
end

function Cache.reset()
    if not data then return false end
    data.chunks = {}
    return true
end

Events.OnInitGlobalModData.Add(initialize)

return Cache
