# Dedicated server startup checks

On 2026-11-22, a Windows Project Zomboid Build 42.22.2 dedicated server used a separate cache and save, loopback ports, and Steam and debug mode disabled. It loaded all four packaged companions, their original mods, and MinidoracatUI. The generated True Swimming override used public Workshop version 1.11.

All seven checks appeared once after `SERVER STARTED`.

```text
[ApocalipseBR_LiuDingTiles_fix] startup OK LiuDing3DItem.lua - sledgehammer sprite hook registered
[ApocalipseBR_TrueSwimming_fix] startup OK TrueSwimmingShared.lua - orphan-pontoon sprite hook registered
[minidoracatbuilderfix] startup OK Place.lua - chunk migration hook registered
[minidoracatbuilderfix] startup OK MigrationCache.lua - migration index initialized
[apocalipsebr_basementdig_fix] startup OK aparosa_BD_Build.lua - chunk hook ready
[apocalipsebr_basementdig_fix] startup OK aparosa_BD_Ladder.lua - ladder sprite hooks ready
[apocalipsebr_basementdig_fix] startup OK aparosa_BD_Mirror.lua - record recovery timer ready
```

The Lua test suite also verified that each reporter prints `startup ERROR` when its expected step has not run. `npm run build -- --check-upstream` downloaded and checked the four public items, tested the generated True Swimming file, and rebuilt the Workshop package. This run validated dedicated-server initialization. Gameplay and networking still need a connecting-client smoke test. [Startup check reference](../features/map-load-compatibility-patches.md#dedicated-server-startup-checks)
