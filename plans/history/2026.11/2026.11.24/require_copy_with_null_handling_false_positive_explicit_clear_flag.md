# BUG: `require_copy_with_null_handling` — copyWith with an explicit clear flag is flagged

**Status: Open**

Created: 2026-11-24
Rule: `require_copy_with_null_handling`
File: `lib/src/rules/packages/equatable_rules.dart` (RequireCopyWithNullHandlingRule, ~line 928)
Severity: False positive
Rule version: v2 | Reported against: saropa_lints 17.7.9

---

## Summary

A `copyWith` that uses `extra ?? this.extra` for a nullable field but also takes a `bool noExtra = false` parameter to clear the field is flagged. The null-out case IS supported (via the flag), so the message "cannot set nullable fields to null" is wrong for this code.

---

## Attribution Evidence

```bash
grep -rn "'require_copy_with_null_handling'" lib/src/rules/
# lib/src/rules/packages/equatable_rules.dart:928:    'require_copy_with_null_handling',
```

Diagnostic seen in the VS Code Problems panel (saropa_lints extension export) at the `copyWith` declaration.

---

## Reproducer

```dart
class Avatar {
  const Avatar({this.face = 'otter', this.extra});
  final String face;
  final String? extra; // nullable field

  // LINT, but should NOT lint: the caller clears `extra` with noExtra: true.
  Avatar copyWith({String? face, String? extra, bool noExtra = false}) => Avatar(
    face: face ?? this.face,
    extra: noExtra ? null : (extra ?? this.extra),
  );
}
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: a boolean clear flag (`noX`, `clearX`, `removeX`) is a valid way to allow nulling, equivalent to a sentinel |
| **Actual** | `[require_copy_with_null_handling] copyWith with ?? operator cannot set nullable fields to null` |

---

## Root Cause

The rule only looks for `param ??` in the body of a nullable parameter whose field is nullable. It does not check whether the same expression is guarded by a boolean parameter (`noExtra ? null : (extra ?? this.extra)`), which is the third common way to support clearing besides a sentinel and an `Optional<T>` wrapper.

---

## Suggested Fix

Skip the report when the flagged `??` sits in the else branch of a conditional expression whose condition is a bool parameter of the same `copyWith`, or whose name matches `no<Field>` / `clear<Field>` / `remove<Field>` (case-insensitive) for the flagged parameter.
