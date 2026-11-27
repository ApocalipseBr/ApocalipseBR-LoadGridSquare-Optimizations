# Patch tests and Workshop compatibility

Run these commands from the repository root with Python 3.12 and Node.js. On Windows, `py -3` can be used for the Python commands.

```powershell
npm ci --ignore-scripts
python -m pip install -r tests/requirements.txt
python -B -m unittest discover -s tests -v
npm run build
python -B tests/compatibility.py --steamcmd C:/tools/steamcmd/steamcmd.exe
```

Plain `npm run build` finds SteamCMD on PATH or uses the executable set by `STEAMCMD`. On Windows, when neither is configured, the build downloads Valve's SteamCMD into `%LOCALAPPDATA%/ApocalipseBR/LoadGridSquare/steamcmd` and reuses it on subsequent builds. Pass `--steamcmd <path>` to select a specific installation. The build downloads the three generated mods anonymously. Add `--check-upstream` to also download and check the LiuDing Tiles baseline. The standalone compatibility command checks all four and exits with code 2 for a download failure or code 1 for a compatibility failure. Both commands accept `--workshop-root <path>` to use an existing `steamapps/workshop/content/108600` cache. Add `--reviewed` with that option to select the recorded reviewed item IDs.

## Generated Lua overrides

Builder and BasementDig use unified diffs in [patches/](../../patches/). Each hunk requires unique matching context in the current upstream Lua. The line numbers in a diff can shift as the author edits other parts of the file. True Swimming uses [before and after snippets](../../patches/true-swimming/) for the orphan-pontoon hook. The build logs the effective Workshop mod version, the LF-normalized SHA-256 of each source file, and each fixture that passes. Source drift on a generated target is reported for review. Missing or ambiguous context, a syntax error in any override or a failing fixture stops promotion.

To refresh a unified diff, start with the new upstream file and edit a scratch copy with the intended local changes. Generate the replacement diff with:

```powershell
python -m scripts.lua_diff <upstream.lua> <edited.lua> <patches/mod/file.patch>
```

Run the build against the same Workshop revision. It checks Builder's deferred migration, refund transfer, cache hits and sliding-door frames, BasementDig's ladder hook, late-anchor record recovery and multiplayer floor adoption, and True Swimming's orphan cleanup, shallow water and dock behavior.

PZ Studio stages the output using the same build configuration as the other companions. The build verifies that the package contains the tested bytes and the expected dependency metadata before replacing the configured output. It preserves a published item ID from the previous `workshop.txt` when the project's Workshop configuration leaves the ID unset. Use `--output <directory>` for a separate build destination. `npm run watch` generates the package first and continues watching authored mod files. Rerun the build after editing a patch snippet or refreshing Workshop inputs.

## Adding a regression test

1. Add or extend a `tests/lua/*_spec.lua` file. Each spec runs in a fresh Lua 5.1 VM.
2. Define the game objects and upstream modules involved in the scenario, then load the real companion file with `load_patch(companionId, mediaRelativePath)`. Paths include the `media/lua` prefix. The harness records event callbacks and provides a zero-based list for mocks of Java collections.
3. Trigger the engine entry point that calls the Lua code, such as `fire("LoadChunk", chunk)` or the callback registered with `MapObjects.OnLoadWithSprite`. Assert the resulting state or calls, including cases where state should be preserved. Keep dependencies explicit so a newly required API fails until the test supplies it.
4. When adding a full-file override, add its exact path and reviewed upstream SHA-256 to `tests/workshop-baselines.json`. Hash the upstream file with CRLF normalized to LF. The Workshop check prints the observed digest on a mismatch. Review the upstream change and carry forward behavior the companion needs before updating the digest.

## What the fixtures assert

| Fixture | Assertions |
| --- | --- |
| `liuding_spec.lua` | Clients leave conversion to the server. A matching marker places the sledgehammer at the final height before transmission. Repeated callbacks publish one item. A failed marker removal rolls back the staged item. |
| `startup_logs_spec.lua` | Each startup reporter emits the expected status for ready and missing hooks. |
| `true_swimming_spec.lua` | One sprite handler removes an orphan pontoon and leaves other objects alone. The shallow-water and save hooks still register. |
| `true_swimming_dock.lua` | Wooden docks stay dry and the invisible pontoon leaves water swimmable. The real square-load callback opens shallow water once and skips deep water. The save hook removes active pontoons, leaves unloaded chunks alone and allows the square to reopen later. |
| `builder_spec.lua` | Chunk loads queue one worker, defer material transfer until the ledger is ready, and preserve region rechecks on cache hits. A refund lookup can transfer pending materials before the migration worker runs, with one ledger write across both paths. Stale ledger entries and vanilla floors return no refund. The last sliding-door frame stays in place. |
| `basement_spec.lua` | Ladder discovery is authoritative, duplicate stale candidates are discarded and recovery waits for a late anchor. A newer recovery copy supersedes an older record. Distance and owner limits prevent adoption from mutating or publishing records. A successful merge still publishes the full record set and mirrors only the surviving record. |

The offline Python tests also exercise exact patch matching, mixed line endings, preservation of unrelated source, dependency metadata and staged Workshop ID retention. A synthetic Workshop source verifies that generation rejects both changed patch context and syntax errors after a matching diff is applied.

## Before-and-after streaming benchmark

```powershell
npm run build -- --workshop-root <cache> --output <staging> --benchmark-output <results.json>
```

