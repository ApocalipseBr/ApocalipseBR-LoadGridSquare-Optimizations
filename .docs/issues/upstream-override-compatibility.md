# Upstream override compatibility

**Status:** Recheck on upstream updates.

Each implemented companion overrides a complete upstream Lua file at its original path. An upstream update can introduce behavior in that file which the companion's copy will hide. If upstream moves the handler to another path, both scripts can load and the original per-square callback can return.

Check upstream mod metadata, compare the overridden file with the current upstream revision, and inspect the active subscriptions after updating. For shared files, verify the same resolved patch on the dedicated server and a connecting client. See the [file and event reference](../features/map-load-compatibility-patches.md).

## True Swimming Workshop identity

The 2026-11-22 telemetry and local source comparison identify the installed copy under Workshop ID `3691681426`. The distribution description links [Harkwood's True Swimming listing, 3802372726](https://steamcommunity.com/sharedfiles/filedetails/?id=3802372726). The companion declares the internal mod ID `TrueSwimming`. The local comparison confirmed the orphan-hook change against the `3691681426` copy. Verify the current Workshop download and compare its shared file before declaring compatibility with that release.

## True Swimming 1.11 drift

Anonymous SteamCMD downloaded item `3802372726` as version 1.11 on 2026-11-22. Its shared file adds `TS.eauCouverte` and uses it to keep players from sinking while walking on docks, quays, and bridges over water. The companion's full-file override is based on 1.9 and omits that fix. The live Workshop check flags the shared file until the override is reconciled. [Test workflow and baseline instructions](../features/patch-tests.md)
