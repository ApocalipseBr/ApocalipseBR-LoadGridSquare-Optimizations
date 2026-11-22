require "MinidoracatBuilder/Place"

Events.OnClientCommand.Add(function(module, command, player)
    if module == "MinidoracatBuilderFix" and command == "resetMigrationCache"
        and player and player:isAccessLevel("admin") then
        MinidoracatBuilder.Place.resetMigrationCache()
    end
end)
