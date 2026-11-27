# Workshop refresh and BasementDig floor adoption

The supplied 13:10:21 Fortaleza capture shows a 1,498.517 ms server tick. A single BasementDig `OnClientCommand` callback in `aparosa_BD_Adopt.lua` took 909.644 ms, about 61% of the tick and 94% of the reported Lua time. The next Lua callback took 20.856 ms. The inspected Build 42.22.2 `GameServer` dispatches `OnClientCommand` synchronously during incoming packet handling, so the callback overlaps the 958.507 ms `network.incoming` phase. The capture includes one peak and does not identify the deployed game or patch revision, average cost, or the time spent within each step of the callback.

## Workshop cache review

Resolved the installed sources for game Build 42.22.2 from `Z:/SteamLibrary/steamapps/workshop/content/108600`. The [baseline inventory](../../tests/workshop-baselines.json) records the selected item IDs, mod releases and LF-normalized SHA-256 hashes for the replaced paths.

| Workshop item | Installed release | Result |
| --- | --- | --- |
| LiuDing Tiles `3736154771` | Unversioned | The converter's upstream path and hash match the reviewed baseline. |
| True Swimming `3802372726` | `1.11` | Recorded the public release as the current baseline. The orphan-pontoon snippet applies as written. Tests cover shallow water and dock walking. |
| Build Anything `3830045886` | `42.22.2-1.5.0` | Rebased `Place.lua`. Kept the upstream `IsoThumpable` guards around build-material methods and carried forward deferred refunds, chunk migration and region checks. |
| Basement Building `3806513504` | `1.6.13` | The three previous targets match their reviewed hashes. Adoption now passes the surviving record through the generated Sync override to Mirror. |

## BasementDig command path

`Adopt.apply` validates the floor, resolves neighboring records, registers the room and updates walls and nearby squares. `Sync.publish` sends the record snapshot and updates square recovery copies. The patch uses the existing frozen index during each read-only four-way lookup and checks the updated index again after adoption changes the record. Mirror fingerprints and rewrites copies only for the surviving record. The full snapshot still goes to clients so that a merged record can be removed from their local world state.

The exact Build 42.22.2 engine source shows that `GlobalModData.transmit` writes the full table to each connection. Room registration also calls into `BuildingRoomsEditor`. Either step can still dominate a large adoption. The new `slow adopt` console entry logs `applyMs` and `publishMs` when their sum reaches 100 ms. The upstream `room registered` timing can help isolate room work in the same capture. A dedicated-server reproduction with representative basement records and connected clients is needed to measure the change and verify live room replication.

## Local verification

- `py -3 -B -m unittest discover -s tests -v` passed seven tests.
- `py -3 -B tests/compatibility.py --workshop-root <cache> --reviewed` passed for all four mods.
- `npm run build -- --workshop-root <cache> --check-upstream --output <staging>` generated seven overrides and verified their packaged bytes and dependency metadata.
- The installed game's Kahlua compiler accepted all 15 packaged Lua files. Its runtime passed six mocked fixtures, including adoption with a merged record, recovery copies, a rejected distant request, and the Builder vanilla-floor guard.
