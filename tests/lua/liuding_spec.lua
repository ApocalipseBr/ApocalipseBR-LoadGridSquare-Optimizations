local function loadPatch()
    load_patch("ApocalipseBR_LiuDingTiles_fix", "media/lua/server/Items/LiuDing3DItem.lua")
end

isClient = function() return true end
loadPatch()
assert(#Events.OnInitGlobalModData.callbacks == 0, "client must leave conversion to the server")

isClient = function() return false end
local convert
MapObjects = { OnLoadWithSprite = function(sprite, callback, priority)
    assert(sprite == "LiuDing_Tiles_3DItem_0" and priority == 5)
    assert(not convert, "expected exactly one sprite callback")
    convert = callback
end }
loadPatch()
assert(not ApocalipseBR_LiuDingTilesSpriteHookReady)
fire("OnInitGlobalModData")
assert(ApocalipseBR_LiuDingTilesSpriteHookReady)
assert(convert and #Events.LoadGridsquare.callbacks == 0)

local index, placed, published, rolledBack = 0, 0, 0, 0
local square = {}
local marker = {
    getSprite = function() return nil end,
    getSquare = function() return square end,
    getObjectIndex = function() return index end,
}
local surface = { IsTable = true, Surface = "64" }
local sprite = {
    getName = function() return "test_table" end,
    getProperties = function() return { get = function(_, name) return surface[name] end } end,
}
local worldItem = { transmitCompleteItemToClients = function()
    assert(index == -1, "publish only after removing the marker")
    published = published + 1
end }
local sledgehammer = { getWorldItem = function() return worldItem end }
instanceof = function() return false end
ZombRandFloat = function() return 0.5 end
instanceItem = function(id)
    assert(id == "Base.Sledgehammer")
    return sledgehammer
end

function square:getObjects()
    return javaList({ { getSprite = function() return sprite end }, marker })
end
function square:AddWorldInventoryItem(item, x, y, z, transmit)
    assert(item == sledgehammer and x == 0.5 and y == 0.5)
    assert(math.abs(z - 0.6) < 0.00001 and not transmit, "stage item at final height before transmission")
    placed = placed + 1
    return item
end
function square:transmitRemoveItemFromSquare(object)
    assert(object == marker)
    index = -1
end

convert(marker)
convert(marker)
assert(placed == 1 and published == 1, "repeat callbacks must leave one synchronized item")
assert(#Events.OnTick.callbacks == 0)

index = 0
function square:transmitRemoveItemFromSquare() end
function square:RemoveTileObject(object)
    assert(object == worldItem)
    rolledBack = rolledBack + 1
end
convert(marker)
assert(placed == 2 and published == 1 and rolledBack == 1, "undo placement when the marker remains")
