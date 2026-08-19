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

import json
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

# Statuses that make an "avoid this package" claim worth re-verifying.
# "active"/"freemium"/"paid"/etc. aren't lifecycle claims a release can falsify.
_CHECKABLE_STATUSES = {"end_of_life", "caution", "maintenance_mode"}

# Reason-text fragments that a continued, non-discontinued release directly
# contradicts. Keep narrow — this drives a build-gate warning, so false
# positives here erode trust in the check.
_FALSIFIABLE_KEYWORDS = (
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

_KNOWN_ISSUES_RELATIVE_PATH = Path(
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
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:  # noqa: S310 (pub.dev, fixed host)
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, ValueError, OSError):
        return None


def _check_one(issue: dict, timeout: float) -> tuple[dict, bool]:
    """Return (issue, network_error) — issue is unchanged; caller decides staleness."""
    name = issue["name"]
    package = _fetch_json(f"https://pub.dev/api/packages/{name}", timeout)
    if package is None:
        return issue, True
    score = _fetch_json(f"https://pub.dev/api/packages/{name}/score", timeout)
    latest = package.get("latest", {})
    published = latest.get("published", "")
    issue["_actual_published"] = published[:10] if published else ""
    issue["_actual_version"] = latest.get("version", "")
    issue["_is_discontinued"] = bool(score.get("isDiscontinued")) if score else False
    return issue, False


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
    result = KnownIssuesFreshnessResult()
    known_issues_path = project_dir / _KNOWN_ISSUES_RELATIVE_PATH
    if not known_issues_path.exists():
        return result

    with known_issues_path.open(encoding="utf-8") as f:
        data = json.load(f)

    candidates = [
        issue
        for issue in data.get("issues", [])
        if issue.get("status") in _CHECKABLE_STATUSES
        and issue.get("lastUpdated")
        and any(kw in issue.get("reason", "").lower() for kw in _FALSIFIABLE_KEYWORDS)
    ]
    result.checked_count = len(candidates)

    with ThreadPoolExecutor(max_workers=max_workers) as ex:
        checked = list(
            ex.map(lambda issue: _check_one(issue, timeout), candidates)
        )

    for issue, network_error in checked:
        if network_error:
            result.network_error_count += 1
            continue
        recorded = issue["lastUpdated"]
        actual = issue.get("_actual_published", "")
        if actual and actual > recorded and not issue.get("_is_discontinued"):
            result.confirmed_stale.append(
                {
                    "name": issue["name"],
                    "status": issue["status"],
                    "reason": issue["reason"],
                    "recorded_lastUpdated": recorded,
                    "actual_latest_published": actual,
                    "actual_latest_version": issue.get("_actual_version", ""),
                }
            )

    return result
