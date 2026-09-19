"""Tests for the guard against overwriting translations with English."""

from __future__ import annotations

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import generate_locales as g  # noqa: E402


class TestEnglishRegressions(unittest.TestCase):
    def test_detects_overwrite_with_english(self) -> None:
        en = {"a": {"b": "Hello", "c": "Bye"}}
        old = {"a": {"b": "Hallo", "c": "Tschüss"}}
        new = {"a": {"b": "Hello", "c": "Tschüss"}}
        self.assertEqual(g.find_english_regressions(en, old, new), ["a.b"])

    def test_missing_or_identical_old_is_fine(self) -> None:
        en = {"a": "Dart", "b": "Hi"}
        old = {"a": "Dart"}
        new = {"a": "Dart", "b": "Hi"}
        self.assertEqual(g.find_english_regressions(en, old, new), [])


if __name__ == "__main__":
    unittest.main()
