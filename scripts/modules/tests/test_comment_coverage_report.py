"""Tests for scripts.modules._comment_coverage_report."""
# Unit tests for per-file comment stats, progress bar formatting, and collect_per_file_comment_stats.

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.modules._comment_coverage_report import (
    FileCommentStat,
    _format_progress_bar,
    collect_per_file_comment_stats,
)


class TestCommentCoverageReport(unittest.TestCase):
    def test_format_progress_bar_edges(self) -> None:
        self.assertIn("100.0%", _format_progress_bar(10, 10))
        self.assertIn("0.0%", _format_progress_bar(0, 10))
        self.assertTrue(_format_progress_bar(0, 0).endswith("0%"))

    def test_file_comment_stat_ratio(self) -> None:
        s = FileCommentStat(rel_path="a.dart", physical_lines=100, comment_line_count=10)
        self.assertAlmostEqual(s.ratio, 0.1)

    def test_collect_per_file_comment_stats_smoke(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib").mkdir(parents=True)
            body = "\n".join([f"// line {i}" for i in range(10)]) + "\n" + "\n".join(
                [f"final x{i} = {i};" for i in range(10)],
            )
            (root / "lib" / "sample.dart").write_text(body + "\n", encoding="utf-8")
            stats = collect_per_file_comment_stats(
                root,
                min_physical_lines=15,
                exclude_fixture_subdir=True,
                progress_to_stderr=False,
            )
            rels = {s.rel_path for s in stats}
            self.assertIn("lib/sample.dart", rels)
            sample = next(s for s in stats if s.rel_path == "lib/sample.dart")
            self.assertGreaterEqual(sample.comment_line_count, 10)
