"""Regression tests for tier-integrity rule name extraction.

Run from repository root::

    python -m unittest discover -s scripts/tests -t . -v
"""

from __future__ import annotations

import unittest
from pathlib import Path

# Repo root (parent of scripts/)
_ROOT = Path(__file__).resolve().parents[2]


class TestFindLintRuleClassStart(unittest.TestCase):
    """``_find_lint_rule_class_start`` must accept common declaration shapes."""

    def setUp(self) -> None:
        from scripts.modules import _tier_integrity as ti

        self._find = ti._find_lint_rule_class_start

    def test_same_line_extends(self) -> None:
        src = "class FooRule extends Bar {\n  static const LintCode _code = LintCode(\n"
        self.assertEqual(self._find(src, "FooRule"), 0)

    def test_multiline_extends(self) -> None:
        src = (
            "class FooRule\n    extends Bar {\n"
            "  static const LintCode _code = LintCode(\n"
        )
        self.assertEqual(self._find(src, "FooRule"), 0)

    def test_substring_class_name_not_matched(self) -> None:
        src = "class FooRuleExtra extends Bar {"
        self.assertEqual(self._find(src, "FooRule"), -1)


class TestGetRegisteredRuleNames(unittest.TestCase):
    """Live repo: NoSuchMethod migration rule must map from factory to LintCode."""

    def test_nosuchmethod_default_constructor_registered(self) -> None:
        from scripts.modules._tier_integrity import get_registered_rule_names

        names = get_registered_rule_names(
            _ROOT / "lib" / "saropa_lints.dart",
            _ROOT / "lib" / "src" / "rules",
        )
        self.assertIn(
            "avoid_removed_nosuchmethoderror_default_constructor",
            names,
        )


class TestTierIntegritySmoke(unittest.TestCase):
    """Full tier integrity gate used by ``scripts/publish.py``."""

    def test_check_tier_integrity_passes(self) -> None:
        from scripts.modules._tier_integrity import check_tier_integrity

        result = check_tier_integrity(
            _ROOT / "lib" / "src" / "rules",
            _ROOT / "lib" / "src" / "tiers.dart",
            _ROOT / "lib" / "saropa_lints.dart",
        )
        self.assertTrue(
            result.passed,
            msg=(
                f"phantoms={result.phantom_rules!r} "
                f"orphans={result.orphan_rules!r} "
                f"multi={result.multi_tier_rules!r}"
            ),
        )


if __name__ == "__main__":
    unittest.main()
