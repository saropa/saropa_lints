# BUG: `avoid_global_state` — False positive on analyzer plugin cache/config globals

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_global_state`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (grep for exact line)
Severity: False positive
Rule version: v5

---

## Summary

The rule fires 21 times on top-level mutable variables. All are intentional and fall into two categories:

1. **Lazy-init-once caches** (effectively final after first access): `_tierIndex`, `_ruleMetadataCache`, `_resolvedVersion` — use `??=` or set-once-in-init pattern. Thread-safe in Dart's single-isolate analyzer plugin model.

2. **Config/cache globals with explicit invalidation**: `_crossFileSnapKey`/`_crossFileSnap` (has `clearCrossFileSnapshotCache()`), pubspec lock resolver vars (has `clearPubspecLockResolverCacheForTests()`), `_cachedFilteredRules` + key fields, `_activeLane`, `maxDeclarationsPerFile`, `bannedUsageEntries` — all part of the documented plugin-config-reload lifecycle.

The rule's concern about "race conditions in concurrent code" does not apply: `custom_lint` analyzer plugins run single-threaded in one isolate. The "hidden dependencies" concern is mitigated by the project's `ProjectContext` cache architecture, which documents these as intentional shared state.

---

## Attribution Evidence

```bash
grep -rn "'avoid_global_state'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:NNNN:    'avoid_global_state',
```

---

## Reproducer

```dart
// Pattern 1: Lazy-init-once cache (effectively final)
Map<String, int>? _tierIndex;
Map<String, int> get tierIndex => _tierIndex ??= _buildTierIndex();
// LINT on `_tierIndex` — but should NOT lint (set once, never reassigned)

// Pattern 2: Config global with clear hook
List<BannedUsageEntry> bannedUsageEntries = [];
void loadBannedUsageConfig(YamlMap config) {
  bannedUsageEntries = _parseEntries(config);
}
// LINT — but should NOT lint (single-threaded plugin config lifecycle)
```

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on lazy caches with `??=` or globals with explicit clear/reload hooks in single-threaded plugins |
| **Actual** | `[avoid_global_state] Mutable global state detected` on all 21 variables |

---

## Suggested Fix

1. Exempt variables that are only assigned via `??=` (lazy-init-once, effectively final).
2. Exempt variables that have a corresponding `clear*()` or `reset*()` function in the same file (indicates deliberate lifecycle management).
3. Consider a package-type exemption for analyzer plugins.

---

## Affected Files

- `max_declarations_config.dart:18,26` — config globals
- `rule_tier_index.dart:28` — lazy cache
- `banned_usage_config.dart:36` — config global
- `project_context_cross_file.dart:47,48` — keyed cache with clear hook
- `pubspec_lock_resolver.dart:91-97` — 6 vars with `clearForTests()`
- `rule_metadata.dart:108` — lazy cache
- `rule_lane.dart:113,117` — config globals
- `saropa_lints.dart:150,2964,3222,3225,3228,3232` — lazy caches and filtered-rule cache

---

## Environment

- saropa_lints version: current (unreleased)
