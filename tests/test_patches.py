import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from lupa.lua51 import LuaRuntime

from scripts.lua_diff import apply_diff, unified_diff
from scripts.true_swimming import PATCH_DIR, patch_source
from tests.compatibility import (
    BASELINES, GENERATED, GENERATED_TESTS, ROOT, generate_companion, lua_files, mod_info, version_layer,
)
from tests.lua_runner import LUA_TESTS, run_lua_spec


class PatchTests(unittest.TestCase):
    def test_override_inventory_and_metadata(self):
        configured = json.loads((ROOT / "project.json").read_text(encoding="utf-8"))["mods"]
        self.assertEqual(configured.keys(), BASELINES["mods"].keys())
        for companion, spec in BASELINES["mods"].items():
            with self.subTest(companion=companion):
                mod = ROOT / companion
                layer = version_layer(mod)
                info = mod_info(layer)
                self.assertEqual(info["id"], companion)
                self.assertEqual(info["require"], configured[companion]["require"])
                self.assertEqual(info["require"], "\\" + spec["mod_id"])
                self.assertEqual(info.get("versionMin"), configured[companion].get("versionMin"))
                self.assertEqual(info.get("loadModAfter"), configured[companion].get("loadModAfter"))
                files = lua_files(mod)
                lua = LuaRuntime()
                for name in spec["overrides"]:
                    if companion in GENERATED:
                        self.assertNotIn(name.lower(), files)
                        if spec["patch_dir"] != "true-swimming":
                            diff = ROOT / "patches" / spec["patch_dir"] / (Path(name).stem + ".patch")
                            self.assertTrue(diff.is_file(), diff)
                        continue
                    self.assertIn(name.lower(), files)
                    file = files[name.lower()]
                    actual_path = file.relative_to(mod).as_posix().split("/", 1)[1]
                    self.assertEqual(actual_path, name)
                for file in files.values():
                    lua.compile(file.read_bytes(), name=file.as_posix())

    def test_lua_behaviors(self):
        def read_patch(companion, path):
            return lua_files(ROOT / companion)[path.lower()].read_bytes()

        build_specs = {name for tests in GENERATED_TESTS.values() for name in tests}
        for spec in sorted(LUA_TESTS.glob("*_spec.lua")):
            if spec.name not in build_specs:
                with self.subTest(spec=spec.name):
                    run_lua_spec(spec.name, read_patch)

    def test_generated_override_preserves_unrelated_bytes(self):
        before = (PATCH_DIR / "orphan-pontoon.before.lua").read_bytes().replace(b"\r\n", b"\n")
        after = (PATCH_DIR / "orphan-pontoon.after.lua").read_bytes().replace(b"\r\n", b"\n")
        prefix = b"-- upstream prefix\r\n"
        suffix = b"-- upstream suffix\n"
        for newline in (b"\n", b"\r\n"):
            with self.subTest(newline=newline):
                source = prefix + before.replace(b"\n", newline) + suffix
                self.assertEqual(patch_source(source), prefix + after.replace(b"\n", newline) + suffix)

    def test_diff_preserves_shifted_context_and_mixed_newlines(self):
        original = b"one\ntwo\nthree\nfour\nfive\n"
        modified = original.replace(b"three\n", b"third\nadded\n")
        patch = unified_diff(original, modified, b"example.lua")
        source = b"shifted\n" + original.replace(b"\n", b"\r\n").replace(b"two\r\n", b"two\n")
        expected = source.replace(b"three\r\n", b"third\r\nadded\r\n")
        self.assertEqual(apply_diff(source, patch), expected)

    def test_diff_rejects_missing_or_ambiguous_context(self):
        original = b"one\ntwo\nthree\n"
        patch = unified_diff(original, b"one\nthree\n", b"example.lua")
        for source in (original.replace(b"two", b"upstream edit"), original * 2):
            with self.subTest(source=source):
                with self.assertRaisesRegex(ValueError, "expected exactly one"):
                    apply_diff(source, patch)

    def test_generation_requires_one_complete_hook(self):
        before = (PATCH_DIR / "orphan-pontoon.before.lua").read_bytes()
        for source in (b"-- missing hook", before.replace(b"sq:getObjects()", b"sq:getSpecialObjects()"),
                       b"-- " + before, before + before):
            with self.subTest(source=source):
                with self.assertRaisesRegex(ValueError, "expected exactly one"):
                    patch_source(source)

    def test_workshop_generation_rejects_broken_context_and_syntax(self):
        companion = "minidoracatbuilderfix"
        path = next(iter(GENERATED[companion]["overrides"]))
        original = b"local legacy = true\nreturn legacy\n"
        with TemporaryDirectory() as directory:
            scratch = Path(directory)
            source = scratch / path
            source.parent.mkdir(parents=True)
            diff = scratch / "patches/minidoracat-builder/Place.patch"
            diff.parent.mkdir(parents=True)
            diff.write_bytes(unified_diff(original, b"local legacy =\nreturn legacy\n", b"Place.lua"))
            inputs = ("Builder test source", {path.lower(): source}, {})
            with patch("tests.compatibility.ROOT", scratch), patch(
                "tests.compatibility.upstream_files", return_value=inputs,
            ), patch("builtins.print"):
                for contents, error in (
                    (original.replace(b"legacy", b"current"), "expected exactly one match, found 0"),
                    (original, "generated Lua failed to compile"),
                ):
                    with self.subTest(error=error):
                        source.write_bytes(contents)
                        with self.assertRaisesRegex(ValueError, error):
                            generate_companion(scratch, companion, reviewed=False)


if __name__ == "__main__":
    unittest.main()
