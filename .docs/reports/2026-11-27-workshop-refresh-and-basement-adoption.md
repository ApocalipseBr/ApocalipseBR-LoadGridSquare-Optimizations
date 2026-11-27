# Workshop refresh and BasementDig floor adoption

The supplied 13:10:21 Fortaleza capture shows a 1,498.517 ms server tick. A single BasementDig `OnClientCommand` callback in `aparosa_BD_Adopt.lua` took 909.644 ms, about 61% of the tick and 94% of the reported Lua time. The next Lua callback took 20.856 ms. The inspected Build 42.22.2 `GameServer` dispatches `OnClientCommand` synchronously during incoming packet handling, so the callback overlaps the 958.507 ms `network.incoming` phase. The capture includes one peak and does not identify the deployed game or patch revision, average cost, or the time spent within each step of the callback.

## Workshop source review

The [baseline inventory](../../tests/workshop-baselines.json) records the Workshop item IDs, mod releases and LF-normalized SHA-256 hashes reviewed for Build 42.22.2.

| Workshop item | Installed release | Result |
| --- | --- | --- |
| LiuDing Tiles `3736154771` | Unversioned | The converter's upstream path and hash match the reviewed baseline. |
| True Swimming `3802372726` | `1.11` | Recorded the public release as the current baseline. The orphan-pontoon snippet applies as written. Tests cover shallow water and dock walking. |
| Build Anything `3830045886` | `42.22.2-1.5.0` | Rebased `Place.lua`. Kept the upstream `IsoThumpable` guards around build-material methods and carried forward deferred refunds, chunk migration and region checks. |
| Basement Building `3806513504` | `1.6.13` | The three previous targets match their reviewed hashes. Adoption now passes the surviving record through the generated Sync override to Mirror. |

## BasementDig command path

`Adopt.apply` validates the floor, resolves neighboring records, registers the room and updates walls and nearby squares. `Sync.publish` sends the record snapshot and updates square recovery copies. The patch uses the existing frozen index during each read-only four-way lookup and checks the updated index again after adoption changes the record. Mirror fingerprints and rewrites copies only for the surviving record. The full snapshot still goes to clients so that a merged record can be removed from their local world state.

The exact Build 42.22.2 engine source shows that `GlobalModData.transmit` writes the full table to each connection. Room registration also calls into `BuildingRoomsEditor`. Either step can still dominate a large adoption. The new `slow adopt` console entry logs `applyMs` and `publishMs` when their sum reaches 100 ms. The upstream `room registered` timing can help isolate room work in the same capture. A dedicated-server reproduction with representative basement records and connected clients is needed to measure the change and verify live room replication.

## Workflow verification

Use [Patch tests](https://github.com/ApocalipseBr/ApocalipseBR-LoadGridSquare-Optimizations/actions/workflows/patch-tests.yml) for the companion fixtures and [Workshop compatibility](https://github.com/ApocalipseBr/ApocalipseBR-LoadGridSquare-Optimizations/actions/workflows/workshop-compatibility.yml) for checks against downloaded Workshop sources and the generated package. The Java editor timings are in the separate integration workflow described below.

## Follow-up after wiring BPJobs

The [ApocalipseBR Best Practices Library](https://github.com/rbm4/apocalipsebr_bplib/blob/master/README.md) moved adoption commands into the BasementDig FIFO. The companion uses checkpoints to resume neighborhood refresh and coalesces full-state publication. Ordinary expansion uses the same FIFO to pause read-only preparation and revalidate before committing. These changes gave Lua work safe pause points and made it possible to time registration separately.

A later queued adoption spent **228 ms in room registration** in one server frame. Dirt-edge work and neighborhood recalculation each measured **0 ms** at log precision, and `publicationWorkMs` measured **1 ms**. The 228 ms timer includes the Java editor and the Lua server-square refresh. This capture and the 909.644 ms callback above have different workloads and timing boundaries. [Registration trace](2026-11-27-basementdig-room-registration-stutter.md)

The original-JAR fixture isolates the vanilla editor's three world-wide ID checks and final global rebuild. Build 42.22.2 exposes no equivalent Lua-only operation for immediately growing a registered room without the editor commit. The Java agent first replaced repeated room-list searches with indexed checks, then scoped ID work to the affected owner cells for explicit Lua commits. Open [Project Zomboid server integration](https://github.com/rbm4/apocalipsebr-zomboid-patches/actions/workflows/server-integration.yml) and look for `room-registration-ab`. Compare **Vanilla** with **Indexed lookup**, then **Indexed lookup** with **Indexed + scoped**, in the run summary. [Indexed validation](https://github.com/rbm4/apocalipsebr-zomboid-patches/blob/master/.docs/reports/2026-11-27-room-registration-validation.md) · [Scoped commit comparison](https://github.com/rbm4/apocalipsebr-zomboid-patches/blob/master/.docs/reports/2026-11-27-scoped-room-commit-validation.md)

The [Rooms override](../../patches/basement-dig/aparosa_BD_Rooms.patch) requests the [opt-in Java commit](https://github.com/rbm4/apocalipsebr-zomboid-patches/blob/master/.docs/features/room-id-validation.md#scoped-lua-commits) for dedicated-server growth of an existing main basement and falls back to the ordinary editor if the bridge is absent or declines the request. The Java fixture excludes BasementDig's loaded-square refresh and publication. End-to-end production adoption timing with the scoped hook remains pending.
