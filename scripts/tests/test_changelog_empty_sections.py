"""Regression tests for empty-version-section detection in CHANGELOG.md.

Run from repository root::

    python -m unittest discover -s scripts/tests -t . -v

These tests pin the guard added to prevent the v13.4.2 silent-skip
incident from recurring (commit 0c5950aa wrote an empty ``## [13.4.2]``
stub; the v13.4.3 publish caught a rename collision in
``apply_version_and_rename_unreleased`` and silently jumped past 13.4.2).
"""

from __future__ import annotations

import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


class TestFindEmptyVersionSections(unittest.TestCase):
    """Pin the contract of ``find_empty_version_sections``."""

    def setUp(self) -> None:
        from scripts.modules._version_changelog import (
            find_empty_version_sections,
        )

        self._find = find_empty_version_sections

    def _write(self, content: str) -> Path:
        fh = tempfile.NamedTemporaryFile(
            "w", suffix=".md", delete=False, encoding="utf-8",
        )
        fh.write(content)
        fh.close()
        return Path(fh.name)

    def test_empty_stub_between_real_sections_is_flagged(self) -> None:
        # The exact shape that caused the v13.4.2 skip: heading followed
        # only by `---` separator and blank lines.
        path = self._write(
            "## [13.4.3]\n\nReal content here.\n\n---\n\n"
            "## [13.4.2]\n\n---\n\n"
            "## [13.4.1]\n\nAlso real.\n"
        )
        self.assertEqual(self._find(path), ["13.4.2"])

    def test_unreleased_empty_is_not_flagged(self) -> None:
        # An empty ``## [Unreleased]`` is the normal post-release state
        # and must NEVER trip the guard — only ``## [X.Y.Z]`` headings do.
        path = self._write(
            "## [Unreleased]\n\n---\n\n"
            "## [13.4.3]\n\nContent.\n"
        )
        self.assertEqual(self._find(path), [])

    def test_section_with_only_a_paragraph_is_not_flagged(self) -> None:
        # Prose alone (no `### Added/Fixed`) still counts as content;
        # the guard's job is to catch *truly* empty sections, not to
        # police section structure.
        path = self._write("## [13.4.1]\n\nA short prose summary.\n")
        self.assertEqual(self._find(path), [])

    def test_section_with_only_separator_lines_is_flagged(self) -> None:
        # Multiple ``---`` separators with no other content is still
        # empty — separators are noise, not body.
        path = self._write(
            "## [9.9.9]\n\n---\n\n---\n\n"
            "## [9.9.8]\n\nReal.\n"
        )
        self.assertEqual(self._find(path), ["9.9.9"])

    def test_multiple_empty_sections_all_returned(self) -> None:
        # If two stubs slipped in (e.g. two skipped publishes), both
        # must be reported so the author fixes them in one pass.
        path = self._write(
            "## [3.0.0]\n\n---\n\n"
            "## [2.0.0]\n\n---\n\n"
            "## [1.0.0]\n\nReal.\n"
        )
        self.assertEqual(self._find(path), ["3.0.0", "2.0.0"])

    def test_real_project_changelog_has_no_empty_sections(self) -> None:
        # Sanity check against the actual repo state — if this fails,
        # someone reintroduced an orphan stub and publish would abort.
        repo_root = Path(__file__).resolve().parents[2]
        self.assertEqual(self._find(repo_root / "CHANGELOG.md"), [])


class TestAssertNoEmptyChangelogSections(unittest.TestCase):
    """Pin the abort behavior of the assert wrapper."""

    def setUp(self) -> None:
        from scripts.modules._version_changelog import (
            assert_no_empty_changelog_sections,
        )

        self._assert = assert_no_empty_changelog_sections

    def _write(self, content: str) -> Path:
        fh = tempfile.NamedTemporaryFile(
            "w", suffix=".md", delete=False, encoding="utf-8",
        )
        fh.write(content)
        fh.close()
        return Path(fh.name)

    def test_clean_changelog_returns_silently(self) -> None:
        path = self._write("## [13.4.3]\n\nContent.\n")
        # Returns None on success — should not raise / exit.
        self.assertIsNone(self._assert(path))

    def test_empty_stub_calls_exit_with_error(self) -> None:
        # ``exit_with_error`` calls ``sys.exit`` which raises SystemExit;
        # the assert's contract is to abort the publish, not return.
        # ``print_warning`` writes the ``⚠`` glyph (U+26A0); on Windows
        # the default cp1252 stdout encoding raises UnicodeEncodeError
        # before the SystemExit fires. Redirect stdout to an in-memory
        # UTF-8 buffer so we exercise the abort contract, not the
        # platform's console codec.
        path = self._write(
            "## [13.4.3]\n\nReal.\n\n---\n\n"
            "## [13.4.2]\n\n---\n\n"
            "## [13.4.1]\n\nAlso real.\n"
        )
        with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit):
            self._assert(path)


if __name__ == "__main__":
    unittest.main()