`--benchmark-output` runs compatibility checks for all four mods, including the LiuDing baseline. A loads the resolved files from Workshop and B loads the generated or checked-in Lua used as package input. Each sample starts in a fresh restricted Lua 5.1 VM. Both variants prime the same empty chunk before timing and alternate measurement order across seven samples. Each timed sample streams that chunk 128 times, issuing 64 square loads, one chunk load and one tick per iteration. The Builder sample therefore measures an established empty-chunk cache hit. The BasementDig sample uses an empty underground level after startup recovery. The True Swimming fixture also checks that both variants remove an orphan pontoon and keep a dock tile before timing.

| Companion | A callbacks per chunk (square / chunk / tick) | B callbacks per chunk (square / chunk / tick) | Net callbacks avoided per chunk |
| --- | ---: | ---: | ---: |
| LiuDing Tiles | 64 / 0 / 0 | 0 / 0 / 0 | 64 |
| True Swimming | 128 / 0 / 0 | 64 / 0 / 0 | 64 |
| Build Anything | 64 / 0 / 0 | 0 / 1 / 0 | 63 |
| Basement Building | 128 / 1 / 2 | 0 / 1 / 1 | 129 |

The fixture asserts each event count before package promotion. It counts only the callbacks registered by the Lua files under test. A mismatch on either side fails the build and calls for reviewing the changed hook or test expectation. The workflow writes the Markdown comparison to the Actions job summary and uploads `mocked-lua-benchmark.json` with the upstream version labels, callback counts, raw timing samples in nanoseconds and derived medians.

Milliseconds per chunk is the median batch wall time divided by 128. Amortized milliseconds per callback divides the same batch time by its callback count, so it includes harness overhead and changes when the mix of callbacks changes. A zero-callback side reports `n/a`. Compare milliseconds per chunk for the same workload. Timings are informational to accommodate runner variance. This phase covers warmed empty-chunk streaming. Cold-cache Builder scans, floor adoption, native engine calls, network replication and dedicated-server tick latency need separate workloads in later phases.

## GitHub Actions

[Patch tests](../../.github/workflows/patch-tests.yml) run on pushes and pull requests without Steam. [Workshop compatibility](../../.github/workflows/workshop-compatibility.yml) runs daily at 06:23 Fortaleza time and can be triggered manually. It runs the offline suite before downloading Workshop files with SteamCMD and resolving their layers for game Build `42.22.2`. It generates and tests Builder, BasementDig and True Swimming from the public items and checks LiuDing Tiles for missing paths, unexpected Lua collisions and hash changes. A successful run attaches the tested Workshop package. Steam downloads stay in the runner's temporary directory.

The [November 26 run](https://github.com/ApocalipseBr/ApocalipseBR-LoadGridSquare-Optimizations/actions/runs/45881594964) downloaded Builder `42.22.2-1.4.0`. Its `Place.lua` matched the reviewed hash at that commit and passed the Builder fixture. The local `1.5.0` download changed the refund section and the previous patch stopped on its first missing hunk, before fixture execution. These are two different upstream inputs. The build now records hashes for both matching and changed sources so future runs can be compared directly.

The Workshop check reads the overridden files and mod metadata. An untouched upstream file can still introduce an integration failure. The Lua specs exercise the companion code with mocked game APIs. A dedicated-server smoke test would cover actual Java/Kahlua loading, tile streaming, persistence, and network sync.

For that smoke test, stage the complete downloaded mods and their Workshop dependencies alongside the PZ Studio build on a dedicated server at the target Build 42 version. Capture the game log and check that the engine resolves each replacement from the companion. Use a disposable save and a connecting client to exercise these scenarios.

| Fixture | In-game assertion |
| --- | --- |
| LiuDing marker on a table | Streaming the square leaves one pickable sledgehammer at the expected height on both server and client. |
| True Swimming chunk with a stale pontoon and a wooden dock | The stale swimming pontoon disappears, and the player stays dry when crossing the dock. |
| Builder chunk with a legacy object | Deferred migration restores the object's expected properties, including after a save and reload. |
| Basement record with its exit in a neighboring chunk | Streaming the chunks recovers the room record and leaves a usable ladder after reconnecting. |

## Validation

The resumable adoption fixture forces checkpoints after the structural edit and between individual square refreshes. It checks that a reloaded square is resolved again, that the coordinate cursor advances without duplicate work, and that recovery and notification wait for the refresh to complete. The test also checks that a removed record is skipped on publication and that a completed job requests a 500 ms coalescing window. A staging smoke test with the actual BPLib modules checks lane order and the broadcast deadline against a simulated clock. Multiplayer latency still needs a live capture.

The November 27 refresh passed eight offline tests, the four-mod compatibility check and the staging build against the installed Workshop cache. The old Builder patch reproduced the missing-hunk failure on `1.5.0`. The installed game's Kahlua compiled all 15 staged Lua files and ran all six fixtures, including the expanded refund, water and adoption tests. Live dedicated-server gameplay remains to be verified.

The local Workshop cache and a fresh anonymous SteamCMD download produced byte-identical packages for Builder `42.22.2-1.3.0`, BasementDig `1.6.13` and True Swimming `1.11`. PZ Studio packaged five generated Lua files whose bytes matched the tested output. The BasementDig files match the prior overrides after normalizing line endings. All 13 packaged Lua files compiled in the installed game's Kahlua runtime, and all six mocked gameplay and startup fixtures passed against the packaged files. Synthetic upstream additions survived in all five overrides. A conflicting Builder edit stopped promotion and left the previous package byte-for-byte intact. A live multiplayer smoke test is still pending.
