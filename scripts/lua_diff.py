"""Generate and apply exact, line-based unified diffs for Workshop Lua."""
import argparse
import difflib
import re
from pathlib import Path


def unified_diff(original, modified, name):
    def lines(source):
        source = source.replace(b"\r\n", b"\n")
        if not source.endswith(b"\n"):
            raise ValueError("Expected a final newline in both Lua files")
        return source.splitlines(keepends=True)

    return b"".join(difflib.diff_bytes(
        difflib.unified_diff, lines(original), lines(modified),
        fromfile=b"a/" + name, tofile=b"b/" + name,
    ))


def apply_diff(source, patch):
    lines = patch.replace(b"\r\n", b"\n").splitlines(keepends=True)
    if len(lines) < 3 or not lines[0].startswith(b"--- ") or not lines[1].startswith(b"+++ "):
        raise ValueError("Expected a unified diff for one Lua file")

    original = source.splitlines(keepends=True)
    normalized = source.replace(b"\r\n", b"\n")
    result = []
    cursor = 0
    index = 2
    while index < len(lines):
        header = lines[index].rstrip(b"\n")
        counts = re.fullmatch(rb"@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@.*", header)
        if counts is None:
            raise ValueError(f"Invalid hunk header {header!r}")
        index += 1
        start = index
        while index < len(lines) and lines[index].startswith((b" ", b"-", b"+")):
            index += 1
        hunk = lines[start:index]
        before = [line[1:] for line in hunk if line[:1] != b"+"]
        after = [line[1:] for line in hunk if line[:1] != b"-"]
        if not before or [len(before), len(after)] != [int(count or b"1") for count in counts.groups()]:
            raise ValueError(f"Invalid context or line counts in {header.decode()}")

        # Resolve hunks against the original bytes. Line numbers are only hints.
        matches = list(re.finditer(rb"(?m)(?=^" + re.escape(b"".join(before)) + rb")", normalized))
        if len(matches) != 1:
            raise ValueError(f"{header.decode()}: expected exactly one match, found {len(matches)}")
        position = normalized.count(b"\n", 0, matches[0].start())
        if position < cursor:
            raise ValueError(f"{header.decode()}: hunks overlap or are out of order")

        result.extend(original[cursor:position])
        for line in hunk:
            kind = line[:1]
            if kind == b"+":
                neighbor = original[min(position, len(original) - 1)]
                newline = b"\r\n" if neighbor.endswith(b"\r\n") else b"\n"
                result.append(line[1:-1] + newline)
            else:
                if kind == b" ":
                    result.append(original[position])
                position += 1
        cursor = position
    result.extend(original[cursor:])
    return b"".join(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", type=Path)
    parser.add_argument("modified", type=Path)
    parser.add_argument("patch", type=Path)
    args = parser.parse_args()
    patch = unified_diff(args.original.read_bytes(), args.modified.read_bytes(), args.original.name.encode())
    if not patch:
        parser.error("The Lua files are identical")
    args.patch.write_bytes(patch)


if __name__ == "__main__":
    main()
