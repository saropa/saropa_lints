"""Regression tests: a `## [Unreleased]` mention in CHANGELOG prose is not a section.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

Pins the fix for the v14.0.0 publish-block incident. The publish prompt's own
release note describes the prior behavior by quoting the heading inside a
backtick code-span ("...whether an ``## [Unreleased]`` section exists..."). The
``[Unreleased]`` matchers used an unanchored regex, so they matched that prose
even after the real heading had been renamed to ``## [14.0.0]``. With both a
phantom ``[Unreleased]`` and a real ``[14.0.0]`` "present",
``rename_unreleased_to_version`` raised the bogus "both exist" error, and the
publish loop recovered by bumping to the next patch — corrupting the chosen
version. Real headings always start the line, so anchoring to ``^`` (MULTILINE)
distinguishes a heading from a prose mention.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

# A changelog whose top section is a real release AND whose body mentions the
# `## [Unreleased]` heading inside a bullet's code-span — the exact shape that
# tripped the v14.0.0 publish.
_CHANGELOG_WITH_PROSE_MENTION = (
    "# Changelog\n\n"
    "## [14.0.0]\n\n"
    "A real release overview. "
    "[log](https://example.test/v14.0.0/CHANGELOG.md)\n\n"
    "### Fixed\n\n"
    "- The publish prompt no longer relies on whether an "
    "`## [Unreleased]` section exists; it now takes the higher of the "
    "pubspec default and the latest `## [X.Y.Z]` heading.\n\n"
    "## [13.13.0]\n\n- prior release\n"
)


class TestUnreleasedProseMention(unittest.TestCase):
    """A heading quoted in a bullet must not read as a real section."""

    def setUp(self) -> None:
        from scripts.modules._version_changelog import (
            has_unreleased_section,
            rename_unreleased_to_version,
        )

        self._has_unreleased = has_unreleased_section
        self._rename = rename_unreleased_to_version

    def _write(self, content: str) -> Path:
        fh = tempfile.NamedTemporaryFile(
            "w", suffix=".md", delete=False, encoding="utf-8",
        )
        fh.write(content)
        fh.close()
        return Path(fh.name)

    def test_prose_mention_is_not_an_unreleased_section(self) -> None:
        path = self._write(_CHANGELOG_WITH_PROSE_MENTION)
        self.assertFalse(self._has_unreleased(path))

    def test_rename_does_not_raise_on_prose_mention(self) -> None:
        # No real [Unreleased] heading present, so rename is a no-op (False)
        # rather than the bogus "both [Unreleased] and [14.0.0] exist" raise.
        path = self._write(_CHANGELOG_WITH_PROSE_MENTION)
        self.assertFalse(self._rename(path, "14.0.0"))
        # The prose bullet must survive untouched — the no-op must not rewrite
        # the code-span into a `## [14.0.0]` heading.
        text = path.read_text(encoding="utf-8")
        self.assertIn("`## [Unreleased]` section exists", text)
        self.assertEqual(text.count("## [14.0.0]"), 1)

    def test_real_unreleased_heading_still_renames(self) -> None:
        # Guard against over-anchoring: a genuine line-leading heading must
        # still rename, even when a prose mention also appears in the body.
        path = self._write(
            "# Changelog\n\n"
            "## [Unreleased]\n\n"
            "Overview. [log](https://example.test/v14.0.0/CHANGELOG.md)\n\n"
            "### Fixed\n\n"
            "- references an `## [Unreleased]` mention in prose.\n\n"
            "## [13.13.0]\n\n- prior release\n"
        )
        self.assertTrue(self._has_unreleased(path))
        self.assertTrue(self._rename(path, "14.0.0"))
        text = path.read_text(encoding="utf-8")
        # The heading was renamed; the prose code-span mention is preserved.
        self.assertIn("## [14.0.0]", text)
        self.assertNotIn("## [Unreleased]\n", text)
        self.assertIn("`## [Unreleased]` mention in prose", text)


class TestVersionedUnreleasedSuffix(unittest.TestCase):
    """Headings like ``## [15.1.0] - Unreleased`` are detected and cleaned."""

    def setUp(self) -> None:
        from scripts.modules._version_changelog import (
            has_unreleased_section,
            rename_unreleased_to_version,
        )

        self._has_unreleased = has_unreleased_section
        self._rename = rename_unreleased_to_version

    def _write(self, content: str) -> Path:
        fh = tempfile.NamedTemporaryFile(
            "w", suffix=".md", delete=False, encoding="utf-8",
        )
        fh.write(content)
        fh.close()
        return Path(fh.name)

    def test_versioned_unreleased_detected(self) -> None:
        # ``## [15.1.0] - Unreleased`` counts as an unreleased section.
        path = self._write(
            "# Changelog\n\n"
            "## [15.1.0] - Unreleased\n\n### Added\n\n- stuff\n"
        )
        self.assertTrue(self._has_unreleased(path))

    def test_versioned_unreleased_typo_detected(self) -> None:
        # Common typo "Unreleasted" is also caught.
        path = self._write(
            "# Changelog\n\n"
            "## [15.1.0] - Unreleasted\n\n### Added\n\n- stuff\n"
        )
        self.assertTrue(self._has_unreleased(path))

    def test_rename_strips_unreleased_suffix(self) -> None:
        # When the heading already carries the target version, the suffix
        # is stripped and the function returns True (content changed).
        path = self._write(
            "# Changelog\n\n"
            "## [15.1.0] - Unreleased\n\n### Added\n\n- stuff\n\n"
            "## [15.0.0]\n\n- prior\n"
        )
        result = self._rename(path, "15.1.0")
        self.assertTrue(result)
        text = path.read_text(encoding="utf-8")
        # Suffix is gone, heading is clean.
        self.assertIn("## [15.1.0]", text)
        self.assertNotIn("Unreleased", text)

    def test_rename_strips_suffix_but_keeps_original_version(self) -> None:
        # Heading carries a version different from the publish target —
        # the suffix is stripped but the heading version is NOT changed
        # to the target.  The version mismatch is resolved downstream
        # by ``reconcile_pubspec_changelog_versions``, not here.
        path = self._write(
            "# Changelog\n\n"
            "## [15.1.0] - Unreleased\n\n### Added\n\n- stuff\n\n"
            "## [15.0.0]\n\n- prior\n"
        )
        # Publishing as 15.2.0 — the suffix gets stripped, leaving
        # ``## [15.1.0]`` (not ``## [15.2.0]``).
        result = self._rename(path, "15.2.0")
        self.assertTrue(result)
        text = path.read_text(encoding="utf-8")
        self.assertNotIn("Unreleased", text)
        # Heading stays at the original version — no silent rename.
        self.assertIn("## [15.1.0]", text)
        self.assertNotIn("## [15.2.0]", text)

    def test_case_insensitive_suffix(self) -> None:
        # All-caps variant is also stripped.
        path = self._write(
            "# Changelog\n\n"
            "## [15.1.0] - UNRELEASED\n\n### Added\n\n- stuff\n"
        )
        self.assertTrue(self._has_unreleased(path))
        result = self._rename(path, "15.1.0")
        self.assertTrue(result)
        text = path.read_text(encoding="utf-8")
        self.assertNotIn("UNRELEASED", text)


if __name__ == "__main__":
    unittest.main()
