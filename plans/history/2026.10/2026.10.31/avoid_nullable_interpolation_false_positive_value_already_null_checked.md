# BUG: `avoid_nullable_interpolation` — Flags nullable values interpolated after a null check on the same value (`x != null ? '${x?.m()}' : ...`)

**Status: Fixed**

Created: 2026-10-31
Rule: `avoid_nullable_interpolation`
File: `lib/src/rules/data/type_rules.dart` (line ~474)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags nullable values interpolated after a null check on the same value (`x != null ? '${x?.m()}' : ...`). In a downstream app review, 28 of 37 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_nullable_interpolation'" lib/src/rules/
# lib/src/rules/data/type_rules.dart:474:    'avoid_nullable_interpolation',
```

**Emitter registration:** `lib/src/rules/data/type_rules.dart:474`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
String describe(List<Status>? includeStatuses) => <String>[
  if (includeStatuses != null)
    '[Statuses]: `${includeStatuses?.map((Status e) => e.name).join(',')}`', // LINT — but should NOT lint
].join(' ');

return answered.contains('${c.contactSaropaUUID}|$code'); // LINT — but should NOT lint when guarded by `c.contactSaropaUUID != null &&`
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/contact_search/contact_db_filters_describe.dart:16,18,20,22,25,27,29,31 (collection-if null check on the same field); lib/utils/contact/heritage/heritage_suggestion_index.dart:231 (`&&` guard on the same property).

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_nullable_interpolation]` reported at each site above |

---

## Root Cause

The rule uses the declared type of the expression and does not account for flow promotion or collection-if/`&&` guards on the same getter. The `?.` inside the interpolation is itself redundant after a guard, so the real hazard (printing 'null') cannot happen.

---

## Suggested Fix

Honor null checks in enclosing `if` elements, `&&`/`?:` conditions and early returns for the same identifier or property chain. Fields are not promoted by Dart, so also match syntactically identical receivers.

---

## Fixture Gap

The fixture for `avoid_nullable_interpolation` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

## Resolution

Fixed in `lib/src/rules/data/type_rules.dart`. The existing same-expression `!= null` ancestor guard now also (1) accepts a guard on the left of `&&` when the interpolation sits in the right operand, and (2) treats `x != null` as covering a null-aware chain off that receiver (`x?.m()`). Fixture cases added to `example/lib/type/avoid_nullable_interpolation_fixture.dart` (good: collection-if receiver guard, `&&` guard; bad: no guard, `||` guard). Verified with `dart run saropa_lints:scan --resolve` on a scratch copy: only the bad cases reported.
