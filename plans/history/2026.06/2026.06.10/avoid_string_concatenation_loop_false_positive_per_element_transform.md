# BUG: `avoid_string_concatenation_loop` — Fires on per-element string composition (no accumulator)

**Status: Fixed**

Created: 2026-06-10
Rule: `avoid_string_concatenation_loop`
File: `lib/src/rules/core/performance_rules.dart` (line ~1251)
Severity: False positive
Rule version: v3

---

## Summary

The rule flags any string `+` inside a loop/`.map()`/`for`, regardless of whether the result accumulates into a growing variable. A single `a + b` that produces a fresh string per iteration (assigned to a fresh local, or returned from `.map`) is O(n) total, not the O(n²) accumulation the rule exists to catch. `StringBuffer` cannot apply because there is no running string to append to.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_string_concatenation_loop'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:1230:    'avoid_string_concatenation_loop',

# Negative — NOT in sibling repo
grep -rn "'avoid_string_concatenation_loop'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:1230`
**Rule class:** `AvoidStringConcatenationLoopRule`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
// Case A — .map() per-element transform (no accumulator)
List<String> withSuffix(List<String> items, String suffix) {
  return items
      .map((String item) => item + suffix) // LINT (false positive): O(n) total,
                                            // a fresh string per element, no growth.
      .toList();
}

// Case B — fresh local composed per iteration of a for loop
void compose(List<String> tags, String text) {
  for (final String tag in tags) {
    final String normalized = tag.startsWith('#') ? tag : '#$tag';
    // LINT (false positive): r'\s*' + escaped is a 2-part pattern composed once
    // per tag into a NEW value, not appended to a running string.
    final RegExp re = RegExp(r'\s*' + RegExp.escape(normalized));
    text = text.replaceAll(re, '');
  }
}
```

Real sites:
- `D:\src\contacts\lib\models\search\search_query_part.dart:106` — `.map((String item) => item + (appendToFindList ?? ''))`
- `D:\src\contacts\lib\service\bluesky_api\bluesky_post_item_extensions.dart:145` — `RegExp(r'\s*' + RegExp.escape(normalized))` inside a `for` loop.

**Frequency:** Always, for any string `+` lexically inside a loop/`map`/`forEach`/`reduce`, even with no accumulating left-hand side.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — each `+` yields a fresh string; total cost is O(n), `StringBuffer` is inapplicable. |
| **Actual** | `[avoid_string_concatenation_loop] Each += creates new String object...` reported at the `+` expression. |

---

## AST Context

```
MethodInvocation (.map)                 ← _isInsideLoop walks up to this and returns true
  └─ FunctionExpression
      └─ ExpressionFunctionBody
          └─ BinaryExpression (+)        ← node reported here
              ├─ SimpleIdentifier (item)
              └─ ... (suffix)
```

There is no `AssignmentExpression (+=)` and no left-hand variable that the loop body reads back — the result leaves the loop body as a fresh value.

---

## Root Cause

`performance_rules.dart:1251-1263` (the `addBinaryExpression` branch):

```dart
context.addBinaryExpression((BinaryExpression node) {
  if (node.operator.type != TokenType.PLUS) return;
  if (!_isInsideLoop(node)) return;          // true for any map/for/forEach ancestor
  final String source = node.toSource();
  if (_looksLikeStringOperation(source)) {   // matches a quote or 'string'/'name'/'text'
    reporter.atNode(node);
  }
});
```

`_isInsideLoop` (lines 1280-1300) returns true for `ForStatement`/`WhileStatement`/`DoStatement`/`ForEachParts`/`ForElement` **and** `MethodInvocation` named `map`/`forEach`/`reduce`. `_looksLikeStringOperation` (1302) matches if the source merely contains a quote (`RegExp(r"'")`), the word `name`/`text`/`message`, or `string`. A 2-arg `RegExp(r'\s*' + ...)` and a `.map(item => item + suffix)` both satisfy this.

The rule never checks the defining characteristic of the O(n²) anti-pattern: that the **left operand of `+` (or target of `+=`) is the SAME variable read on each iteration** (an accumulator). Without that check, every per-element transform is flagged. The `+=` branch (1265-1277) at least requires an assignment target, but the bare `+` branch reports any in-loop string concatenation.

---

## Suggested Fix

For the `addBinaryExpression` branch, only report when the `+` expression actually feeds an accumulator that lives outside the loop body. Concretely:

- Require the `BinaryExpression` to be the RHS of a compound assignment (`+=`) or of an assignment/`=` whose target is a variable declared **outside** the enclosing loop (an accumulator), OR whose left operand is that same outer variable (`s = s + x`).
- Per-element transforms — `.map((e) => e + suffix)`, a `final` local initialized once per iteration, a `RegExp(... + ...)` argument — have no outer accumulator and must not be flagged.

The `+=` branch should likewise confirm the target is loop-invariant in declaration scope (an accumulator), not a per-iteration local.

---

## Fixture Gap

`example*/lib/core/avoid_string_concatenation_loop_fixture.dart` should include:

1. `for (...) { s += x; }` with `var s = ''` declared **before** the loop — expect LINT (real accumulator).
2. `items.map((e) => e + suffix)` — expect **NO** lint (per-element transform).
3. `for (final t in tags) { final p = a + b; use(p); }` — expect **NO** lint (fresh per-iteration local).
4. `RegExp(r'\s*' + RegExp.escape(x))` inside a `for` — expect **NO** lint (one-shot argument composition).

---

## Environment

- saropa_lints version: ^13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- custom_lint version: native analyzer plugin (analysis_server_plugin), not custom_lint
- Triggering project/file: `search_query_part.dart:106`, `bluesky_post_item_extensions.dart:145`

## Finish Report (2026-06-10)

Fixed in WS-6. The bare `+` branch now only reports when the BinaryExpression is the RHS of an `s = s + x` (or `s = x + s`) assignment whose target is one of the operands (a genuine accumulator). Per-element transforms (.map, fresh local, RegExp arg) have no such assignment and are not flagged. Pure-AST; verified via scan (FP `.map` not flagged, accumulator TP flagged).
