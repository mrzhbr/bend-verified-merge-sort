"""Identical U32 inputs and diagnostics for native Bend and Python."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "build" / "sort"
BEND = ROOT / ".tools" / "bend" / "bin" / "bend"
MASK = (1 << 32) - 1
PATTERNS = ("random", "sorted", "reverse", "duplicates", "equal")


def generate(count, seed, pattern):
    state = seed | 1
    values = []
    for index in range(count):
        state ^= (state << 13) & MASK
        state ^= state >> 17
        state = (state ^ ((state << 5) & MASK)) & MASK
        if pattern == "random":
            value = state
        elif pattern == "sorted":
            value = index
        elif pattern == "reverse":
            value = count - 1 - index
        elif pattern == "duplicates":
            value = state % 16
        elif pattern == "equal":
            value = 17
        else:
            raise ValueError(f"Unknown pattern: {pattern}")
        values.append(value)
    return values


def digest(values):
    state = 2166136261
    for value in values:
        state = ((state ^ value) * 16777619) & MASK
    return state


def native(args, threads=1):
    result = subprocess.run(
        [str(BINARY), "--threads", str(threads), *map(str, args)],
        check=True,
        capture_output=True,
        text=True,
        timeout=120,
    )
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"Invalid native JSON: {result.stdout!r}") from error
