"""Regression tests for ``scripts/modules/_tier_yaml_version.py``.

Run from repository root::

    python -m unittest discover -s scripts/tests -t . -v

Pins the contract that prevents a recurrence of issue #216 — the
``lib/tiers/*.yaml`` files shipped pinned to ``^5.0.0-beta.8`` from
Feb 2026 right through to v13.4.x because nothing in the publish
pipeline was rewriting them on version bumps. See the module's
docstring for the failure mode the user-side ``dart analyze`` hits.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path


class TestDesiredConstraintFor(unittest.TestCase):
    """Pin the major-only widening rule."""

    def setUp(self) -> None:
        from scripts.modules._tier_yaml_version import desired_constraint_for
        self._fn = desired_constraint_for

    def test_stable_release_uses_major_floor(self) -> None:
        # A patch release must NOT churn the constraint. 13.4.6 → ^13.0.0
        # so consumers on any 13.x see a satisfiable range without
        # having to bump in lockstep with our publishes.
        self.assertEqual(self._fn("13.4.6"), "^13.0.0")
        self.assertEqual(self._fn("13.0.0"), "^13.0.0")
        self.assertEqual(self._fn("13.99.99"), "^13.0.0")

    def test_major_bump_advances_floor(self) -> None:
        # New major (= breaking) MUST move the floor; otherwise a
        # consumer on 13.x would resolve fine but the synthetic
        # plugin-manager project would pull in 14.x and crash on
        # incompatible APIs.
        self.assertEqual(self._fn("14.0.0"), "^14.0.0")

    def test_pre_release_keeps_major_only(self) -> None:
        # Pre-release suffixes don't change the major; the wider
        # constraint allows beta consumers to coexist with stable
        # consumers on the same range.
        self.assertEqual(self._fn("14.0.0-beta.1"), "^14.0.0")
        self.assertEqual(self._fn("13.5.0-dev.3"), "^13.0.0")

    def test_invalid_version_raises(self) -> None:
        # Defensive — pubspec.yaml is already validated upstream by
        # _version_changelog.py, but reject garbage so a corrupted
        # caller fails loudly instead of silently writing nonsense.
        with self.assertRaises(ValueError):
            self._fn("not a version")
        with self.assertRaises(ValueError):
            self._fn("")


class TestUpdateTierYaml(unittest.TestCase):
    """Verify in-place rewrite of a tier yaml's version line."""

    def setUp(self) -> None:
        from scripts.modules._tier_yaml_version import update_tier_yaml
        self._fn = update_tier_yaml
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._dir = Path(self._tmp.name)

    def _write(self, name: str, body: str) -> Path:
        # Write as bytes so test fixtures can deliberately use CRLF
        # without Python silently translating on Windows.
        path = self._dir / name
        path.write_bytes(body.encode("utf-8"))
        return path

    def test_rewrites_legacy_5x_pin_to_current_major(self) -> None:
        # The exact shape that triggered issue #216.
        path = self._write(
            "recommended.yaml",
            'plugins:\n  saropa_lints:\n    version: "^5.0.0-beta.8"\n    diagnostics:\n      avoid_print: true\n',
        )
        changed, previous = self._fn(path, "^13.0.0")
        self.assertTrue(changed)
        self.assertEqual(previous, "^5.0.0-beta.8")
        self.assertIn('version: "^13.0.0"', path.read_text(encoding="utf-8"))
        # And the rest of the file must survive untouched.
        self.assertIn("avoid_print: true", path.read_text(encoding="utf-8"))

    def test_no_op_when_already_at_desired_version(self) -> None:
        # Idempotence: re-running the publish step doesn't churn.
        path = self._write(
            "recommended.yaml",
            'plugins:\n  saropa_lints:\n    version: "^13.0.0"\n',
        )
        before = path.read_bytes()
        changed, previous = self._fn(path, "^13.0.0")
        self.assertFalse(changed)
        self.assertEqual(previous, "^13.0.0")
        self.assertEqual(path.read_bytes(), before)

    def test_returns_none_when_yaml_has_no_version_line(self) -> None:
        # A tier yaml might legitimately have no plugin block (e.g. a
        # future stylistic-only tier that just tweaks diagnostics).
        # Don't crash — just report nothing to do.
        path = self._write(
            "stylistic.yaml",
            'include: package:saropa_lints/tiers/recommended.yaml\n',
        )
        changed, previous = self._fn(path, "^13.0.0")
        self.assertFalse(changed)
        self.assertIsNone(previous)

    def test_preserves_crlf_line_endings(self) -> None:
        # Windows users edit yaml as CRLF; flipping to LF on every
        # publish would create a noisy git diff on every contributor's
        # machine. Pin the EOL preservation contract.
        path = self._write(
            "recommended.yaml",
            'plugins:\r\n  saropa_lints:\r\n    version: "^5.0.0-beta.8"\r\n',
        )
        changed, _ = self._fn(path, "^13.0.0")
        self.assertTrue(changed)
        raw = path.read_bytes()
        self.assertIn(b"\r\n", raw)
        # And no LF-only lines accidentally introduced.
        self.assertNotIn(b"\nplugins", raw.replace(b"\r\n", b""))

    def test_does_not_match_a_version_line_outside_saropa_block(self) -> None:
        # If a tier yaml ever grows another `version:` key (e.g. for
        # an analyzer plugin shim), we must NOT rewrite that line —
        # only the saropa_lints one. This guards against a future
        # nested-plugin case that would otherwise corrupt the yaml.
        path = self._write(
            "with-other-plugin.yaml",
            'analyzer:\n  version: "1.0.0"\nplugins:\n  saropa_lints:\n    version: "^5.0.0-beta.8"\n',
        )
        changed, previous = self._fn(path, "^13.0.0")
        self.assertTrue(changed)
        self.assertEqual(previous, "^5.0.0-beta.8")
        text = path.read_text(encoding="utf-8")
        # The analyzer's 1.0.0 line is unchanged.
        self.assertIn('version: "1.0.0"', text)
        # And the saropa_lints version was the one we touched.
        self.assertIn('    version: "^13.0.0"', text)


