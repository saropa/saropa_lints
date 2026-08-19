"""Regression tests for the known_issues.json freshness cross-check.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

Network calls (``urllib.request.urlopen``) are never exercised here — the
module's own fetch boundary (``check_pubdev_data`` / ``fetch_pubdev_candidates``)
is mocked out so these tests run offline and deterministically, pinning:

1. ``check_pubdev_data``'s discontinued-tag detection (pub.dev signals
   discontinuation via ``"is:discontinued"`` inside the ``tags`` array, not a
   top-level boolean — this was wrong in the first implementation, see
   commit ``aa7c05bf``) and its network-error handling (a failed ``/score``
   fetch must count as inconclusive, not "not discontinued").
2. ``is_outgrown`` / ``freshness_result_from_fetched``'s staleness rule.
3. ``check_known_issues_freshness``'s candidate-filtering pipeline (status +
   falsifiable-keyword match) using a temp known_issues.json.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


class TestCheckPubdevData(unittest.TestCase):
    """Pin ``check_pubdev_data``'s pub.dev response parsing."""

    def setUp(self) -> None:
        from scripts.modules._known_issues_freshness import check_pubdev_data

        self._check_one = check_pubdev_data

    def test_invalid_name_is_network_error(self) -> None:
        # Synthetic version-pinned tracking names like "pkg (Orig)" aren't
        # real pub.dev packages and would raise http.client.InvalidURL if
        # fetched — must be skipped before the request, not crash.
        issue = {"name": "flutter_rating_bar (Orig)"}
        result_issue, network_error = self._check_one(issue, timeout=5.0)
        self.assertTrue(network_error)
        self.assertIs(result_issue, issue)

    def test_discontinued_tag_detected(self) -> None:
        # pub.dev has no top-level "isDiscontinued" boolean — discontinued
        # status is signaled via "is:discontinued" inside the score API's
        # "tags" array. Pin this against the actual response shape.
        package_json = {"latest": {"published": "2026-01-01T00:00:00Z", "version": "1.0.0"}}
        score_json = {"tags": ["is:discontinued", "sdk:flutter"]}

        def fake_fetch(url: str, timeout: float):
            if url.endswith("/score"):
                return score_json
            return package_json

        with patch(
            "scripts.modules._known_issues_freshness._fetch_json",
            side_effect=fake_fetch,
        ):
            issue, network_error = self._check_one({"name": "pedantic"}, timeout=5.0)
        self.assertFalse(network_error)
        self.assertTrue(issue["_is_discontinued"])
        self.assertEqual(issue["_actual_published"], "2026-01-01")
        self.assertEqual(issue["_actual_version"], "1.0.0")

    def test_non_discontinued_package_is_not_flagged(self) -> None:
        package_json = {"latest": {"published": "2026-06-01T00:00:00Z", "version": "2.0.0"}}
        score_json = {"tags": ["sdk:dart", "sdk:flutter"]}

        def fake_fetch(url: str, timeout: float):
            if url.endswith("/score"):
                return score_json
            return package_json

        with patch(
            "scripts.modules._known_issues_freshness._fetch_json",
            side_effect=fake_fetch,
        ):
            issue, network_error = self._check_one({"name": "timezone"}, timeout=5.0)
        self.assertFalse(network_error)
        self.assertFalse(issue["_is_discontinued"])

    def test_score_fetch_failure_is_network_error_not_false(self) -> None:
        # The bug fixed in commit aa7c05bf: a dropped /score request used to
        # silently default "_is_discontinued" to False, which could turn a
        # genuinely discontinued package into a false "confirmed stale"
        # warning. It must instead be reported as inconclusive.
        package_json = {"latest": {"published": "2026-01-01T00:00:00Z", "version": "1.0.0"}}

        def fake_fetch(url: str, timeout: float):
            if url.endswith("/score"):
                return None  # score request failed
            return package_json

        with patch(
            "scripts.modules._known_issues_freshness._fetch_json",
            side_effect=fake_fetch,
        ):
            issue, network_error = self._check_one({"name": "somepkg"}, timeout=5.0)
        self.assertTrue(network_error)
        self.assertNotIn("_is_discontinued", issue)

    def test_package_fetch_failure_is_network_error(self) -> None:
        with patch(
            "scripts.modules._known_issues_freshness._fetch_json",
            return_value=None,
        ):
            issue, network_error = self._check_one({"name": "somepkg"}, timeout=5.0)
        self.assertTrue(network_error)


class TestIsOutgrown(unittest.TestCase):
    """Pin the staleness predicate: newer release + not discontinued."""

    def setUp(self) -> None:
        from scripts.modules._known_issues_freshness import is_outgrown

        self._is_outgrown = is_outgrown

    def test_newer_release_and_not_discontinued_is_outgrown(self) -> None:
        issue = {
            "lastUpdated": "2026-01-01",
            "_actual_published": "2026-06-01",
            "_is_discontinued": False,
        }
        self.assertTrue(self._is_outgrown(issue))

    def test_older_release_is_not_outgrown(self) -> None:
        issue = {
            "lastUpdated": "2026-06-01",
            "_actual_published": "2026-01-01",
            "_is_discontinued": False,
        }
        self.assertFalse(self._is_outgrown(issue))

    def test_discontinued_package_is_not_outgrown_even_with_newer_release(self) -> None:
        # A discontinued package's last release doesn't disprove an
        # "avoid this" claim — the claim may BE that it's discontinued.
        issue = {
            "lastUpdated": "2026-01-01",
            "_actual_published": "2026-06-01",
            "_is_discontinued": True,
        }
        self.assertFalse(self._is_outgrown(issue))

    def test_missing_actual_published_is_not_outgrown(self) -> None:
        issue = {"lastUpdated": "2026-01-01", "_is_discontinued": False}
        self.assertFalse(self._is_outgrown(issue))


