"""Tests for coverage_report: table rendering and README block replacement."""
from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import coverage_report as cr  # noqa: E402

DATA = {
    "generated": "2026-11-20T16:30:49+00:00",
    "locales": {
        "en": {"coveragePct": 100, "missing": 0},
        "de": {"coveragePct": 88, "missing": 279},
        "ar": {"coveragePct": 50, "missing": 600},
    },
}


class TestRender(unittest.TestCase):
    def test_bar_bounds(self) -> None:
        self.assertEqual(cr.bar(0), "░" * 10)
        self.assertEqual(cr.bar(100), "█" * 10)
        self.assertEqual(cr.bar(150), "█" * 10)  # out-of-range input clamps

    def test_overall_excludes_english(self) -> None:
        self.assertEqual(cr.overall_pct(DATA["locales"]), 69)  # (88+50)/2

    def test_markdown_lowest_first_and_no_english_row(self) -> None:
        md = cr.render_markdown(DATA)
        self.assertLess(md.index("`ar`"), md.index("`de`"))
        self.assertNotIn("`en`", md)
        self.assertIn("Overall: 69%", md)


class TestUpdateReadme(unittest.TestCase):
    def _tmp(self, text: str) -> Path:
        d = tempfile.mkdtemp()
        p = Path(d) / "README.md"
        p.write_text(text, encoding="utf-8")
        return p

    def test_replaces_only_marked_block(self) -> None:
        p = self._tmp(f"before\n{cr.START}\nOLD\n{cr.END}\nafter\n")
        self.assertTrue(cr.update_readme(DATA, p))
        out = p.read_text(encoding="utf-8")
        self.assertIn("before", out)
        self.assertIn("after", out)
        self.assertNotIn("OLD", out)
        self.assertIn("`de`", out)

    def test_missing_markers_leaves_file_untouched(self) -> None:
        p = self._tmp("no markers here\n")
        self.assertFalse(cr.update_readme(DATA, p))
        self.assertEqual(p.read_text(encoding="utf-8"), "no markers here\n")

    def test_idempotent(self) -> None:
        p = self._tmp(f"{cr.START}\n{cr.END}\n")
        cr.update_readme(DATA, p)
        first = p.read_text(encoding="utf-8")
        cr.update_readme(DATA, p)
        self.assertEqual(p.read_text(encoding="utf-8"), first)


if __name__ == "__main__":
    unittest.main()
