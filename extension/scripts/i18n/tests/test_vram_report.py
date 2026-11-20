"""Tests for vram_report parsing and formatting (positive + degenerate cases)."""
from __future__ import annotations

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import vram_report as v  # noqa: E402


class TestVram(unittest.TestCase):
    def test_parse_sums_by_name_and_drops_small(self) -> None:
        raw = ('[{"name":"Code","pid":1,"mb":400},{"name":"Code","pid":2,"mb":300},'
               '{"name":"tiny","pid":3,"mb":20}]')
        self.assertEqual(v.parse_apps(raw), {"code": 700})

    def test_parse_single_object_and_garbage(self) -> None:
        self.assertEqual(v.parse_apps('{"name":"firefox","pid":1,"mb":500}'), {"firefox": 500})
        self.assertEqual(v.parse_apps("not json"), {})
        self.assertEqual(v.parse_apps(""), {})

    def test_report_lists_largest_first_with_tip(self) -> None:
        lines = v.format_report(7300, 8192, {"firefox": 500, "code": 900})
        self.assertIn("892 MB free", lines[0])
        self.assertIn("code: 900", lines[1])
        self.assertIn("disable-hardware-acceleration", lines[2])
        self.assertIn("firefox: 500", lines[3])

    def test_overcommit_note_only_when_sum_exceeds_total(self) -> None:
        over = v.format_report(7000, 8192, {"chrome": 5000, "llama-server": 5500})
        self.assertTrue(any("note:" in l for l in over))
        under = v.format_report(7000, 8192, {"chrome": 500})
        self.assertFalse(any("note:" in l for l in under))


if __name__ == "__main__":
    unittest.main()
