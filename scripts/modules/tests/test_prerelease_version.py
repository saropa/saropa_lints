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
3. The fixed-slot mapping (ext patch = 10*P + slot) gives every publish a
   distinct, strictly increasing extension version with the package's
   major.minor.
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
    """Pin the fixed-slot mapping: ext patch = 10*P + slot, same major.minor."""

    def setUp(self) -> None:
        from scripts.modules._utils import extension_version_for

        self.fn = extension_version_for

    def test_mapping_table(self) -> None:
        table = [
            ("17.0.0-beta.1", "17.0.0"),
            ("17.0.0-beta.2", "17.0.1"),
            ("17.0.0", "17.0.9"),
            ("17.0.1-beta.1", "17.0.10"),
            ("17.0.1-beta.2", "17.0.11"),
            ("17.0.1", "17.0.19"),
        ]
        for dart, ext in table:
            with self.subTest(dart=dart):
                self.assertEqual(self.fn(dart), ext)

    def test_table_is_strictly_increasing(self) -> None:
        order = [
            "17.0.0-beta.1", "17.0.0-beta.2", "17.0.0-beta.9", "17.0.0",
            "17.0.1-beta.1", "17.0.1-beta.2", "17.0.1",
            "17.0.2-beta.1", "17.0.2",
        ]
        tup = [tuple(int(x) for x in self.fn(v).split(".")) for v in order]
        for lo, hi in zip(tup, tup[1:]):
            self.assertLess(lo, hi)

    def test_major_minor_preserved(self) -> None:
        for v in ("17.0.0", "16.13.4-beta.3", "9.2.0-rc.1"):
            self.assertEqual(self.fn(v).rsplit(".", 1)[0], v.split("-")[0].rsplit(".", 1)[0])

    def test_bare_channel_is_iteration_one(self) -> None:
        self.assertEqual(self.fn("17.0.0-beta"), "17.0.0")

    def test_tenth_beta_refused(self) -> None:
        self.assertEqual(self.fn("17.0.0-beta.9"), "17.0.8")
        with self.assertRaises(ValueError):
            self.fn("17.0.0-beta.10")
        with self.assertRaises(ValueError):
            self.fn("17.0.0-beta.0")

    def test_channels_share_a_slot(self) -> None:
        # The channel name is ignored: -alpha.1 and -beta.1 of the same
        # patch map to the same extension version, so they must not both
        # be published for the same patch.
        self.assertEqual(self.fn("17.0.0-alpha.1"), self.fn("17.0.0-beta.1"))


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

    def test_stable_version_mapped(self) -> None:
        # Stable takes slot 9: 15.2.7 -> 15.2.79.
        self._package_with_mocks("15.2.7")
        pkg = json.loads((self.root / "extension" / "package.json").read_text(encoding="utf-8"))
        self.assertEqual(pkg["version"], "15.2.79")

    def test_prerelease_version_offset_before_writing(self) -> None:
        self._package_with_mocks("15.2.7-beta.1")
        pkg = json.loads((self.root / "extension" / "package.json").read_text(encoding="utf-8"))
        self.assertEqual(
            pkg["version"], "15.2.70",
            msg="extension/package.json must never contain a hyphenated "
                "version — vsce rejects it even with --pre-release",
        )
        self.assertNotIn("-", pkg["version"])


class TestSetExtensionVersionDryRun(unittest.TestCase):
    """Pin that dry_run returns the expected version without modifying the file."""

    def setUp(self) -> None:
        import scripts.modules._extension_publish as mod

        self._mod = mod
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        ext_dir = self.root / "extension"
        ext_dir.mkdir()
        # Seed with a known version so we can verify it stays unchanged.
        (ext_dir / "package.json").write_text(
            json.dumps({"name": "saropa-lints", "version": "0.0.0"}), encoding="utf-8"
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_dry_run_returns_converted_version(self) -> None:
        # Dry-run should return the extension version string, not a bool.
        result = self._mod.set_extension_version(
            self.root, "16.0.0-beta.2", dry_run=True,
        )
        self.assertEqual(result, "16.0.1")

    def test_dry_run_does_not_modify_file(self) -> None:
        # File must keep the seed version after a dry run.
        self._mod.set_extension_version(
            self.root, "16.0.0-beta.2", dry_run=True,
        )
        pkg = json.loads(
            (self.root / "extension" / "package.json").read_text(encoding="utf-8")
        )
        self.assertEqual(pkg["version"], "0.0.0")

    def test_dry_run_stable_returns_mapped_version(self) -> None:
        # Stable takes slot 9: 15.2.7 -> 15.2.79.
        result = self._mod.set_extension_version(
            self.root, "15.2.7", dry_run=True,
        )
        self.assertEqual(result, "15.2.79")

    def test_dry_run_missing_package_json_returns_empty(self) -> None:
        # When extension dir has no package.json, dry-run returns "".
        empty_root = Path(self._tmp.name) / "empty_project"
        empty_root.mkdir()
        result = self._mod.set_extension_version(
            empty_root, "16.0.0-beta.2", dry_run=True,
        )
        self.assertEqual(result, "")


if __name__ == "__main__":
    unittest.main()
