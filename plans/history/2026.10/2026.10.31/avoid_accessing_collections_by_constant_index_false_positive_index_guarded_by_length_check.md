# BUG: `avoid_accessing_collections_by_constant_index` — Flags `list[0]`/`list[1]` after an explicit length check in the same condition or a prior `continue`

**Status: Closed**

Created: 2026-10-31
Rule: `avoid_accessing_collections_by_constant_index`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~2912)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags `list[0]`/`list[1]` after an explicit length check in the same condition or a prior `continue`. In a downstream app review, 8 of 8 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_accessing_collections_by_constant_index'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:2912:    'avoid_accessing_collections_by_constant_index',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:2912`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
for (final String line in lines) {
  final List<String> cols = line.trim().split('\t');
  if (cols.length != 2 || line.startsWith('#')) continue;
  final key = cols[0]; // LINT — but should NOT lint: length == 2 proven by the continue above
  final val = cols[1]; // LINT — but should NOT lint
}

final bool ok = c.length == 2 && c[0].isNotEmpty && _isHiragana(c[1]); // LINT x2 — but should NOT lint
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/language/pronunciation/name_pronunciation_hanzi_mapper.dart:15,16; name_pronunciation_surname_overrides.dart:24,26; name_pronunciation_pinyin_syllables.dart:125.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_accessing_collections_by_constant_index]` reported at each site above |

---

## Root Cause

No guard analysis for `length == N`, `length >= N`, `length != N` followed by `continue`/`return`, or a left-hand `&&` operand that already proves the length.

---

## Suggested Fix

Suppress when an enclosing condition or a preceding early-exit guard on the same collection variable proves `length > index`. Also treat `runes.length == 1` style guards the same way.

---

## Fixture Gap

The fixture for `avoid_accessing_collections_by_constant_index` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Resolution

The rule now skips a constant-index read when the same collection's `length` is compared in the left operand of an enclosing `&&`, an enclosing `if` or ternary, or a preceding early-exit `if` (`continue`/`break`/`return`/`throw`) in the same or an outer block. Files: `lib/src/rules/code_quality/code_quality_avoid_rules.dart`, `example/lib/code_quality/avoid_accessing_collections_by_constant_index_fixture.dart` (three good cases, one near-miss bad case), `CHANGELOG.md`. Tests: `dart test test/rules/code_quality/code_quality_rules_test.dart` passes (fixture checks only; no analyzer-level behavior test exists for this rule).
