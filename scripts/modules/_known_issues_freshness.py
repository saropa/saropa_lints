"""Detect stale entries in the extension's known-issues database.

``extension/src/vibrancy/data/known_issues.json`` is hand-curated: each entry
records why a package should be avoided as of a given date. Nothing re-checks
that reason against the package's current pub.dev state, so an entry can go
stale silently once the flagged package fixes the underlying problem upstream
(e.g. ``timezone`` was flagged "Pre-null-safety; blocks Dart 3 compilation
entirely" for months after it shipped a null-safe, Dart-3-compatible release).

This module queries the live pub.dev API and flags entries whose reason text
uses a claim class that a newer release directly falsifies (abandoned, dead,
pre-null-safety, discontinued, ...) while pub.dev shows the package is not
discontinued and has published since the entry's ``lastUpdated`` date.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import http.client
import json
import re
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

# known_issues.json also carries synthetic version-pinned names for historical
# tracking (e.g. "cached_network_image_v1", "flutter_rating_bar (Orig)") that
# were never real pub.dev packages. pub.dev package names are lowercase
# letters/digits/underscores only — anything outside that isn't worth an API
# round-trip and, for names containing spaces/parens, urllib rejects the URL
# outright (http.client.InvalidURL) rather than 404ing.
_VALID_PUBDEV_NAME = re.compile(r"^[a-z0-9_]+$")

# Statuses that make a lifecycle-style "avoid this package" claim worth
# re-verifying against release cadence. Business-model statuses (commercial,
# paid, freemium, ...) aren't lifecycle claims a release can falsify — a
# licensing model doesn't change because the vendor ships a patch — so they
# are handled separately (see _known_issues_review_report.py).
CHECKABLE_LIFECYCLE_STATUSES = {"end_of_life", "caution", "maintenance_mode"}

# Reason-text fragments that a continued, non-discontinued release directly
# contradicts. Keep narrow — this drives a build-gate warning, so false
# positives here erode trust in the check. Public: shared with
# _known_issues_review_report.py's tier classifier.
FALSIFIABLE_KEYWORDS = (
    "abandon",
    "unmaintain",
    "discontinu",
    "no longer maintain",
    "pre-null",
    "null-safety",
    "null safety",
    "blocks dart",
    "dead package",
    "dead repository",
    "archived",
    "no updates",
    "not maintained",
    "deprecated by",
)

# Public: shared with _known_issues_review_report.py so both modules load the
# same source file rather than each hardcoding the path independently.
KNOWN_ISSUES_RELATIVE_PATH = Path(
    "extension/src/vibrancy/data/known_issues.json"
)


@dataclass
class KnownIssuesFreshnessResult:
    """Result of cross-checking known_issues.json against live pub.dev data."""

    checked_count: int = 0
    network_error_count: int = 0
    confirmed_stale: list[dict] = field(default_factory=list)

    @property
    def has_confirmed_stale(self) -> bool:
        return bool(self.confirmed_stale)


def _fetch_json(url: str, timeout: float) -> dict | None:
    """Fetch and parse a pub.dev JSON endpoint. Returns None on any failure —
    network error, timeout, non-JSON body, or a JSON body that isn't an
    object (a pub.dev API-shape change should degrade to "unknown", not crash
    the whole check)."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:  # noqa: S310 (pub.dev, fixed host)
            parsed = json.loads(resp.read().decode("utf-8"))
    except (
        urllib.error.URLError,
        TimeoutError,
        ValueError,
        OSError,
        http.client.InvalidURL,
    ):
        return None
    return parsed if isinstance(parsed, dict) else None


def check_pubdev_data(issue: dict, timeout: float) -> tuple[dict, bool]:
    """Return (issue, network_error) — issue is unchanged; caller decides staleness.

    Non-pub.dev names (synthetic version-pinned tracking entries like
    "flutter_rating_bar (Orig)") are treated the same as a network error —
    there's nothing to check, so downstream code should not treat them as a
    fresh/stale verdict either way.

    The score fetch failing independently of the package fetch is ALSO
    treated as network_error=True, not as "not discontinued" — the
    discontinued check only comes from the score endpoint, so a dropped
    score request means we genuinely don't know, and defaulting the unknown
    to False would let a real timeout/rate-limit turn a discontinued
    package into a false "confirmed stale" flag.
    """
    name = issue["name"]
    if not _VALID_PUBDEV_NAME.match(name):
        return issue, True
    package = _fetch_json(f"https://pub.dev/api/packages/{name}", timeout)
    if package is None:
        return issue, True
    score = _fetch_json(f"https://pub.dev/api/packages/{name}/score", timeout)
    if score is None:
        return issue, True
    latest = package.get("latest") or {}
    published = latest.get("published") or ""
    issue["_actual_published"] = published[:10] if published else ""
    issue["_actual_version"] = latest.get("version", "")
    # pub.dev's score API has no top-level "isDiscontinued" boolean — discontinued
    # status is signaled via "is:discontinued" in the tags array (confirmed against
    # the `pedantic` package, which pub.dev explicitly marks discontinued).
    issue["_is_discontinued"] = "is:discontinued" in (score.get("tags") or [])
    return issue, False


