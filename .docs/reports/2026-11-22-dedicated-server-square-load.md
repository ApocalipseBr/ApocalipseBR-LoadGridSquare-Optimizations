# 2026-11-22 dedicated-server square-load baseline

The supplied ApocalipseBR snapshot identified the game as 42.22, schema 3, sequence 21. It covered 30.541 seconds and was emitted at 02:00:17 America/Fortaleza. The slowest tick, at 02:00:10, lasted **2,558.741 ms**. The map spent **2,030.614 ms** integrating cells and **392.796 ms** unloading cells. The capture predates the bundle changes and the exact deployed patch revision was unverified.

| Callback in the peak tick | Event | Reported total |
| --- | --- | ---: |
| LiuDing Tiles marker converter | `LoadGridsquare` | 448.159 ms |
| ExtractionMapUtils lobby perimeter | `LoadGridsquare` | 219.762 ms |
| True Swimming orphan cleanup | `LoadGridsquare` | 126.291 ms |
| MinidoracatBuilder migration | `LoadGridsquare` | 77.769 ms |
| BasementDig ladder repair | `LoadGridsquare` | 69.570 ms |
| BasementDig persistence mirror | `LoadGridsquare` | 10.310 ms |
| BasementDig light restoration | `LoadChunk` | 6.372 ms |
| True Swimming shallow water | `LoadGridsquare` | 4.632 ms |

The seven `LoadGridsquare` rows sum to 956.493 ms of reported callback time. They run inside map integration, so adding them to the map phase would double-count elapsed time. The inspected local telemetry implementation aggregates individual callback rows at 1 ms or more. The displayed call counts therefore omit shorter calls even when the omitted-key counter is zero. These timings do not isolate Kahlua dispatch, the work inside each callback, or JVM pauses.

ExtractionMapUtils was handled in its own project, where startup zombie cleanup now owns the lifetime of the lobby's square callback. This repository contains the [independent compatibility patches](../features/map-load-compatibility-patches.md). To measure their effect, compare chunk integration and tick maxima under similar player movement and streaming load, and inspect the Builder repair backlog while chunks are arriving. No post-change snapshot was supplied for this report.
