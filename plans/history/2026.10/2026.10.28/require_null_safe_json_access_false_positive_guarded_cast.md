# BUG: `require_null_safe_json_access` — flags casts already guarded by `is` check or prior assignment

**Status: Open**

Created: 2026-10-28
Rule: `require_null_safe_json_access`
File: `lib/src/rules/data/type_safety_rules.dart` (line ~1389)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

The rule flags map-index casts that cannot be null or wrong-typed: (1) `m['k'] is bool ? m['k'] as bool : null`, where the `is` test guards the cast; (2) `(m['k'] as Map)[...] = x` one statement after `m['k'] = value` assigned the key.

---

## Attribution Evidence

```bash
grep -rn "'require_null_safe_json_access'" lib/src/rules/
# lib/src/rules/data/type_safety_rules.dart:1389:    'require_null_safe_json_access',
```

---

## Reproducer

```dart
bool? readShowYears(Map<String, dynamic> decoded) {
  return decoded['show_years'] is bool ? decoded['show_years'] as bool : null; // LINT — but should NOT lint
}

void addIdentifiers(Map<dynamic, dynamic> trimmed, Map<dynamic, dynamic> android) {
  trimmed['android'] = Map<dynamic, dynamic>.of(android);
  (trimmed['android'] as Map<dynamic, dynamic>)['identifiers'] = 1; // LINT — but should NOT lint (key assigned above)
}
```

**Frequency:** Always for these two patterns.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[require_null_safe_json_access]` on the cast |

---

## Suggested Fix

Skip a cast `m['k'] as T` when it is the then-branch of a conditional whose condition is `m['k'] is T`, or an `if (m['k'] is T)` body. Skip when the same key was assigned earlier in the same block.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/models/contact/sharing/sent_share_record.dart:66`, `lib/utils/contact/native_raw_json_hash.dart:43`
