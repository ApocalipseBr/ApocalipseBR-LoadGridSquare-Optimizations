# Map-load compatibility patches

The three Lua overrides are implemented. The BasementDig package is a scaffold. See the [baseline report](../reports/2026-11-22-dedicated-server-square-load.md) for the measured server spike and the [compatibility issue](../issues/upstream-override-compatibility.md) for upstream update checks.

## File overrides and event reference

The mod dependency in `42/mod.info` orders each original before its companion. B42 indexes files by mod-relative path and resolves them to the last loaded copy. The Lua loader deduplicates the list by path before executing that resolved file. In the inspected B42.22.2 game source, see `zombie/ZomboidFileSystem.java` (`loadMod`, `loadModAndRequired`) and `zombie/Lua/LuaManager.java` (`LoadDirBase`).

| Event or API | When it runs and how the patches use it |
| --- | --- |
| `Events.OnInitGlobalModData` | World initialization. LiuDing registers its sprite handler and Builder initializes its migration index on dedicated servers and in single-player. See `GlobalModData.init`. |
| `Events.OnLoadedTileDefinitions` | After tile definitions are loaded. True Swimming registers its shared pontoon cleanup here. See `IsoWorld.init`. |
| `MapObjects.OnLoadWithSprite(sprite, callback, priority)` | Java matches the sprite name in `MapObjects.loadGridSquare` and passes the matching `IsoObject` to Lua. The handler can get the square through `object:getSquare()`. This path runs during chunk integration for new and saved chunks. Higher priorities run first. Registering the same sprite and priority replaces the previous callback. |
| `Events.LoadGridsquare` | Receives a square during `IsoChunk.doLoadGridsquare`, after the map-object callbacks. The companions replace the original LiuDing converter, True Swimming orphan cleanup and Builder migration subscriptions. True Swimming still uses a separate square callback to classify and open shallow water. |
| `Events.LoadChunk` | Receives the chunk later in `IsoChunk.doLoadGridsquare`. Builder checks the migration index and queues a scan cursor when work remains. |
| `Events.OnTick` | Builder processes pending scans and repairs on game ticks and unregisters its migration worker when all queues are empty. LiuDing no longer uses this event for item height. |
| `Events.OnObjectAdded`, `Events.OnObjectAboutToBeRemoved` | Builder retains its original object handlers, invalidates affected cache entries and restarts the in-progress square's scan index if that square's object list changes. It tracks objects already visited during that square scan. |
| `Events.OnFillWorldObjectContextMenu`, `Events.OnClientCommand` | Builder exposes a cache-reset action in single-player and in the multiplayer admin context menu. The server checks admin access before accepting the reset command. |
| `Events.OnSave` | True Swimming retains its existing cleanup of active pontoon state before save. |

## LiuDing Tiles

- **Original** [LiuDing Tiles, Workshop 3736154771](https://steamcommunity.com/sharedfiles/filedetails/?id=3736154771), mod ID `LiuDing_Tiles`.
- **Override** [`media/lua/server/Items/LiuDing3DItem.lua`](../../ApocalipseBR_LiuDingTiles_fix/common/media/lua/server/Items/LiuDing3DItem.lua), distributed under `common/`.
- **Behavior** The upstream script scanned every loaded square, looked up surface properties and converted the one active marker, `LiuDing_Tiles_3DItem_0`, into a pickable `Base.Sledgehammer`. The companion registers that sprite at priority 5 and examines surfaces only on a matching square. It preserves random X/Y placement and supplies the surface height plus the original lift of `0.1` to `AddWorldInventoryItem`.
- **Synchronization and failure handling** The companion creates the item locally before trying to remove the marker. It sends the finished item only once the marker is gone. If removal leaves the marker in place, it removes the staged item. This also avoids the upstream per-item `OnTick` closure, whose attempted removal supplied a string where B42's `Event.Remove` expects the registered Lua function.

## True Swimming

- **Original** [True Swimming by Harkwood, Workshop 3802372726](https://steamcommunity.com/sharedfiles/filedetails/?id=3802372726), mod ID `TrueSwimming`. The bundle description records version 1.9. The diagnostic and local comparison used a copy under Workshop ID `3691681426`.
- **Override** [`media/lua/shared/TrueSwimmingShared.lua`](../../ApocalipseBR_TrueSwimming_fix/42/media/lua/shared/TrueSwimmingShared.lua), distributed under `42/`.
- **Behavior** Replaces the Lua object scan on every square with a handler at priority 0 for `TrueSwimming_ponton`. It still checks the object's name before removing it with `RemoveTileObject`. The shared override runs wherever the original swimming module loads, including multiplayer clients handling streamed chunks.
- **Shallow water** The separate `LoadGridsquare` handler remains because depth classification and water walkability depend on square properties and neighboring squares. Active pontoon save cleanup is preserved.

## MinidoracatBuilder

- **Original** [Build Anything by Minidoracat, Workshop 3830045886](https://steamcommunity.com/sharedfiles/filedetails/?id=3830045886), mod ID `MinidoracatBuilderFor42`, inspected release `42.22.2-1.1.1`.
- **Override** [`media/lua/shared/MinidoracatBuilder/Place.lua`](../../minidoracatbuilderfix/42/media/lua/shared/MinidoracatBuilder/Place.lua), distributed under `42/`.
- **Dispatch and scan** The original ran `Place.migrate` on special objects during each `LoadGridsquare` callback. The companion queues a cursor for chunks that need work. The worker tracks the level, tile and object index so it can resume inside a dense square. It revalidates the square against the live cell, drops scans for unloaded chunks when detected, restarts a cursor when its chunk instance is loaded again, and caches static overlay and corner classifications.
- **Migration index** The server and single-player can skip previously verified empty chunks and revisit just the recorded candidate squares in other cached chunks. Multiplayer clients continue to use bounded discovery. See the [migration cache feature](minidoracatbuilder-migration-cache.md) for persistence, invalidation, manual reset and validation.
- **Repairs** The migration reapplies zombie protection, container capacity, object metadata, legacy corners, floor dismantle protections and client light-switch registration as it reaches each object. Legacy overlay relinks and floor refunds waiting for the original ledger have separate queues. The existing ledgers and saved object state determine eligibility. An overlay stays in place until the host, attachment and refund entry can be confirmed. An eligible floor keeps its old build materials until the refund ledger records them. Dismantling accounts for a pending refund transfer. Path and collision state are refreshed when the delayed changes require it.
- **Latency and limits** Up to 256 scan steps and eight queued repair jobs share a 2 ms time target per tick. The check comes between steps, so a native call may run longer. Changes can become visible after a delay. The cursor is runtime-only and the patch requires Build 42.22.2 or later.

## BasementDig

[Basement Building, Workshop 3806513504](https://steamcommunity.com/sharedfiles/filedetails/?id=3806513504) uses mod ID `aparosa_BasementDig`. The snapshot attributed costs to the ladder and persistence-mirror `LoadGridsquare` handlers and a light restoration `LoadChunk` handler. The [project entry](../../project.json) and scaffold exist, but no B42 metadata, Lua override or event change is implemented for this companion.

## Verification

The initial LiuDing implementation passed a local PZ Studio build and a mocked Fengari check of sprite registration, client authority, item height, repeated conversion and removal failure. This documentation also compares the current True Swimming and Builder overrides with locally installed upstream files. Full-bundle gameplay, client synchronization and timing still need a representative dedicated-server run.
