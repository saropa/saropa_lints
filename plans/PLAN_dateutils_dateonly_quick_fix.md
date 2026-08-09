# Plan: `DateUtils.dateOnly()` quick fix for `avoid_datetime_constructor`

**Status: Open**
**Created: 2026-08-09**
**Rule: `avoid_datetime_constructor`**
**File: `lib/src/rules/data/json_datetime_rules.dart`**

---

## Summary

Add a second quick fix to `avoid_datetime_constructor` that recognizes the strip-time idiom `DateTime(x.year, x.month, x.day)` and replaces it with `DateUtils.dateOnly(x)`. The existing `ReplaceDateTimeConstructorFix` converts to `DateTime.tryParse(...)`, which changes the return type to nullable and is semantically wrong for this pattern — the caller already has a valid `DateTime` and just wants midnight.

---

## Motivation

In a downstream project (saropa contacts), 38 of 53 `avoid_datetime_constructor` diagnostics were the strip-time pattern. Every one was manually replaced with `DateUtils.dateOnly()`. A quick fix would have made the entire sweep one-click per site.

Three private helpers reimplementing `DateTime(d.year, d.month, d.day)` were also found and deleted. The pattern is extremely common in Flutter codebases.

---

## Detection

Match `InstanceCreationExpression` where:

1. Constructor is `DateTime()` (unnamed) or `DateTime.utc()`.
2. Exactly 3 positional arguments, no named arguments.
3. All three arguments are `PropertyAccess` or `PrefixedIdentifier` nodes with property names `.year`, `.month`, `.day` (in that order).
4. All three share the **same receiver** (by `toSource()` string equality on the target/prefix).
5. The receiver's `staticType` is `DateTime` or `DateTime?` (not `PublicHolidayDate`, `ContactEventItem`, or other types with `.year`/`.month`/`.day` accessors).

Condition 5 is critical — without it the fix produces a type error on non-DateTime types that happen to have matching accessor names.

---

## Fix output

**Before:**
```dart
DateTime(someDate.year, someDate.month, someDate.day)
```

**After:**
```dart
DateUtils.dateOnly(someDate)
```

The fix must also ensure `package:flutter/material.dart` is imported (for `DateUtils`). If the file already imports it, no change. If not, add the import. If the file also imports `package:drift/drift.dart`, the import must include `hide Column` to avoid the name collision.

### Edge cases

- `DateTime.utc(x.year, x.month, x.day)` — `DateUtils.dateOnly()` returns local time, not UTC. Do NOT offer this fix for `.utc()` constructors.
- Nullable receiver (`DateTime? x`) — `DateUtils.dateOnly()` does not accept nullable. Do NOT offer the fix; let the existing `tryParse` fix handle it.
- Receiver is a complex expression (e.g. `someMethod().year`) — offer the fix but use the full `toSource()` of the receiver. The expression is already evaluated three times in the original code, so evaluating it once is strictly better.

---

## Implementation

### File: `lib/src/fixes/json_datetime/replace_dateonly_fix.dart` (new)

Extend `SaropaFixProducer`. Override `compute` with the detection logic above. Priority should be higher than `ReplaceDateTimeConstructorFix` (e.g. 60 vs 50) so it appears first in the fix menu when both apply.

```dart
class ReplaceDateOnlyFix extends SaropaFixProducer {
  // fixKind: 'saropa.fix.replaceDateOnly', priority 60,
  //          'Replace with DateUtils.dateOnly()'
  //
  // compute: check 3-arg same-receiver .year/.month/.day pattern,
  //          verify staticType is DateTime (non-nullable),
  //          verify constructor is unnamed (not .utc()),
  //          replace with DateUtils.dateOnly(receiver),
  //          ensure flutter/material.dart import exists
}
```

### File: `lib/src/rules/data/json_datetime_rules.dart`

Add `ReplaceDateOnlyFix` to `AvoidDateTimeConstructorRule.fixGenerators` list (before the existing `ReplaceDateTimeConstructorFix` so it takes priority when both match):

```dart
@override
List<SaropaFixGenerator> get fixGenerators => [
  ({required CorrectionProducerContext context}) =>
      ReplaceDateOnlyFix(context: context),
  ({required CorrectionProducerContext context}) =>
      ReplaceDateTimeConstructorFix(context: context),
];
```

Also add to `AvoidDateTimeConstructorUnvalidatedRule.fixGenerators` — the strip-time pattern is equally common there.

### Fixture: `example/lib/json_datetime/avoid_datetime_constructor_dateonly_fixture.dart` (new)

Cases:
- `DateTime(d.year, d.month, d.day)` — expect fix offered
- `DateTime(d.year, d.month, d.day, d.hour)` — 4 args, NOT strip-time → no dateOnly fix
- `DateTime.utc(d.year, d.month, d.day)` — UTC → no dateOnly fix
- `DateTime(a.year, b.month, c.day)` — different receivers → no dateOnly fix
- `DateTime(holiday.year, holiday.month, holiday.day)` where `holiday` is not `DateTime` — wrong type → no dateOnly fix
- `DateTime(d?.year ?? 0, d?.month ?? 0, d?.day ?? 0)` — complex args → no dateOnly fix

### Test: `test/scan/fix_application_smoke_test.dart`

Add entry for `ReplaceDateOnlyFix` with the positive fixture case.

---

## Acceptance criteria

- [ ] `ReplaceDateOnlyFix` offered for exact 3-arg same-receiver `.year/.month/.day` on non-nullable `DateTime`
- [ ] `ReplaceDateTimeConstructorFix` still offered as fallback for cases `ReplaceDateOnlyFix` declines
- [ ] Fix not offered for `.utc()`, nullable receiver, non-DateTime types, or 4+ args
- [ ] `package:flutter/material.dart` import added when missing
- [ ] `dart analyze --fatal-infos` passes
- [ ] `dart format .` clean
- [ ] `dart test` passes
- [ ] Fixture covers all edge cases above

---

## Risk

Low. This is a new fix producer alongside the existing one. The detection is narrow (exact 3-arg accessor pattern with type check). The main risk is the type-resolution check — `staticType` on a `PropertyAccess.target` may return `null` in some edge cases (unresolved code, generated files). The fix should bail out on `null` staticType.

---

## References

- Downstream sweep: `d:\src\contacts\docs\history\2026.08\2026.08.09\datetime_constructor_lint_fixes.md`
- Existing rule history: `plans/history/2026.08/2026.08.04/avoid_datetime_constructor_rule.md`
- Existing fix: `lib/src/fixes/json_datetime/replace_datetime_constructor_fix.dart`
- Flutter `DateUtils.dateOnly`: strips time components, returns `DateTime(d.year, d.month, d.day)`
