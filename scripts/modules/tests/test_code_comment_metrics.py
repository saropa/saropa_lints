"""Unit tests for scripts.modules._code_comment_metrics."""

# Covers Dart/TS/Python comment-line heuristics used by the publish banner metrics.
# Each case pins an edge of the scanner: strings, templates, `${}` holes, tokenization.

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.modules._code_comment_metrics import (
    _dart_comment_lines,
    _python_comment_lines,
    _ts_comment_lines,
    collect_comment_metric_buckets,
)


class TestDartTsCommentLines(unittest.TestCase):
    # Dart and TS share the C-family scanner; TS additionally tracks template/template-expr depth.

    def test_slash_slash_inside_string_not_counted(self) -> None:
        src = "final u = 'http://example.com/foo';\n// real\n"
        lines = _dart_comment_lines(src)
        self.assertIn(2, lines)
        self.assertNotIn(1, lines)

    def test_line_comment_counted(self) -> None:
        src = "// top\nvoid f() {}\n"
        lines = _dart_comment_lines(src)
        self.assertIn(1, lines)

    def test_block_comment_multiline(self) -> None:
        src = "/* a\n b */\nint x;\n"
        lines = _dart_comment_lines(src)
        self.assertIn(1, lines)
        self.assertIn(2, lines)
        self.assertNotIn(3, lines)

    def test_ts_template_hides_slash_slash(self) -> None:
        src = 'const x = `// not a comment\nstill string`;\n// real\n'
        lines = _ts_comment_lines(src)
        self.assertNotIn(1, lines)
        self.assertNotIn(2, lines)
        self.assertIn(3, lines)

    def test_ts_comment_inside_template_expression(self) -> None:
        src = "const y = `${1 // inner\n}`;\n"
        lines = _ts_comment_lines(src)
        self.assertIn(1, lines)


class TestPythonCommentLines(unittest.TestCase):
    # Python uses tokenizer COMMENT tokens so `#` in strings does not inflate coverage.

    def test_hash_comment(self) -> None:
        src = "a = 1  # c\nb = 2\n"
        lines = _python_comment_lines(src)
        self.assertIn(1, lines)
        self.assertNotIn(2, lines)


class TestCollectBuckets(unittest.TestCase):
    # End-to-end: ensure bucket labels appear for a tiny synthetic package tree.

    def test_collect_on_minimal_tree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib").mkdir(parents=True)
            (root / "lib" / "a.dart").write_text("// x\nclass A {}\n", encoding="utf-8")
            (root / "scripts").mkdir(parents=True)
            (root / "scripts" / "t.py").write_text("# y\nx = 1\n", encoding="utf-8")
            buckets = collect_comment_metric_buckets(root)
        labels = {b.label for b in buckets}
        self.assertIn("Dart (lib/)", labels)
        self.assertIn("Python (scripts/)", labels)


if __name__ == "__main__":
    unittest.main()
