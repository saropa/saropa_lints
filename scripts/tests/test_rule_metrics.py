"""Tests for scripts.modules._rule_metrics fixture counting."""

from __future__ import annotations

import unittest
from pathlib import Path

from scripts.modules._rule_metrics import (
    _collect_category_rules,
    _count_fixtures_for_category,
    _get_example_dirs,
)


class CodeQualityFixtureCountTests(unittest.TestCase):
    """Regression: split code_quality_* categories must not share one fixture total."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.root = Path(__file__).resolve().parents[2]
        cls.rules_dir = cls.root / "lib" / "src" / "rules"
        cls.example_dirs = _get_example_dirs(cls.root)

    def test_code_quality_avoid_matches_disk_intersection(self) -> None:
        fixture_dir = self.root / "example" / "lib" / "code_quality"
        self.assertTrue(
            fixture_dir.is_dir(),
            "expected example/lib/code_quality for code_quality fixtures",
        )
        on_disk = {
            p.stem.replace("_fixture", "")
            for p in fixture_dir.glob("*_fixture.dart")
        }
        cat = next(
            c
            for c in _collect_category_rules(self.rules_dir)
            if c.category == "code_quality_avoid"
        )
        expected = len(on_disk & frozenset(cat.rule_names))
        got = _count_fixtures_for_category(
            self.example_dirs,
            cat.category,
            rule_names=cat.rule_names,
        )
        self.assertEqual(got, expected)

    def test_code_quality_split_counts_are_not_all_identical(self) -> None:
        """Each split file has its own rule list; fixture hits must not collapse."""
        names = (
            "code_quality_avoid",
            "code_quality_prefer",
            "code_quality_control_flow",
            "code_quality_variables",
        )
        by_cat = {
            c.category: c
            for c in _collect_category_rules(self.rules_dir)
            if c.category in names
        }
        self.assertEqual(set(by_cat), set(names))
        counts = [
            _count_fixtures_for_category(
                self.example_dirs,
                by_cat[n].category,
                rule_names=by_cat[n].rule_names,
            )
            for n in names
        ]
        self.assertGreater(len(set(counts)), 1, counts)


if __name__ == "__main__":
    unittest.main()
