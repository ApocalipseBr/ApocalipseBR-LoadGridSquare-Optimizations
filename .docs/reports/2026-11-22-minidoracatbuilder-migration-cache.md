# MinidoracatBuilder migration cache validation

Target engine source was Project Zomboid Build `42.22.2`. The installed upstream override was `MinidoracatBuilderFor42` version `42.22.2-1.1.1` from Workshop item `3830045886`. See the [feature documentation](../features/minidoracatbuilder-migration-cache.md) for the current implementation.

| Check | Result |
| --- | --- |
| Installed Project Zomboid JAR, Kahlua compiler and runtime, with mocked world objects and ledgers | The replacement compiled and ran. Assertions covered empty-chunk cache hits, candidate-only scans, mismatched save markers, direct placement and native double-door invalidation, pending floor and overlay repairs, refund resolution before the cursor arrives, version changes, missing version metadata, admin-only resets, and multiplayer client fallback. |
| Kahlua binary table save and load | The engine serializer preserved both the empty-chunk marker and the populated candidate list. |
| PZ Studio `buildCmd` with a scratch output directory | The Workshop package contained the resolved `Place.lua` path, cache module, client and server scripts, English context-menu label, dependency, companion version, and updated description. |
| `git diff --check` | Passed for tracked edits. The added English translation parsed as JSON and had no UTF-8 BOM. |

The Kahlua checks exercised the scheduler and cache logic with simulated chunks. Live world streaming, cache hit rates, save size, collision behavior, and server tick duration were outside this run.
