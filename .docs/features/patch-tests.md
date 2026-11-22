# Patch tests and Workshop compatibility

Run these commands from the repository root with Python 3.12.

```powershell
python -m pip install -r tests/requirements.txt
python -B -m unittest discover -s tests -v
python -B tests/compatibility.py --steamcmd C:/tools/steamcmd/steamcmd.exe
```

Use a standalone SteamCMD installation for the last command. It logs in anonymously, downloads the four complete Workshop items, and checks the files under its own `steamapps/workshop/content/108600`. It exits with code 2 when SteamCMD fails or a download cannot be confirmed, and code 1 for a compatibility failure. The checks can also read an existing Workshop installation with `--workshop-root <path>`. Add `--reviewed` to use the recorded baseline item IDs, including the older True Swimming copy, for a local reproduction.

## Adding a regression test

1. Add or extend a `tests/lua/*_spec.lua` file. Each spec runs in a fresh Lua 5.1 VM.
2. Define the game objects and upstream modules involved in the scenario, then load the real companion file with `load_patch(companionId, mediaRelativePath)`. Paths include the `media/lua` prefix. The harness records event callbacks and provides a zero-based list for mocks of Java collections.
3. Trigger the engine entry point that calls the Lua code, such as `fire("LoadChunk", chunk)` or the callback registered with `MapObjects.OnLoadWithSprite`. Assert the resulting state or calls, including cases where state should be preserved. Keep dependencies explicit so a newly required API fails until the test supplies it.
4. When adding a full-file override, add its exact path and reviewed upstream SHA-256 to `tests/workshop-baselines.json`. Hash the upstream file with CRLF normalized to LF. The Workshop check prints the observed digest on a mismatch. Review the upstream change and carry forward behavior the companion needs before updating the digest.

The first cases cover LiuDing item placement and rollback, True Swimming orphan cleanup, Builder's deferred chunk worker, and BasementDig's deduplicated ladder jobs. The offline suite also compiles the active companion Lua files and checks dependencies against `project.json` and `mod.info`.

## GitHub Actions

[Patch tests](../../.github/workflows/patch-tests.yml) run on pushes and pull requests without Steam. [Workshop compatibility](../../.github/workflows/workshop-compatibility.yml) runs daily at 06:23 Fortaleza time and can be triggered manually. It uses a fresh SteamCMD installation and checks the files resolved for game Build `42.22.2`. It finds upstream mods by their internal IDs, layers `common` and the selected version directory, and flags missing paths, unexpected Lua collisions, and changed replacement targets. Workshop files stay in the runner's temporary directory.

The Workshop check reads the overridden files and mod metadata. An untouched upstream file can still introduce an integration failure. The Lua specs exercise the companion code with mocked game APIs. A dedicated-server smoke test would cover actual Java/Kahlua loading, tile streaming, persistence, and network sync.

For that smoke test, stage the complete downloaded mods and their Workshop dependencies alongside the PZ Studio build on a dedicated server at the target Build 42 version. Capture the game log and check that the engine resolves each replacement from the companion. Use a disposable save and a connecting client to exercise these scenarios.

| Fixture | In-game assertion |
| --- | --- |
| LiuDing marker on a table | Streaming the square leaves one pickable sledgehammer at the expected height on both server and client. |
| True Swimming chunk with a stale pontoon and a wooden dock | The stale swimming pontoon disappears, and the player stays dry when crossing the dock. |
| Builder chunk with a legacy object | Deferred migration restores the object's expected properties, including after a save and reload. |
| Basement record with its exit in a neighboring chunk | Streaming the chunks recovers the room record and leaves a usable ladder after reconnecting. |

## First validation

All four public Workshop items downloaded locally with anonymous SteamCMD. Five of the six replacement targets matched the reviewed digests. The public True Swimming release is 1.11, and its shared Lua file differs from the reviewed 1.9 copy. The drift check therefore fails for that target. The full offline suite and the six comparisons against the locally installed, reviewed item IDs passed. [True Swimming compatibility issue](../issues/upstream-override-compatibility.md)
