"""Tests for generate_locales.existing_translations (keep shipped value on MT failure)."""
from __future__ import annotations

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_locales as g  # noqa: E402


class TestExistingTranslations(unittest.TestCase):
    def test_keeps_real_translation_only(self) -> None:
        en = {"a": "Mobile", "b": {"c": "Web", "d": "Same"}}
        old = {"a": "الجوال", "b": {"c": "Web", "d": "Same"}}
        # Values identical to English carry no translation to keep.
        self.assertEqual(g.existing_translations(en, old), {"Mobile": "الجوال"})

    def test_missing_or_blank_old_values_ignored(self) -> None:
        en = {"a": "One", "b": "Two"}
        self.assertEqual(g.existing_translations(en, {"a": "  "}), {})

    def test_first_value_wins_for_duplicate_source(self) -> None:
        en = {"a": "Open", "b": "Open"}
        self.assertEqual(g.existing_translations(en, {"a": "X", "b": "Y"}), {"Open": "X"})


if __name__ == "__main__":
    unittest.main()
