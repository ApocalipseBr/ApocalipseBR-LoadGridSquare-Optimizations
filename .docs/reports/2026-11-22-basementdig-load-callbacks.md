# Basement Building load callback validation

The companion overrides the installed Basement Building release 1.6.13 from Workshop item 3806513504. The [feature reference](../features/map-load-compatibility-patches.md#basementdig) lists each file and the event it uses.

| Check | Result |
| --- | --- |
| Installed Project Zomboid JAR, Kahlua compiler and runtime | The three override files compiled and executed with mocked events and world objects. Checks covered client startup, the four sprite registrations, deferred conversion, duplicate candidates, the eight-candidate cap, batched publication, a missing top and a late neighbor chunk. |
| Kahlua record recovery fixtures | Checks covered expansion-before-anchor loading, later replacement by a newer copy, backfilled anchors, copies on empty squares, legacy records without a version, and ladder repair following record recovery. Surface-only chunks skipped the Mirror scan and both new tick workers detached when idle. |
| PZ Studio build command with a scratch output directory | The generated package contained all three override paths, the effective Build 42 dependency metadata, the poster and the updated Workshop description. |
| Git whitespace and upstream source comparison | The tracked diff passed the whitespace check. The three replacement files differ from the installed copies in load handling, recovery state and comments related to those changes. |

The Kahlua harness used the installed Java runtime with mocked networking, room registration and map objects. A live dedicated-server run is still required to verify replication, streaming latency and main-thread timings.
