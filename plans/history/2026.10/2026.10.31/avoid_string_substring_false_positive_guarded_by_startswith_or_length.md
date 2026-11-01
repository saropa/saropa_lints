# BUG: `avoid_string_substring` — Flags substring calls whose bounds are guaranteed by a startsWith/length/indexOf check

**Status: Open**

Created: 2026-10-31
Rule: `avoid_string_substring`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~1305)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags substring calls whose bounds are guaranteed by a startsWith/length/indexOf check. In a downstream app review, 9 of 13 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_string_substring'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:1305:    'avoid_string_substring',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:1305`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
final String? chosen = prefixes
    .where((String p) => digits.startsWith(p) && digits.length > p.length)
    .firstOrNull;
// elsewhere, inside the same scope:
final String rest = '+${digits.substring(p.length)}'; // LINT — but should NOT lint (length > p.length proven)

if (first.startsWith('c')) return 'k${first.substring(1)}'; // LINT — but should NOT lint
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/contact/phone/phone_international_prefix.dart:72; lib/utils/speech/contact/home_voice_name_variants.dart:40,41; lib/utils/speech/speech_question_parser.dart:115,142; lib/utils/language/pronunciation/name_pronunciation_latin_scan.dart:98.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_string_substring]` reported at each site above |

---

## Root Cause

No guard analysis: the rule does not recognize `startsWith(x)` followed by `substring(x.length)`, `startsWith(c)` followed by `substring(1)`, or an enclosing `length >`/`indexOf >= 0` condition.

---

## Suggested Fix

Skip when an enclosing if/&&/ternary/where-predicate contains `startsWith`, `contains`, `length` comparison, or `indexOf` check on the same receiver. Skip `substring(n)` when `startsWith(<string of length n>)` guards it.

---

## Fixture Gap

The fixture for `avoid_string_substring` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

## Resolution

Fixed 2026-10-31. The rule already honored `startsWith`/`length` guards in enclosing `if`, ternary and early-exit forms (the `if (first.startsWith('c')) return ...` reproducer was already clean). The remaining gap was a guard on the left side of `&&` (`s.startsWith('c') && s.substring(1) == 'x'`); `AvoidSubstringRule._isGuardedByLengthCheck` now accepts a receiver/argument/regex guard in the left operand. Fixture cases added (good: `&&` startsWith and length; bad: `&&` guard on a different string). Verified with `dart run saropa_lints:scan --resolve --tier comprehensive` on a scratch copy: guarded cases silent, unguarded ones flagged.
