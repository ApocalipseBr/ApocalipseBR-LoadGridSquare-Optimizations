# Documentation index and maintenance

Use lowercase kebab-case filenames and relative Markdown links. Keep this index current when files are added, moved or superseded. Cross-link an issue, report and feature when they describe the same work.

| Directory | What to document |
| --- | --- |
| `issues/` | A reproducible symptom, affected mod and version, evidence, status, and a link to the fix or investigation. Update the issue when it is resolved. |
| `reports/` | Dated investigation or validation evidence. Prefix the filename with `YYYY-MM-DD-` and record the server/game build, inputs, commands, results and limits where known. Distinguish measured timings from code-based expectations. |
| `features/` | Current behavior, original mod and overridden files, event lifecycle, configuration, compatibility, and verification. Update the existing document when behavior changes. |

## Issues

- [Upstream override compatibility](issues/upstream-override-compatibility.md) documents how to check upstream updates and the True Swimming Workshop reference discrepancy.

## Reports

- [2026-11-22 dedicated-server square-load snapshot](reports/2026-11-22-dedicated-server-square-load.md) records the baseline and measurement limits.

- [2026-11-22 MinidoracatBuilder migration cache validation](reports/2026-11-22-minidoracatbuilder-migration-cache.md) records the Kahlua checks and staged package build.

## Features

- [Map-load compatibility patches](features/map-load-compatibility-patches.md) documents LiuDing Tiles, True Swimming, MinidoracatBuilder and the BasementDig scaffold.
- [MinidoracatBuilder migration cache](features/minidoracatbuilder-migration-cache.md) documents the coordinate index, reset action, and deferred refund safeguards.
