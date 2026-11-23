from pathlib import Path

from lupa.lua51 import LuaRuntime

LUA_TESTS = Path(__file__).resolve().parent / "lua"


def run_lua_spec(spec, read_patch, *, restrict=False):
    lua = LuaRuntime(encoding=None, register_eval=False, register_builtins=False, max_memory=32 * 1024 * 1024)
    if restrict:
        # The fixture exposes mocked game APIs. Downloaded Lua gets no OS,
        # Python or module-loader access, and has a VM instruction budget.
        lua.execute(b"""
            debug.sethook(function() error("Lua fixture instruction budget exceeded") end, "", 1000000)
            os, io, debug, package, python, require, module = nil, nil, nil, nil, nil, nil, nil
            dofile, loadfile, load, loadstring, setfenv, getfenv, collectgarbage = nil, nil, nil, nil, nil, nil, nil
        """)

    def load_patch(companion, path):
        name = companion + b"/" + path
        source = read_patch(companion.decode(), path.decode())
        return lua.execute(source, name=b"@" + name, mode="t")

    lua.execute((LUA_TESTS / "harness.lua").read_bytes())
    # The trusted spec can load several files. Source chunks never see the Python loader.
    lua.execute(b"local load_patch = ...\n" + (LUA_TESTS / spec).read_bytes(), load_patch, name=spec.encode())
