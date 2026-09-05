# BUG: `avoid_unsafe_cast` — False positive on casts guarded by type checks or encoding guarantees

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_unsafe_cast`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (grep for exact line)
Severity: False positive
Rule version: v5

---

## Summary

The rule fires 11 times. 10 are false positives, 1 is real (filed separately as a code fix).

**FP pattern 1 — `Process.runSync().stdout as String` (8 instances):** When `Process.runSync` is called with `stdoutEncoding: utf8` (or `systemEncoding`), `stdout` is guaranteed to be `String` at runtime even though the declared type is `dynamic`. The rule does not trace the encoding argument.

**FP pattern 2 — Cast preceded by type check (2 instances):** `cross_file_options_config.dart:80` casts `value as List` after an explicit `value is YamlList || value is List` check. `audit_baseline.dart:42` is the one REAL issue (no guard).

---

## Attribution Evidence

```bash
grep -rn "'avoid_unsafe_cast'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:NNNN:    'avoid_unsafe_cast',
```

---

## Reproducer

```dart
// FP pattern 1: Process.runSync with encoding guarantee
final result = Process.runSync('git', ['log'],
    stdoutEncoding: utf8); // stdout is String, not dynamic
final output = result.stdout as String; // LINT — but should NOT lint

// FP pattern 2: Type check before cast
if (value is YamlList || value is List) {
  final items = value as List; // LINT — but should NOT lint (just checked)
}
```

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the cast is provably safe via preceding check or API guarantee |
| **Actual** | `[avoid_unsafe_cast] Direct cast with "as" may throw at runtime` |

---

## Suggested Fix

1. If an `as` cast is preceded by an `is` check on the same variable for a compatible type in the same scope/block, suppress.
2. Consider a special case for `ProcessResult.stdout`/`.stderr` when the enclosing `Process.runSync` call passes an encoding argument (hard, may not be worth it).

---

## Affected Files (FP only — the real issue at audit_baseline.dart:42 is a separate code fix)

- `git_changed_files.dart:32,46`
- `coverage_rollup.dart:36`
- `temporal_coupling.dart:51,67`
- `git_signals.dart:46,60`
- `cross_file_options_config.dart:80`
- `health_history.dart:127,213`

---

## Environment

- saropa_lints version: current (unreleased)
