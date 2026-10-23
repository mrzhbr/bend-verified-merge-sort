"""Check all universal laws, then require the checker to reject two broken sorts."""

import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import time
from pathlib import Path

from .common import BEND, ROOT

FILES = ("core.bend", "LAWS.bend", "PROOF.bend")


def check(bend, directory):
    return subprocess.run(
        [str(bend), str(directory / "PROOF.bend"), "--check-only"],
        cwd=directory,
        check=False,
        capture_output=True,
        text=True,
        timeout=120,
    )


def gate(bend):
    sources = {name: (ROOT / name).read_text() for name in FILES}
    for name, source in sources.items():
        if "@unsafe" in source or re.search(r"\bdef\s+[\w.]+\?|\?[A-Za-z_]", source):
            raise RuntimeError(f"Unsafe recursion or proof hole in {name}")
    claims = set(re.findall(r"^law (\w+):", sources["LAWS.bend"], re.MULTILINE))
    proofs = set(re.findall(r"^def L\.(\w+)\(", sources["PROOF.bend"], re.MULTILINE))
    if not {"sort_is_sorted", "sort_is_permutation"} <= claims or claims != proofs:
        raise RuntimeError("The law/proof pairs are incomplete")
    started = time.perf_counter()
    result = check(bend, ROOT)
    elapsed = time.perf_counter() - started
    output = result.stdout + result.stderr
    if (
        result.returncode != 0
        or "ALL PROOFS CHECK" not in output
        or "SOME PROOFS FAIL" in output
    ):
        raise RuntimeError(output[-10000:])

    old_sort = "  forest_sort(build(xs), forks)"
    old_sorted = (
        "def L.sort_is_sorted(xs, forks):\n  L.forest_sorted(S.build(xs), forks)"
    )
    old_permutation = (
        "def L.sort_is_permutation(xs, forks, key):\n"
        "  %L.build_count(xs, key) : {L.count(key, S.sort(xs, forks)) == _ : Nat}\n"
        "  L.forest_preserves_count(S.build(xs), forks, key)"
    )
    if (
        sources["core.bend"].count(old_sort) != 1
        or old_sorted not in sources["PROOF.bend"]
        or old_permutation not in sources["PROOF.bend"]
    ):
        raise RuntimeError(
            "Mutation fixtures need updating to match the implementation"
        )
    mutants = [
        (
            "drop_everything",
            "  []",
            old_sorted,
            "def L.sort_is_sorted(xs, forks):\n  Unit{}",
            "sort_is_permutation",
        ),
        (
            "return_unsorted_input",
            "  xs",
            old_permutation,
            "def L.sort_is_permutation(xs, forks, key):\n  {==}",
            "sort_is_sorted",
        ),
    ]
    evidence = []
    for name, replacement, old_proof, new_proof, expected_law in mutants:
        with tempfile.TemporaryDirectory(prefix="bend-sort-proof-") as temp:
            directory = Path(temp)
            for file, text in sources.items():
                if file == "core.bend":
                    text = text.replace(old_sort, replacement)
                elif file == "PROOF.bend":
                    text = text.replace(old_proof, new_proof)
                (directory / file).write_text(text)
            rejected = check(bend, directory)
            diagnostic = rejected.stdout + rejected.stderr
            if (
                rejected.returncode == 0
                or "SOME PROOFS FAIL" not in diagnostic
                or expected_law not in diagnostic
            ):
                raise RuntimeError(
                    f"Mutation {name} was not rejected at {expected_law}:\n{diagnostic}"
                )
            evidence.append(
                {
                    "mutation": name,
                    "rejected": True,
                    "failing_law": expected_law,
                    "diagnostic": diagnostic[-5000:],
                }
            )
    return {
        "checker": "Bend 2.0.37 standard checker; not independent --verdict kernel",
        "laws_checked": sorted(claims),
        "universal_check_seconds": elapsed,
        "source_sha256": {
            name: hashlib.sha256(source.encode()).hexdigest()
            for name, source in sources.items()
        },
        "mutations": evidence,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bend", type=Path, default=BEND)
    parser.add_argument("--record", type=Path)
    args = parser.parse_args()
    evidence = gate(args.bend.resolve())
    print(
        f"All {len(evidence['laws_checked'])} laws check; both incorrect implementations rejected."
    )
    if args.record is not None:
        args.record.parent.mkdir(parents=True, exist_ok=True)
        args.record.write_text(json.dumps(evidence, indent=2) + "\n")
        print(f"Saved {args.record}")


if __name__ == "__main__":
    main()
