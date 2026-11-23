# Map-load compatibility patches

Four independently enabled companions replace map-load handlers in the original mods. See the [baseline report](../reports/2026-11-22-dedicated-server-square-load.md) for the measured server spike and the [compatibility issue](../issues/upstream-override-compatibility.md) for upstream update checks.

## File overrides and event reference

The mod dependency in `42/mod.info` orders each original before its companion. B42 indexes files by mod-relative path and resolves them to the last loaded copy. The Lua loader deduplicates the list by path before executing that resolved file. In the inspected B42.22.2 game source, see `zombie/ZomboidFileSystem.java` (`loadMod`, `loadModAndRequired`) and `zombie/Lua/LuaManager.java` (`LoadDirBase`).

| Event or API | When it runs and how the patches use it |
| --- | --- |
| `Events.OnInitGlobalModData` | World initialization. LiuDing registers its sprite handler and Builder initializes its migration index on dedicated servers and in single-player. See `GlobalModData.init`. |
| `Events.OnLoadedTileDefinitions` | After tile definitions are loaded. True Swimming registers its shared pontoon cleanup here. See `IsoWorld.init`. |
| `MapObjects.OnLoadWithSprite(sprite, callback, priority)` | Java matches the sprite name in `MapObjects.loadGridSquare` and passes the matching `IsoObject` to Lua. The handler can get the square through `object:getSquare()`. This path runs during chunk integration for new and saved chunks. Higher priorities run first. Registering the same sprite and priority replaces the previous callback. |
| `Events.LoadGridsquare` | Receives a square during `IsoChunk.doLoadGridsquare`, after the map-object callbacks. The companions replace the original LiuDing converter, True Swimming orphan cleanup, Builder migration, BasementDig ladder migration and BasementDig record-mirror subscriptions. True Swimming still uses a separate square callback to classify and open shallow water. |
| `Events.LoadChunk` | Receives the chunk later in `IsoChunk.doLoadGridsquare`. Builder checks the migration index and queues a scan cursor when work remains. BasementDig uses its existing callback for marker maintenance, mirror discovery and chunk-dependent retries. |
| `Events.OnTick` | Builder processes pending scans and repairs on game ticks and unregisters its migration worker when all queues are empty. LiuDing finishes item placement without a tick callback. BasementDig defers ladder repair and record recovery to tick workers that detach when idle. |
| `Events.OnObjectAdded`, `Events.OnObjectAboutToBeRemoved` | Builder retains its original object handlers, invalidates affected cache entries and restarts the in-progress square's scan index if that square's object list changes. It tracks objects already visited during that square scan. |
| `Events.OnFillWorldObjectContextMenu`, `Events.OnClientCommand` | Builder exposes a cache-reset action in single-player and in the multiplayer admin context menu. The server checks admin access before accepting the reset command. |
| `Events.OnSave` | True Swimming retains its existing cleanup of active pontoon state before save. |

## LiuDing Tiles

