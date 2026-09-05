# BUG: `avoid_nullable_interpolation` — False positive on `RegExpMatch` group guaranteed present by the pattern

**Status: Open**

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

## Suggested Fix

Consider suppressing when the group index is a literal ≤ the pattern's
required (non-optional) capture-group count. Flagged as hard / may not be
worth the complexity in the original report — parsing the regex pattern
string to determine which groups are optional (inside `(...)?`, `(...)*`,
alternation, etc.) is nontrivial and error-prone to get right. A narrower,
safer heuristic (e.g. only when the pattern literal has no `?`, `*`, `|`
at all) may be a reasonable first cut if this is picked up.

---

## Affected Files (FP only)

- `health_summary.dart:51` — RegExpMatch group

---

## Environment

- saropa_lints version: current (unreleased)
