# Known-issues database: stale end-of-life entries

The extension's Package Dashboard known-issues database (`extension/src/vibrancy/data/known_issues.json`) contained hand-curated entries whose `status`/`reason` fields were not refreshed as flagged packages continued to receive releases. The `timezone` package was reported as "Pre-null-safety; blocks Dart 3 compilation entirely" despite shipping a null-safe, Dart-3-compatible release five months prior to the check.

## Investigation

An automated audit script queried the live pub.dev API (`GET /api/packages/{name}` and `/score`) for all 504 entries in `known_issues.json`, comparing each entry's recorded `lastUpdated` date against the package's actual latest-release publish date.

Results:
- 504 entries total.
- 166 entries had a pub.dev release newer than the recorded `lastUpdated` (the majority — a patch release doesn't necessarily disprove the entry's stated reason, e.g. licensing/commercial-trap claims).
- 15 entries were "not found" on pub.dev by design — synthetic version-pinned names (`cached_network_image_v1`, etc.) used for historical tracking, and Flutter SDK packages (`flutter_localizations`, `flutter_web_plugins`) not published on pub.dev's package API.
- 7 entries had a reason directly and unambiguously contradicted by the current release (pub.dev score API confirms `isDiscontinued: null` and full/near-full pub points on all 7): `timezone`, `retrofit`, `sqflite_sqlcipher`, `intl_translation`, `window_size`, `routemaster`, `flutter_keychain`.

## Fix

Removed the 7 confirmed-stale entries from `known_issues.json` (504 → 497 entries). Verified the file remains valid JSON and that no TypeScript test in `extension/src/test/vibrancy/` asserts on any of the removed package names (a `timezone` string appears in `floor-constraints.test.ts` and `constraint-notes.test.ts`, but only as a generic dependency-name fixture unrelated to `known_issues.json`).

The remaining 159 stale-but-unverified entries were intentionally left untouched — pending manual review of whether each package's continued releases actually addressed the stated reason (e.g., a security-CVE reason needs the CVE checked, not just "package still gets patches"). Full comparison data was written to a scratch report during the session and was not persisted to the repo.

## Root cause

`known_issues.json` is static, hand-curated data with no automated freshness check against pub.dev. Nothing in CI or the build re-verifies entries against live package state, so an entry can silently go stale indefinitely once the flagged package's underlying issue is fixed upstream.

## Follow-up: automated freshness gate

The ad hoc audit logic was promoted into a reusable check:

- `scripts/modules/_known_issues_freshness.py` — `check_known_issues_freshness()`. Restricted to `end_of_life`/`caution`/`maintenance_mode` entries whose `reason` text uses one of a narrow set of falsifiable claim keywords (`abandon`, `unmaintain`, `discontinu`, `pre-null`, `blocks dart`, `dead package`, `archived`, etc.) — the same class of claim that made the original 7 entries wrong. A candidate is flagged only when pub.dev shows a release published after the entry's recorded `lastUpdated` AND the package's pub.dev score does not report `isDiscontinued`.
- `scripts/check_known_issues_freshness.py` — standalone CLI wrapping the same function (`--fail-on-stale` for scripted/CI use; default run is report-only).
- Wired into `scripts/modules/_publish_steps.py::run_pre_publish_audits()` as a non-blocking (`warn`) entry in the existing audit's `extra_checks` list, so every publish run reports the finding without depending on a third-party API for a hard gate.

Re-running the check against the post-fix `known_issues.json` found 70 lifecycle-claim entries eligible for the keyword check and 0 remaining confirmed-stale — the 7 removed entries were the full extent of what this heuristic catches. The other ~159 entries flagged by the broader "any newer release" sweep during investigation (e.g. `commercial_trap`, `paid`, or reasons without a falsifiable keyword) are out of this check's scope by design — a patch release doesn't by itself disprove a licensing or CVE claim, so they require manual review, not automation.

A bug surfaced while implementing this: pub.dev's `/score` endpoint has no top-level `isDiscontinued` boolean field — discontinued status is signaled by `"is:discontinued"` inside the response's `tags` array. The first implementation checked a field that never exists, so the discontinued corroboration silently always evaluated `False`. Confirmed against `pedantic` (a package pub.dev explicitly marks discontinued) before and after the fix. A related fix: when the `/score` fetch fails independently of the `/package` fetch, the candidate is now treated as a network error (skip), not as "not discontinued" — the earlier version would have let a dropped score request turn a genuinely discontinued package into a false "confirmed stale" warning.

