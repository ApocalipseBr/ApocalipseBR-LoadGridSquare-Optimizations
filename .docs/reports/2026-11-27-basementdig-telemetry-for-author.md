# Basement Building performance report: 219 ticks over 30.027 seconds

**For the Basement Building maintainer (Workshop item 3806513504)**

The server completed **219 simulation ticks across 963 outer-loop iterations**. This report summarizes that full window and shows the timing breakdown for its single slowest tick. Three recorded calls to the floor-adoption handler took **2,806.520 ms combined**. The longest call took **1,198.319 ms**. In the slowest overall server tick, a different call to the same handler took **909.644 ms** of the **1,498.517 ms** tick. That single call accounted for **60.7% of the tick** and **94.4% of its measured Lua time**. Because the handler runs synchronously during incoming packet processing, the server waits for adoption to finish before it can continue processing that iteration.

## Capture and metric scope

| Field | Value |
| --- | --- |
| Server | ApocalipseBR dedicated server, Project Zomboid Build `42.22` |
| Basement Building | `1.6.13`, the Workshop release used for the source review |
| Snapshot emitted and received | 2026-11-27 13:10:40, Fortaleza time (UTC−03:00) |
| Actual reporting window | 30,027 ms |
| Slowest tick timestamp | 2026-11-27 13:10:21, same time zone |
| Telemetry and Lua coverage | 0 dropped telemetry snapshots reported. Lua events and callback measurement enabled. 0 callback calls omitted by the recorder's capacity limit. |

| Section in the capture | How to read it |
| --- | --- |
| **Ticks, loop, population and map** | Tick count, rate, mean, maximum and overruns describe the reporting window. A tick is a completed simulation iteration. The outer loop also has iterations that process packets without running simulation. Its elapsed total includes waiting and sleep. Players, map cells and active object counts are sampled when the snapshot is emitted. |
| **Lua callbacks in the interval** | One row per recorded hook and source location. Calls counts the invocations included in the row, Total sums their elapsed time across the window, and Max is the largest individual invocation. The inspected implementation ranks up to 12 rows and records individual callback rows for calls of at least 1 ms. |
| **Lua events in the interval** | An event is a dispatch, such as `OnClientCommand`. One dispatch may invoke many Lua listeners. Calls counts dispatches, Callbacks counts listener invocations, and Total, Average and Max describe the full dispatch. |
| **Slowest tick, its phases and Lua callbacks** | The wall time and timing breakdown describe one simulation iteration. A phase row accumulates the time recorded for that phase within that tick. A callback row covers only calls in that tick. The slowest overall tick need not contain the slowest individual callback in the window. |
| **JVM, counters and server phases** | Heap values are measurements at emission. GC counts and times are changes over the reporting window. Engine counters count occurrences or visits during the window. Interval phase averages and maxima describe each phase's instrumented calls. Their maxima can occur at different times. |

Lua callback rows include the hook, mod ID, Workshop ID, source file, function label and line. The affected source is `media/lua/shared/aparosa_BasementDig/aparosa_BD_Adopt.lua` in mod `aparosa_BasementDig`. The `Add` label and line 225 identify the registered closure in this capture. In Basement Building 1.6.13, that closure handles the `adopt` command and calls `Adopt.apply` after checking the requester.

## The 30.027-second window

| Metric | Value |
| --- | ---: |
| Completed simulation ticks | 219 |
| Observed tick rate | 7.293/s |
| Mean / maximum tick duration | 121.965 / 1,498.517 ms |
| Ticks above 100 ms | 75 of 219 (34.2%) |
| Outer loop iterations / elapsed total | 963 / 30,022.739 ms |
| Players / active zombies at emission | 5 / 2,191 |
| Loaded / pending map cells at emission | 61 / 0 |
| Moving objects at emission | 3,106, including 2,191 zombies, 415 zombie giblets, 370 vehicles, 125 animals and 5 players |

| Lua measurement across the window | Calls | Total (ms) | Max (ms) |
| --- | ---: | ---: | ---: |
| Basement Building adoption callback, `aparosa_BD_Adopt.lua:225` | 3 | 2,806.520 | 1,198.319 |
| All `OnClientCommand` dispatches (162 listener invocations) | 3 | 2,807.487 | 1,198.535 |
| Game `OnProcessAction` callback in `ActionManager.lua` | 2 | 1,265.656 | 672.964 |
| Basement Building room-split `OnTick` callback | 2 | 102.000 | 51.207 |

The three adoption calls averaged **935.507 ms each** and accounted for approximately **99.97% of the measured `OnClientCommand` dispatch time**. The dispatch already includes the callback. The capture records other expensive work, including `OnProcessAction`, and gives no basis for attributing all 75 overruns to Basement Building.

## The slowest of the 219 ticks

| Measurement at 13:10:21 | Elapsed (ms) |
| --- | ---: |
| Whole simulation tick | 1,498.517 |
| Measured Lua time, with 241 timed callback invocations | 963.806 |
| `network.incoming` | 958.507 |
| Basement Building adoption callback (one invocation) | 909.644 |
| `simulation.update` | 367.761 |
| `simulation.world` | 292.864 |
| `simulation.cell` | 256.612 |
| `simulation.movingObjects.update` | 223.634 |
| Next largest listed Lua callback, ApocalipseBR Radio `OnTick` | 20.856 |

