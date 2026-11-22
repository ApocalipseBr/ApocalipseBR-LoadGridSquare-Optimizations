-- This path overrides LiuDing_Tiles' original per-square Lua handler.
if isClient() then return end

local MARKER_SPRITE = "LiuDing_Tiles_3DItem_0"
local ITEM_TYPE = "Base.Sledgehammer"

local function surfaceHeight(square)
    local objects = square:getObjects()
    local surface = 0
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local sprite = object:getSprite()
        if sprite and sprite:getName() ~= MARKER_SPRITE and not instanceof(object, "IsoWorldInventoryObject") then
            local properties = sprite:getProperties()
            if properties:get("IsStackable") or properties:get("IsTable") then
                surface = tonumber(properties:get("Surface")) or 0
            end
        end
    end
    return surface / 128 + 0.1
end

local function convertMarker(marker)
    local square = marker:getSquare()
    if not square or marker:getObjectIndex() < 0 then return end

    local item = instanceItem(ITEM_TYPE)
    if not item then return end

    local x = ZombRandFloat(0.1, 1.0)
    local y = ZombRandFloat(0.1, 1.0)
    local placed = square:AddWorldInventoryItem(item, x, y, surfaceHeight(square), false)
    local worldItem = placed and placed:getWorldItem()
    if not worldItem then return end

    -- Publish the replacement only after the marker is gone.
    local ok, err = pcall(function() square:transmitRemoveItemFromSquare(marker) end)
    if marker:getObjectIndex() >= 0 then
        square:RemoveTileObject(worldItem)
    else
        worldItem:transmitCompleteItemToClients()
    end
    if not ok then error(err) end
end

Events.OnInitGlobalModData.Add(function()
    MapObjects.OnLoadWithSprite(MARKER_SPRITE, convertMarker, 5)
    ApocalipseBR_LiuDingTilesSpriteHookReady = true
end)
