# MinidoracatBuilder migration cache

`minidoracatbuilderfix` requires `MinidoracatBuilderFor42` from [Workshop item 3830045886](https://steamcommunity.com/sharedfiles/filedetails/?id=3830045886). The build applies the local [placement diff](../../patches/minidoracat-builder/Place.patch) to upstream `Place.lua` and emits the override at `42/media/lua/shared/MinidoracatBuilder/Place.lua`. The diff was rebased onto `42.22.2-1.5.1`. It targets Project Zomboid Build `42.22.2` and later. The generated file retains upstream sliding-door handling and schedules the upstream missing-region-flag recheck for marked objects, including cached candidates and adjacent stair landings. It also retains the upstream basement light switch fixes and uses the cached Java method references in the deferred chunk worker. [Workshop compatibility notes](../issues/upstream-override-compatibility.md#builder-151-migration-context)

## Chunk loading and cache validity

The original `LoadGridsquare` handler crossed from Java into Lua for each nonempty square. `LoadChunk` now performs at most one anchor-square lookup for the cache and queues unfinished work. The `OnTick` worker uses a cursor that can resume within a square's object list. The worker shares limits of 256 scan steps and eight deferred repairs per tick across chunks, with a 2 ms target checked between steps. A single operation can exceed that target. The worker detaches when its queues drain.

The server and single-player save index completed scans by chunk X and Y in `GlobalModData`. Each record stores the chunk's Z range and candidate square offsets. A marker in the anchor square's saved mod data has to match the index. This lets the loader reject an index entry paired with a different chunk save. Verified chunks with no candidates skip discovery. Chunks with candidates revisit those squares for load-time behavior. Multiplayer clients use the full bounded cursor because they may later receive a changed chunk from the server.

Builder placement, object changes, and the native cross-boundary double-door movement path invalidate affected records. A scan with a failed or pending repair leaves its chunk eligible for a later scan. A change in either mod's reported version or the explicit migration revision replaces the index. The revision handles installs with missing mod version metadata.

Right-click the world and choose **Reset Builder Migration Cache** to clear the coordinate index. The server validates admin access for multiplayer. Loaded chunks observed by the cache are queued for a bounded rescan, and chunks elsewhere in the save are discovered as they next load. The reset affects cache records only. Use it after changing the save while the companion was disabled.

## Deferred gameplay state and refunds

Zombie protection, container capacity, corner and floor flags, and light-switch registration apply when the cursor reaches the object. The worker refreshes affected squares after changing pathing flags. Builder dismantling can resolve a legacy floor refund before the scan reaches it. Eligible floor materials stay on the original object until its ledger entry is confirmed. A legacy overlay stays in place until replacement attachment and its refund entry are confirmed. Unavailable ledgers, conflicts, and missing overlay hosts remain eligible for retry.

## Verification

The [2026-11-22 validation report](../reports/2026-11-22-minidoracatbuilder-migration-cache.md) records the Kahlua checks and staged package build. Live dedicated-server timing and collision behavior remain to be measured.
