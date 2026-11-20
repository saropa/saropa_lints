"""Tests for semantic_check pure logic (no Ollama server needed)."""
from __future__ import annotations

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import semantic_check as sc  # noqa: E402


class TestCosine(unittest.TestCase):
    def test_identical_is_one(self) -> None:
        self.assertAlmostEqual(sc.cosine([1.0, 2.0], [1.0, 2.0]), 1.0)

    def test_orthogonal_is_zero(self) -> None:
        self.assertAlmostEqual(sc.cosine([1.0, 0.0], [0.0, 1.0]), 0.0)

    def test_zero_vector_does_not_raise(self) -> None:
        self.assertEqual(sc.cosine([0.0, 0.0], [1.0, 1.0]), 0.0)


class TestRank(unittest.TestCase):
    def test_lowest_similarity_first(self) -> None:
        pairs = [("a", "good", "gut"), ("b", "bad", "schlecht")]
        # English vectors, then locale vectors: pair a aligned, pair b orthogonal.
        vecs = iter([[[1.0, 0.0], [1.0, 0.0]], [[1.0, 0.0], [0.0, 1.0]]])
        with mock.patch.object(sc, "embed", side_effect=lambda t, m: next(vecs)):
            rows = sc.rank(pairs, "m", 10)
        self.assertEqual([r["key"] for r in rows], ["b", "a"])

    def test_empty_pairs(self) -> None:
        self.assertEqual(sc.rank([], "m", 10), [])


if __name__ == "__main__":
    unittest.main()
