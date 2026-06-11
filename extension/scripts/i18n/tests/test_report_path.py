"""Tests for the datetime-stamped audit report path helper.

Run from the repo root::

    python extension/scripts/i18n/tests/test_report_path.py

Pins the contract that audit outputs are day-bucketed and second-stamped so
successive runs never overwrite each other: the path must be
``reports/<YYYYMMDD>/<YYYYMMDD_HHMMSS>_<filename>`` and the dated directory must
exist after the call. ``datetime.now`` is stubbed so the assertion is exact and
the test is deterministic (a real clock would make the stamp unpredictable).
"""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import generate_locales as g  # noqa: E402 — path injected above


class TestTimestampedReportPath(unittest.TestCase):
    def test_path_is_day_bucketed_and_second_stamped(self) -> None:
        fixed = datetime(2026, 6, 11, 0, 52, 6)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with mock.patch.object(g, "datetime") as dt:
                dt.now.return_value = fixed
                out = g.timestamped_report_path(root, "i18n_translation_audit.md")
            # Layout the repo convention requires: reports/<day>/<day_HHMMSS>_<name>.
            self.assertEqual(
                out,
                root / "reports" / "20260611" / "20260611_005206_i18n_translation_audit.md",
            )
            # The dated directory must be created so write_audit_report can open the
            # file immediately — a missing parent would raise on the very next call.
            self.assertTrue(out.parent.is_dir())

    def test_filename_suffix_is_preserved(self) -> None:
        # A second report type (the NLLB fallback log) shares the helper; its
        # basename must survive intact so the two outputs stay distinguishable.
        fixed = datetime(2026, 6, 11, 1, 2, 3)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with mock.patch.object(g, "datetime") as dt:
                dt.now.return_value = fixed
                out = g.timestamped_report_path(root, "i18n_nllb_fallbacks.md")
            self.assertEqual(out.name, "20260611_010203_i18n_nllb_fallbacks.md")


if __name__ == "__main__":
    unittest.main()
