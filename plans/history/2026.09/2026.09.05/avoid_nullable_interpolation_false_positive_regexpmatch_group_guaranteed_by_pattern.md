# BUG: `avoid_nullable_interpolation` — False positive on `RegExpMatch` group guaranteed present by the pattern

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_nullable_interpolation`
File: `lib/src/rules/data/type_rules.dart`
Severity: False positive

---

## Summary

Split out of `avoid_nullable_interpolation_false_positive_guarded_by_enclosing_null_check.md`
(2026-09-05) — that bug reported two unrelated false-positive classes; the
enclosing-`if`/`&&`-guard class was fixed in v7 (see the archived original
under `plans/history/2026.09/2026.09.05/`). This file tracks the remaining,
unaddressed class.

`RegExpMatch.group(n)` (and `match[n]`) returns `String?` generically, but
when `n` is within the pattern's guaranteed capture-group count for a
pattern that always produces that group on a successful match, the value
is never actually null. The rule has no way to reason about regex group
structure, so it flags the interpolation as if the value could be null.

---

## Fix (v8)

Added `_isMatchGroupAccess()` guard to the rule. When the interpolated
expression is an `IndexExpression` or `.group()` `MethodInvocation` whose
receiver is typed as `Match` or `RegExpMatch` (dart:core), the lint is
suppressed. The false-positive rate on these accesses is very high and
invalid group indices throw `RangeError` at runtime, not null.

A shared `isDartCoreMatchType()` top-level helper was extracted to
deduplicate the identical type check that already existed in
`AvoidNullAssertionRule._isSafeRegExpMatchGroup()`.

---

## Reproducer

```dart
// FP: group 1 is always present when hasMatch() is true, because the
// pattern's group 1 `(\d)` is not inside an optional quantifier.
final RegExp pattern = RegExp(r'(\d)(?=(\d{3})+$)');
final RegExpMatch? m = pattern.firstMatch(input);
if (m != null) {
  result.write('${m[1]},'); // LINT — but m[1] cannot be null here
}
```

Originally observed at `health_summary.dart:51`.

---

## Affected Files (FP only)

- `health_summary.dart:51` — RegExpMatch group

---

## Environment

- saropa_lints version: current (unreleased)

---

## Finish Report (2026-09-05)

**Defect:** `AvoidNullableInterpolationRule` (v7) flagged `Match[n]` and
`Match.group(n)` in string interpolations as nullable. The Dart type system
returns `String?` from these accessors, but for required capture groups the
value is guaranteed non-null on a successful match. The rule could not
distinguish required from optional groups without parsing the regex pattern.

**Fix (v8):** Added `_isMatchGroupAccess()` to the rule's suppression
chain. The method detects `IndexExpression` (`m[n]`) and `.group()`
`MethodInvocation` on `Match`/`RegExpMatch` from `dart:core`.

When the regex pattern literal is visible in the AST (e.g. inside a
`replaceAllMapped(RegExp(r'...'), ...)` call), a new
`countRequiredCaptureGroups()` parser counts required (non-optional)
capture groups and only suppresses when the accessed group index is
within that count. When the pattern can't be found or is too complex
to parse, the suppression falls back to blanket exemption.

**Regex group counter:** `countRequiredCaptureGroups(String pattern)`
walks the pattern character-by-character with a stack, handling:
escaped chars, character classes `[...]`, non-capturing groups `(?:)`,
lookahead/lookbehind `(?=)` / `(?!)` / `(?<=)` / `(?<!)`, named
groups `(?<name>)`, alternation `|`, and quantifiers `?`/`*` on
groups. Returns null for patterns too complex to analyze.

**Deduplication:** The dart:core Match/RegExpMatch type check was
duplicated between `AvoidNullableInterpolationRule._isMatchType()` and
`AvoidNullAssertionRule._isSafeRegExpMatchGroup()`. Both now delegate
to a shared top-level `isDartCoreMatchType(DartType)` helper.

**Testing:** Three GOOD fixture cases added to the fixture file.
16 unit tests for `countRequiredCaptureGroups` covering simple groups,
optional quantifiers, alternation, non-capturing groups, named groups,
lookbehind/lookahead, escaped/character-class parens, nested groups,
and two real-world patterns. Scan CLI confirmed zero FP hits on
`health_summary.dart:51`. All 71 tests pass.
