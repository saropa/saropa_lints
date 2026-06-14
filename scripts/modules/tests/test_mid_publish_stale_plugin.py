"""Regression tests for the mid-publish stale-plugin guard in
``scripts/modules/_publish_steps.py``.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

Pins the contract that stops the publish analyze step from looping
forever on the package's own dogfood plugin-resolution error. When
``saropa_lints`` analyzes itself mid-release, ``dart analyze`` reports
the plugin dependency as a *constraint* (``^14.0.0``) while
``pubspec.yaml`` holds the bare version (``14.0.0``). The guard
``_is_mid_publish_stale_plugin`` must treat that as the benign
mid-publish state; a prior string-equality comparison failed on the
caret, dropping into the interactive [F]/[S] "fix stale cache" prompt
that can never resolve (the package's own analysis_options.yaml has no
plugin ``version:`` pin to edit), so it cleared the cache, retried, and
re-prompted indefinitely.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path


class TestIsMidPublishStalePlugin(unittest.TestCase):
    """Pin the constraint-aware version comparison."""

    def setUp(self) -> None:
        from scripts.modules._publish_steps import _is_mid_publish_stale_plugin
        self._fn = _is_mid_publish_stale_plugin
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._dir = Path(self._tmp.name)

    def _write_pubspec(self, version: str) -> None:
        (self._dir / "pubspec.yaml").write_text(
            f"name: saropa_lints\nversion: {version}\n",
            encoding="utf-8",
        )

    @staticmethod
    def _analyze_error(constraint: str) -> str:
        # The exact shape the analysis server emits when the published
        # plugin version cannot satisfy the dogfood dependency.
        return (
            "  plugin_entrypoint depends on saropa_lints "
            f"{constraint} which doesn't match any versions\n"
        )

    def test_caret_constraint_matches_bare_pubspec_version(self) -> None:
        # The bug: pubspec holds "14.0.0", the error reports "^14.0.0".
        # String equality said "different" and fell through to the
        # un-resolvable fix prompt. The guard must recognize this as the
        # mid-publish state and report True so analyze is treated as
        # passed.
        self._write_pubspec("14.0.0")
        self.assertTrue(self._fn(self._dir, self._analyze_error("^14.0.0")))

    def test_range_and_tilde_constraints_also_match(self) -> None:
        # Other constraint operators must strip the same way; the
        # comparison is about the version, not the operator the analyzer
        # happened to print.
        self._write_pubspec("14.0.0")
        self.assertTrue(self._fn(self._dir, self._analyze_error(">=14.0.0")))
        self.assertTrue(self._fn(self._dir, self._analyze_error("~14.0.0")))

    def test_bare_constraint_still_matches(self) -> None:
        # Defensive: if a future analyzer prints the bare version with no
        # operator, the guard must keep recognizing the match.
        self._write_pubspec("14.0.0")
        self.assertTrue(self._fn(self._dir, self._analyze_error("14.0.0")))

    def test_genuine_drift_does_not_match(self) -> None:
        # Real drift — the plugin pin disagrees with pubspec — is NOT the
        # mid-publish case and must return False so the caller can offer
        # the downgrade fix. Stripping the operator must not collapse
        # distinct versions together.
        self._write_pubspec("14.0.0")
        self.assertFalse(self._fn(self._dir, self._analyze_error("^13.0.0")))

    def test_non_saropa_plugin_does_not_match(self) -> None:
        # The guard is scoped to the saropa_lints plugin; an unrelated
        # plugin's resolution error is never the saropa mid-publish state.
        self._write_pubspec("14.0.0")
        other = (
            "  plugin_entrypoint depends on some_other_lints ^14.0.0 "
            "which doesn't match any versions\n"
        )
        self.assertFalse(self._fn(self._dir, other))

    def test_no_stale_error_returns_false(self) -> None:
        # Clean analyze output (or any output without the resolution
        # error) is not a mid-publish state.
        self._write_pubspec("14.0.0")
        self.assertFalse(self._fn(self._dir, "No issues found.\n"))

    def test_missing_pubspec_returns_false(self) -> None:
        # No pubspec to compare against → cannot assert the mid-publish
        # invariant; fail safe to False rather than swallow the error.
        self.assertFalse(self._fn(self._dir, self._analyze_error("^14.0.0")))


if __name__ == "__main__":
    unittest.main()
