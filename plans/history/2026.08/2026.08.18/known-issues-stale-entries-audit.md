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
