import json
import unittest

from lupa.lua51 import LuaRuntime

from compatibility import BASELINES, ROOT, lua_files, mod_info, version_layer

TESTS = ROOT / "tests"


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
                    self.assertIn(name.lower(), files)
                    file = files[name.lower()]
                    actual_path = file.relative_to(mod).as_posix().split("/", 1)[1]
                    self.assertEqual(actual_path, name)
                for file in files.values():
                    lua.compile(file.read_bytes(), name=file.as_posix())

    def test_lua_behaviors(self):
        for spec in sorted((TESTS / "lua").glob("*_spec.lua")):
            with self.subTest(spec=spec.name):
                lua = LuaRuntime(encoding=None, register_eval=False, register_builtins=False)

                def load_patch(companion, path):
                    file = lua_files(ROOT / companion.decode())[path.decode().lower()]
                    return lua.execute(file.read_bytes(), name=file.as_posix().encode())

                lua.globals()[b"load_patch"] = load_patch
                lua.execute((TESTS / "lua/harness.lua").read_bytes())
                lua.execute(spec.read_bytes(), name=spec.name.encode())


if __name__ == "__main__":
    unittest.main()
