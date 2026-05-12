# BUG: `avoid_string_substring` — False positive when indices are derived from `indexOf`, loop bounds, or `min()`

**Status: Fixed**

Created: 2026-05-12
Rule: `avoid_string_substring`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~974)
Severity: False positive
Rule version: v3 | Since: v4.1.3 | Updated: v4.13.0

---

## Summary

The rule fires on `substring()` calls where indices are provably in-bounds because they come from `indexOf` results (which return valid indices or -1, checked before use), `while (offset < length)` loop guards, or `min(text.length, ...)` clamping. The `_isGuardedByLengthCheck` method only recognizes `if`/ternary conditions with `.startsWith`/`.endsWith`/`.length` comparisons on the same receiver — it does not recognize these other common safe-index patterns.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_string_substring'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:991:    'avoid_string_substring',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:991`
**Rule class:** `AvoidSubstringRule` — registered in `lib/saropa_lints.dart:325`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#2`

---

## Reproducer

Minimal code that triggers five false positives (adapted from `saropa_dart_utils` `lib/html/html_utils.dart`):

```dart
/// Single-pass scanner — all five substring calls are bounds-safe.
String scanAndDecode(String text) {
  final StringBuffer buffer = StringBuffer();
  int offset = 0;
  final int length = text.length;

  while (offset < length) {
    final int ampIndex = text.indexOf('&', offset);
    if (ampIndex == -1) {
      // SAFE: offset <= length (loop guard); substring(offset) is valid
      buffer.write(text.substring(offset)); // LINT — but should NOT lint
      break;
    }
    if (ampIndex > offset) {
      // SAFE: offset < ampIndex (guarded by condition); ampIndex <= length
      buffer.write(text.substring(offset, ampIndex)); // LINT — but should NOT lint
      break;
    }
  }
  return buffer.toString();
}

String? tryNumeric(String text, int offset) {
  if (offset + 3 >= text.length) return null;
  final int semiIndex = text.indexOf(';', offset + 2);
  if (semiIndex == -1) return null;
  final int digitStart = offset + 3;
  if (digitStart >= semiIndex) return null;
  // SAFE: digitStart < semiIndex; semiIndex < text.length (from indexOf)
  return text.substring(digitStart, semiIndex); // LINT — but should NOT lint
}

String? tryNamed(String text, int offset, int maxLen) {
  final int searchBound = text.length < offset + maxLen ? text.length : offset + maxLen;
  final int semiIndex = text.indexOf(';', offset + 2);
  if (semiIndex <= 0 || semiIndex >= searchBound) return null;
  // SAFE: offset < semiIndex+1 <= text.length
  return text.substring(offset, semiIndex + 1); // LINT — but should NOT lint
}

String? tryLegacy(String text, int offset, int maxLen) {
  final int legacyBound = text.length < offset + maxLen ? text.length : offset + maxLen;
  for (int end = legacyBound; end >= offset + 3; end--) {
    // SAFE: offset+3 <= end <= legacyBound <= text.length
    final String candidate = text.substring(offset, end); // LINT — but should NOT lint
    if (candidate == '&amp') return candidate;
  }
  return null;
}
```

**Frequency:** Always — any `substring` where bounds safety comes from `indexOf`, loop conditions, or `min()`/clamped arithmetic rather than a direct `.length` comparison in an `if` condition.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — indices are provably in-bounds via control flow |
| **Actual** | `[avoid_string_substring] substring() throws RangeError if start or end indices are out of bounds...` reported at each call site |

---

## AST Context

Taking the simplest case (`text.substring(offset)` inside a `while` + `if (ampIndex == -1)` block):

```
FunctionDeclaration (scanAndDecode)
  └─ BlockFunctionBody
      └─ WhileStatement (offset < length)
          └─ Block
              └─ IfStatement (ampIndex == -1)
                  └─ Block (then)
                      └─ ExpressionStatement
                          └─ MethodInvocation (buffer.write)
                              └─ ArgumentList
                                  └─ MethodInvocation (text.substring(offset))  ← flagged here
```

The rule's `_isGuardedByLengthCheck` walks up the parent chain looking for `IfStatement` or `ConditionalExpression` nodes whose condition contains `<receiver>.startsWith(`, `<receiver>.endsWith(`, or `<receiver>.length`. In this case:

1. The immediate `IfStatement` condition is `ampIndex == -1` — does not match the pattern.
2. The `WhileStatement` is not checked at all (only `IfStatement` and `ConditionalExpression` are handled).
3. The fact that `offset` is bounded by the `while` condition and `ampIndex` comes from `indexOf` is not analyzed.

---

## Root Cause

### `_isGuardedByLengthCheck` is too narrow (line ~1024)

The guard detection only recognizes two patterns:
1. `if (<receiver>.startsWith(...))` / `if (<receiver>.endsWith(...))`
2. `if (<receiver>.length <comparator> ...)`

It does not recognize:
- **`indexOf`-derived indices**: When `semiIndex = text.indexOf(';', start)` and `semiIndex != -1`, then `semiIndex` is a valid index into `text`. Using it as a `substring` bound is safe.
- **`while` loop guards**: `while (offset < length)` guarantees `offset` is in bounds for the loop body.
- **`min()`/clamped bounds**: `min(text.length, ...)` as a `substring` end argument is always safe.
- **Arithmetic guards**: `if (digitStart >= semiIndex) return null;` followed by `substring(digitStart, semiIndex)` is safe.

The `_conditionGuardsLength` method (line ~1061) uses regex matching on the condition's source text, looking only for `.startsWith(`, `.endsWith(`, or `.length` on the receiver. It cannot reason about transitive safety through intermediate variables like `semiIndex` or `legacyBound`.

### This is a structural limitation

The rule would need data-flow analysis (or at least recognition of common safe-index idioms like `indexOf` + null-check) to avoid these false positives. The current approach of checking only the immediate `if`/ternary condition for receiver-specific patterns misses the most common safe-substring idiom in parsing code.

---

## Suggested Fix

Several options, ordered by implementation complexity:

**Option A (minimal):** Add `WhileStatement` to the parent-chain walk in `_isGuardedByLengthCheck`, so that `while (offset < text.length)` is recognized as a guard.

**Option B (medium):** Recognize `indexOf`-derived indices as safe. When both arguments to `substring(start, end)` trace back to variables assigned from `indexOf` (with a `-1` check), suppress the diagnostic.

**Option C (broader):** Add a heuristic that suppresses when the `substring` call is inside a block that has an early-return/break/continue guarded by a bounds check on the same variables used as indices — even if the guard is not an `if` wrapping the `substring` directly.

Option A is the smallest change but only addresses the `while` loop case. Option B covers the most common false-positive pattern (parsing code using `indexOf`). Option C is the most general but hardest to implement correctly.

---

## Fixture Gap

The fixture should include:

1. **`indexOf`-guarded substring** — `semiIndex = s.indexOf(';'); if (semiIndex == -1) return; s.substring(0, semiIndex)` — expect NO lint
2. **`while (offset < length)` loop with `substring(offset)`** — expect NO lint
3. **`min(text.length, bound)` as substring end** — expect NO lint
4. **Arithmetic guard before substring** — `if (start >= end) return; s.substring(start, end)` — expect NO lint
5. **Unguarded substring with literal indices** — `s.substring(5, 10)` — expect LINT (should still fire)

---

## Environment

- saropa_lints version: v4.13.0 (rule updated at this version)
- Dart SDK version: (current stable)
- custom_lint version: (current)
- Triggering project/file: `saropa_dart_utils/lib/html/html_utils.dart`
