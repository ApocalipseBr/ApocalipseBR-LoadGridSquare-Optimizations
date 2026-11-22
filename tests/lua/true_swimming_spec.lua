local removeOrphan
MapObjects = { OnLoadWithSprite = function(sprite, callback, priority)
    assert(sprite == "TrueSwimming_ponton" and priority == 0)
    assert(not removeOrphan, "expected exactly one orphan callback")
    removeOrphan = callback
end }
IsoSpriteManager = {}
CharacterTrait, MoodleType = {}, {}

load_patch("ApocalipseBR_TrueSwimming_fix", "media/lua/shared/TrueSwimmingShared.lua")
assert(not ApocalipseBR_TrueSwimmingSpriteHookReady)
fire("OnLoadedTileDefinitions")
assert(ApocalipseBR_TrueSwimmingSpriteHookReady and removeOrphan)
assert(#Events.LoadGridsquare.callbacks == 1, "preserve the shallow-water callback")
assert(Events.OnSave.callbacks[1] == TrueSwimming.restoreAll)

local removed
local square = { RemoveTileObject = function(_, object) removed = object end }
local name = "wooden_dock"
local object = {
    getSquare = function() return square end,
    getName = function() return name end,
}
removeOrphan(object)
assert(removed == nil, "leave ordinary dock objects in place")
name = "TrueSwimming_ponton"
removeOrphan(object)
assert(removed == object, "remove orphaned swimming pontoon")
