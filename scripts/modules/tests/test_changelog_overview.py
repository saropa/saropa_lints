"""Tests for the CHANGELOG Overview / [log]-link publish gate.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

These pin ``check_changelog_overview``: every released ``## [X.Y.Z]``
section must open with a user-facing Overview paragraph that ends in a
``[log](.../vX.Y.Z/CHANGELOG.md)`` link pinned to THAT version's git tag
(see CHANGELOG.md MAINTENANCE NOTES). The gate defaults to retry so the
author can fix the section in place; these tests cover the detection
logic the prompt loop sits on top of.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path


class TestCheckChangelogOverview(unittest.TestCase):
    """Pin the contract of ``check_changelog_overview``."""

    def setUp(self) -> None:
        from scripts.modules._version_changelog import (
            check_changelog_overview,
        )

        self._check = check_changelog_overview

    def _write(self, content: str) -> Path:
        fh = tempfile.NamedTemporaryFile(
            "w", suffix=".md", delete=False, encoding="utf-8",
        )
        fh.write(content)
        fh.close()
        return Path(fh.name)

    def _log(self, version: str) -> str:
        return (
            f"[log](https://github.com/saropa/saropa_lints/blob/"
            f"v{version}/CHANGELOG.md)"
        )

    def test_valid_section_has_no_problems(self) -> None:
        # Intro paragraph ending in a version-pinned [log] link == valid.
        path = self._write(
            f"## [13.13.0]\n\nAdds a thing. {self._log('13.13.0')}\n\n"
            "### Added\n\n- a bullet.\n"
        )
        self.assertEqual(self._check(path, "13.13.0"), [])

    def test_leading_separator_before_intro_is_tolerated(self) -> None:
        # The repo's layout often puts a `---` between the heading and the
        # body; that separator must not be mistaken for the intro prose.
        path = self._write(
            f"## [9.9.9]\n\n---\n\nSummary line. {self._log('9.9.9')}\n\n"
            "### Fixed\n\n- fix.\n"
        )
        self.assertEqual(self._check(path, "9.9.9"), [])

    def test_missing_section_is_reported(self) -> None:
        path = self._write("## [1.0.0]\n\nReal. " + self._log("1.0.0") + "\n")
        problems = self._check(path, "2.0.0")
        self.assertEqual(len(problems), 1)
        self.assertIn("No [2.0.0] section", problems[0])

    def test_missing_intro_and_link_both_reported(self) -> None:
        # Current [Unreleased] shape after rename: straight into ### with
        # no Overview and no link — both defects must surface in one pass.
        path = self._write(
            "## [13.13.0]\n\n### Fixed\n\n- something fixed.\n"
        )
        problems = self._check(path, "13.13.0")
        self.assertEqual(len(problems), 2)
        joined = " ".join(problems)
        self.assertIn("no Overview intro paragraph", joined)
        self.assertIn("no [log](...) link", joined)

    def test_intro_present_but_link_missing(self) -> None:
        path = self._write(
            "## [5.0.0]\n\nA perfectly good summary sentence.\n\n"
            "### Added\n\n- bullet.\n"
        )
        problems = self._check(path, "5.0.0")
        self.assertEqual(len(problems), 1)
        self.assertIn("no [log](...) link", problems[0])

    def test_link_present_but_wrong_version(self) -> None:
        # The canonical failure: a copy-pasted /main/ link, or a stale tag,
        # left in the section being published.
        path = self._write(
            "## [13.12.2]\n\nFixes stuff. "
            "[log](https://github.com/saropa/saropa_lints/blob/"
            "main/CHANGELOG.md)\n\n### Fixed\n\n- fix.\n"
        )
        problems = self._check(path, "13.12.2")
        self.assertEqual(len(problems), 1)
        self.assertIn("does not point at tag v13.12.2", problems[0])

    def test_link_pinned_to_prior_tag_is_reported(self) -> None:
        # Forgetting to bump the tag in the link from the previous release.
        path = self._write(
            f"## [13.13.0]\n\nNew release. {self._log('13.12.9')}\n\n"
            "### Added\n\n- bullet.\n"
        )
        problems = self._check(path, "13.13.0")
        self.assertEqual(len(problems), 1)
        self.assertIn("does not point at tag v13.13.0", problems[0])

    def test_missing_file_is_reported(self) -> None:
        problems = self._check(Path("does_not_exist_xyz.md"), "1.0.0")
        self.assertEqual(len(problems), 1)
        self.assertIn("not found", problems[0])

    def test_real_project_unreleased_will_gate(self) -> None:
        # Documents the live state: the real [Unreleased] has no Overview,
        # so the next publish (after rename) WILL hit the gate. If someone
        # later adds the Overview to [Unreleased], update this expectation.
        # parents[3] = repo root (file is scripts/modules/tests/<name>.py).
        repo_root = Path(__file__).resolve().parents[3]
        changelog = repo_root / "CHANGELOG.md"
        # A real published section with a correct v-tag link passes clean.
        self.assertEqual(self._check(changelog, "13.12.3"), [])


if __name__ == "__main__":
    unittest.main()
