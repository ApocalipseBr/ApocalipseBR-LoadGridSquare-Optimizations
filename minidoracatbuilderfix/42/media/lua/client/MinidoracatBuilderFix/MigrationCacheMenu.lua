require "MinidoracatBuilder/Place"

local function reset(player)
    if isClient() then
        sendClientCommand(player, "MinidoracatBuilderFix", "resetMigrationCache", {})
    else
        MinidoracatBuilder.Place.resetMigrationCache()
    end
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, _, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player or (isClient() and not player:isAccessLevel("admin")) then return end
    context:addOption(getText("ContextMenu_MinidoracatBuilderFix_ResetMigrationCache"), player, reset)
end)
