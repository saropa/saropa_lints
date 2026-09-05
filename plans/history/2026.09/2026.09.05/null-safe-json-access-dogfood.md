# Null-Safe JSON Access Dogfood Fix

Three internal files (`asset_scanner.dart`, `health_cache.dart`, `saropa_lint_rule.dart`) violated the project's own `require_null_safe_json_access` and `avoid_unsafe_cast` lint rules. Fixed by replacing direct `as` casts with type-checked locals and null-coalescing fallbacks.

## Finish Report (2026-09-05)

### What changed

- **`asset_scanner.dart`** — Split compound `is!` guards (`doc['flutter'] is! YamlMap`) into separate `is!` checks with local variables, eliminating the redundant `as YamlMap` / `as YamlList` casts that followed the guard.
- **`health_cache.dart`** — `CacheEntry.fromJson`: replaced `(j['hash'] as num).toInt()` and `(j['complexity'] as Map)` with `is` type checks and safe fallbacks (zeroed `FileComplexity` if corrupt). `loadComplexityCache`: replaced `jsonDecode(...) as Map<String, Object?>` with an `is!` guard; iterated entries via a local variable for type promotion instead of `(e.value! as Map)`. Added explicit `<String, CacheEntry>{}` type annotations on empty map returns to fix `avoid_misused_set_literals`. Suppressed `avoid_platform_specific_imports` (CLI-only file) and `require_catch_logging` (intentionally silent corrupt-cache fallback) with inline ignores and rationale comments.
- **`saropa_lint_rule.dart`** — Changed `memStats['estimatedUsageMb'] as int` and `memStats['relieveCount'] as int` to `as int?` with `?? 0` fallback.

### Hardening pass

- Verified `// ignore:` directive syntax matches the established project pattern (confirmed via grep of `lib/src/`).
- Verified Dart type promotion works correctly for: local variable `v` in `loadComplexityCache`'s for-loop, and `rawComplexity` / `rawHash` in `CacheEntry.fromJson`'s ternary expressions.
- Verified `worstLcom: 0` is acceptable — `FileComplexity.fromJson` already defaults it to `0`.
- Added `FileComplexity.zero` static const — single source of truth for the all-zero fallback, used in `CacheEntry.fromJson` and available for future callers.

### Risk assessment

All changes are cast-mechanism refactors — the runtime behavior on valid data is identical. The defensive fallbacks only activate on corrupt or missing cache data, where the prior code would have thrown.
