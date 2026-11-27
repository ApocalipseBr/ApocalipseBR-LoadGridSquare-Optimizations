# Upstream override compatibility

**Status:** Recheck on upstream updates.

## Builder 1.5.1 migration context

The installed Build Anything `42.22.2-1.5.1` changed `Place.migrate` to cache a single object ModData lookup and changed its per-square listener to reuse Java method references. The `1.5.0` diff required the previous source around both edits and the build rejected it during generation. The rebased companion retains deferred chunk migration and uses the cached method references inside its worker. It also preserves upstream storage of underground switch state and the new-switch callback argument. [Builder change notes](https://steamcommunity.com/sharedfiles/filedetails/changelog/3830045886)

Basement Building remained at `1.6.13`. All five upstream override targets matched their reviewed hashes. Its latest published entry addresses ladder descent with the fall guard enabled. [Basement Building change notes](https://steamcommunity.com/sharedfiles/filedetails/changelog/3806513504)

The rebase passed the eight offline tests and the full Workshop-cache build with the A/B benchmark. The installed game's Kahlua compiled all 15 packaged Lua files and ran six mocked fixtures. The Builder fixture exercised the cached method branch, and the streaming benchmark exercised its fallback. In-game circuit behavior still needs a live test.

Each companion overrides a complete Lua file at its original path. The generated Builder, BasementDig and True Swimming files incorporate upstream updates outside the patch context. Changed or ambiguous context stops the build for review. LiuDing Tiles uses a checked-in converter with a reviewed upstream hash. If an author moves or adds a handler in another file, review the new file for duplicate subscriptions.

Check upstream mod metadata, compare the overridden file with the current upstream revision, and inspect the active subscriptions after updating. For shared files, verify the same resolved patch on the dedicated server and a connecting client. See the [file and event reference](../features/map-load-compatibility-patches.md).

## True Swimming Workshop identity

The 2026-11-22 telemetry and local source comparison identify the installed copy under Workshop ID `3691681426`. The distribution description links [Harkwood's True Swimming listing, 3802372726](https://steamcommunity.com/sharedfiles/filedetails/?id=3802372726). The companion declares the internal mod ID `TrueSwimming`. The current baseline uses the public item at version 1.11 and records the hash from the installed Workshop cache.

## True Swimming 1.11 drift

Anonymous SteamCMD downloaded item `3802372726` as version 1.11 on 2026-11-22. Its shared file adds `TS.eauCouverte` and uses it to keep players from sinking while walking on docks, quays, and bridges over water. The old checked-in override was based on 1.9 and hid that fix. The generated 1.11 override retains it, and a Lua regression test exercises the dock behavior with mocked game objects. The dedicated-server smoke test is still pending. [Test workflow and baseline instructions](../features/patch-tests.md)
