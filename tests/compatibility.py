"""Check the Build 42 Lua files that the companions shadow."""
import argparse
import hashlib
import json
import operator
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINES = json.loads((ROOT / "tests/workshop-baselines.json").read_text(encoding="utf-8"))


def build_number(version):
    # ZomboidFileSystem.getGameVersionIntFromName uses the major and minor parts.
    major, minor, *_ = [int(part) for part in version.split(".")] + [0]
    return major * 1000 + min(minor, 999)


def version_layer(mod):
    target = build_number(BASELINES["game_build"])
    choices = [
        (build_number(child.name), child)
        for child in mod.iterdir()
        if child.is_dir() and re.fullmatch(r"42(?:\.\d+)*", child.name)
    ]
    choices = [(version, child) for version, child in choices if version <= target]
    version = max((version for version, _ in choices), default=None)
    latest = [child for number, child in choices if number == version]
    if len(latest) > 1:
        raise ValueError(f"{mod.name}: ambiguous B42 folders {', '.join(p.name for p in latest)}")
    return latest[0] if latest else mod / "42"


def mod_info(layer):
    file = layer / "mod.info"
    if not file.is_file():
        return {}
    return dict(line.split("=", 1) for line in file.read_text(encoding="utf-8-sig").splitlines() if "=" in line)


def lua_files(mod):
    files = {}
    for layer in (mod / "common", version_layer(mod)):
        for file in (layer / "media/lua").rglob("*.lua"):
            path = file.relative_to(layer).as_posix()
            files[path.lower()] = file
    return files


def find_mod(item, mod_id):
    candidates = [
        mod for mod in (item / "mods").glob("*")
        if mod.is_dir() and mod_info(version_layer(mod)).get("id") == mod_id
    ]
    if len(candidates) != 1:
        raise ValueError(f"{item.name}: expected one compatible mod with id={mod_id}, found {len(candidates)}")
    mod = candidates[0]
    info = mod_info(version_layer(mod))
    game = tuple(int(part) for part in BASELINES["game_build"].split("."))
    for key, fails in (("versionMin", operator.gt), ("versionMax", operator.lt)):
        if key in info:
            bound = tuple(int(part) for part in info[key].split("."))
            bound = (bound + (0, 0, 0))[:3]
            if fails(bound, game):
                raise ValueError(f"{mod_id}: {key}={info[key]} excludes {BASELINES['game_build']}")
    return mod


def digest(path):
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def check(workshop_root, *, reviewed):
    errors = []
    for companion, spec in BASELINES["mods"].items():
        item_id = spec["reviewed_workshop_id"] if reviewed else spec["workshop_id"]
        try:
            upstream = find_mod(workshop_root / item_id, spec["mod_id"])
            original = lua_files(upstream)
            patch = lua_files(ROOT / companion)
        except (OSError, ValueError) as error:
            errors.append(str(error))
            continue

        version = mod_info(version_layer(upstream)).get("modversion", "unlisted version")
        expected = {path.lower() for path in spec["overrides"]}
        actual = original.keys() & patch.keys()
        for path in sorted(expected - actual):
            errors.append(f"{companion}: replacement path missing from companion or Workshop item {item_id}: {path}")
        for path in sorted(actual - expected):
            errors.append(f"{companion}: untracked Lua override in Workshop item {item_id}: {path}")

        for path, baseline in spec["overrides"].items():
            key = path.lower()
            if key not in actual:
                continue
            observed = digest(original[key])
            if observed != baseline:
                errors.append(
                    f"{companion}: upstream drift in {item_id} ({version}): {path}\n"
                    f"  Reviewed SHA-256: {baseline}\n  Current SHA-256:  {observed}\n"
                    f"  Compare {original[key]} with {patch[key]} before updating the baseline."
                )
            else:
                print(f"PASS {item_id} ({version}) -> {companion}: {path} ({observed})")
    return errors


def download(steamcmd):
    steamcmd = steamcmd.resolve()
    ids = [spec["workshop_id"] for spec in BASELINES["mods"].values()]
    command = [str(steamcmd), "+login", "anonymous"]
    for item_id in ids:
        command.extend(["+workshop_download_item", "108600", item_id, "validate"])
    def run():
        result = subprocess.run(
            [*command, "+quit"], cwd=steamcmd.parent, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, errors="replace", timeout=360,
        )
        print(result.stdout, end="")
        return result

    result = run()
    if result.returncode == 7:
        # The Windows bootstrapper can return 7 after updating and relaunching.
        result = run()
    root = steamcmd.parent / "steamapps/workshop/content/108600"
    missing = [
        item_id for item_id in ids
        if f"Success. Downloaded item {item_id} to" not in result.stdout
        or not (root / item_id / "mods").is_dir()
    ]
    if result.returncode or missing:
        raise RuntimeError(f"SteamCMD exit {result.returncode}. Unconfirmed downloads: {', '.join(missing) or 'none'}")
    return root


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--steamcmd", type=Path, help="SteamCMD executable in its own install directory")
    source.add_argument("--workshop-root", type=Path, help="Existing steamapps/workshop/content/108600 directory")
    parser.add_argument("--reviewed", action="store_true", help="Use the reviewed Workshop IDs in a local cache")
    args = parser.parse_args()
    if args.reviewed and args.steamcmd:
        parser.error("--reviewed requires --workshop-root")
    try:
        root = download(args.steamcmd) if args.steamcmd else args.workshop_root.resolve()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Workshop download failed: {error}")
        return 2
    errors = check(root, reviewed=args.reviewed)
    for error in errors:
        print(f"FAIL {error}")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
