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
