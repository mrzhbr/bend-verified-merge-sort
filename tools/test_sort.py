"""Independent runtime checks against Python's exact integer sorting."""

import collections
import itertools
import random
import subprocess
import unittest

from .common import BINARY, PATTERNS, digest, generate, native


class SortTests(unittest.TestCase):
    def check_values(self, values, forks=3, threads=4):
        result = native(["values", forks, *values], threads)
        self.assertEqual(result["values"], sorted(values))
        self.assertEqual(
            collections.Counter(result["values"]), collections.Counter(values)
        )
        self.assertEqual(result["count"], len(values))
        self.assertEqual(result["input_hash"], digest(values))
        self.assertEqual(result["output_hash"], digest(sorted(values)))
        self.assertTrue(result["ordered"])
        return result

    def test_edge_cases_and_duplicate_multiplicities(self):
        cases = [
            [],
            [0],
            [1],
            [2, 1],
            [1, 1],
            [3, 0, 3, 1, 0, 3],
            [4294967295, 0, 4294967295, 1],
            list(range(64)),
            list(range(64, -1, -1)),
            [17] * 65,
        ]
        for values in cases:
            for forks in (0, 3):
                with self.subTest(values=values, forks=forks):
                    self.check_values(values, forks)

    def test_exhaustive_small_lists(self):
        for length in range(5):
            for values in itertools.product(range(3), repeat=length):
                with self.subTest(values=values):
                    self.check_values(list(values))

    def test_random_lists_at_carry_boundaries(self):
        rng = random.Random(42)
        for count in (3, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 257):
            for maximum in (4, 4294967296):
                values = [rng.randrange(maximum) for _ in range(count)]
                with self.subTest(count=count, maximum=maximum):
                    serial = self.check_values(values, 0, 1)
                    parallel = self.check_values(values, 3, 4)
                    self.assertEqual(serial["values"], parallel["values"])

    def test_every_cutoff_changes_only_scheduling(self):
        values = [9, 0, 8, 2, 8, 1, 0, 4, 7, 3, 6, 6, 5]
        for forks in (0, 1, 2, 3, 6, 12):
            with self.subTest(forks=forks):
                self.check_values(values, forks)

    def test_generated_inputs_match_python_for_all_patterns(self):
        for count in (0, 1, 17, 255, 1024):
            for pattern in PATTERNS:
                for seed in (0, 4294967295):
                    with self.subTest(count=count, pattern=pattern, seed=seed):
                        values = generate(count, seed, pattern)
                        result = native(["bench", count, seed, 3, pattern], 4)
                        self.assertEqual(result["count"], count)
                        self.assertEqual(result["input_hash"], digest(values))
                        self.assertEqual(result["output_hash"], digest(sorted(values)))
                        self.assertTrue(result["ordered"])

    def test_invalid_arguments(self):
        cases = [
            ["unknown"],
            ["values"],
            ["values", -1, 3],
            ["values", 13, 3],
            ["values", 0, -1],
            ["values", 0, "4294967296"],
            ["values", 0, "abc"],
            ["bench", -1, 0, 3, "random"],
            ["bench", 1048577, 0, 3, "random"],
            ["bench", 16, -1, 3, "random"],
            ["bench", 16, 0, 13, "random"],
            ["bench", 16, 0, 3, "unknown"],
            ["bench", 16, 0, 3],
            ["bench", 16, 0, 3, "random", "extra"],
        ]
        for args in cases:
            with self.subTest(args=args):
                result = subprocess.run(
                    [str(BINARY), *map(str, args)],
                    check=False,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
