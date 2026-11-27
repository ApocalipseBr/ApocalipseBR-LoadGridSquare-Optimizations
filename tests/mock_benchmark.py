"""Compare upstream and staged Lua under a fixed mocked streaming workload."""
import json
from pathlib import Path
from statistics import median
from time import perf_counter_ns

from lupa.lua51 import LuaError

from tests.compatibility import BASELINES, ROOT, upstream_files, version_layer
from tests.lua_runner import run_lua_spec

CHUNKS_PER_SAMPLE = 128
SAMPLES = 7
EVENTS = ("square", "chunk", "tick")


def measure(companion, read, patched):
    workload = run_lua_spec(
        "streaming_benchmark.lua", read, restrict=True, arguments=(companion.encode(), patched),
    )
    started = perf_counter_ns()
    counts = workload(CHUNKS_PER_SAMPLE)
    elapsed_ns = perf_counter_ns() - started
    return elapsed_ns, {event: int(counts[event.encode()]) for event in EVENTS}


def collect(workshop, generated, *, reviewed):
    rows = []
    for companion, spec in BASELINES["mods"].items():
        label, original, authored = upstream_files(workshop, companion, spec, reviewed)
        layer = version_layer(ROOT / companion).name

        def read_a(_, path):
            return original[path.lower()].read_bytes()

        def read_b(_, path):
            key = Path(companion, layer, path)
            if key in generated:
                return generated[key]
            return authored[path.lower()].read_bytes()

        timings = {"before": [], "after": []}
        counts = {}
        variants = [("before", read_a, False), ("after", read_b, True)]
        for sample in range(SAMPLES):
            order = variants if sample % 2 == 0 else reversed(variants)
            for side, read, patched in order:
                try:
                    elapsed_ns, counts[side] = measure(companion, read, patched)
                except (LuaError, MemoryError, KeyError) as error:
                    raise ValueError(f"{label}: mocked streaming benchmark ({side}) failed: {error}") from error
                timings[side].append(elapsed_ns)

        row = {"companion": companion, "upstream": label.removeprefix(companion + ": ")}
        for side in timings:
            calls = sum(counts[side].values())
            elapsed_ms = median(timings[side]) / 1_000_000
            row[side] = {
                "calls": counts[side], "total_calls": calls, "samples_ns": timings[side],
                "median_ms_per_chunk": elapsed_ms / CHUNKS_PER_SAMPLE,
                "amortized_ms_per_callback": elapsed_ms / calls if calls else None,
            }
        row["calls_avoided"] = row["before"]["total_calls"] - row["after"]["total_calls"]
        rows.append(row)

    return {
        "runtime": "mocked_lua51", "workload": "warmed_empty_chunk", "chunks_per_sample": CHUNKS_PER_SAMPLE,
        "squares_per_chunk": 64, "samples_per_variant": SAMPLES, "results": rows,
    }


def markdown(report):
    def time(value):
        return "n/a" if value is None else f"{value:.5f}"

    lines = [
        "## Mocked Lua streaming benchmark",
        "",
        f"A uses the Workshop Lua. B uses the package inputs. Each variant runs {report['samples_per_variant']} samples "
        f"of {report['chunks_per_sample']} warmed empty-chunk loads with {report['squares_per_chunk']} squares each.",
        "",
        "| Companion | A square / chunk / tick | B square / chunk / tick | Calls avoided per sample | "
        "A → B ms/chunk | A → B amortized ms/callback |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in report["results"]:
        a, b = row["before"], row["after"]
        before = " / ".join(str(a["calls"][event]) for event in EVENTS)
        after = " / ".join(str(b["calls"][event]) for event in EVENTS)
        lines.append(
            f"| `{row['companion']}` | {before} | {after} | {row['calls_avoided']} | "
            f"{time(a['median_ms_per_chunk'])} → {time(b['median_ms_per_chunk'])} | "
            f"{time(a['amortized_ms_per_callback'])} → {time(b['amortized_ms_per_callback'])} |"
        )
    lines += [
        "", "Call counts are assertions. Timing is the median batch wall time divided by the number of chunks or "
        "tracked callbacks. It includes harness dispatch overhead and is informational. Empty chunks contain no "
        "matching sprites. The test runs in Lua 5.1 with mocked engine APIs. Dedicated-server timing requires a live run.",
    ]
    return "\n".join(lines) + "\n"


def write_report(report, output, step_summary):
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if step_summary:
        with Path(step_summary).open("a", encoding="utf-8") as summary:
            summary.write("\n" + markdown(report))
