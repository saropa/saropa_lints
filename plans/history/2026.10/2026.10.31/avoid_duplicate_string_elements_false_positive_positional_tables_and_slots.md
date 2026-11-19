# BUG: `avoid_duplicate_string_elements` — Flags repeated strings in positional lookup tables and in structured value slots where repeats are required

**Status: Fixed**

Created: 2026-10-31
Rule: `avoid_duplicate_string_elements`
File: `lib/src/rules/data/collection_rules.dart` (line ~2519)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags repeated strings in positional lookup tables and in structured value slots where repeats are required. In a downstream app review, 28 of 28 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_duplicate_string_elements'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:2519:    'avoid_duplicate_string_elements',
```

**Emitter registration:** `lib/src/rules/data/collection_rules.dart:2519`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
const List<String> kHangulMedial = <String>[
  'ah', 'eh', 'yah', 'yeh', 'uh', 'eh', // LINT on the second 'eh' — but should NOT lint
  'yuh', 'yeh', 'oh', 'wah', 'weh',
];

final slots = VCardValue.structured(<String?>['', '', multiline, '', '', '']); // LINT x3 — but should NOT lint
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/language/pronunciation/name_pronunciation_hangul_table.dart:9,10,15,16 (index = Unicode jamo position; repeats are the data); lib/utils/contact/contact_share_utils.dart:235 (vCard ADR has 7 fixed positional fields, empty ones repeat).

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_duplicate_string_elements]` reported at each site above |

---

## Root Cause

The rule is designed for Set literals and unordered lists. In a list where element position carries meaning, duplicates are valid and removing them breaks the index mapping.

---

## Suggested Fix

Do not report on lists with more than N elements indexed by position, nor empty-string elements, nor lists passed to a `structured`-style positional constructor. Consider limiting to `Set` literals and `const` lists used with `contains`.

---

## Fixture Gap

The fixture for `avoid_duplicate_string_elements` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

## Resolution

Fixed in `lib/src/rules/data/collection_rules.dart`. For list literals the rule now skips: empty-string elements, lists passed as call/constructor arguments (fixed positional slots), and const lists of 6+ elements (lookup tables). Set literals and short plain lists with repeats are still flagged. Fixture extended with good cases (const table, slots) and a near-miss bad case. Verified with `dart run saropa_lints:scan` on a copy of the fixture: only the three intended bad sites were reported.
