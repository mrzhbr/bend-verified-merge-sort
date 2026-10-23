"""Measure the verified functional merge sort, not a general language speed claim."""

import argparse
import hashlib
import json
import os
import platform
import statistics
import subprocess
import time
from pathlib import Path

from .common import BEND, BINARY, PATTERNS, ROOT, digest, generate, native
from .proof_gate import gate


def measure_native(count, seed, pattern, forks, threads, input_hash, output_hash):
    start = time.perf_counter()
    result = native(["bench", count, seed, forks, pattern], threads)
    process_ms = (time.perf_counter() - start) * 1000
    if (
        result["count"] != count
        or not result["ordered"]
        or result["input_hash"] != input_hash
        or result["output_hash"] != output_hash
    ):
        raise RuntimeError(f"Native output diagnostics diverged: {result}")
    return {
        "sort_ms": result["elapsed_ms"],
        "process_ms": process_ms,
        "input_hash": input_hash,
        "output_hash": output_hash,
    }


def measure_python(values, expected):
    start = time.perf_counter()
    result = sorted(values)
    elapsed = (time.perf_counter() - start) * 1000
    if result != expected:
        raise RuntimeError("Python baseline mismatch")
    return {"sort_ms": elapsed, "output_hash": digest(result)}


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, nargs="+", default=[16384, 65536])
    parser.add_argument(
        "--patterns", nargs="+", choices=PATTERNS, default=list(PATTERNS)
    )
    parser.add_argument("--repeat", type=int, default=3)
    parser.add_argument("--seed", type=int, default=100)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--forks", type=int, default=3)
    parser.add_argument("--bend", type=Path, default=BEND)
    parser.add_argument(
        "--output", type=Path, default=ROOT / "results" / "benchmark.json"
    )
    args = parser.parse_args()
    if any(size < 0 or size > 1048576 for size in args.size):
        parser.error("size must be 0..1048576")
    if args.repeat < 1 or args.threads < 1 or not 0 <= args.forks <= 12:
        parser.error("invalid repeats, threads or fork depth")
    if not 0 <= args.seed <= 4294967296 - args.repeat:
        parser.error("seeds must fit U32")
    return args


def main():
    args = arguments()
    proof = gate(args.bend.resolve())
    print(
        f"Proof gate: {len(proof['laws_checked'])} universal laws checked; 2 broken sorts rejected.",
        flush=True,
    )
    records = []
    summaries = []
    order = ("bend_sequential", "bend_parallel", "python_sorted")
    for count in args.size:
        for pattern in args.patterns:
            # Full-size unmeasured warm-up, including the same validation path.
            warm = generate(count, args.seed, pattern)
            expected = sorted(warm)
            hi, ho = digest(warm), digest(expected)
            measure_native(count, args.seed, pattern, 0, 1, hi, ho)
            measure_native(count, args.seed, pattern, args.forks, args.threads, hi, ho)
            measure_python(warm, expected)
            group = []
            for trial in range(args.repeat):
                seed = args.seed + trial
                values = generate(count, seed, pattern)
                expected = sorted(values)
                hi, ho = digest(values), digest(expected)
                rotated = order[trial % len(order) :] + order[: trial % len(order)]
                for engine in rotated:
                    load = os.getloadavg()
                    if engine == "python_sorted":
                        result = measure_python(values, expected)
                    else:
                        parallel = engine == "bend_parallel"
                        result = measure_native(
                            count,
                            seed,
                            pattern,
                            args.forks if parallel else 0,
                            args.threads if parallel else 1,
                            hi,
                            ho,
                        )
                    row = {
                        "count": count,
                        "pattern": pattern,
                        "seed": seed,
                        "engine": engine,
                        "load_average_before": load,
                        **result,
                    }
                    group.append(row)
                    records.append(row)
            summary = {
                "count": count,
                "pattern": pattern,
                "median_sort_ms": {
                    engine: statistics.median(
                        row["sort_ms"] for row in group if row["engine"] == engine
                    )
                    for engine in order
                },
            }
            summaries.append(summary)
            times = summary["median_sort_ms"]
            print(
                f"n={count:7d} {pattern:10s}: Bend serial {times['bend_sequential']:7.2f} ms, "
                f"Bend parallel {times['bend_parallel']:7.2f} ms, Python sorted {times['python_sorted']:7.2f} ms",
                flush=True,
            )
    artifact = {
        "schema": 1,
        "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "platform": platform.platform(),
        "python_version": platform.python_version(),
        "bend_version": subprocess.check_output(
            [str(args.bend.resolve()), "version"], text=True
        ).strip(),
        "parameters": {
            "sizes": args.size,
            "patterns": args.patterns,
            "repeat": args.repeat,
            "first_seed": args.seed,
            "threads": args.threads,
            "fork_depth": args.forks,
        },
        "method": "Identical U32 input values; generation, diagnostics and proof checks excluded from sort timers. Native timer includes building the run forest; native process_ms additionally includes startup, generation and diagnostics. Python sorted is C Timsort, not the same algorithm. Native uses linked lists/Nat, Python uses lists/int. Native parallel uses additional workers. No isolated-machine or general language superiority claim.",
        "proof_evidence": proof,
        "source_sha256": {
            name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            for name in ("core.bend", "main.bend", "LAWS.bend", "PROOF.bend")
        },
        "binary_sha256": hashlib.sha256(BINARY.read_bytes()).hexdigest(),
        "summary": summaries,
        "runs": records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(artifact, indent=2) + "\n")
    print(f"Saved {args.output}")


if __name__ == "__main__":
    main()
