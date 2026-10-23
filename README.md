# Verified parallel merge sort in Bend 2

A proof-workflow experiment, not another claim that Bend beats Python.
The actual sorter accepts arbitrary lists of natural numbers and uses parallel
recursive merge sort over balanced runs built by binary carrying.

## Run

Inside this folder (or use `make -C sort ...` from its parent):

```sh
make setup       # checksum-verified Bend 2.0.37, installed locally
make test        # universal proofs, deliberately broken implementations, runtime tests
make bench       # matching integer inputs; sequential, parallel and Python sorted

./build/sort --threads 4 values 3 9 3 3 0
# ... "values":[0, 3, 3, 9]
```

Requires macOS/Linux, clang 14+ and Python 3.10+. Python tooling uses only the
standard library. `make build` runs the proof gate before building the binary.
The CLI supports unsigned 32-bit values; generated workloads are limited to
1,048,576 values and fork depths 0–12. The source-level laws are more general:
arbitrary finite `List<Nat>` values and arbitrary natural fork depths.

## What is actually proved?

The public laws in **`LAWS.bend`** state, for **every input list and fork depth**:

1. **Sortedness:** the output is nondecreasing. `From(0, output)` checks each
   adjacent pair using a threaded lower bound; this is not a checksum or sample.
2. **Permutation:** for **every natural number `key`**, its exact occurrence
   count in the output equals its count in the input. This includes duplicates,
   rather than merely checking length, membership or the sum of values.

**`PROOF.bend`** proves the actual implementation through merge, tree, forest
and input-construction lemmas. The 17 claims include the supporting arithmetic
and ordering lemmas. There are no project axioms, proof holes, unsafe recursion,
foreign sort primitives, or sorted-input/balanced-tree preconditions. The
algorithm is 87 lines; its proof definitions occupy 204 lines, plus the law and
predicate declarations. Stability for records/custom keys is not claimed.

The checker accepted the universal proof in about **0.067 seconds** in the
recorded local run. This is one static proof check, not a check per input.

### Does the gate really reject mistakes?

`tools/proof_gate.py` checks the full proof, then copies the three source modules
into temporary folders and tests two mutants without changing the specification:

- Return `[]` for every input. The still-valid sortedness proof is supplied;
  the **permutation law is rejected**.
- Return the input unchanged. The still-valid permutation proof is supplied;
  the **sortedness law is rejected**.

These are failures at the relevant law, not missing-file or syntax failures.
Diagnostics and source fingerprints are in **`results/proof-check.json`**.
Runtime tests additionally compare full outputs with Python, including duplicate
counts, exhaustive small lists, random U32 values, empty lists, carry boundaries,
all input patterns, invalid arguments, and multiple scheduling cutoffs.

### Trust boundary

These are proofs accepted by **Bend 2.0.37's standard checker**, about Bend's
source semantics—not proofs of its compiler, allocator, scheduler or emitted C.
The independent Lean-backed `--verdict` check was attempted but **unavailable**:
Lean v4.34.0 is not installed. See `results/verdict-status.txt`; no Lean
installation was performed. Review the specification itself: proofs only establish
what its definitions and laws actually say.

## Performance observation

At 65,536 values, median sort times over three seeds were:

| Input | Bend, one worker | Bend, four workers | Python `sorted` |
| --- | ---: | ---: | ---: |
| Random | 25 ms | 12 ms | 9.73 ms |
| Many duplicates | 24 ms | 11 ms | 2.88 ms |
| Already sorted | 12 ms | 6 ms | 0.29 ms |

Generation, diagnostics and proof checking are outside these sort timers.
Bend's timer includes constructing its run forest. Input values match exactly;
no Float32/Float64 or different-RNG issue is involved. Native process wall times
are recorded separately and include generation/startup/diagnostics.

This is **not an apples-to-apples language comparison**: Bend uses a linked-list
merge sort; Python uses C Timsort over Python lists and exploits existing runs.
The parallel version also has more workers. Serial construction and upper-level
merges limit parallel scaling. The machine was not reserved for benchmarking.
Raw runs, scopes, source/binary hashes and proof evidence are in
**`results/benchmark.json`**.

## What this says about Bend

The meaningful success is expressing and checking a complete sorting contract,
including the list-to-tree construction and parallel cutoff—not winning against
an established sorting library. A threaded lower-bound predicate kept the merge
proof small. Nested pattern matches made base cases reducible without requiring
unrelated arguments to be known. Structural recursion shaped the carry-forest
design. Proofs are manual: valid implementation changes may still require proof
maintenance; the checker does not invent a new proof automatically.

Start with `core.bend`, the final two laws in `LAWS.bend`, and their proofs at
the end of `PROOF.bend`. `tools/benchmark.py` records the experiment;
`tools/test_sort.py` checks native execution independently.
