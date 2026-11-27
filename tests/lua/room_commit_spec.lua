local server, accepted = true, true
function isServer() return server end
function getCell() return nil end
function getFileWriter() return nil end
function getTimestampMs() return 0 end
require = function() end

local order = {}
local function add(step) order[#order + 1] = step end
aparosa_BD_RoomSquares = {
    collect = function() add("collect") return {} end,
    fill = function() add("fill") end,
}
local editor = {
    applyChanges = function(_, loading) assert(loading == false) add("vanilla") end,
    setCurrentBuilding = function() end,
    createBuilding = function()
        return { createRoom = function()
            return { setName = function() end, addRectangle = function() end }
        end }
    end,
    isValid = function() return true end,
}
BuildingRoomsEditor = { Reset = function() end, getInstance = function() return editor end }
local bridge = { tryApply = function(draft, x, y, z)
    assert(draft == editor and x == 511 and y == 8 and z == -1)
    add("bridge")
    return accepted
end }
ApocBRRoomEdits = bridge

load_patch("apocalipsebr_basementdig_fix", "media/lua/shared/aparosa_BasementDig/aparosa_BD_Rooms.lua")
local rooms = aparosa_BD_Rooms
rooms.ownRoomPoints = function() return {} end
rooms.noRefill = function() add("noRefill") end
rooms.log = function() end
rooms.refreshServerSquares = function() add("refresh") end
rooms.detachFromPlayerBuildings = function() end
rooms.markExplored = function() end
rooms.turnLightsOn = function() end
local record = { z = -1 }
local function grow(expected)
    order = {}
    rooms.live[record] = { cx = 511, cy = 8, tiles = { { x = 511, y = 8 } } }
    assert(rooms.growRecord(record, { { x = 512, y = 8 } }))
    assert(table.concat(order, ",") == expected)
end

grow("collect,bridge,noRefill,fill,refresh")
accepted = false
grow("collect,bridge,vanilla,noRefill,fill,refresh")
ApocBRRoomEdits = nil
grow("collect,vanilla,noRefill,fill,refresh")
ApocBRRoomEdits = bridge
server = false
grow("collect,vanilla,noRefill,fill")
server = true
order = {}
assert(rooms.registerRects({ { x = 511, y = 8, w = 1, h = 1 } }, -1, true, "room"))
assert(table.concat(order, ",") == "collect,vanilla,noRefill,fill,refresh")
