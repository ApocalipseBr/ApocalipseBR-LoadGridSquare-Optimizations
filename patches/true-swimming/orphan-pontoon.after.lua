local function removeOrphanPontoon(obj)
    local sq = obj:getSquare()
    if sq and obj:getName() == MARK then
        sq:RemoveTileObject(obj)
    end
end

Events.OnLoadedTileDefinitions.Add(function()
    MapObjects.OnLoadWithSprite(MARK, removeOrphanPontoon, 0)
    ApocalipseBR_TrueSwimmingSpriteHookReady = true
end)
