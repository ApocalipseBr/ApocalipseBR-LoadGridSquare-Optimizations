"""Download, test and package the generated True Swimming companion."""
import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.true_swimming import COMPANION, OUTPUT_PATH
from tests.compatibility import BASELINES, ROOT, check, download, generate_true_swimming, mod_info


def configured_output():
    setting = Path.home() / ".pzstudio"
    return Path(setting.read_text(encoding="utf-8").strip()) if setting.is_file() else Path.home() / "Zomboid/Workshop"


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


def build_package(source, output):
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
        target = stage / OUTPUT_PATH
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source)

        packaged = scratch / "package"
        subprocess.run(
            ["node", str(ROOT / "scripts/package_workshop.cjs"), str(stage), str(packaged)],
            check=True,
        )
        package = packaged / title
        installed = package / "Contents/mods" / OUTPUT_PATH
        if installed.read_bytes() != source:
            raise ValueError(f"Packaged Lua differs from the tested source at {installed}")
        info = mod_info(installed.parents[3])
        if info.get("id") != COMPANION or info.get("require") != project["mods"][COMPANION]["require"]:
            raise ValueError("Packaged True Swimming mod.info has unexpected metadata")
        promote(package, destination)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--steamcmd", type=Path, help="Standalone SteamCMD executable")
    source.add_argument("--workshop-root", type=Path, help="Existing steamapps/workshop/content/108600 directory")
    parser.add_argument("--reviewed", action="store_true", help="Use reviewed item IDs in an existing cache")
    parser.add_argument("--check-upstream", action="store_true", help="Also check the other three mods' override baselines")
    parser.add_argument("--output", type=Path, help="Parent directory of the generated Workshop package")
    args = parser.parse_args()
    if args.reviewed and not args.workshop_root:
        parser.error("--reviewed requires --workshop-root")

    spec = BASELINES["mods"][COMPANION]
    other_mods = [name for name in BASELINES["mods"] if name != COMPANION]
    try:
        workshop = args.workshop_root
        if not workshop:
            steamcmd = args.steamcmd or os.environ.get("STEAMCMD") or shutil.which("steamcmd")
            if not steamcmd:
                parser.error("Set STEAMCMD, pass --steamcmd, or use --workshop-root with an existing cache")
            ids = None if args.check_upstream else [spec["workshop_id"]]
            workshop = download(Path(steamcmd), ids=ids)
        generated = generate_true_swimming(workshop.resolve(), reviewed=args.reviewed)
        if args.check_upstream:
            errors = check(workshop, reviewed=args.reviewed, companions=other_mods)
            if errors:
                raise ValueError("\n".join(errors))
        destination = build_package(generated, (args.output or configured_output()).resolve())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Workshop build failed: {error}")
        return 1
    print(f"Workshop package ready at {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
