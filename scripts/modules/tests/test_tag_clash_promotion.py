"""Regression tests for tag-clash CHANGELOG promotion.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

These tests pin the fix for the v13.11.9 incident: when ``v{X.Y.Z}`` was
already on the remote, the publish script used to insert a meaningless
``## [X.Y.Z+1]`` stub with body ``"Release version"`` at the auto-archive
insertion point — so the `.vsix` filename advanced to ``saropa-lints-X.Y.Z+1``
while the top CHANGELOG section still read ``[X.Y.Z]`` (with the real notes)
AND a stranded ``[X.Y.Z+1] = "Release version"`` stub sat past the archive
boundary. Marketplace and pub.dev consumers then saw release notes that did
not match the version they installed.

The fix renames the existing top section so the published version, `.vsix`
filename, and top CHANGELOG section stay in lockstep; or aborts when the top
section is something the script cannot safely repurpose.
"""

from __future__ import annotations

import re
import tempfile
import unittest
from pathlib import Path


class TestPromoteTopSectionToVersion(unittest.TestCase):
    """Pin the contract of ``_promote_top_section_to_version``."""

    def setUp(self) -> None:
        from scripts.modules._version_changelog import (
            _promote_top_section_to_version,
        )

        self._promote = _promote_top_section_to_version

    def _write(self, content: str) -> Path:
        fh = tempfile.NamedTemporaryFile(
            "w", suffix=".md", delete=False, encoding="utf-8",
        )
        fh.write(content)
        fh.close()
        return Path(fh.name)

    def _top_heading(self, path: Path) -> str | None:
        match = re.search(
            r"^## \[([^\]]+)\]", path.read_text(encoding="utf-8"), re.MULTILINE,
        )
        return match.group(1) if match else None

    def test_renames_top_section_matching_colliding_version(self) -> None:
        # The exact shape of the v13.11.9 incident: pubspec at 13.11.8, tag
        # v13.11.8 on remote, top CHANGELOG section is [13.11.8] with new
        # post-release fix content authored under the wrong heading.
        path = self._write(
            "# Changelog\n\n"
            "## [13.11.8]\n\n### Fixed\n\n- avoid_nullable_interpolation fix\n\n"
            "## [13.11.7]\n\n- prior release\n"
        )
        result = self._promote(path, "13.11.8", "13.11.9")
        self.assertEqual(result, "13.11.8")
        self.assertEqual(self._top_heading(path), "13.11.9")
        # Body must travel with the rename — otherwise the .vsix ships with
        # the stub problem all over again.
        self.assertIn(
            "avoid_nullable_interpolation fix",
            path.read_text(encoding="utf-8"),
        )

    def test_renames_top_section_when_unreleased(self) -> None:
        # The normal happy path: notes were authored under [Unreleased] and
        # the bump should publish them.
        path = self._write(
            "# Changelog\n\n"
            "## [Unreleased]\n\n### Added\n\n- new rule foo\n\n"
            "## [13.11.7]\n\n- prior\n"
        )
        result = self._promote(path, "13.11.8", "13.11.9")
        self.assertEqual(result, "Unreleased")
        self.assertEqual(self._top_heading(path), "13.11.9")

    def test_refuses_when_top_section_is_unrelated_version(self) -> None:
        # A future / hand-edited heading: script must not silently bury it.
        path = self._write(
            "# Changelog\n\n## [14.0.0]\n\n- pre-released major\n"
        )
        result = self._promote(path, "13.11.8", "13.11.9")
        self.assertIsNone(result)
        # File must be left untouched on refusal — caller aborts.
        self.assertEqual(self._top_heading(path), "14.0.0")

    def test_refuses_when_target_version_already_exists(self) -> None:
        # Duplicate-section guard: never merge two histories under one heading.
        path = self._write(
            "# Changelog\n\n"
            "## [13.11.9]\n\n- already documented\n\n"
            "## [13.11.8]\n\n- prior\n"
        )
        result = self._promote(path, "13.11.8", "13.11.9")
        self.assertIsNone(result)

    def test_strips_unreleased_suffix_from_versioned_heading(self) -> None:
        # ``## [15.1.0] - Unreleased`` should be treated as ``## [15.1.0]``,
        # promoted to next_version, and the suffix must not survive in output.
        path = self._write(
            "# Changelog\n\n"
            "## [13.11.8] - Unreleased\n\n### Added\n\n- new stuff\n\n"
            "## [13.11.7]\n\n- prior\n"
        )
        result = self._promote(path, "13.11.8", "13.11.9")
        self.assertEqual(result, "13.11.8")
        self.assertEqual(self._top_heading(path), "13.11.9")
        # The suffix must be fully stripped from the written file.
        content = path.read_text(encoding="utf-8")
        self.assertNotIn("Unreleased", content)
        self.assertIn("new stuff", content)

    def test_strips_unreleased_typo_suffix(self) -> None:
        # Covers a common typo: "Unreleasted" instead of "Unreleased".
        path = self._write(
            "# Changelog\n\n"
            "## [13.11.8] - Unreleasted\n\n### Fixed\n\n- typo test\n\n"
            "## [13.11.7]\n\n- prior\n"
        )
        result = self._promote(path, "13.11.8", "13.11.9")
        self.assertEqual(result, "13.11.8")
        content = path.read_text(encoding="utf-8")
        self.assertNotIn("Unreleasted", content)

    def test_ignores_heading_example_in_leading_doc_comment(self) -> None:
        # 2026-09-04 incident: this repo's real CHANGELOG.md carries a
        # maintenance doc-comment above the first release describing the
        # heading convention with literal inline-code text like
        # "## [X.Y.Z] - Unreleased". An unanchored search matched that
        # placeholder as the "top heading" (label "X.Y.Z"), which is
        # neither the expected nor next version nor "Unreleased", so the
        # script refused to auto-rename a heading that was already correct.
        path = self._write(
            "# Changelog\n\n"
            "<!--\n"
            "Convention: use \"## [X.Y.Z] - Unreleased\" while in progress.\n"
            "-->\n\n"
            "## [13.11.8]\n\n### Fixed\n\n- avoid_nullable_interpolation fix\n\n"
            "## [13.11.7]\n\n- prior release\n"
        )
        result = self._promote(path, "13.11.8", "13.11.9")
        self.assertEqual(result, "13.11.8")
        self.assertEqual(self._top_heading(path), "13.11.9")


if __name__ == "__main__":
    unittest.main()