class TestSyncTierYamls(unittest.TestCase):
    """End-to-end: rewrite a directory of tier yamls in one pass."""

    def setUp(self) -> None:
        from scripts.modules._tier_yaml_version import sync_tier_yamls
        self._fn = sync_tier_yamls
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._dir = Path(self._tmp.name)

    def _write(self, name: str, version: str) -> Path:
        path = self._dir / name
        path.write_text(
            f'plugins:\n  saropa_lints:\n    version: "{version}"\n',
            encoding="utf-8",
        )
        return path

    def test_reports_only_files_that_actually_changed(self) -> None:
        a = self._write("a.yaml", "^5.0.0-beta.8")
        b = self._write("b.yaml", "^13.0.0")  # already in sync
        c = self._write("c.yaml", "^12.0.0")
        changes = self._fn(self._dir, "13.4.6")
        # b is in sync → must NOT appear in the change report; the
        # publish summary stays clean and only mentions real edits.
        self.assertEqual(set(changes.keys()), {a, c})
        self.assertEqual(changes[a], ("^5.0.0-beta.8", "^13.0.0"))
        self.assertEqual(changes[c], ("^12.0.0", "^13.0.0"))


class TestAssertTierYamlsSynced(unittest.TestCase):
    """Drift guard for CI / pre-publish gate."""

    def setUp(self) -> None:
        from scripts.modules._tier_yaml_version import assert_tier_yamls_synced
        self._fn = assert_tier_yamls_synced
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._dir = Path(self._tmp.name)

    def _write(self, name: str, version: str) -> Path:
        path = self._dir / name
        path.write_text(
            f'plugins:\n  saropa_lints:\n    version: "{version}"\n',
            encoding="utf-8",
        )
        return path

    def test_returns_empty_when_all_yamls_match(self) -> None:
        self._write("a.yaml", "^13.0.0")
        self._write("b.yaml", "^13.0.0")
        self.assertEqual(self._fn(self._dir, "13.4.6"), [])

    def test_returns_drifted_files(self) -> None:
        a = self._write("a.yaml", "^5.0.0-beta.8")
        self._write("b.yaml", "^13.0.0")
        c = self._write("c.yaml", "^12.0.0")
        drifted = self._fn(self._dir, "13.4.6")
        self.assertEqual(set(drifted), {a, c})

    def test_ignores_yamls_with_no_version_line(self) -> None:
        # A tier yaml that doesn't enrol the plugin (e.g. a pure
        # `include:` aggregator) is not "drifted" — it has nothing
        # to compare against. Don't false-positive the publish gate.
        path = self._dir / "aggregator.yaml"
        path.write_text(
            "include: package:saropa_lints/tiers/recommended.yaml\n",
            encoding="utf-8",
        )
        self.assertEqual(self._fn(self._dir, "13.4.6"), [])


if __name__ == "__main__":
    unittest.main()
