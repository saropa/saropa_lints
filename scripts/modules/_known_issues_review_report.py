"""Generate a manual-review report for known_issues.json entries pub.dev has
outgrown but that ``check_known_issues_freshness`` can't auto-classify as false.

``check_known_issues_freshness`` only flags entries where the reason text uses
a claim class a newer non-discontinued release directly falsifies (abandoned,
pre-null-safety, ...). Everything else that pub.dev shows as "package moved
on since this entry was recorded" still needs a human to read the reason and
decide, because a patch release doesn't by itself disprove a licensing claim
("commercial trap") or a specific unpatched CVE. This module produces the
triage list for that manual pass, grouped by how confidently a reviewer
should expect a re-write or removal is warranted, so working through the
backlog is a prioritized queue instead of an undifferentiated 159-entry dump.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from scripts.modules._known_issues_freshness import (
    CHECKABLE_LIFECYCLE_STATUSES,
    FALSIFIABLE_KEYWORDS,
    KnownIssuesFreshnessResult,
    fetch_pubdev_candidates,
    freshness_result_from_fetched,
    is_outgrown,
    load_known_issues,
)

# Business-model statuses: a continued release doesn't disprove a licensing
# claim, so these are surfaced at low confidence for a manual reread of the
# vendor's current terms rather than treated as likely-stale.
_BUSINESS_MODEL_STATUSES = {
    "commercial_trap",
    "commercial",
    "freemium",
    "paid",
    "enterprise",
}

_REVIEWABLE_STATUSES = CHECKABLE_LIFECYCLE_STATUSES | _BUSINESS_MODEL_STATUSES

# Order defines report section order, high confidence first.
_TIER_ORDER = ("high", "medium", "low")
_TIER_TITLES = {
    "high": "HIGH confidence — reason contradicted by current pub.dev data",
    "medium": "MEDIUM confidence — lifecycle claim, package still releasing",
    "low": "LOW confidence — business-model claim, verify terms manually",
}
_TIER_ACTIONS = {
    "high": "Likely safe to remove or rewrite the reason — same pattern as the "
    "7 entries fixed 2026-08-18.",
    "medium": "Reread the reason against the package's current state; a release "
    "doesn't disprove e.g. a specific unfixed bug, but often the "
    "underlying complaint has moved on too.",
    "low": "Release cadence is not evidence here — check pricing/license page "
    "directly before touching the entry.",
}


@dataclass
class ReviewEntry:
    name: str
    status: str
    reason: str
    recorded_last_updated: str
    actual_latest_published: str
    actual_latest_version: str
    tier: str


@dataclass
class KnownIssuesReviewReport:
    checked_count: int = 0
    network_error_count: int = 0
    entries: list[ReviewEntry] = field(default_factory=list)

    def by_tier(self, tier: str) -> list[ReviewEntry]:
        return [e for e in self.entries if e.tier == tier]


def _classify_tier(issue: dict) -> str:
    status = issue["status"]
    if status in CHECKABLE_LIFECYCLE_STATUSES:
        has_keyword = any(
            kw in issue.get("reason", "").lower() for kw in FALSIFIABLE_KEYWORDS
        )
        return "high" if has_keyword else "medium"
    return "low"  # business-model status


def _review_report_from_fetched(
    fetched: list[dict], network_error_count: int, *, checked_count: int
) -> KnownIssuesReviewReport:
    """Derive a review report from an already-fetched candidate set. Shared
    by ``build_known_issues_review_report`` and ``run_known_issues_checks``
    so both apply the identical outgrown/tier rule to whatever candidates
    they fetched."""
    report = KnownIssuesReviewReport(
        checked_count=checked_count, network_error_count=network_error_count
    )
    for issue in fetched:
        if not is_outgrown(issue):
            continue  # not outgrown by pub.dev's account — nothing to review
        report.entries.append(
            ReviewEntry(
                name=issue["name"],
                status=issue["status"],
                reason=issue.get("reason", ""),
                recorded_last_updated=issue["lastUpdated"],
                actual_latest_published=issue.get("_actual_published", ""),
                actual_latest_version=issue.get("_actual_version", ""),
                tier=_classify_tier(issue),
            )
        )
    report.entries.sort(key=lambda e: (_TIER_ORDER.index(e.tier), e.name))
    return report


def build_known_issues_review_report(
    project_dir: Path,
    *,
    timeout: float = 15.0,
    max_workers: int = 20,
) -> KnownIssuesReviewReport:
    """Cross-check every reviewable known_issues.json entry against pub.dev
    and classify pub.dev-outgrown entries into HIGH/MEDIUM/LOW confidence
    tiers for manual triage. See module docstring for the tier definitions.
    """
    issues = load_known_issues(project_dir)
    # Skip version-scoped entries — they warn only about old package versions
    # and a newer pub.dev release doesn't invalidate them.
    candidates = [
        issue
        for issue in issues
        if issue.get("status") in _REVIEWABLE_STATUSES
        and issue.get("lastUpdated")
        and not issue.get("appliesToMaxVersion")
    ]
    fetched, network_error_count = fetch_pubdev_candidates(
        candidates, timeout=timeout, max_workers=max_workers
    )
    return _review_report_from_fetched(
        fetched, network_error_count, checked_count=len(candidates)
    )


def run_known_issues_checks(
    project_dir: Path,
    *,
    timeout: float = 15.0,
    max_workers: int = 20,
) -> tuple[KnownIssuesFreshnessResult, KnownIssuesReviewReport]:
    """Run the freshness check and the review-report scan as a single pub.dev
    fetch pass over the union of both candidate sets.

    ``check_known_issues_freshness`` (narrow, ~70 keyword-matched entries)
    and ``build_known_issues_review_report`` (broad, ~302 all-reviewable
    entries) overlap almost entirely — every freshness candidate is also a
    review candidate. Calling both independently fetches the overlapping
    entries twice; this fetches the review candidate set once (a superset)
    and derives both results from it, so the publish pipeline pays for one
    ~302-entry pass instead of 70 + 302. Used by the publish pipeline, which
    needs both the pass/warn gate line and a fresh ``known_issues_review.md``
    on every run — see ``scripts/modules/_publish_steps.py``.
    """
    issues = load_known_issues(project_dir)
    # Skip version-scoped entries — see build_known_issues_review_report.
    candidates = [
        issue
        for issue in issues
        if issue.get("status") in _REVIEWABLE_STATUSES
        and issue.get("lastUpdated")
        and not issue.get("appliesToMaxVersion")
    ]
    fetched, network_error_count = fetch_pubdev_candidates(
        candidates, timeout=timeout, max_workers=max_workers
    )
    # network_error_count here is for the full review candidate set, not
    # just the freshness subset (70) — the combined fetch can't attribute a
    # given failure to one subset or the other. Cosmetic only: it can only
    # over-report freshness's error count relative to a standalone run, never
    # under-report a real stale entry, since staleness is only ever derived
    # from candidates that were actually fetched successfully.
    freshness = freshness_result_from_fetched(fetched, network_error_count)
    review = _review_report_from_fetched(
        fetched, network_error_count, checked_count=len(candidates)
    )
    return freshness, review


def render_markdown(report: KnownIssuesReviewReport, *, generated_on: str) -> str:
    """Render the report as a Markdown triage list, one section per tier."""
    lines = [
        "# known_issues.json manual review queue",
        "",
        f"Generated {generated_on}. Checked {report.checked_count} "
        f"lifecycle/business-model entries against live pub.dev "
        f"({report.network_error_count} network error(s)); "
        f"{len(report.entries)} appear outgrown by a newer release.",
        "",
        "Each entry needs a human read of the current reason against the "
        "package's present state before editing `known_issues.json` — this "
        "report does not edit the file.",
        "",
    ]
    for tier in _TIER_ORDER:
        entries = report.by_tier(tier)
        lines.append(f"## {_TIER_TITLES[tier]} ({len(entries)})")
        lines.append("")
        lines.append(f"**Suggested action:** {_TIER_ACTIONS[tier]}")
        lines.append("")
        if not entries:
            lines.append("_None._")
            lines.append("")
            continue
        for e in entries:
            lines.append(
                f"- **`{e.name}`** ({e.status}) — recorded "
                f"`{e.recorded_last_updated}`, pub.dev latest "
                f"`{e.actual_latest_published}` (v{e.actual_latest_version}). "
                f"[pub.dev](https://pub.dev/packages/{e.name})"
            )
            lines.append(f"  - Current reason: {e.reason}")
        lines.append("")
    return "\n".join(lines)
