"""Generate the True Swimming override by replacing a single upstream hook."""
from pathlib import Path

COMPANION = "ApocalipseBR_TrueSwimming_fix"
LUA_PATH = "media/lua/shared/TrueSwimmingShared.lua"
OUTPUT_PATH = Path(COMPANION, "42", LUA_PATH)
PATCH_DIR = Path(__file__).resolve().parents[1] / "patches/true-swimming"


def patch_source(source):
    before = (PATCH_DIR / "orphan-pontoon.before.lua").read_bytes().replace(b"\r\n", b"\n").rstrip(b"\n")
    after = (PATCH_DIR / "orphan-pontoon.after.lua").read_bytes().replace(b"\r\n", b"\n").rstrip(b"\n")
    matches = []
    for newline in (b"\n", b"\r\n"):
        block = before.replace(b"\n", newline)
        start = source.find(block)
        while start != -1:
            end = start + len(block)
            if (start == 0 or source[start - 1:start] == b"\n") and (
                end == len(source) or source.startswith((b"\n", b"\r\n"), end)
            ):
                matches.append((start, end, newline))
            start = source.find(block, end)

    if len(matches) != 1:
        raise ValueError(
            f"{LUA_PATH}: expected exactly one orphan-pontoon hook, found {len(matches)}. "
            "Review the upstream registration and update patches/true-swimming."
        )
    start, end, newline = matches[0]
    return source[:start] + after.replace(b"\n", newline) + source[end:]
