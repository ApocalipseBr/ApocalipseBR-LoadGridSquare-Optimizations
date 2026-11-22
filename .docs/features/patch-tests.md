# Patch tests and Workshop compatibility

Run these commands from the repository root with Python 3.12 and Node.js. On Windows, `py -3` can be used for the Python commands.

```powershell
npm ci --ignore-scripts
python -m pip install -r tests/requirements.txt
python -B -m unittest discover -s tests -v
npm run build
python -B tests/compatibility.py --steamcmd C:/tools/steamcmd/steamcmd.exe
```

Plain `npm run build` finds SteamCMD on PATH or uses the executable set by `STEAMCMD`. On Windows, when neither is configured, the build downloads Valve's SteamCMD into `%LOCALAPPDATA%/ApocalipseBR/LoadGridSquare/steamcmd` and reuses it on subsequent builds. Pass `--steamcmd <path>` to select a specific installation. The build downloads True Swimming anonymously. Add `--check-upstream` to download and check all four Workshop items before packaging. The standalone compatibility command checks all four and exits with code 2 for a download failure or code 1 for a compatibility failure. Both commands accept `--workshop-root <path>` to use an existing `steamapps/workshop/content/108600` cache. Add `--reviewed` with that option to use the recorded reviewed IDs, including the local True Swimming 1.9 copy.

## Generated True Swimming override

Edit [the before and after snippets](../../patches/true-swimming/) when the callback changes. The generator requires exactly one matching registration and preserves every byte outside that block. Whole-file hash changes are logged. The build checks the generated Lua for the sprite registration, orphan cleanup, retained shallow-water and save hooks, and the upstream dock fix. Reviewed 1.9 runs the orphan checks because the dock behavior was added in 1.11.

PZ Studio stages the output using the same build configuration as the other companions. The build verifies that the package contains the tested bytes and the expected dependency metadata before replacing the configured output. It preserves a published item ID from the previous `workshop.txt` when the project's Workshop configuration leaves the ID unset. Use `--output <directory>` for a separate build destination. `npm run watch` generates the package first and continues watching authored mod files. Rerun the build after editing a patch snippet or refreshing Workshop inputs.

## Adding a regression test

1. Add or extend a `tests/lua/*_spec.lua` file. Each spec runs in a fresh Lua 5.1 VM.
2. Define the game objects and upstream modules involved in the scenario, then load the real companion file with `load_patch(companionId, mediaRelativePath)`. Paths include the `media/lua` prefix. The harness records event callbacks and provides a zero-based list for mocks of Java collections.
3. Trigger the engine entry point that calls the Lua code, such as `fire("LoadChunk", chunk)` or the callback registered with `MapObjects.OnLoadWithSprite`. Assert the resulting state or calls, including cases where state should be preserved. Keep dependencies explicit so a newly required API fails until the test supplies it.
4. When adding a full-file override, add its exact path and reviewed upstream SHA-256 to `tests/workshop-baselines.json`. Hash the upstream file with CRLF normalized to LF. The Workshop check prints the observed digest on a mismatch. Review the upstream change and carry forward behavior the companion needs before updating the digest.

The offline suite covers LiuDing item placement and rollback, Builder's deferred chunk worker, and BasementDig's deduplicated ladder jobs. It checks dependency metadata, compiles checked-in companion Lua, and verifies that the generator preserves unrelated bytes and rejects missing or duplicate hooks. The True Swimming behavior fixtures run on the generated Lua during the live build.

## GitHub Actions

[Patch tests](../../.github/workflows/patch-tests.yml) run on pushes and pull requests without Steam. [Workshop compatibility](../../.github/workflows/workshop-compatibility.yml) runs daily at 06:23 Fortaleza time and can be triggered manually. It uses a fresh SteamCMD installation and checks files resolved for game Build `42.22.2`. It generates and tests True Swimming from the public item, then checks the three checked-in companions for missing paths, unexpected Lua collisions, and hash changes. A successful run attaches the tested Workshop package. Steam downloads stay in the runner's temporary directory.

The Workshop check reads the overridden files and mod metadata. An untouched upstream file can still introduce an integration failure. The Lua specs exercise the companion code with mocked game APIs. A dedicated-server smoke test would cover actual Java/Kahlua loading, tile streaming, persistence, and network sync.

For that smoke test, stage the complete downloaded mods and their Workshop dependencies alongside the PZ Studio build on a dedicated server at the target Build 42 version. Capture the game log and check that the engine resolves each replacement from the companion. Use a disposable save and a connecting client to exercise these scenarios.

| Fixture | In-game assertion |
| --- | --- |
| LiuDing marker on a table | Streaming the square leaves one pickable sledgehammer at the expected height on both server and client. |
| True Swimming chunk with a stale pontoon and a wooden dock | The stale swimming pontoon disappears, and the player stays dry when crossing the dock. |
| Builder chunk with a legacy object | Deferred migration restores the object's expected properties, including after a save and reload. |
| Basement record with its exit in a neighboring chunk | Streaming the chunks recovers the room record and leaves a usable ladder after reconnecting. |

## Validation

The live `npm run build -- --steamcmd <path> --check-upstream --output <scratch>` downloaded all four public Workshop items and produced a staged package. The generated True Swimming 1.11 Lua passed the orphan and dock fixtures, and the five checked-in override targets matched their reviewed digests. The local 1.9 source passed its orphan fixture. A simulated upstream change to the targeted callback failed the build and left the previous package byte-for-byte intact. [True Swimming compatibility issue](../issues/upstream-override-compatibility.md)