## Follow-up: manual-review triage report

`scripts/generate_known_issues_review.py` (backed by `scripts/modules/_known_issues_review_report.py`) extends the same pub.dev cross-check to every `end_of_life`/`caution`/`maintenance_mode`/business-model-status entry, not just the keyword-matched subset, and classifies pub.dev-outgrown entries into HIGH/MEDIUM/LOW confidence tiers instead of leaving the backlog as an undifferentiated list. Written to `plans/known_issues_review.md` (regenerate with `--write`). Current run: 302 reviewable entries checked, 49 outgrown by a newer release (0 HIGH, 34 MEDIUM — lifecycle claims worth a reread, 15 LOW — business-model/licensing claims a release doesn't disprove). This report does not edit `known_issues.json`; each entry needs a human read of the current reason before acting.

Also noticed but out of scope for this change: `known_issues.json` has a duplicate `flutter_local_notifications` entry (two objects, different `reason` text) and at least two entries with an empty `reason` string (`better_player`, `flutter_vibrate`) — both pre-existing data-quality issues unrelated to staleness.

## Follow-up: review-report wired into publish, not left standalone

`scripts/generate_known_issues_review.py` initially shipped as a manually-invoked-only script — explicitly rejected as an "orphan script" and required to be integrated into the real publish pipeline instead of just existing as a runnable tool.

Rather than adding a second, independent ~302-entry pub.dev scan to every publish (on top of the freshness check's existing ~70-entry scan — the two candidate sets overlap almost entirely), `_known_issues_freshness.py` and `_known_issues_review_report.py` were refactored to share one fetch pass: `run_known_issues_checks()` in `_known_issues_review_report.py` loads the full reviewable candidate set (302, a superset of the freshness check's 70), fetches pub.dev data for it once, and derives both the freshness result and the review report from that single fetch. `scripts/modules/_publish_steps.py::run_pre_publish_audits()` now calls `run_known_issues_checks()` and regenerates `plans/known_issues_review.md` on every publish (still non-blocking — wrapped in the same `try/except` pattern as the freshness check, since a disk-write failure or pub.dev outage must not stop a release). Live smoke test against pub.dev: 4.4s for the combined 302-entry pass, well within the bounded worst case.

As part of this refactor, `_known_issues_review_report.py`'s underscore-prefixed cross-module imports (`_FALSIFIABLE_KEYWORDS`, `_KNOWN_ISSUES_RELATIVE_PATH`, `_check_one`) were promoted to an explicit public surface in `_known_issues_freshness.py` (`FALSIFIABLE_KEYWORDS`, `KNOWN_ISSUES_RELATIVE_PATH`, `check_pubdev_data`, plus new `load_known_issues`/`fetch_pubdev_candidates`/`is_outgrown`/`freshness_result_from_fetched` helpers), closing the "reaches into private names" gap flagged in the code review.

Test coverage was added: `scripts/modules/tests/test_known_issues_freshness.py` and `test_known_issues_review_report.py` (21 tests), covering the discontinued-tag detection, the network-error-vs-false distinction on a failed `/score` fetch, the staleness/outgrown predicate, the candidate-filtering pipeline, and — the core contract of this integration — that `run_known_issues_checks()` calls the pub.dev fetch exactly once for the union of both candidate sets, not once per check. All mock the fetch boundary; no test hits the network.

## Known limitations (still not addressed)

- The freshness/review check has no opt-out flag if a developer wants to skip it on a specific publish run.
- No caching between repeated publish attempts in one session — each re-fetches identical pub.dev data from scratch.
- `network_error_count` doesn't distinguish 404/429/timeout — a systemic pub.dev rate-limit would look identical to isolated flakiness.
- `_VALID_PUBDEV_NAME` regex (`^[a-z0-9_]+$`) doesn't enforce pub.dev's "must start with a letter" rule — harmless (invalid names just fall into the network-error bucket).
- The duplicate `flutter_local_notifications` entry and the two empty-`reason` entries (`better_player`, `flutter_vibrate`) noted above are still unfixed — pre-existing data-quality issues unrelated to staleness.