- **Original** [LiuDing Tiles, Workshop 3736154771](https://steamcommunity.com/sharedfiles/filedetails/?id=3736154771), mod ID `LiuDing_Tiles`.
- **Override** [`media/lua/server/Items/LiuDing3DItem.lua`](../../ApocalipseBR_LiuDingTiles_fix/common/media/lua/server/Items/LiuDing3DItem.lua), distributed under `common/`.
- **Behavior** The upstream script scanned every loaded square, looked up surface properties and converted the one active marker, `LiuDing_Tiles_3DItem_0`, into a pickable `Base.Sledgehammer`. The companion registers that sprite at priority 5 and examines surfaces only on a matching square. It preserves random X/Y placement and supplies the surface height plus the original lift of `0.1` to `AddWorldInventoryItem`.
- **Synchronization and failure handling** The companion creates the item locally before trying to remove the marker. It sends the finished item only once the marker is gone. If removal leaves the marker in place, it removes the staged item. This also avoids the upstream per-item `OnTick` closure, whose attempted removal supplied a string where B42's `Event.Remove` expects the registered Lua function.

## True Swimming

- **Original** [True Swimming by Harkwood, Workshop 3802372726](https://steamcommunity.com/sharedfiles/filedetails/?id=3802372726), mod ID `TrueSwimming`. The build uses the public Workshop listing. The diagnostic used the local 1.9 copy under Workshop ID `3691681426`.
- **Override** The build generates `42/media/lua/shared/TrueSwimmingShared.lua` from the selected upstream file using the [orphan-pontoon patch](../../patches/true-swimming/orphan-pontoon.after.lua).
- **Behavior** Replaces the Lua object scan on every square with a handler at priority 0 for `TrueSwimming_ponton`. It still checks the object's name before removing it with `RemoveTileObject`. The shared override runs wherever the original swimming module loads, including multiplayer clients handling streamed chunks.
- **Shallow water** The separate `LoadGridsquare` handler remains because depth classification and water walkability depend on square properties and neighboring squares. Active pontoon save cleanup is preserved.

## MinidoracatBuilder

- **Original** [Build Anything by Minidoracat, Workshop 3830045886](https://steamcommunity.com/sharedfiles/filedetails/?id=3830045886), mod ID `MinidoracatBuilderFor42`, inspected release `42.22.2-1.3.0`.
- **Override** Generates `42/media/lua/shared/MinidoracatBuilder/Place.lua` from the [placement diff](../../patches/minidoracat-builder/Place.patch).
- **Dispatch and scan** The original ran `Place.migrate` on special objects during each `LoadGridsquare` callback. The companion queues a cursor for chunks that need work. The worker tracks the level, tile and object index so it can resume inside a dense square. It revalidates the square against the live cell, drops scans for unloaded chunks when detected, restarts a cursor when its chunk instance is loaded again, and caches static overlay and corner classifications.
- **Migration index** The server and single-player can skip previously verified empty chunks and revisit just the recorded candidate squares in other cached chunks. Multiplayer clients continue to use bounded discovery. See the [migration cache feature](minidoracatbuilder-migration-cache.md) for persistence, invalidation, manual reset and validation.
- **Repairs** The migration reapplies zombie protection, container capacity, object metadata, legacy corners, floor dismantle protections and client light-switch registration as it reaches each object. Legacy overlay relinks and floor refunds waiting for the original ledger have separate queues. The existing ledgers and saved object state determine eligibility. An overlay stays in place until the host, attachment and refund entry can be confirmed. An eligible floor keeps its old build materials until the refund ledger records them. Dismantling accounts for a pending refund transfer. Path and collision state are refreshed when the delayed changes require it. Marked objects and stair landings still enter the upstream missing-region-flag recheck on authoritative worlds, including when the chunk hits the migration cache.
- **Latency and limits** Up to 256 scan steps and eight queued repair jobs share a 2 ms time target per tick. The check comes between steps, so a native call may run longer. Changes can become visible after a delay. The cursor is runtime-only and the patch requires Build 42.22.2 or later.

## BasementDig

- **Original** [Basement Building, Workshop 3806513504](https://steamcommunity.com/sharedfiles/filedetails/?id=3806513504), mod ID `aparosa_BasementDig`, inspected release `1.6.13`. The companion requires the 8-by-8 chunk layout used from Build `42.20.0`.
- **Ladder** The generated [`aparosa_BD_Ladder.lua`](../../patches/basement-dig/aparosa_BD_Ladder.patch) originally looked for wooden ladder sprites on every loaded underground square. The replacement registers the four wooden ladder sprites at priority 17 in authoritative worlds. It collects underground coordinates during the object-load pass and revalidates them on later ticks. It checks up to eight candidates per tick, parks retries by missing neighbor chunk, and publishes once when the batch changed ladders. Native conversion keeps the rope/top evidence checks. Legacy repair keeps the basement, opening and exit checks. New placement, removal and multiplayer object replication still use the upstream paths.
- **Mirror** The generated [`aparosa_BD_Mirror.lua`](../../patches/basement-dig/aparosa_BD_Mirror.patch) originally collected persisted record copies from underground square mod data during `LoadGridsquare`. It now checks only the loaded chunk's negative levels and keeps the newest discovered version per basement. It recovers after startup room registration and processes later batches after 30 ticks. It retains copies for unloaded anchor chunks and rejects copies whose loaded anchor lacks a floor. Recovered versions stay eligible for supersession by a newer copy. Recovery can requeue loaded legacy ladders whose original check ran before the record was available.
- **Build** The generated [`aparosa_BD_Build.lua`](../../patches/basement-dig/aparosa_BD_Build.patch) already maintained level markers in an authoritative `LoadChunk` callback. It now calls Mirror and wakes Ladder retries for the loaded chunk through that same callback. Mirror adds underground square lookups, and sprite filtering replaces Lua object scans across unrelated squares. The original light restoration `LoadChunk` callback is still active.
- **Sync** The upstream `42/media/lua/shared/aparosa_BasementDig/aparosa_BD_Sync.lua` publishes authoritative records, calls Mirror when records change, and applies records to rooms on multiplayer clients. The companion uses the upstream file and protocol.

## Dedicated server startup checks

Each enabled companion has a separate server-side reporter on `Events.OnServerStarted`. It prints a line for each checked Lua file with the companion mod ID and `startup OK` or `startup ERROR`. The messages use normal Lua logging and appear with debug mode off.

| File | What must happen before it reports OK |
| --- | --- |
| `LiuDing3DItem.lua` | `OnInitGlobalModData` registers the sledgehammer sprite callback. |
| `TrueSwimmingShared.lua` | The generated replacement registers the orphan-pontoon sprite callback during `OnLoadedTileDefinitions`. |
| `Place.lua` | The Builder override registers its chunk migration callback. |
| `MigrationCache.lua` | The Builder migration index initializes from global mod data. |
| `aparosa_BD_Build.lua` | The Basement Building override registers its chunk callback. |
| `aparosa_BD_Ladder.lua` | The ladder override registers its four sprite names for load callbacks. |
| `aparosa_BD_Mirror.lua` | The server startup handler schedules record recovery. |

An `ERROR` means the companion's reporter ran and its expected step did not finish. Check the enabled mod IDs and earlier Lua errors if a line is missing. The checks confirm hook registration and initialization at startup. Actual chunk visits, repairs, and multiplayer replication are exercised separately.

## Verification

The initial LiuDing implementation passed a local PZ Studio build and a mocked Fengari check of sprite registration, client authority, item height, repeated conversion and removal failure. The generated True Swimming override passed mocked Lua checks against Workshop 1.11, including pontoon cleanup and the dock behavior. The local 1.9 input passed the orphan-pontoon checks. The Builder diff was rebased onto the installed 1.3.0 release. The generated Builder, BasementDig and True Swimming files compiled and passed mocked regression fixtures in the installed game's Kahlua runtime. Full-bundle gameplay, client synchronization and timing still need a representative dedicated-server run.

The Basement Building overrides passed mocked Kahlua checks and a staged PZ Studio build. The [Basement Building validation report](../reports/2026-11-22-basementdig-load-callbacks.md) lists the scenarios and remaining runtime checks.
