"""Download Workshop sources, compile and test Lua overrides, and package the companions."""
import argparse
import json
import os
import shutil
import subprocess
from contextlib import nullcontext
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.steamcmd import bundled_steamcmd
from tests.compatibility import BASELINES, GENERATED, ROOT, check, download, generate_companion, mod_info, version_layer


def configured_output():
    setting = Path.home() / ".pzstudio"
    return Path(setting.read_text(encoding="utf-8").strip()) if setting.is_file() else Path.home() / "Zomboid/Workshop"


def preserve_workshop_id(package, destination):
    previous = destination / "workshop.txt"
    if not previous.is_file():
        return
    published_ids = [
        line for line in previous.read_text(encoding="utf-8-sig").splitlines()
        if line.startswith("id=") and line[3:].isascii() and line[3:].isdigit()
    ]
    if not published_ids:
        return
    if len(published_ids) != 1:
        raise ValueError(f"Multiple published Workshop IDs in {previous}")
    metadata = package / "workshop.txt"
    lines = metadata.read_text(encoding="utf-8").splitlines(keepends=True)
    if not any(line.startswith("id=") for line in lines):
        lines.insert(1, published_ids[0] + "\n")
        metadata.write_text("".join(lines), encoding="utf-8", newline="\n")


def promote(package, destination):
    # Hold the lock only while replacing the finished package.
    backup = destination.with_name(f".{destination.name}.previous")
    lock = destination.with_name(f".{destination.name}.lock")
    try:
        lock.mkdir()
    except FileExistsError:
        raise ValueError(f"Package promotion is locked at {lock}") from None
    try:
        if backup.is_symlink() or backup.is_junction():
            raise ValueError(f"Expected a regular backup directory at {backup}")
        if backup.exists():
            if destination.exists():
                raise ValueError(f"Previous package needs review at {backup}")
            backup.rename(destination)
        if destination.is_symlink() or destination.is_junction():
            raise ValueError(f"Expected a regular Workshop package directory at {destination}")
        if destination.exists():
            if not destination.is_dir():
                raise ValueError(f"Expected a Workshop package directory at {destination}")
            preserve_workshop_id(package, destination)
            destination.rename(backup)
        try:
            package.rename(destination)
        except BaseException:
            if backup.exists() and not destination.exists():
                backup.rename(destination)
            raise
        if backup.exists():
            shutil.rmtree(backup)
    finally:
        lock.rmdir()


def build_package(generated, output):
    project = json.loads((ROOT / "project.json").read_text(encoding="utf-8"))
    title = project["title"]
    if title in ("", ".", "..") or Path(title).name != title:
        raise ValueError("Expected project title to be a single directory name")
    destination = output / title
    source_folders = [ROOT / folder for folder in (*project["mods"], "workshop")]
    if destination == ROOT or destination in ROOT.parents or any(
        folder == destination or folder in output.parents or folder == output
        for folder in source_folders
    ):
        raise ValueError("Workshop output overlaps the source project")
    output.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix=".apoc-workshop-", dir=output) as scratch:
        scratch = Path(scratch)
        stage = scratch / "project"
        stage.mkdir()
        shutil.copy2(ROOT / "project.json", stage)
        for folder in (*project["mods"], "workshop"):
            shutil.copytree(ROOT / folder, stage / folder)
        for relative, source in generated.items():
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source)

        packaged = scratch / "package"
        subprocess.run(
            ["node", str(ROOT / "scripts/package_workshop.cjs"), str(stage), str(packaged)],
            check=True,
        )
        package = packaged / title
        mods = package / "Contents/mods"
        for relative, source in generated.items():
            installed = mods / relative
            if installed.read_bytes() != source:
                raise ValueError(f"Packaged Lua differs from the tested source at {installed}")
        for companion, settings in project["mods"].items():
            info = mod_info(version_layer(mods / companion))
            if (info.get("id"), info.get("require"), info.get("versionMin"), info.get("loadModAfter")) != (
                companion, settings["require"], settings.get("versionMin"), settings.get("loadModAfter")
            ):
                raise ValueError(f"Packaged {companion} mod.info has unexpected metadata")
        promote(package, destination)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--steamcmd", type=Path, help="Standalone SteamCMD executable")
    source.add_argument("--workshop-root", type=Path, help="Existing steamapps/workshop/content/108600 directory")
    parser.add_argument("--reviewed", action="store_true", help="Use reviewed item IDs in an existing cache")
    parser.add_argument("--check-upstream", action="store_true", help="Also check the checked-in LiuDing Tiles override baseline")
    parser.add_argument("--benchmark-output", type=Path, help="Run mocked before/after benchmarks and write their JSON results")
    parser.add_argument("--output", type=Path, help="Parent directory of the generated Workshop package")
    args = parser.parse_args()
    if args.reviewed and not args.workshop_root:
        parser.error("--reviewed requires --workshop-root")

    other_mods = BASELINES["mods"].keys() - GENERATED.keys()
    check_upstream = args.check_upstream or args.benchmark_output is not None
    try:
        workshop = args.workshop_root
        steamcmd = args.steamcmd or os.environ.get("STEAMCMD") or shutil.which("steamcmd")
        provision = bundled_steamcmd() if not workshop and not steamcmd else nullcontext(steamcmd)
        with provision as executable:
            if workshop is None:
                ids = None if check_upstream else [spec["workshop_id"] for spec in GENERATED.values()]
                workshop = download(Path(executable), ids=ids)
            workshop = workshop.resolve()
            generated = {}
            for companion in GENERATED:
                generated.update(generate_companion(workshop, companion, reviewed=args.reviewed))
            if check_upstream:
                errors = check(workshop, reviewed=args.reviewed, companions=other_mods)
                if errors:
                    raise ValueError("\n".join(errors))
            if args.benchmark_output:
                from tests.mock_benchmark import collect, write_report

                report = collect(workshop, generated, reviewed=args.reviewed)
                write_report(report, args.benchmark_output, os.environ.get("GITHUB_STEP_SUMMARY"))
                print(f"Mocked Lua benchmark report ready at {args.benchmark_output}")
        destination = build_package(generated, (args.output or configured_output()).resolve())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Workshop build failed: {error}")
        return 1
    print(f"Workshop package ready at {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
