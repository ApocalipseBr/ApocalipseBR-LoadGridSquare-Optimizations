# ApocalipseBR LoadGridSquare Optimizations

Build 42 compatibility mods for Project Zomboid dedicated servers. The project started with a single LiuDing Tiles fix after ApocalipseBR telemetry showed a **2.56-second server tick**, with **2.03 seconds** spent integrating map cells. Several mods had registered per-square Lua callbacks, so ordinary streaming repeatedly crossed from Java into Kahlua even for squares that contained no object the fix cared about. [Baseline snapshot](.docs/reports/2026-11-22-dedicated-server-square-load.md)

The bundle keeps the original Workshop mods as dependencies. Each companion has its own mod ID and replaces the targeted Lua files at their original paths. B42 loads the dependency first and runs only the companion's copy at each matching path. The original code in those files never runs, so its event handlers never register. The upstream mods still provide their other scripts and assets. [Implementation reference](.docs/features/map-load-compatibility-patches.md)

## Mods and changes

| Companion mod ID | Original mod | Upstream patch baseline | Overridden file and event change |
| --- | --- | --- | --- |
| `ApocalipseBR_LiuDingTiles_fix` | [LiuDing Tiles](https://steamcommunity.com/sharedfiles/filedetails/?id=3736154771), `LiuDing_Tiles` | Unversioned Workshop item `3736154771`. The reviewed file is identified by its [SHA-256](tests/workshop-baselines.json). | [`LiuDing3DItem.lua`](ApocalipseBR_LiuDingTiles_fix/common/media/lua/server/Items/LiuDing3DItem.lua). `OnInitGlobalModData` now registers `MapObjects.OnLoadWithSprite` for the sledgehammer marker. The item is placed at its final height before synchronization, removing the old per-item `OnTick` callback. |
| `ApocalipseBR_TrueSwimming_fix` | [True Swimming by Harkwood](https://steamcommunity.com/sharedfiles/filedetails/?id=3802372726), `TrueSwimming` | `1.11` | Generates `TrueSwimmingShared.lua` from Workshop source using the [orphan-pontoon patch](patches/true-swimming/orphan-pontoon.after.lua). `OnLoadedTileDefinitions` registers `MapObjects.OnLoadWithSprite` for orphaned pontoons. The separate shallow-water `LoadGridsquare` handler and pontoon cleanup on `OnSave` remain active. |
| `minidoracatbuilderfix` | [Build Anything by Minidoracat](https://steamcommunity.com/sharedfiles/filedetails/?id=3830045886), `MinidoracatBuilderFor42` | `42.22.2-1.5.1` | [`Place.lua` patch](patches/minidoracat-builder/Place.patch). `LoadChunk` queues migration work for a bounded `OnTick` worker. A versioned save index skips known empty chunks and limits other cache hits to candidate squares. Right-click **Reset Builder Migration Cache** in single-player or as a multiplayer admin. Preserves upstream sliding-door support and region repairs. Requires game Build `42.22.2` or later. |
| `apocalipsebr_basementdig_fix` | [Basement Building](https://steamcommunity.com/sharedfiles/filedetails/?id=3806513504), `aparosa_BasementDig` | `1.6.13` | Generates [seven Lua overrides](patches/basement-dig/) for Ladder, Mirror, Build, Adopt, Sync, Expand and Entity. Sprite and chunk callbacks replace two square-load subscriptions. Multiplayer floor adoption limits mirror work to the affected basement. Requires game Build `42.20.0` or later. |

### Why this matters on a multiplayer server

The server runs `LoadGridsquare` synchronously during chunk integration. As multiple players move into new areas, the number of loaded squares can grow quickly, and every subscribed handler adds work to that same server tick. `MapObjects.OnLoadWithSprite` still checks objects in Java, but it enters Lua only for an exact sprite match. LiuDing looks up furniture height only on a marker square, and True Swimming's orphan cleanup runs only for a pontoon candidate.

Builder migrations depend on saved object state and multiple object types. They use one `LoadChunk` callback per loaded chunk and move the remaining Lua work into a resumable queue. Scanning and repairs share a **2 ms target** checked between steps, with up to **256 scan steps** and **eight queued repair jobs** per tick. A native operation can exceed the target, and repairs can lag behind chunk loading under sustained load. [Event and implementation details](.docs/features/map-load-compatibility-patches.md)

The snapshot is the baseline. A comparable dedicated-server capture is still needed to quantify the impact of the combined bundle. [Baseline and measurement limits](.docs/reports/2026-11-22-dedicated-server-square-load.md)

## Requirements and installation

Install Project Zomboid Build 42 and the original Workshop item for each companion you plan to enable. The full bundle targets Build `42.22.2` or later. For individual companions, LiuDing Tiles follows the original mod's Build 42 requirements, True Swimming lists `42.20+`, and Basement Building requires `42.20.0` or later. Install any dependencies declared by the originals. [Original mods and IDs](#mods-and-changes)

1. Subscribe to this bundle and the originals you use.
2. Enable each original alongside its companion. On a dedicated server, add the Workshop item IDs to `WorkshopItems` and the corresponding mod IDs to `Mods`. The companion dependency puts the original first.
3. Keep the enabled mod set consistent between the server and connecting clients, especially for shared Lua patches.
4. After a dedicated server starts, look for `startup OK` lines from each enabled companion. These checks run with debug mode off. [Startup messages and what they verify](.docs/features/map-load-compatibility-patches.md#dedicated-server-startup-checks)

## Patch architecture

The Workshop download contains full replacement Lua files built ahead of time. At build time, SteamCMD downloads the original Workshop mods and the build resolves their Lua files for the target game version. It programmatically applies the repository’s `.patch` files for MinidoracatBuilder and Basement Building and the before-and-after Lua snippets for True Swimming. Each edit must match exactly once. The build preserves upstream code outside the edits, runs regression tests on the generated Lua, and verifies that the PZ Studio package contains the tested files. A missing or ambiguous match or a failed test stops the build before replacing the previous package. [Patch and build design](.docs/features/patch-tests.md)

LiuDing Tiles ships a checked-in converter. The optional Workshop check compares its upstream target with the reviewed hash. [Upstream compatibility notes](.docs/issues/upstream-override-compatibility.md)

## Build and regenerate

Use Node.js with npm and Python 3.12. Run the following from the repository root. On Windows, the build can install its own SteamCMD on the first run.

```powershell
npm ci --ignore-scripts
py -3 -m pip install -r tests/requirements.txt
npm run build
```

The command downloads the three generated mods' sources anonymously, generates and tests their overrides, and packages all four companions in the configured PZ Studio output directory. The default is `%USERPROFILE%/Zomboid/Workshop` on Windows. If the existing package has a published item ID in `workshop.txt`, a rebuild keeps it unless `project.json` supplies a different ID. Use `--output <directory>` for a separate destination, `--check-upstream` to check all four items before packaging, or `--workshop-root <path>` to build from an existing Workshop cache. [Build and test options](.docs/features/patch-tests.md)

Run the build again after an upstream update. GitHub Actions also checks the latest Workshop downloads daily and on demand, and attaches a tested package on success. Use that package for a staging server or a Workshop upload. [Workshop workflow](.github/workflows/workshop-compatibility.yml)

## For upstream mod authors

Review the `.patch` files for the local additions and removals with their surrounding context. For True Swimming, compare the before and after snippets. To inspect the complete files as shipped, subscribe to this bundle and open the companion’s `42/media/lua` directory in the Workshop download. The LiuDing converter is under `common/media/lua`. [Builder diff](patches/minidoracat-builder/Place.patch) · [Basement Building diffs](patches/basement-dig/) · [True Swimming snippets](patches/true-swimming/)

- **True Swimming.** In the shared Lua file, replace the anonymous orphan-pontoon `Events.LoadGridsquare.Add(...)` callback with the linked snippet. It registers the `TrueSwimming_ponton` sprite from `OnLoadedTileDefinitions`. Keep the existing sprite setup, the separate shallow-water callback, and the `OnSave` cleanup. Check chunk streaming and dock walking with True Water on a dedicated server and a connecting client. Once a release includes equivalent cleanup, users of that release can disable this companion. [Replacement snippet](patches/true-swimming/orphan-pontoon.after.lua) · [Regression scenarios](.docs/features/patch-tests.md)
- **LiuDing Tiles.** Use the registered marker sprite to trigger the conversion. Calculate the height on that square, remove the marker, and publish the item at its final position. [LiuDing converter](ApocalipseBR_LiuDingTiles_fix/common/media/lua/server/Items/LiuDing3DItem.lua)
- **MinidoracatBuilder and Basement Building.** Use `LoadChunk` for work that depends on several squares. Put deferred scanning and repairs behind a tick budget, and test old saves and dependencies that load with a neighboring chunk. Basement Building also uses a sprite callback for ladder discovery. [Implementation reference](.docs/features/map-load-compatibility-patches.md)
- **Basement Building floor adoption.** Three adoption callbacks took 2,806.520 ms over 219 simulation ticks in 30.027 seconds. One adoption took 909.644 ms in the slowest tick of that window. The companion reduces repeated spatial-index checks and limits recovery-copy updates to the affected basement. The report includes the callback and JVM data for the maintainer. [Basement Building performance report](.docs/reports/2026-11-27-basementdig-telemetry-for-author.md)

Enable `apocalipsebr_bplib` alongside the Basement Building companion to queue multiplayer floor adoption and expansion entities in the same mod lane. Expansion can pause during read-only preparation and revalidates the site before writing. After the structural edit, the additional neighborhood refresh can resume between squares on later ticks. Completed adoptions coalesce their full snapshots over a 500 ms window. [Adoption and publication details](.docs/features/map-load-compatibility-patches.md#basementdig)

## Tests

Run `python -B -m unittest discover -s tests -v` after installing `tests/requirements.txt`. The offline suite checks patch matching, dependency metadata, syntax, startup hooks and rollback. The scheduled Workshop job also downloads the upstream files, applies the patches, compiles every generated override and runs gameplay fixtures against the resulting Lua with mocked game APIs. Before promotion, the build checks that the package contains the tested bytes and expected dependencies. [Test commands and coverage](.docs/features/patch-tests.md)

| Companion | Behavior checked |
| --- | --- |
| LiuDing Tiles | Server-only marker conversion, correct item height, one synchronized sledgehammer and rollback if the marker remains. |
| True Swimming | Orphan pontoon removal, dry dock walking, shallow-water opening without duplicates and safe cleanup on save. |
| Build Anything | Deferred chunk migration, cache hits and region rechecks, refunds before the worker runs, stale-ledger rejection and sliding-door frame protection. |
| Basement Building | Deferred ladder discovery, recovery when an anchor chunk arrives late, adoption permission checks and publication after a merge with recovery writes limited to the surviving record. |

The November 26 Workshop run passed its Builder fixture against `42.22.2-1.4.0`. The local `1.5.0` source changed the refund context and required a rebase. CI now logs each upstream source hash and each fixture result to make this comparison easier. [Workflow run](https://github.com/ApocalipseBr/ApocalipseBR-LoadGridSquare-Optimizations/actions/runs/45881594964)

### Before-and-after streaming benchmark

The Workshop workflow also runs the original and patched Lua through identical empty-chunk loads. It asserts the callback counts and publishes the calls avoided, median milliseconds per chunk and amortized milliseconds per callback in the Actions summary. The JSON artifact includes every timing sample. These measurements use mocked game APIs. [Run locally and interpret the results](.docs/features/patch-tests.md#before-and-after-streaming-benchmark)

## Reports

- [Dedicated-server square-load baseline](.docs/reports/2026-11-22-dedicated-server-square-load.md)
- [Workshop refresh and Basement Building adoption](.docs/reports/2026-11-27-workshop-refresh-and-basement-adoption.md)
- [Basement Building performance report for the maintainer](.docs/reports/2026-11-27-basementdig-telemetry-for-author.md)

The [documentation index](.docs/AGENTS.md) lists features, issues and reports. [AGENTS.md](AGENTS.md) describes the project structure and how to maintain it.
