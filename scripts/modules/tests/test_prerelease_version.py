"""Regression tests for prerelease-version handling in the publish pipeline.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

Pins three things:

1. ``is_prerelease_version`` / ``strip_prerelease_suffix`` / ``extension_version_for``
   (scripts/modules/_utils.py) are pure and handle the semver shapes the
   pipeline actually produces.
2. ``package_extension`` (scripts/modules/_extension_publish.py) writes a
   plain, non-hyphenated version into extension/package.json, never the
   full pub.dev version. vsce hard-rejects a hyphenated "version" field
   (e.g. "1.2.3-beta.1") even when --pre-release is passed — a
   caught-in-review bug where the full pub.dev version was written
   straight through and broke every prerelease extension packaging
   attempt.
3. Successive beta iterations of the same base version ("16.0.0-beta.1",
   "16.0.0-beta.2", ...) produce DISTINCT extension versions. Naively
   stripping the suffix collapses every iteration to the same value
   ("16.0.0"), which collides at the Marketplace/Open VSX level on the
   second publish.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        pass


class TestPrereleaseVersionHelpers(unittest.TestCase):
    """Pin is_prerelease_version / strip_prerelease_suffix edge cases."""

    def setUp(self) -> None:
        from scripts.modules._utils import is_prerelease_version, strip_prerelease_suffix

        self.is_prerelease = is_prerelease_version
        self.strip = strip_prerelease_suffix

    def test_stable_version_is_not_prerelease(self) -> None:
        self.assertFalse(self.is_prerelease("15.2.7"))

    def test_beta_suffix_is_prerelease(self) -> None:
        self.assertTrue(self.is_prerelease("15.2.7-beta.1"))

    def test_strip_no_suffix_is_identity(self) -> None:
        self.assertEqual(self.strip("15.2.7"), "15.2.7")

    def test_strip_removes_beta_suffix(self) -> None:
        self.assertEqual(self.strip("15.2.7-beta.1"), "15.2.7")

    def test_strip_removes_everything_after_first_hyphen(self) -> None:
        # Multi-segment prerelease identifiers (rc.2, alpha.3, etc.) all
        # collapse to the numeric core the same way.
        self.assertEqual(self.strip("1.0.0-rc.2.extra"), "1.0.0")


class TestExtensionVersionFor(unittest.TestCase):
    """Pin extension_version_for's stable pass-through and beta-offset scheme."""

    def setUp(self) -> None:
        from scripts.modules._utils import extension_version_for

        self.fn = extension_version_for

    def test_stable_version_passes_through(self) -> None:
        self.assertEqual(self.fn("15.2.7"), "15.2.7")

    def test_first_beta_gets_offset_patch(self) -> None:
        # Minor is forced to odd (0 → 1) for pre-release so the VS Code
        # "Switch to Pre-Release Version" button works.
        self.assertEqual(self.fn("16.0.0-beta.1"), "16.1.913")

    def test_successive_betas_are_distinct(self) -> None:
        v1 = self.fn("16.0.0-beta.1")
        v2 = self.fn("16.0.0-beta.2")
        self.assertNotEqual(
            v1, v2,
            msg="successive beta iterations of the same base version must "
                "not collapse to the same extension version",
        )
        # Minor forced odd (0 → 1), patch offset incremented by iteration.
        self.assertEqual(v2, "16.1.914")

    def test_offset_preserves_original_patch(self) -> None:
        # A prerelease of a non-zero base patch keeps that patch as part
        # of the offset base. Minor forced odd (2 → 3).
        self.assertEqual(self.fn("15.2.7-beta.3"), "15.3.922")

    def test_missing_iteration_number_defaults_to_one(self) -> None:
        # Minor forced odd (0 → 1).
        self.assertEqual(self.fn("16.0.0-beta"), "16.1.913")

    def test_different_channels_of_same_base_version_are_distinct(self) -> None:
        # The version prompt accepts any prerelease tag, not just "beta" —
        # a beta.1 build and a later rc.1 of the same base version must not
        # collide at the Marketplace/Open VSX level.
        beta = self.fn("16.0.0-beta.1")
        rc = self.fn("16.0.0-rc.1")
        self.assertNotEqual(beta, rc)

    def test_double_conversion_is_idempotent(self) -> None:
        # set_extension_version() calls extension_version_for() internally.
        # If a caller also wraps, the double-conversion must not corrupt
        # the version. Converted pre-release versions look stable (no
        # hyphen), so the second call hits the identity path.
        once = self.fn("16.0.0-beta.2")
        twice = self.fn(once)
        self.assertEqual(
            once, twice,
            msg="double-converting a pre-release version must be idempotent "
                "— set_extension_version relies on this",
        )

    def test_stable_double_conversion_is_idempotent(self) -> None:
        # Stable versions pass through unchanged on every call.
        once = self.fn("15.2.12")
        twice = self.fn(once)
        self.assertEqual(once, twice)


class TestPackageExtensionWritesSafeVersion(unittest.TestCase):
    """Pin that package.json never receives a hyphenated version string."""

    def setUp(self) -> None:
        import scripts.modules._extension_publish as mod

        self._mod = mod
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        ext_dir = self.root / "extension"
        ext_dir.mkdir()
        (ext_dir / "package.json").write_text(
            json.dumps({"name": "saropa-lints", "version": "0.0.0"}), encoding="utf-8"
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _package_with_mocks(self, version: str) -> None:
        # Stub every side-effecting step except set_extension_version, so the
        # real regex-based writer runs and we can inspect package.json.
        with mock.patch.object(self._mod, "copy_changelog_to_extension", return_value=True), \
             mock.patch.object(self._mod, "copy_readme_to_extension", return_value=True), \
             mock.patch.object(self._mod, "audit_extension_locales", return_value=None), \
             mock.patch.object(self._mod, "regenerate_rule_catalog", return_value=True), \
             mock.patch.object(self._mod, "run_extension_compile", return_value=True), \
             mock.patch.object(self._mod, "run_extension_package", return_value=None):
            self._mod.package_extension(self.root, version)

    def test_stable_version_written_as_is(self) -> None:
        self._package_with_mocks("15.2.7")
        pkg = json.loads((self.root / "extension" / "package.json").read_text(encoding="utf-8"))
        self.assertEqual(pkg["version"], "15.2.7")

    def test_prerelease_version_offset_before_writing(self) -> None:
        # Minor forced odd (2 → 3) for pre-release channel detection.
        self._package_with_mocks("15.2.7-beta.1")
        pkg = json.loads((self.root / "extension" / "package.json").read_text(encoding="utf-8"))
        self.assertEqual(
            pkg["version"], "15.3.920",
            msg="extension/package.json must never contain a hyphenated "
                "version — vsce rejects it even with --pre-release",
        )
        self.assertNotIn("-", pkg["version"])


if __name__ == "__main__":
    unittest.main()
