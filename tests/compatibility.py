"""Check the Build 42 Lua files that the companions shadow."""
import argparse
import hashlib
import json
import operator
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINES = json.loads((ROOT / "tests/workshop-baselines.json").read_text(encoding="utf-8"))

if __package__ in ("", None):
    sys.path.insert(0, str(ROOT))
from scripts.lua_diff import apply_diff
from scripts.true_swimming import COMPANION as SWIMMING, patch_source

GENERATED = {
    companion: spec for companion, spec in BASELINES["mods"].items() if "patch_dir" in spec
}
GENERATED_TESTS = {
    SWIMMING: ("true_swimming_spec.lua", "true_swimming_dock.lua"),
    "minidoracatbuilderfix": ("builder_spec.lua",),
    "apocalipsebr_basementdig_fix": ("basement_spec.lua", "expansion_spec.lua"),
}


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


def upstream_files(workshop_root, companion, spec, reviewed):
    item_id = spec["reviewed_workshop_id"] if reviewed else spec["workshop_id"]
    upstream = find_mod(workshop_root / item_id, spec["mod_id"])
    version = mod_info(version_layer(upstream)).get("modversion", "unlisted version")
    label = f"{companion}: Workshop item {item_id} ({version})"
    original = lua_files(upstream)
    authored = lua_files(ROOT / companion)
    expected = {path.lower() for path in spec["overrides"]}
    collisions = original.keys() & authored.keys()
    if companion not in GENERATED:
        missing = expected - collisions
        if missing:
            raise ValueError(f"{label}: missing replacement paths: {', '.join(sorted(missing))}")
        collisions -= expected
    if collisions:
        raise ValueError(f"{label}: unexpected authored overrides: {', '.join(sorted(collisions))}")
    return label, original, authored


def generate_companion(workshop_root, companion, *, reviewed):
    from lupa.lua51 import LuaError, LuaRuntime
    from tests.lua_runner import run_lua_spec

    spec = GENERATED[companion]
    label, original, authored = upstream_files(workshop_root, companion, spec, reviewed)
    generated = {}
    compiler = LuaRuntime(encoding=None, register_eval=False, register_builtins=False, max_memory=32 * 1024 * 1024)
    for path, baseline in spec["overrides"].items():
        file = original.get(path.lower())
        if file is None or not file.as_posix().endswith("/" + path):
            raise ValueError(f"{label}: missing exact upstream path {path}")
        source = file.read_bytes()
        observed = hashlib.sha256(source.replace(b"\r\n", b"\n")).hexdigest()
        print(f"SOURCE {label}: {path} SHA-256 {observed}")
        if observed != baseline:
            print(f"INFO {label}: {path} differs from reviewed SHA-256 {baseline}")
        try:
            if companion == SWIMMING:
                generated[path] = patch_source(source)
            else:
                patch = ROOT / "patches" / spec["patch_dir"] / (Path(path).stem + ".patch")
                generated[path] = apply_diff(source, patch.read_bytes())
        except (OSError, ValueError) as error:
            raise ValueError(f"{label}: {path}: {error}. Review patches/{spec['patch_dir']}.") from error
        try:
            compiler.compile(generated[path], name=path.encode(), mode="t")
        except (LuaError, MemoryError) as error:
            raise ValueError(f"{label}: {path}: generated Lua failed to compile: {error}") from error

    def read_patch(requested_companion, path):
        if requested_companion != companion:
            raise ValueError(f"Unexpected Lua fixture request: {requested_companion}/{path}")
        if path in generated:
            return generated[path]
        return authored[path.lower()].read_bytes()

    for test in GENERATED_TESTS[companion]:
        try:
            run_lua_spec(test, read_patch, restrict=True)
        except (LuaError, MemoryError) as error:
            raise ValueError(f"{label}: {test} failed on generated Lua: {error}") from error
        print(f"PASS {label}: {test}")

    print(f"PASS {label}: generated and tested {len(generated)} Lua override(s)")
    return {Path(companion, version_layer(ROOT / companion).name, path): source for path, source in generated.items()}


def check(workshop_root, *, reviewed, companions=None):
    errors = []
    for companion in companions if companions is not None else BASELINES["mods"]:
        spec = BASELINES["mods"][companion]
        try:
            if companion in GENERATED:
                generate_companion(workshop_root, companion, reviewed=reviewed)
                continue
            label, original, authored = upstream_files(workshop_root, companion, spec, reviewed)
        except (OSError, ValueError) as error:
            errors.append(str(error))
            continue

        for path, baseline in spec["overrides"].items():
            key = path.lower()
            observed = digest(original[key])
            if observed != baseline:
                errors.append(
                    f"{label}: upstream drift in {path}\n"
                    f"  Reviewed SHA-256: {baseline}\n  Current SHA-256:  {observed}\n"
                    f"  Compare {original[key]} with {authored[key]} before updating the baseline."
                )
            else:
                print(f"PASS {label}: {path} ({observed})")
    return errors


def download(steamcmd, *, ids=None):
    steamcmd = steamcmd.resolve()
    if ids is None:
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
