Events.LoadGridsquare.Add(function(sq)
    local objs = sq and sq:getObjects()
    if not objs then return end
    for i = objs:size() - 1, 0, -1 do
        local obj = objs:get(i)
        if obj and obj:getName() == MARK then sq:RemoveTileObject(obj) end
    end
end)
