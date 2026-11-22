# ApocalipseBR LoadGridSquare Optimizations

Build 42 compatibility mods for Project Zomboid dedicated servers. The project started with a single LiuDing Tiles fix after ApocalipseBR telemetry showed a **2.56-second server tick**, with **2.03 seconds** spent integrating map cells. Several mods had registered per-square Lua callbacks, so ordinary streaming repeatedly crossed from Java into Kahlua even for squares that contained no object the fix cared about. [Baseline snapshot](.docs/reports/2026-11-22-dedicated-server-square-load.md)

The bundle keeps the original Workshop mods as dependencies. Each companion has its own mod ID and replaces the targeted Lua files at their original paths. B42 loads the dependency first and runs only the companion's copy at each matching path. The original code in those files never runs, so its event handlers never register. The upstream mods still provide their other scripts and assets. [Implementation reference](.docs/features/map-load-compatibility-patches.md)

## Mods and changes

| Companion mod ID | Original mod | Overridden file and event change |
| --- | --- | --- |
| `ApocalipseBR_LiuDingTiles_fix` | [LiuDing Tiles](https://steamcommunity.com/sharedfiles/filedetails/?id=3736154771), `LiuDing_Tiles` | [`LiuDing3DItem.lua`](ApocalipseBR_LiuDingTiles_fix/common/media/lua/server/Items/LiuDing3DItem.lua). `OnInitGlobalModData` now registers `MapObjects.OnLoadWithSprite` for the sledgehammer marker. The item is placed at its final height before synchronization, removing the old per-item `OnTick` callback. |
| `ApocalipseBR_TrueSwimming_fix` | [True Swimming by Harkwood](https://steamcommunity.com/sharedfiles/filedetails/?id=3802372726), `TrueSwimming` | Generates `TrueSwimmingShared.lua` from Workshop source using the [orphan-pontoon patch](patches/true-swimming/orphan-pontoon.after.lua). `OnLoadedTileDefinitions` registers `MapObjects.OnLoadWithSprite` for orphaned pontoons. The separate shallow-water `LoadGridsquare` handler and pontoon cleanup on `OnSave` remain active. |
| `minidoracatbuilderfix` | [Build Anything by Minidoracat](https://steamcommunity.com/sharedfiles/filedetails/?id=3830045886), `MinidoracatBuilderFor42` | [`Place.lua`](minidoracatbuilderfix/42/media/lua/shared/MinidoracatBuilder/Place.lua). `LoadChunk` queues migration work for a bounded `OnTick` worker. A versioned save index skips known empty chunks and limits other cache hits to candidate squares. Right-click **Reset Builder Migration Cache** in single-player or as a multiplayer admin. Based on upstream `42.22.2-1.1.1` and requires game Build `42.22.2` or later. |
| `apocalipsebr_basementdig_fix` | [Basement Building](https://steamcommunity.com/sharedfiles/filedetails/?id=3806513504), `aparosa_BasementDig` | Overrides `aparosa_BD_Ladder.lua`, `aparosa_BD_Mirror.lua`, and `aparosa_BD_Build.lua`. Sprite-filtered ladder discovery and the existing `LoadChunk` callback replace two `LoadGridsquare` subscriptions. Based on upstream `1.6.13` and requires game Build `42.20.0` or later. |

### Why this matters on a multiplayer server

The server runs `LoadGridsquare` synchronously during chunk integration. As multiple players move into new areas, the number of loaded squares can grow quickly, and every subscribed handler adds work to that same server tick. `MapObjects.OnLoadWithSprite` still checks objects in Java, but it enters Lua only for an exact sprite match. LiuDing looks up furniture height only on a marker square, and True Swimming's orphan cleanup runs only for a pontoon candidate.

Builder migrations depend on saved object state and multiple object types. They use one `LoadChunk` callback per loaded chunk and move the remaining Lua work into a resumable queue. Scanning and repairs share a **2 ms target** checked between steps, with up to **256 scan steps** and **eight queued repair jobs** per tick. A native operation can exceed the target, and repairs can lag behind chunk loading under sustained load. [Event and implementation details](.docs/features/map-load-compatibility-patches.md)

The snapshot is the baseline. A comparable dedicated-server capture is still needed to quantify the impact of the combined bundle. [Baseline and measurement limits](.docs/reports/2026-11-22-dedicated-server-square-load.md)

## Requirements and installation

Install Project Zomboid Build 42 and the original Workshop item for each companion you plan to enable. The full bundle targets Build `42.22.2` or later. For individual companions, LiuDing Tiles follows the original mod's Build 42 requirements, True Swimming lists `42.20+`, and Basement Building requires `42.20.0` or later. Install any dependencies declared by the originals. [Original mods and IDs](#mods-and-changes)

1. Subscribe to this bundle and the originals you use.
2. Enable each original alongside its companion. On a dedicated server, add the Workshop item IDs to `WorkshopItems` and the corresponding mod IDs to `Mods`. The companion dependency puts the original first.
3. Keep the enabled mod set consistent between the server and connecting clients, especially for shared Lua patches.

## Patch architecture

True Swimming's companion stores the original callback and its replacement as small Lua snippets. The build downloads the public Workshop item, resolves the Lua file for the target game build, then replaces exactly one matching callback. It preserves the upstream source outside that callback, including True Swimming 1.11's dock fix. The build runs the orphan-pontoon and dock regression tests on the generated Lua and uses PZ Studio to package those same bytes at `42/media/lua/shared/TrueSwimmingShared.lua`. A changed or missing callback, duplicate match, or failed test stops the build before it replaces the previous package. [True Swimming patch](patches/true-swimming/) · [Test and build design](.docs/features/patch-tests.md)

LiuDing Tiles, MinidoracatBuilder, and Basement Building ship checked-in Lua replacements. The Workshop check compares their upstream targets with reviewed hashes. A mismatch prompts a source review before updating the baseline. [Upstream compatibility notes](.docs/issues/upstream-override-compatibility.md)

## Build and regenerate

Use Node.js with npm and Python 3.12. Run the following from the repository root. On Windows, the build can install its own SteamCMD on the first run.

```powershell
npm ci --ignore-scripts
py -3 -m pip install -r tests/requirements.txt
npm run build
```

The command downloads True Swimming anonymously, regenerates the override, runs its tests, and packages all four companions in the configured PZ Studio output directory. The default is `%USERPROFILE%/Zomboid/Workshop` on Windows. If the existing package has a published item ID in `workshop.txt`, a rebuild keeps it unless `project.json` supplies a different ID. Use `--output <directory>` for a separate destination, `--check-upstream` to check all four items before packaging, or `--workshop-root <path>` to build from an existing Workshop cache. [Build and test options](.docs/features/patch-tests.md)

Run the build again after an upstream update. GitHub Actions also checks the latest Workshop downloads daily and on demand, and attaches a tested package on success. Use that package for a staging server or a Workshop upload. [Workshop workflow](.github/workflows/workshop-compatibility.yml)

## For upstream mod authors

- **True Swimming.** In the shared Lua file, replace the anonymous orphan-pontoon `Events.LoadGridsquare.Add(...)` callback with the linked snippet. It registers the `TrueSwimming_ponton` sprite from `OnLoadedTileDefinitions`. Keep the existing sprite setup, the separate shallow-water callback, and the `OnSave` cleanup. Check chunk streaming and dock walking with True Water on a dedicated server and a connecting client. Once a release includes equivalent cleanup, users of that release can disable this companion. [Replacement snippet](patches/true-swimming/orphan-pontoon.after.lua) · [Regression scenarios](.docs/features/patch-tests.md)
- **LiuDing Tiles.** Use the registered marker sprite to trigger the conversion. Calculate the height on that square, remove the marker, and publish the item at its final position. [LiuDing converter](ApocalipseBR_LiuDingTiles_fix/common/media/lua/server/Items/LiuDing3DItem.lua)
- **MinidoracatBuilder and Basement Building.** Use `LoadChunk` for work that depends on several squares. Put deferred scanning and repairs behind a tick budget, and test old saves and dependencies that load with a neighboring chunk. Basement Building also uses a sprite callback for ladder discovery. [Implementation reference](.docs/features/map-load-compatibility-patches.md)

## Tests

Run the Lua regression suite locally with `python -B -m unittest discover -s tests -v` after installing `tests/requirements.txt`. GitHub Actions runs the suite on pushes and pull requests. A separate daily job downloads the latest Workshop items, tests and packages the generated True Swimming override, and checks the other overrides for upstream changes. [Local setup and test pattern](.docs/features/patch-tests.md)

The [documentation index](.docs/AGENTS.md) lists features, issues and reports. [AGENTS.md](AGENTS.md) describes the project structure and how to maintain it.
