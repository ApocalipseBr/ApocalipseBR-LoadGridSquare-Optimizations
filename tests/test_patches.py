import json
import unittest
from pathlib import Path

from lupa.lua51 import LuaRuntime

from scripts.true_swimming import COMPANION, OUTPUT_PATH, PATCH_DIR, patch_source
from tests.compatibility import BASELINES, ROOT, lua_files, mod_info, version_layer
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
                files = lua_files(mod)
                lua = LuaRuntime()
                for name in spec["overrides"]:
                    if companion == COMPANION:
                        self.assertNotIn(name.lower(), files)
                        self.assertEqual(OUTPUT_PATH, Path(companion, layer.name, name))
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

        for spec in sorted(LUA_TESTS.glob("*_spec.lua")):
            if spec.name != "true_swimming_spec.lua":
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

    def test_generation_requires_one_complete_hook(self):
        before = (PATCH_DIR / "orphan-pontoon.before.lua").read_bytes()
        for source in (b"-- missing hook", before.replace(b"sq:getObjects()", b"sq:getSpecialObjects()"),
                       b"-- " + before, before + before):
            with self.subTest(source=source):
                with self.assertRaisesRegex(ValueError, "expected exactly one"):
                    patch_source(source)


if __name__ == "__main__":
    unittest.main()
