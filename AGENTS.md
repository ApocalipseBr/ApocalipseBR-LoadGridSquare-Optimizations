# ApocalipseBR LoadGridSquare Optimizations

This is a Project Zomboid Build 42 multi-mod project managed with the [PZ Studio VS Code plugin and CLI](https://github.com/escapepz/pzstudio). The repository directory retains the original LiuDing fix name. The current Workshop bundle is named in [project.json](project.json).

## Repository layout

| Path | Purpose |
| --- | --- |
| `project.json` | PZ Studio project and Workshop settings, mod IDs, dependency declarations and build options. |
| `package.json` | Project commands for generating and packaging the companions, watching authored files, and cleaning output. |
| `patches/` | Unified Lua diffs for Builder and BasementDig. Before and after snippets for True Swimming. |
| `<mod-id>/42/` | Build 42 mod metadata and any version-specific runtime files. |
| `<mod-id>/common/` | Assets and Lua shared across versions of that mod. |
| `workshop/` | Workshop description and preview for the bundle. |
| `.template-mod/` | Scaffold for a new mod entry. |
| `.libraries/`, `.vscode/` | Lua language-server references and editor settings. |
| `.docs/` | Indexed issues, reports and feature documentation. Start with [.docs/AGENTS.md](.docs/AGENTS.md). |

Keep each fix independently enableable under its own mod ID. Declare the original mod as a dependency so it loads first. For a file override, match the upstream path relative to the mod's media root, including filename case. Keep unrelated upstream assets in the original mod. Edit authored files and run `npm run build` from the root so the Builder, BasementDig and True Swimming overrides are generated and tested before PZ Studio packages it. Verify the generated package contains the expected Lua path and effective Build 42 `mod.info`. Keep authored metadata and the matching `project.json` entry consistent.

## Runtime changes

Read the matching feature document and inspect the installed upstream file and target Build 42 engine code before editing an override. Record the original mod ID, Workshop ID, inspected revision and exact replaced path. Compare against upstream after updates, since a full-file override can mask upstream fixes. Preserve server authority, shared client behavior and existing save compatibility. For an event change, verify when it fires, its arguments, where it runs, and whether its handler needs to be removed. Prefer a sprite-specific callback for a fixed sprite match and bounded work across ticks when scanning is necessary.

## Keeping the documentation current

Update the relevant feature document in the same change as the implementation. Add issues for concrete defects or unresolved compatibility questions and reports for investigations or validation runs. Index each new document in [.docs/AGENTS.md](.docs/AGENTS.md) and keep links and status current. Update [README.md](README.md) when package structure, supported mods, dependencies, event behavior or installation changes. Record the commands and results actually verified, including any dedicated-server behavior still awaiting validation.
