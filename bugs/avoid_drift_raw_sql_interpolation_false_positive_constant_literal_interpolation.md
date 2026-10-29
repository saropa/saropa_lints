# BUG: `avoid_drift_raw_sql_interpolation` — flags interpolation of compile-time constant literals

**Status: Open**

Created: 2026-10-28
Rule: `avoid_drift_raw_sql_interpolation`
File: `lib/src/rules/packages/drift_rules.dart` (line ~1176)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

The rule flags `customStatement('... $x ...')` even when `$x` can only be a string from a constant literal list. No user input reaches the SQL. It should not report when every interpolated value is a compile-time constant or a loop variable over a constant list of literals.

---

## Attribution Evidence

```bash
grep -rn "'avoid_drift_raw_sql_interpolation'" lib/src/rules/
# lib/src/rules/packages/drift_rules.dart:1176:    'avoid_drift_raw_sql_interpolation',
```

---

## Reproducer

```dart
Future<void> migrate() async {
  for (final String column in <String>['narrative_saved_text', 'narrative_source_hash']) {
    await customStatement('ALTER TABLE contacts ADD COLUMN $column TEXT'); // LINT — but should NOT lint
  }
}

Future<void> add(String definition) async {
  await customStatement('ALTER TABLE t ADD COLUMN $definition'); // LINT — but should NOT lint when every caller passes a literal
}

Future<void> run() async {
  await add('a TEXT');
  await add('b INTEGER');
}
```

**Frequency:** Always for interpolation of constant-origin values.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. Values are compile-time constants (loop over a literal list) |
| **Actual** | `[avoid_drift_raw_sql_interpolation]` reported at the interpolated statement |

---

## Suggested Fix

Skip when each interpolation expression is a const expression, a for-each variable over a literal list of string literals, or a private-method parameter whose in-file callers all pass literals. Ignore migration files if needed.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/database/drift/migration_steps/migration_steps_v77.dart:9`, `lib/database/drift/migration_steps/migration_steps_v79.dart:13`

## Status 2026-10-28

drift: private-method parameter case not implemented.
