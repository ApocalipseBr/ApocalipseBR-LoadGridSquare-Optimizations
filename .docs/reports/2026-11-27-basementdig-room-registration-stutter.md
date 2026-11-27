# BasementDig room registration stutter

## Dedicated-server capture

The supplied console excerpt records a single floor adoption at `10350,9569,-1` after dispatch through the `aparosa_BasementDig` BPJobs lane. The reference sources are Workshop item `3806513504`, Basement Building `1.6.13`, and the Build `42.22.2` vanilla decompile under `42.22.2/decompiled/zombie` in the local Java agent repository. The excerpt does not identify the deployed JAR or agent revision. This is a single-event observation. See the [tracked issue](../issues/basementdig-room-registration-stutter.md) and [companion behavior](../features/map-load-compatibility-patches.md#basementdig).

| Observation | Result |
| --- | --- |
| Dispatch and registration | Both ran in frame `8001`. The inner room timer recorded 226 ms for one room in five rectangles. |
| Registration interval | The outer adoption timer recorded `roomRegistrationMs=228` and `applyMs=228`. The inner timer is part of the outer interval. |
| Server square refresh | 26 squares were refreshed within registration. The log gives a count without a separate elapsed time. |
| Follow-up | Adoption finished in frame `8006`. `dirtEdgesMs=0`, `neighborhoodRecalcMs=0`, and `publicationWorkMs=1` at the logging resolution. The next ticket dispatched in frame `8012`. |

The `duplicate BuildingDef.metaID` message for `10350,9567` comes from `BuildingRoomsEditor.applyChanges`. The matching branch logs the collision, removes the existing definition from the world and recalculates IDs for its meta cell. BasementDig deliberately preserves the main building's corner when rebuilding its rectangles to reuse the meta ID. In this trace the editor continued and room registration completed. The collision log is a source-path marker. Its timestamp cannot time the rest of the branch or the global passes independently.

## What the call touches

| Scope | Work in Build 42.22.2 | Scaling input |
| --- | --- | --- |
| Basement geometry and loaded squares | `aparosa_BD_Rooms.growRecord` rebuilds the main building's rectangles from its tile set. `registerRects` splits rooms, collects and restores room squares around the editor commit, then walks the registered footprint to rebind loaded server squares, restore switch associations and recalculate square properties. | Basement tiles, rectangles, room partitions and objects on loaded squares. |
| ID validation | `BuildingRoomsEditor.applyChanges` calls the no-argument `checkBuildingAndRoomIDs` three times. Each call walks `IsoLot.InfoHeaders.values()` and resolves each header to an `IsoMetaCell`. Inside each cell it walks buildings and uses `roomList.indexOf` for each building room and outside-room definition, then checks the indexed room list and map size. This validator reads IDs and logs mismatches. | Map metadata across the world and the room distribution within each cell. `roomList` is an `ArrayList`. Checking a list of `R` rooms against itself with one successful linear lookup per room can require roughly `R² / 2` comparisons per pass in a dense cell. |
| ID rebuild | Removing an existing building can trigger a rebuild in that cell before insertion. After insertion, the no-argument `recalculateBuildingAndRoomIDs` goes through the world lot headers again. It assigns definition IDs from list positions, clears and repopulates the room ID map, and copies and re-keys the live `IsoRoom` and `IsoBuilding` maps. | World room and building definitions plus live room and building objects. Streamed objects contribute to the live-map work. The definition checks also run for distant map cells with no players nearby. |
| Editor tail | `applyChanges(false)` triggers lighting and occlusion updates and runs `updateSquares`, which iterates local player chunk maps. BasementDig's dedicated-server refresh repairs the registered footprint separately. | Local chunk maps and the server-side footprint refresh. Measure these paths separately. |

The three validation passes and the final ID rebuild run synchronously even for a one-tile change. They are plausible sources of the stutter. The 228 ms wrapper includes these passes, the remove-and-add work, and the Lua footprint work. It gives no elapsed-time ranking within registration. Publication, recovery copies and the final neighborhood refresh were measured elsewhere or contributed negligible time in this event. BPJobs can move follow-up work to later ticks. It cannot pause inside the Java commit. See the [adoption timing patch](../../patches/basement-dig/aparosa_BD_Adopt.patch).

## Discriminating measurements

1. Time the exact Lua-to-Java `editor:applyChanges(false)` call separately from room splitting, room-square collection and fill, and `refreshServerSquares`. Log rectangle, footprint and refreshed-square counts with the same registration sample.
2. Within the Java call, time the three global ID checks as a group, the collision removal and local reindex, the add, the final global reindex, and the lighting and square-update tail. Count distinct meta cells, room definitions examined and live entries re-keyed. Use aggregate timings or a slow-call summary to keep logging out of the inner loops. These times are nested under the editor total.
3. Repeat equivalent one-tile additions from the same disposable save with the same basement footprint and different streamed populations. Then vary the basement footprint on the same map. A separate small-map versus production-map comparison can help isolate metadata cost while keeping the edited footprint comparable. Include several warm samples for each scenario.

If the checks dominate, a narrow engine optimization can preserve the validator and avoid most linear searches. Decode the room ID's index with `RoomID.getIndex`, check bounds and verify that `roomList[index]` is the same definition. Use the existing `indexOf` path for mismatches so missing definitions and wrong IDs still produce their diagnostics. A larger change would narrow the final ID rebuild to cells whose metadata changed. That needs tests for replacement, old and new anchor cells, adjacent-cell spatial registration, ID stability and existing square references. The local Java repository routes new engine work through its root Byte Buddy agent against the original game JAR.

Lua batching can amortize repeated editor calls for compatible additions to the same basement. It leaves the cost of an isolated registration to the editor. The current investigation is based on source inspection and the supplied console excerpt. A live timing split or profile is still needed before choosing between the validator, the rebuild and the footprint work.