class TestFreshnessResultFromFetched(unittest.TestCase):
    """Pin the keyword/status narrowing applied on top of a fetched set."""

    def setUp(self) -> None:
        from scripts.modules._known_issues_freshness import (
            freshness_result_from_fetched,
        )

        self._derive = freshness_result_from_fetched

    def test_narrows_to_lifecycle_status_and_keyword_match(self) -> None:
        fetched = [
            {
                "name": "pkgA",
                "status": "end_of_life",
                "reason": "Abandoned by maintainer",
                "lastUpdated": "2026-01-01",
                "_actual_published": "2026-06-01",
                "_is_discontinued": False,
            },
            {
                # Business-model status: must never be counted, even if the
                # reason text happens to contain a falsifiable keyword —
                # a combined publish-time fetch passes the full reviewable
                # superset through this function, so the status filter is
                # what keeps business-model entries out of the freshness
                # result.
                "name": "pkgB",
                "status": "commercial",
                "reason": "Abandoned free tier, now paid-only",
                "lastUpdated": "2026-01-01",
                "_actual_published": "2026-06-01",
                "_is_discontinued": False,
            },
            {
                # Lifecycle status but no falsifiable keyword: excluded.
                "name": "pkgC",
                "status": "caution",
                "reason": "Occasional API breakage",
                "lastUpdated": "2026-01-01",
                "_actual_published": "2026-06-01",
                "_is_discontinued": False,
            },
        ]
        result = self._derive(fetched, network_error_count=2)
        self.assertEqual(result.checked_count, 1)
        self.assertEqual(result.network_error_count, 2)
        self.assertEqual([s["name"] for s in result.confirmed_stale], ["pkgA"])

    def test_no_matches_yields_empty_result(self) -> None:
        result = self._derive([], network_error_count=0)
        self.assertEqual(result.checked_count, 0)
        self.assertFalse(result.has_confirmed_stale)


class TestLoadKnownIssues(unittest.TestCase):
    """Pin ``load_known_issues``'s file-loading contract."""

    def setUp(self) -> None:
        self._root = Path(tempfile.mkdtemp(prefix="known_issues_test_"))

    def _write_known_issues(self, issues: list[dict]) -> None:
        from scripts.modules._known_issues_freshness import KNOWN_ISSUES_RELATIVE_PATH

        path = self._root / KNOWN_ISSUES_RELATIVE_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"issues": issues}), encoding="utf-8")

    def test_missing_file_returns_empty_list(self) -> None:
        from scripts.modules._known_issues_freshness import load_known_issues

        self.assertEqual(load_known_issues(self._root), [])

    def test_loads_issues_list(self) -> None:
        from scripts.modules._known_issues_freshness import load_known_issues

        self._write_known_issues([{"name": "pkgA", "status": "end_of_life"}])
        issues = load_known_issues(self._root)
        self.assertEqual(len(issues), 1)
        self.assertEqual(issues[0]["name"], "pkgA")


class TestCheckKnownIssuesFreshnessCandidateFilter(unittest.TestCase):
    """Pin the candidate-selection pipeline without hitting the network."""

    def setUp(self) -> None:
        self._root = Path(tempfile.mkdtemp(prefix="known_issues_test_"))

    def _write_known_issues(self, issues: list[dict]) -> None:
        from scripts.modules._known_issues_freshness import KNOWN_ISSUES_RELATIVE_PATH

        path = self._root / KNOWN_ISSUES_RELATIVE_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"issues": issues}), encoding="utf-8")

    def test_only_falsifiable_lifecycle_entries_are_fetched(self) -> None:
        from scripts.modules._known_issues_freshness import (
            check_known_issues_freshness,
        )

        self._write_known_issues([
            # Should be selected: lifecycle status + falsifiable keyword.
            {
                "name": "pkgA",
                "status": "end_of_life",
                "reason": "Abandoned by maintainer",
                "lastUpdated": "2026-01-01",
            },
            # Should be excluded: no falsifiable keyword.
            {
                "name": "pkgB",
                "status": "caution",
                "reason": "Occasional API breakage",
                "lastUpdated": "2026-01-01",
            },
            # Should be excluded: business-model status, not checkable here.
            {
                "name": "pkgC",
                "status": "commercial",
                "reason": "Abandoned free tier",
                "lastUpdated": "2026-01-01",
            },
            # Should be excluded: missing lastUpdated.
            {
                "name": "pkgD",
                "status": "end_of_life",
                "reason": "Abandoned by maintainer",
            },
        ])

        captured_candidates: list[list[dict]] = []

        def fake_fetch(candidates, *, timeout, max_workers):
            captured_candidates.append(candidates)
            return [], 0

        with patch(
            "scripts.modules._known_issues_freshness.fetch_pubdev_candidates",
            side_effect=fake_fetch,
        ):
            check_known_issues_freshness(self._root, timeout=5.0)

        self.assertEqual(len(captured_candidates), 1)
        names = [c["name"] for c in captured_candidates[0]]
        self.assertEqual(names, ["pkgA"])


if __name__ == "__main__":
    unittest.main()
