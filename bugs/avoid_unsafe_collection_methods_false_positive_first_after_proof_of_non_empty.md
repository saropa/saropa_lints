# BUG: `avoid_unsafe_collection_methods` — Flags `.first`/`.last`/`.single` where non-emptiness is guaranteed (split result, length check, firstOrNull fallback)

**Status: Fixed (partial; see Resolution)**

Created: 2026-10-31
Rule: `avoid_unsafe_collection_methods`
File: `lib/src/rules/data/collection_rules.dart` (line ~430)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags `.first`/`.last`/`.single` where non-emptiness is guaranteed (split result, length check, firstOrNull fallback). In a downstream app review, 22 of 24 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_unsafe_collection_methods'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:430:    'avoid_unsafe_collection_methods',
```

**Emitter registration:** `lib/src/rules/data/collection_rules.dart:430`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
final String head = line.split('\t').first; // LINT — but should NOT lint: String.split never returns an empty list

final CountryEnum? residence = countries?.length == 1 ? countries!.first : null; // LINT — but should NOT lint

final List<String>? rs = pack.surname(kanji);
final x = rs == null ? null : mapWord(rs.first); // pack API returns null or a non-empty list
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/language/pronunciation/name_pronunciation_japanese_name.dart:106; name_pronunciation_latin_scan.dart:165 (split); lib/utils/native_phone_import/native_import_rulings.dart:229 (length==1 ternary); lib/utils/speech/lexicon/voice_lexicon.dart:492,505 (already uses firstOrNull with fallback).

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_unsafe_collection_methods]` reported at each site above |

---

## Root Cause

The rule lacks (a) knowledge that `String.split` returns at least one element, (b) ternary/if guards on `length` or `isNotEmpty`, and (c) a distinction between `.first` and `firstOrNull`-style safe usage that it flags by mistake on lines 492/505.

---

## Suggested Fix

Add the three guards above. Verify the voice_lexicon sites: if the flagged node is a `firstOrNull` call, that is a separate defect (it should never be reported).

---

## Fixture Gap

The fixture for `avoid_unsafe_collection_methods` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Resolution

Fixed in `lib/src/rules/data/collection_rules.dart`:
- Guards written null-aware on the same collection (`countries?.length == 1 ? countries!.first : null`, `(xs?.isNotEmpty ?? false) ? xs!.first : null`) now cover the null-asserted access; null operators are stripped before comparing names.
- `parts.first` where `parts` is a local initialized from `s.split(...)` was handled for `.first` on property access but not on the prefixed-identifier path; now handled.
- `line.split('\t').first` was already skipped. `.firstOrNull` is never in the rule's method set, so it cannot be reported by this rule (the voice_lexicon sites are not from this rule's logic).
- Not fixable: `rs == null ? null : mapWord(rs.first)` relies on an external API contract (non-empty list) that is invisible to the rule; keep an `// ignore:` there.

Fixture: `example/lib/collection/avoid_unsafe_collection_methods_fixture.dart` (good and bad cases added). Verified with `dart run saropa_lints:scan --tier comprehensive --resolve`: only the 5 bad cases are flagged.

## Info needed to close

Partly fixed (null-aware guards and `split(...)` locals). Still flagged: `rs == null ? null : mapWord(rs.first)`, where non-emptiness comes from the app's API contract and is invisible to the rule.
Needed to close:
1. Owner decision: keep `// ignore:` for contract-guaranteed non-empty lists, or add a marker the rule honors.
2. The `firstOrNull` sites (voice_lexicon:492, 505) are not from this rule; confirm which rule emits them and file a separate report.
