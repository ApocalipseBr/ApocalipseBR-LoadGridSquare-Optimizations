# BasementDig room registration stalls the dedicated server tick

**Status** Open. Registration is isolated as the slow phase. Timing within registration is pending.

On Workshop item `3806513504` with the Basement Building companion, a single queued floor adoption spent 228 ms registering a room and refreshed 26 squares in one frame. The adoption continuation resumed later. The Build `42.22.2` reference editor runs three world-wide room and building ID checks and one world-wide ID rebuild for a successful commit. The checks perform linear room-list searches in each cell. Main-building registration also revisits the basement footprint. The current live sample does not resolve which of these operations dominates.

To reproduce, adopt one floor tile into an existing main basement on a representative dedicated-server save. Match `Work dispatched`, `room registered` and `slow adopt` by frame and coordinates. Capture the exact Java apply time and the server-square refresh time first, then profile the editor passes if the Java apply dominates. Use a copy of the save for repeated measurements from the same starting geometry. See the [source trace and measurement plan](../reports/2026-11-27-basementdig-room-registration-stutter.md) and the [companion patch behavior](../features/map-load-compatibility-patches.md#basementdig).
