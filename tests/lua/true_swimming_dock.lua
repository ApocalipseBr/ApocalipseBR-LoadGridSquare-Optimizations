IsoSpriteManager = {}
CharacterTrait, MoodleType = {}, {}
IsoFlagType = { water = "water", solidfloor = "solidfloor" }

load_patch("ApocalipseBR_TrueSwimming_fix", "media/lua/shared/TrueSwimmingShared.lua")

local function tile(name, flag)
    return {
        getName = function() return name end,
        getProperties = function()
            return { has = function(_, property) return property == flag end }
        end,
    }
end

local water = tile("river", IsoFlagType.water)
local dock = tile("wooden_dock", IsoFlagType.solidfloor)
local pontoon = tile("TrueSwimming_ponton", IsoFlagType.solidfloor)
local covered = { getObjects = function() return javaList({ water, dock }) end }
local swimming = { getObjects = function() return javaList({ water, pontoon }) end }
assert(TrueSwimming.eauCouverte(covered), "wooden docks count as covered water")
assert(not TrueSwimming.eauCouverte(swimming), "the invisible pontoon leaves the square swimmable")

getCell = function()
    return { getGridSquare = function(_, x, y, z)
        assert(x == 12 and y == 20 and z == 0, "covered water skips neighboring depth lookups")
        return covered
    end }
end
TrueSwimming.classeDe = function() error("covered water skips depth classification") end
assert(not TrueSwimming.berge(12, 20), "the dock is not a shallow bank")
assert(TrueSwimming.enfoncementContinu(12.2, 20.2) == 0, "walking on a dock stays dry")

-- Run the retained square-load and save hooks with a shallow square in the middle of a chunk.
local additions, removals = 0, 0
local chunk = {}
local shallow = {
    getX = function() return 4 end,
    getY = function() return 4 end,
    getZ = function() return 0 end,
    getChunk = function() return chunk end,
    getObjects = function() return javaList({ water }) end,
}
local function squareChanged(sq, object)
    assert(sq == shallow and object:getSquare() == shallow and object:getName() == TrueSwimming.MARK)
end
shallow.AddTileObject = function(sq, object)
    squareChanged(sq, object)
    additions = additions + 1
end
shallow.RemoveTileObject = function(sq, object)
    squareChanged(sq, object)
    removals = removals + 1
end
IsoObject = { new = function(sq, sprite, name)
    assert(sq == shallow and sprite == TrueSwimming.MARK and name == TrueSwimming.MARK)
    return { getSquare = function() return sq end, getName = function() return name end }
end }
IsoSpriteManager.instance = { getSprite = function(_, id)
    assert(id == TrueSwimming.MARK_ID)
    return pontoon
end }
getCell = function() return {} end
local depth = 3
TrueSwimming.classeReelle = function(x, y)
    assert(x == 4 and y == 4)
    return depth
end
fire("LoadGridsquare", shallow)
assert(additions == 0, "deep water must not get a shallow-water pontoon at square load")
depth = 1
fire("LoadGridsquare", shallow)
fire("LoadGridsquare", shallow)
assert(additions == 1, "shallow water must open once even when the square-load hook repeats")
fire("OnSave")
fire("OnSave")
assert(removals == 1, "saving removes the active pontoon once")
fire("LoadGridsquare", shallow)
assert(additions == 2, "the square can reopen after saving clears the active entry")
chunk = nil
fire("OnSave")
assert(removals == 1, "saving must not touch a pontoon on an unloaded chunk")