Keep the measurements inclusive. Incoming packet processing contains the adoption callback, and simulation phases such as world, cell and moving objects are nested. Adding those rows would count some elapsed time multiple times.

## JVM and ZGC

| Heap measurement at snapshot emission | Bytes | GiB |
| --- | ---: | ---: |
| Used, estimated from committed heap minus free space within it | 6,224,347,136 | 5.80 |
| Committed to the JVM heap | 19,327,352,832 | 18.00 |
| Maximum heap | 21,474,836,480 | 20.00 |

Heap values exclude non-heap process memory. A single endpoint reading cannot establish an allocation rate or a memory leak.

| ZGC management counter | Count in window | Elapsed total (ms) |
| --- | ---: | ---: |
| Minor cycles | 5 | 1,213 |
| Major cycles | 1 | 13,313 |
| Minor pauses | 15 | 1 |
| Major pauses | 2 | 0 |
| **Sum of reported counters** | **23** | **14,527** |

The 23 entries combine **six cycle entries and 17 pause entries**. The 14,527 ms is the sum of collector management counters. ZGC does much of its work concurrently with application threads. The pause counters recorded 1 ms at the reported resolution. Java exposes accumulated collection times in whole milliseconds, so short pauses can increment the count without changing the time. These interval counters provide no timestamp to correlate a GC event with the adoption call. Timestamped GC logs or JFR can establish that correlation in a follow-up capture. [Java collector counter documentation](https://docs.oracle.com/en/java/javase/25/docs/api/java.management/java/lang/management/GarbageCollectorMXBean.html) · [Oracle collector overview](https://docs.oracle.com/en/java/javase/25/gctuning/available-collectors.html)

## Why we refactored floor adoption

The earlier companion addressed ladder and record recovery during map streaming. This capture exposed a different entry point. During adoption, the server validates the floor, resolves adjacent records, registers the room, opens dirt edges, recalculates nearby squares, sends the authoritative snapshot and writes square-level recovery copies. Repeated lookups can recalculate a fingerprint over the saved records, and the previous publication path checked every saved record for mirror changes. The three slow calls across the window made this synchronous path worth addressing even though the telemetry had no timings for its internal steps.

- **Reuse the spatial index within each read-only neighbor pass.** Adoption now calls the mod's existing `withFrozenIndex` API for the four-way neighbor lookup and the dirt-edge lookup. Each pass checks the index once. After adoption changes the record, the dirt-edge pass can see the updated state.
- **Limit recovery-copy work to the affected basement.** The successful adoption passes the surviving record through `Sync.publish` to Mirror. Mirror checks and writes copies for that record. The full authoritative snapshot still goes to clients so they can remove records that disappeared in a merge. Other publication paths keep their existing behavior.
- **Measure application and publication separately.** Successful adopts that spend at least 100 ms across these two steps emit `slow adopt` with `applyMs` and `publishMs`. Application includes room registration and world updates. Publication still includes the full snapshot broadcast and the mirror write. This split helps locate the remaining cost.

The companion targets Basement Building **1.6.13**. The adoption fixtures cover a merge and a rejected distant request. Check [Workshop compatibility](https://github.com/ApocalipseBr/ApocalipseBR-LoadGridSquare-Optimizations/actions/workflows/workshop-compatibility.yml) for the Workshop sources and companion package tested by CI.

## Follow-up after the Lua refactor

We wired adoption and ordinary expansion into the [ApocalipseBR Best Practices Library](https://github.com/rbm4/apocalipsebr_bplib/blob/master/README.md). Adoption can resume its neighborhood refresh across ticks and coalesce publication. Expansion can pause during preparation before editing the world. A later queued adoption still recorded **228 ms of room registration in one server frame** and **1 ms of publication work**. The registration timer includes Java and the mod's server-square refresh. [Dedicated-server registration trace](2026-11-27-basementdig-room-registration-stutter.md)

The original Build 42.22.2 editor validates room and building IDs across the map three times and then rebuilds the global ID maps. The vanilla Lua API has no supported in-place resize that provides equivalent registration for an isolated edit. Lua can batch compatible additions, and BPJobs can choose when to start the commit. Shortening the commit itself required changing the Java path. [Original-JAR validation](https://github.com/rbm4/apocalipsebr-zomboid-patches/blob/master/.docs/reports/2026-11-27-room-registration-validation.md)

The [Java agent implementation](https://github.com/rbm4/apocalipsebr-zomboid-patches/blob/master/.docs/features/room-id-validation.md#scoped-lua-commits) keeps the editor's replacement and spatial updates and limits ID repair to the relevant owner cells for explicit Lua requests. Ordinary editor calls retain their global passes. The companion requests the agent path for an existing main basement and retains the vanilla fallback.

Look for `room-registration-ab` in [Project Zomboid server integration](https://github.com/rbm4/apocalipsebr-zomboid-patches/actions/workflows/server-integration.yml). Its summary compares **Vanilla**, **Indexed lookup**, and **Indexed + scoped** on the same dedicated-server runner. The [comparison guide](https://github.com/rbm4/apocalipsebr-zomboid-patches/blob/master/.docs/reports/2026-11-27-scoped-room-commit-validation.md) identifies the artifacts and explains how to read the results. The fixture isolates the editor call. A production capture with BasementDig installed is still needed.
