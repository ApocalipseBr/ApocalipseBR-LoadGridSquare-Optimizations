# Upstream override compatibility

**Status:** Recheck on upstream updates.

Each companion overrides a complete Lua file at its original path. For checked-in overrides, an upstream change to that file needs a manual review. The True Swimming build preserves upstream source outside its targeted callback and checks the generated file before packaging. If upstream moves the handler to another path, both scripts can load and the original per-square callback can return.

Check upstream mod metadata, compare the overridden file with the current upstream revision, and inspect the active subscriptions after updating. For shared files, verify the same resolved patch on the dedicated server and a connecting client. See the [file and event reference](../features/map-load-compatibility-patches.md).

## True Swimming Workshop identity

The 2026-11-22 telemetry and local source comparison identify the installed copy under Workshop ID `3691681426`. The distribution description links [Harkwood's True Swimming listing, 3802372726](https://steamcommunity.com/sharedfiles/filedetails/?id=3802372726). The companion declares the internal mod ID `TrueSwimming`. The local 1.9 copy remains available as a reviewed input. The live build uses the public Workshop listing.

## True Swimming 1.11 drift

Anonymous SteamCMD downloaded item `3802372726` as version 1.11 on 2026-11-22. Its shared file adds `TS.eauCouverte` and uses it to keep players from sinking while walking on docks, quays, and bridges over water. The old checked-in override was based on 1.9 and hid that fix. The generated 1.11 override retains it, and a Lua regression test exercises the dock behavior with mocked game objects. The dedicated-server smoke test is still pending. [Test workflow and baseline instructions](../features/patch-tests.md)
