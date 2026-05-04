"""Tests for scripts.modules._rule_metrics fixture counting."""

from __future__ import annotations

import unittest
from pathlib import Path

from scripts.modules._rule_metrics import (
    _collect_category_rules,
    _compute_rule_instantiation_stats,
    _compute_unit_test_stats,
    _count_fixtures_for_category,
    _get_example_dirs,
    _index_rule_test_files,
    _resolve_test_path,
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


class NestedRuleTestDiscoveryTests(unittest.TestCase):
    """Regression: rule tests live at test/rules/{group}/, not flat at test/.

    A previous bug used a non-recursive glob and reported every nested-only
    category as untested (widget_patterns_avoid_prefer, structure, async,
    bloc, performance). These tests pin the recursive-discovery behavior so
    the gap report cannot silently regress.
    """

    @classmethod
    def setUpClass(cls) -> None:
        cls.root = Path(__file__).resolve().parents[2]
        cls.rules_dir = cls.root / "lib" / "src" / "rules"
        cls.test_dir = cls.root / "test"

    def test_index_finds_nested_rule_tests(self) -> None:
        # Sample five categories whose tests live exclusively under
        # test/rules/<group>/ — the flat glob missed all of these.
        index = _index_rule_test_files(self.test_dir)
        for stem in (
            "structure_rules_test",
            "async_rules_test",
            "bloc_rules_test",
            "performance_rules_test",
            "widget_patterns_rules_test",
        ):
            self.assertIn(stem, index, f"missing nested test: {stem}")
            # Path must actually live under a subdirectory of test/.
            self.assertNotEqual(index[stem].parent, self.test_dir, stem)

    def test_index_excludes_fixture_tests(self) -> None:
        # test/fixtures/ holds synthetic projects whose own *_test.dart files
        # are not rule-category tests; including them risked stem collisions.
        index = _index_rule_test_files(self.test_dir)
        for stem, path in index.items():
            self.assertNotIn(
                "fixtures",
                path.relative_to(self.test_dir).parts,
                f"fixture test leaked into index: {stem} → {path}",
            )

    def test_resolve_uses_alias_for_split_categories(self) -> None:
        # widget_patterns_* sources share one test file via _test_category_alias.
        index = _index_rule_test_files(self.test_dir)
        resolved = _resolve_test_path(
            index, "widget_patterns_avoid_prefer", "widget_patterns",
        )
        self.assertIsNotNone(resolved)
        self.assertEqual(resolved.stem, "widget_patterns_rules_test")

    def test_previously_missing_categories_are_now_tested(self) -> None:
        # End-to-end: the five categories the gap report falsely flagged
        # must each carry a positive test count after the fix.
        _tested, _total, _total_tests, untested = _compute_unit_test_stats(
            self.root, self.rules_dir,
        )
        regression_set = {
            "widget_patterns_avoid_prefer",
            "structure",
            "async",
            "bloc",
            "performance",
        }
        leaked = regression_set & {name for name, _rules in untested}
        self.assertEqual(leaked, set(), f"regression — untested again: {leaked}")

    def test_rule_instantiation_stats_see_nested_files(self) -> None:
        # Both metric paths must agree on which file backs a category.
        # If the recursive index regresses, this count drops sharply.
        ri, total, _missing = _compute_rule_instantiation_stats(
            self.root, self.rules_dir,
        )
        self.assertGreater(ri, 0)
        self.assertEqual(total, len(_collect_category_rules(self.rules_dir)))


if __name__ == "__main__":
    unittest.main()
