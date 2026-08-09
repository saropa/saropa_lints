# Fix health_history_test timeout

The `health_history_test.dart` "builds well-formed trajectory points from git tags" test timed out at 2 minutes. Root cause: `loadHealthHistory` hardcoded `withComplexity: true` in its `runSizeScan` call, forcing a full AST parse + cognitive-complexity walk of every Dart file in each archived tag tree. For a 2300+ rule project, two tags exceeded the budget.

## Finish Report (2026-08-08)

**Defect:** `loadHealthHistory` unconditionally enabled complexity scanning, making the history test O(files × tags) in parse cost — far exceeding the 2-minute test timeout on large repos.

**Fix:** Added an optional `withComplexity` parameter to `loadHealthHistory` (default `true`, preserving production behavior). The test now passes `withComplexity: false` since it only validates `HistoryPoint` structure, not complexity values. Runtime dropped from >2 minutes to ~9 seconds.

**Files changed:**
- `lib/src/cli/project_health/health_history.dart` — new `withComplexity` param, forwarded to `SizeScanOptions`
- `test/project_health/health_history_test.dart` — passes `withComplexity: false`
- `CHANGELOG.md` — Unreleased entry

**Verification:** `dart test test/project_health/health_history_test.dart` — 4/4 passed (9s).

## Finish Report (2026-08-08, hardening pass)

Reflection gate raised two concerns: whether production call sites (which don't pass `withComplexity`) still get complexity data, and whether repeat test runs could be made faster.

**Verified:** `bin/project_health.dart:145` calls `loadHealthHistory(cli.path)` with no `withComplexity` argument, so it uses the default `true` — production behavior unaffected by the new parameter.

**Added:** an on-disk cache (`_HistoryCache` in `health_history.dart`) keyed by `<tagCommitSha>_<withComplexity>`, stored at `.dart_tool/saropa_lints/health_history_cache.json` (gitignored via the existing `.dart_tool/` rule). Tags resolve to their commit SHA via `git rev-list -n 1 <tag>`; a SHA hit skips archiving and scanning entirely and reuses the cached `HistoryPoint`. Tags are immutable in normal use, so this is safe; a moved tag simply produces a new cache key and recomputes.

**Verification:**
- Cold run: `dart test test/project_health/health_history_test.dart` — 4/4 passed, ~9s (history test).
- Warm run (cache populated): same test — 4/4 passed, history test dropped to ~0s (12.5s → 2.8s total suite wall time, dominated by VM startup).
- Regression check: `dart test test/project_health/` — full directory, 125/125 passed.
- Non-git-directory test confirmed no cache file is written when `_recentTags` returns empty (cache `persist()` is a no-op when nothing was cached).