def load_known_issues(project_dir: Path) -> list[dict]:
    """Load known_issues.json's ``issues`` list, or ``[]`` if the file is
    missing (a fresh checkout before the extension has been built, or a
    project_dir that isn't the repo root)."""
    known_issues_path = project_dir / KNOWN_ISSUES_RELATIVE_PATH
    if not known_issues_path.exists():
        return []
    with known_issues_path.open(encoding="utf-8") as f:
        data = json.load(f)
    return data.get("issues", [])


def fetch_pubdev_candidates(
    candidates: list[dict],
    *,
    timeout: float,
    max_workers: int,
) -> tuple[list[dict], int]:
    """Fetch pub.dev data for each candidate concurrently. Returns
    (successfully-fetched issues, network_error_count) — issues that hit a
    network error are dropped rather than returned with stale/absent
    ``_actual_*`` fields, so callers never need to re-check the error flag.

    Public and shared between ``check_known_issues_freshness`` (narrow,
    keyword-matched subset) and ``_known_issues_review_report`` (broad,
    all-reviewable-status set) so a caller that needs both results — the
    publish pipeline — can fetch the union of candidates once instead of
    each function independently re-fetching the ~70 entries they have in
    common. See ``run_known_issues_checks`` for that combined pass.
    """
    checked_ok: list[dict] = []
    network_error_count = 0
    with ThreadPoolExecutor(max_workers=max_workers) as ex:
        checked = list(
            ex.map(lambda issue: check_pubdev_data(issue, timeout), candidates)
        )
    for issue, network_error in checked:
        if network_error:
            network_error_count += 1
        else:
            checked_ok.append(issue)
    return checked_ok, network_error_count


def _is_falsifiable_keyword_match(issue: dict) -> bool:
    reason = issue.get("reason", "").lower()
    return any(kw in reason for kw in FALSIFIABLE_KEYWORDS)


def is_outgrown(issue: dict) -> bool:
    """True if a fetched issue's recorded claim is contradicted by pub.dev:
    a later release exists and the package isn't discontinued."""
    recorded = issue["lastUpdated"]
    actual = issue.get("_actual_published", "")
    return bool(actual) and actual > recorded and not issue.get("_is_discontinued")


def freshness_result_from_fetched(
    fetched: list[dict], network_error_count: int
) -> KnownIssuesFreshnessResult:
    """Derive a freshness result from an already-fetched candidate set,
    narrowing to the falsifiable-keyword subset. Shared by
    ``check_known_issues_freshness`` and ``run_known_issues_checks`` so both
    apply the identical keyword/staleness rule to whatever candidates they
    fetched."""
    keyword_matched = [
        i
        for i in fetched
        if i.get("status") in CHECKABLE_LIFECYCLE_STATUSES
        and _is_falsifiable_keyword_match(i)
    ]
    result = KnownIssuesFreshnessResult(
        checked_count=len(keyword_matched),
        network_error_count=network_error_count,
    )
    for issue in keyword_matched:
        if is_outgrown(issue):
            result.confirmed_stale.append(
                {
                    "name": issue["name"],
                    "status": issue["status"],
                    "reason": issue["reason"],
                    "recorded_lastUpdated": issue["lastUpdated"],
                    "actual_latest_published": issue.get("_actual_published", ""),
                    "actual_latest_version": issue.get("_actual_version", ""),
                }
            )
    return result


def check_known_issues_freshness(
    project_dir: Path,
    *,
    timeout: float = 15.0,
    max_workers: int = 20,
) -> KnownIssuesFreshnessResult:
    """Cross-check checkable known_issues.json entries against pub.dev.

    Network failures for individual packages are counted but non-fatal —
    a pub.dev outage or CI network restriction shouldn't block publish, it
    just means fewer entries got re-verified this run.
    """
    issues = load_known_issues(project_dir)
    candidates = [
        issue
        for issue in issues
        if issue.get("status") in CHECKABLE_LIFECYCLE_STATUSES
        and issue.get("lastUpdated")
        and _is_falsifiable_keyword_match(issue)
    ]
    fetched, network_error_count = fetch_pubdev_candidates(
        candidates, timeout=timeout, max_workers=max_workers
    )
    return freshness_result_from_fetched(fetched, network_error_count)
