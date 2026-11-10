"""Regression tests for the known_issues.json manual-review report generator.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

Network calls are never exercised — ``fetch_pubdev_candidates`` is mocked at
the module boundary so these tests run offline. Pins:

1. ``_classify_tier``'s HIGH/MEDIUM/LOW rule.
2. ``_review_report_from_fetched``'s outgrown filter + tier sort order.
3. ``run_known_issues_checks`` fetches pub.dev data exactly ONCE for the
   union of both checks' candidates and derives both results from that one
   pass — this is the whole point of the publish-pipeline integration
   (2026-08-18): calling the freshness check and the review-report
   generator independently would double-fetch the ~70 overlapping
   candidates on every publish.
4. ``render_markdown`` produces the expected section structure.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest.mock import patch


class TestClassifyTier(unittest.TestCase):
    def setUp(self) -> None:
        from scripts.modules._known_issues_review_report import _classify_tier

        self._classify = _classify_tier

    def test_lifecycle_status_with_keyword_is_high(self) -> None:
        issue = {"status": "end_of_life", "reason": "Abandoned by maintainer"}
        self.assertEqual(self._classify(issue), "high")

    def test_lifecycle_status_without_keyword_is_medium(self) -> None:
        issue = {"status": "caution", "reason": "Occasional API breakage"}
        self.assertEqual(self._classify(issue), "medium")

    def test_business_model_status_is_low(self) -> None:
        issue = {"status": "commercial", "reason": "Requires paid license"}
        self.assertEqual(self._classify(issue), "low")


class TestReviewReportFromFetched(unittest.TestCase):
    def setUp(self) -> None:
        from scripts.modules._known_issues_review_report import (
            _review_report_from_fetched,
        )

        self._derive = _review_report_from_fetched

    def _issue(self, name: str, status: str, reason: str, outgrown: bool) -> dict:
        return {
            "name": name,
            "status": status,
            "reason": reason,
            "lastUpdated": "2026-01-01",
            "_actual_published": "2026-06-01" if outgrown else "2025-01-01",
            "_actual_version": "1.0.0",
            "_is_discontinued": False,
        }

    def test_only_outgrown_entries_are_included(self) -> None:
        fetched = [
            self._issue("pkgA", "end_of_life", "Abandoned by maintainer", outgrown=True),
            self._issue("pkgB", "end_of_life", "Abandoned by maintainer", outgrown=False),
        ]
        report = self._derive(fetched, network_error_count=0, checked_count=2)
        self.assertEqual([e.name for e in report.entries], ["pkgA"])
        self.assertEqual(report.checked_count, 2)

    def test_entries_sorted_high_before_medium_before_low(self) -> None:
        fetched = [
            self._issue("pkgLow", "commercial", "Requires paid license", outgrown=True),
            self._issue("pkgHigh", "end_of_life", "Abandoned by maintainer", outgrown=True),
            self._issue("pkgMedium", "caution", "Occasional API breakage", outgrown=True),
        ]
        report = self._derive(fetched, network_error_count=0, checked_count=3)
        self.assertEqual(
            [(e.name, e.tier) for e in report.entries],
            [("pkgHigh", "high"), ("pkgMedium", "medium"), ("pkgLow", "low")],
        )


class TestRecentlyVerifiedSkip(unittest.TestCase):
    TODAY = date(2026, 11, 10)

    def _run(self, status: str, verified: str | None, **extra: str) -> object:
        from scripts.modules._known_issues_review_report import (
            _review_report_from_fetched,
        )

        issue = {
            "name": "pkg",
            "status": status,
            "reason": "Requires paid license",
            "lastUpdated": "2026-01-01",
            "_actual_published": "2026-06-01",
            "_actual_version": "1.0.0",
            "_is_discontinued": False,
        }
        issue.update(extra)
        if verified is not None:
            issue["reasonVerified"] = verified
        return _review_report_from_fetched(
            [issue], 0, checked_count=1, today=self.TODAY
        )

    def test_recent_reason_verified_low_entry_skipped(self) -> None:
        r = self._run("commercial", "2026-09-19")
        self.assertEqual(r.entries, [])
        self.assertEqual(r.skipped_recently_verified_count, 1)

    def test_old_reason_verified_low_entry_listed(self) -> None:
        self.assertEqual(len(self._run("commercial", "2026-01-01").entries), 1)

    def test_missing_or_bad_reason_verified_listed(self) -> None:
        self.assertEqual(len(self._run("commercial", None).entries), 1)
        self.assertEqual(len(self._run("commercial", "garbage").entries), 1)

    def test_future_reason_verified_listed(self) -> None:
        self.assertEqual(len(self._run("commercial", "2026-12-01").entries), 1)

    def test_exact_183_day_boundary(self) -> None:
        # 2026-11-10 minus 182 days = 2026-05-12 (skipped); 183 days = 05-11.
        self.assertEqual(self._run("commercial", "2026-05-12").entries, [])
        self.assertEqual(len(self._run("commercial", "2026-05-11").entries), 1)

    def test_recent_as_of_without_reason_verified_listed(self) -> None:
        r = self._run("commercial", None, as_of="2026-11-01")
        self.assertEqual(len(r.entries), 1)

    def test_lifecycle_entry_verified_after_latest_release_skipped(self) -> None:
        # Latest release 2026-06-01; verified 2026-09-19 (after it).
        r = self._run("end_of_life", "2026-09-19")
        self.assertEqual(r.entries, [])
        self.assertEqual(r.skipped_recently_verified_count, 1)

    def test_lifecycle_entry_verified_before_latest_release_listed(self) -> None:
        self.assertEqual(len(self._run("end_of_life", "2026-05-31").entries), 1)

    def test_lifecycle_entry_verified_on_release_date_skipped(self) -> None:
        self.assertEqual(self._run("end_of_life", "2026-06-01").entries, [])

    def test_lifecycle_entry_future_verified_listed(self) -> None:
        self.assertEqual(len(self._run("end_of_life", "2026-12-01").entries), 1)

    def test_old_low_entry_verified_after_release_skipped(self) -> None:
        # Verified long ago (outside 183 days) but after the release.
        r = self._run("commercial", "2026-06-02", _actual_published="2025-01-01")
        self.assertEqual(r.entries, [])


class TestZeroEntriesWritesNoFile(unittest.TestCase):
    def test_generator_write_with_no_entries_creates_no_file(self) -> None:
        from scripts.generators import generate_known_issues_review as gen
        from scripts.modules._known_issues_review_report import (
            KnownIssuesReviewReport,
        )

        with tempfile.TemporaryDirectory() as tmp:
            fake_file = Path(tmp) / "scripts" / "generators" / "gen.py"
            fake_file.parent.mkdir(parents=True)
            with patch.object(
                gen, "build_known_issues_review_report",
                return_value=KnownIssuesReviewReport(checked_count=3),
            ), patch.object(gen, "__file__", str(fake_file)), patch(
                "sys.argv", ["gen", "--write"]
            ):
                self.assertEqual(gen.main(), 0)
            self.assertFalse((Path(tmp) / "bugs").exists())


class TestRunKnownIssuesChecksSharesOneFetch(unittest.TestCase):
    """The core contract of the publish-pipeline integration: one fetch."""

    def setUp(self) -> None:
        self._root = Path(tempfile.mkdtemp(prefix="known_issues_test_"))

    def _write_known_issues(self, issues: list[dict]) -> None:
        from scripts.modules._known_issues_freshness import KNOWN_ISSUES_RELATIVE_PATH

        path = self._root / KNOWN_ISSUES_RELATIVE_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"issues": issues}), encoding="utf-8")

    def test_fetches_once_for_the_union_of_both_candidate_sets(self) -> None:
        from scripts.modules._known_issues_review_report import (
            run_known_issues_checks,
        )

        self._write_known_issues([
            # In both the freshness subset (keyword match) and the review
            # superset.
            {
                "name": "pkgA",
                "status": "end_of_life",
                "reason": "Abandoned by maintainer",
                "lastUpdated": "2026-01-01",
            },
            # Only in the review superset (no falsifiable keyword).
            {
                "name": "pkgB",
                "status": "caution",
                "reason": "Occasional API breakage",
                "lastUpdated": "2026-01-01",
            },
            # Only in the review superset (business-model status).
            {
                "name": "pkgC",
                "status": "commercial",
                "reason": "Requires paid license",
                "lastUpdated": "2026-01-01",
            },
        ])

        def fake_fetch(candidates, *, timeout, max_workers):
            fetched = []
            for issue in candidates:
                issue["_actual_published"] = "2026-06-01"
                issue["_actual_version"] = "9.9.9"
                issue["_is_discontinued"] = False
                fetched.append(issue)
            return fetched, 0

        with patch(
            "scripts.modules._known_issues_review_report.fetch_pubdev_candidates",
            side_effect=fake_fetch,
        ) as mock_fetch:
            freshness, review = run_known_issues_checks(self._root, timeout=5.0)

        # Exactly one fetch call, over all 3 candidates (the review-set
        # superset) — not one call for the freshness subset and a second,
        # overlapping call for the review superset.
        self.assertEqual(mock_fetch.call_count, 1)
        fetched_names = [c["name"] for c in mock_fetch.call_args.args[0]]
        self.assertEqual(sorted(fetched_names), ["pkgA", "pkgB", "pkgC"])

        # Both derived results are still correct despite sharing one fetch.
        self.assertEqual(freshness.checked_count, 1)
        self.assertEqual([s["name"] for s in freshness.confirmed_stale], ["pkgA"])
        self.assertEqual(
            sorted(e.name for e in review.entries), ["pkgA", "pkgB", "pkgC"]
        )


class TestVersionScopedEntriesExcluded(unittest.TestCase):
    """Entries with appliesToMaxVersion or replacementObsoleteFromVersion are
    already scoped to old versions — a newer pub.dev release doesn't
    invalidate them."""

    def setUp(self) -> None:
        self._root = Path(tempfile.mkdtemp(prefix="known_issues_test_"))

    def _write_known_issues(self, issues: list[dict]) -> None:
        from scripts.modules._known_issues_freshness import KNOWN_ISSUES_RELATIVE_PATH

        path = self._root / KNOWN_ISSUES_RELATIVE_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"issues": issues}), encoding="utf-8")

    def test_version_scoped_entries_are_not_fetched(self) -> None:
        from scripts.modules._known_issues_review_report import (
            run_known_issues_checks,
        )

        self._write_known_issues([
            # Unscoped — should be fetched.
            {
                "name": "pkgA",
                "status": "end_of_life",
                "reason": "Abandoned by maintainer",
                "lastUpdated": "2026-01-01",
            },
            # Version-scoped via appliesToMaxVersion — should be SKIPPED.
            {
                "name": "pkgB",
                "status": "end_of_life",
                "reason": "Fails on Dart 3",
                "lastUpdated": "2025-01-01",
                "appliesToMaxVersion": "2.0.0",
            },
            # Version-scoped via replacementObsoleteFromVersion alone (no
            # appliesToMaxVersion) — same false-positive class as pkgB,
            # should also be SKIPPED.
            {
                "name": "pkgC",
                "status": "end_of_life",
                "reason": "Global singletons block Dart 3 compilation",
                "lastUpdated": "2025-06-12",
                "replacementObsoleteFromVersion": "7.0.0",
            },
        ])

        def fake_fetch(candidates, *, timeout, max_workers):
            fetched = []
            for issue in candidates:
                issue["_actual_published"] = "2026-06-01"
                issue["_actual_version"] = "9.9.9"
                issue["_is_discontinued"] = False
                fetched.append(issue)
            return fetched, 0

        with patch(
            "scripts.modules._known_issues_review_report.fetch_pubdev_candidates",
            side_effect=fake_fetch,
        ) as mock_fetch:
            _, review = run_known_issues_checks(self._root, timeout=5.0)

        # Only pkgA should be fetched — pkgB has appliesToMaxVersion and
        # pkgC has replacementObsoleteFromVersion.
        fetched_names = [c["name"] for c in mock_fetch.call_args.args[0]]
        self.assertEqual(fetched_names, ["pkgA"])


class TestRenderMarkdown(unittest.TestCase):
    def test_renders_all_three_tier_sections(self) -> None:
        from scripts.modules._known_issues_review_report import (
            KnownIssuesReviewReport,
            ReviewEntry,
            render_markdown,
        )

        report = KnownIssuesReviewReport(
            checked_count=1,
            network_error_count=0,
            entries=[
                ReviewEntry(
                    name="pkgA",
                    status="end_of_life",
                    reason="Abandoned by maintainer",
                    recorded_last_updated="2026-01-01",
                    actual_latest_published="2026-06-01",
                    actual_latest_version="1.0.0",
                    tier="high",
                )
            ],
        )
        markdown = render_markdown(report, generated_on="2026-08-18")
        self.assertIn("HIGH confidence", markdown)
        self.assertIn("MEDIUM confidence", markdown)
        self.assertIn("LOW confidence", markdown)
        self.assertIn("pkgA", markdown)
        self.assertIn("_None._", markdown)  # medium/low sections are empty


class ReviewReportPathTests(unittest.TestCase):
    def test_valid_date_used(self) -> None:
        from scripts.modules._known_issues_review_report import review_report_path

        path = review_report_path(Path("/p"), "2026-08-18")
        self.assertEqual(path, Path("/p/bugs/2026-08-18_known_issues_review_queue.md"))

    def test_invalid_or_missing_date_falls_back_to_today(self) -> None:
        from scripts.modules._known_issues_review_report import review_report_path

        expected = f"{date.today().isoformat()}_known_issues_review_queue.md"
        self.assertEqual(review_report_path(Path("/p"), "(not a date)").name, expected)
        self.assertEqual(review_report_path(Path("/p")).name, expected)


if __name__ == "__main__":
    unittest.main()
