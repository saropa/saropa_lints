# BUG: `require_cache_expiration` + `avoid_unbounded_cache_growth` — False positive on content-addressed and bounded caches

**Status: Fixed**

Created: 2026-09-05
Rule: `require_cache_expiration`, `avoid_unbounded_cache_growth`
Severity: False positive
Rule version: v3/v4

---

## Summary

All 5 findings are false positives in the context of a single-invocation CLI tool:

1. **`health_history.dart:135` (`_HistoryCache`)** — Both rules fire. Cache is keyed by `<commitSha>_<withComplexity>`, content-addressed (never stale). Growth bounded by number of git tags in the repo. The CLI process exits after one run — no long-lived memory concern.

2. **`baseline_date.dart:318` (`_FileDateCache`)** — `require_cache_expiration` fires. Per-file map bounded by line count. Staleness handled via content-hash invalidation one level up (documented in class doc comment).

3. **`project_vibrancy.dart:1326` (`_ProjectVibrancyCache`)** — Both rules fire. Content-addressed by blob hash / lcov fingerprint — stale entries are impossible by design. Growth is in an on-disk JSON file, not process RAM.

The rules' threat model (OOM on mobile, stale data in long-lived services) does not apply to a short-lived CLI tool with content-addressed caching.

---

## Attribution Evidence

```bash
grep -rn "'require_cache_expiration'" lib/src/rules/
grep -rn "'avoid_unbounded_cache_growth'" lib/src/rules/
# (matches in respective rule files)
```

---

## Suggested Fix

1. Exempt content-addressed caches (keyed by hash/fingerprint) from `require_cache_expiration` — they cannot serve stale data.
2. Consider package-type awareness for `avoid_unbounded_cache_growth` — short-lived CLI processes do not have the OOM risk of long-running services or mobile apps.

---

## Affected Files

- `health_history.dart:135`
- `baseline_date.dart:318`
- `project_vibrancy.dart:1326`

---

## Environment

- saropa_lints version: current (unreleased)

---

## Fix

`lib/src/rules/resources/memory_management_rules.dart`: both rules now skip a
class when `classSource` matches `_isContentAddressedCacheKey` (hash / sha /
fingerprint / digest / content_key), when `context.filePath` sits under a
`bin/`/`tool/` directory (`_isInShortLivedToolDirectory`, on top of the
existing whole-package `ProjectContext.isCliOrToolPackage` check), or when
the enclosing compilation unit contains an explicit `.clear()` call anywhere
in the file (`_fileHasExplicitCacheClear`). GOOD fixture cases added to
`example/lib/memory_management/require_cache_expiration_fixture.dart`,
`example/lib/memory_management/avoid_unbounded_cache_growth_fixture.dart`,
and `example/lib/memory/avoid_unbounded_cache_growth_fixture.dart`.
