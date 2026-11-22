# ApocalipseBR LoadGridSquare Optimizations

Build 42 compatibility mods for Project Zomboid dedicated servers. The project started with a single LiuDing Tiles fix after ApocalipseBR telemetry showed a **2.56-second server tick**, with **2.03 seconds** spent integrating map cells. Several mods had registered per-square Lua callbacks, so ordinary streaming repeatedly crossed from Java into Kahlua even for squares that contained no object the fix cared about. [Baseline snapshot](.docs/reports/2026-11-22-dedicated-server-square-load.md)

The bundle keeps the original Workshop mods as dependencies. Each companion has its own mod ID and overrides one Lua file at the same logical path. B42 loads the dependency first, resolves duplicate paths to the later mod, and executes the resolved file once. The upstream mods still provide their other scripts and assets. [Implementation reference](.docs/features/map-load-compatibility-patches.md)

## Mods and changes

| Companion mod ID | Original mod | Overridden file and event change |
| --- | --- | --- |
| `ApocalipseBR_LiuDingTiles_fix` | [LiuDing Tiles](https://steamcommunity.com/sharedfiles/filedetails/?id=3736154771), `LiuDing_Tiles` | [`LiuDing3DItem.lua`](ApocalipseBR_LiuDingTiles_fix/common/media/lua/server/Items/LiuDing3DItem.lua). `OnInitGlobalModData` now registers `MapObjects.OnLoadWithSprite` for the sledgehammer marker. The item is placed at its final height before synchronization, removing the old per-item `OnTick` callback. |
| `ApocalipseBR_TrueSwimming_fix` | [True Swimming by Harkwood](https://steamcommunity.com/sharedfiles/filedetails/?id=3802372726), `TrueSwimming` | [`TrueSwimmingShared.lua`](ApocalipseBR_TrueSwimming_fix/42/media/lua/shared/TrueSwimmingShared.lua). `OnLoadedTileDefinitions` registers `MapObjects.OnLoadWithSprite` for orphaned pontoons. The separate shallow-water `LoadGridsquare` handler and pontoon cleanup on `OnSave` remain active. |
| `minidoracatbuilderfix` | [Build Anything by Minidoracat](https://steamcommunity.com/sharedfiles/filedetails/?id=3830045886), `MinidoracatBuilderFor42` | [`Place.lua`](minidoracatbuilderfix/42/media/lua/shared/MinidoracatBuilder/Place.lua). `LoadChunk` queues migration work for a bounded `OnTick` worker. A versioned save index skips known empty chunks and limits other cache hits to candidate squares. Right-click **Reset Builder Migration Cache** in single-player or as a multiplayer admin. Based on upstream `42.22.2-1.1.1` and requires game Build `42.22.2` or later. |
| `apocalipsebr_basementdig_fix` | [Basement Building](https://steamcommunity.com/sharedfiles/filedetails/?id=3806513504), `aparosa_BasementDig` | Scaffold. There is no gameplay override or event change for this package yet. |

### Why this matters on a multiplayer server

The server runs `LoadGridsquare` synchronously during chunk integration. As multiple players move into new areas, the number of loaded squares can grow quickly, and every subscribed handler adds work to that same server tick. `MapObjects.OnLoadWithSprite` still checks objects in Java, but it enters Lua only for an exact sprite match. LiuDing looks up furniture height only on a marker square, and True Swimming's orphan cleanup runs only for a pontoon candidate.

Builder migrations depend on saved object state and multiple object types. They use one `LoadChunk` callback per loaded chunk and move the remaining Lua work into a resumable queue. Scanning and repairs share a **2 ms target** checked between steps, with up to **256 scan steps** and **eight queued repair jobs** per tick. A native operation can exceed the target, and repairs can lag behind chunk loading under sustained load. [Event and implementation details](.docs/features/map-load-compatibility-patches.md)

The snapshot is the baseline. A comparable dedicated-server capture is still needed to quantify the impact of the combined bundle. [Baseline and measurement limits](.docs/reports/2026-11-22-dedicated-server-square-load.md)

## Build and enable

Open the project root in the [PZ Studio VS Code plugin](https://github.com/escapepz/pzstudio), or run `pzstudio build` from that directory. The build assembles the Workshop package in the configured output directory. [Project configuration](project.json)

Enable each desired companion alongside its original mod. Keep the server and connecting clients on the same mod set, especially for the shared True Swimming and MinidoracatBuilder overrides. With LiuDing, use the original Workshop copy with the companion and remove the duplicate full fork from the active mod sources. After updating an upstream mod, compare its overridden file with the revision the companion was based on. [Upstream compatibility notes](.docs/issues/upstream-override-compatibility.md)

The [documentation index](.docs/AGENTS.md) lists features, issues and reports. [AGENTS.md](AGENTS.md) describes the project structure and how to maintain it.
