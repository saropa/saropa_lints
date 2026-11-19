"""Tests for _parse_failed_test_files (publish retry targets)."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path


class TestParseFailedTestFiles(unittest.TestCase):
    def test_parses_failures_dedupes_and_skips_missing(self) -> None:
        from scripts.modules._publish_steps import _parse_failed_test_files

        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "test").mkdir()
            (root / "test" / "a_test.dart").write_text("")
            (root / "test" / "b_test.dart").write_text("")
            log = root / "log.txt"
            log.write_text(
                "09:37 +5 -1: test/a_test.dart: foo [E]\n"
                "09:38 +6 -1: test/b_test.dart: passing test\n"
                "\nFailing tests:\n"
                "  test/a_test.dart: foo\n"
                "  test/gone_test.dart: bar\n"
                "\nother\n",
                encoding="utf-8",
            )
            self.assertEqual(
                _parse_failed_test_files(log, root), ["test/a_test.dart"],
            )

    def test_no_failures_returns_empty(self) -> None:
        from scripts.modules._publish_steps import _parse_failed_test_files

        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / "log.txt"
            log.write_text("crash\n")
            self.assertEqual(_parse_failed_test_files(log, Path(d)), [])


    def test_aggregate_lines_map_to_originals(self) -> None:
        from scripts.modules._publish_steps import _parse_failed_test_files

        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "test" / "rules" / "core").mkdir(parents=True)
            (root / "test" / "aggregate").mkdir()
            (root / "test" / "rules" / "core" / "foo_test.dart").write_text("")
            (root / "test" / "rules" / "bar_test.dart").write_text("")
            (root / "test" / "aggregate" / "x_aggregate.dart").write_text("")
            log = root / "log.txt"
            log.write_text(
                "09:37 +5 -1: test/aggregate/x_aggregate.dart: "
                "test/rules/core/foo_test.dart my test [E]\n"
                "\nFailing tests:\n"
                "  test/aggregate/x_aggregate.dart: test/rules/core/foo_test.dart my test\n"
                "  test/aggregate/x_aggregate.dart: test/rules/bar_test.dart other\n"
                "  test/aggregate/x_aggregate.dart: no group path here\n"
                "\nother\n",
                encoding="utf-8",
            )
            self.assertEqual(
                _parse_failed_test_files(log, root),
                ["test/rules/core/foo_test.dart", "test/rules/bar_test.dart"],
            )


class TestAggregateTargets(unittest.TestCase):
    def test_builds_targets_from_manifest(self) -> None:
        from scripts.modules._publish_steps import _aggregate_targets

        manifest = {
            "aggregates": {
                "a_aggregate.dart": ["test/rules/x_test.dart"],
                "b_aggregate.dart": ["test/rules/y_test.dart"],
            },
            "left_out": ["test/cli/z_test.dart"],
            "counts": {"test/rules/x_test.dart": 3},
        }
        self.assertEqual(
            _aggregate_targets(manifest),
            [
                "test/aggregate/a_aggregate.dart",
                "test/aggregate/b_aggregate.dart",
                "test/cli/z_test.dart",
            ],
        )


if __name__ == "__main__":
    unittest.main()
