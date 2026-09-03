# PROPOSAL: Extend `avoid_long_functions` With a Statement-Count Ceiling

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_long_functions`

---

## Summary

Extend `avoid_long_functions` to also enforce a maximum statement count per function/method body, in addition to its existing line-count ceiling, matching DCM's `max-statements`, which is a pure statement-count check independent of line count.

**Closes gap:** DCM `max-statements` (dcm.dev) — currently PARTIAL via saropa's `avoid_long_functions`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`lib/src/rules/architecture/structure_rules.dart:1163-1232` implements `AvoidLongFunctionsRule`. Its check is purely line-based:

```dart
static const int _maxLines = 100;
...
void _checkFunctionBody(FunctionBody? body, Token nameToken, SaropaDiagnosticReporter reporter) {
  if (body == null) return;
  if (body is EmptyFunctionBody) return;

  final root = body.root;
  if (root is! CompilationUnit) return;
  final unit = root;
  final int lineCount = _countCodeLinesInTokenRange(
    unit.lineInfo,
    body.beginToken,
    endToken: body.endToken,
  );

  if (lineCount > _maxLines) {
    reporter.atToken(nameToken);
  }
}
```

Line count and statement count diverge in both directions:
- A function can stay under 100 lines while packing many chained/short statements onto few lines (e.g. dense one-line `if` bodies, chained method calls each on its own short line, or a long sequence of one-statement-per-line assignments) — `avoid_long_functions` never fires even though the function does far too much.
- Conversely a function can exceed 100 lines while containing very few actual statements, because of long argument lists, multi-line widget trees, or heavily wrapped expressions — a single `Column(children: [...])` call spanning 120 lines is one statement, and today's rule flags it as "too long" even though there is nothing to extract in terms of control flow or logic.

DCM's `max-statements` measures cyclomatic-adjacent complexity by counting statements (assignments, control-flow statements, expression statements, declarations) rather than physical lines, which correlates more directly with "how many things is this function doing" than line count does.

## Detection / Behavior

### Should flag (bad code)

```dart
// Fewer than 100 lines, but performs far more than the statement ceiling
// (illustrative — a real function would have ~40+ statements packed densely).
void processOrder(Order order) {
  if (order.isValid) validate(order);
  if (order.hasDiscount) applyDiscount(order);
  if (order.isExpress) expedite(order);
  logStep(order); trackMetric(order); notifyWarehouse(order);
  updateInventory(order); reserveStock(order); chargePayment(order);
  sendConfirmation(order); scheduleDelivery(order); archiveOrder(order);
  // ... 30+ more one-line statements, still under 100 total lines // LINT
}
```

### Should pass (good code)

```dart
void processOrder(Order order) {
  _validateAndPrice(order);
  _fulfillOrder(order);
  _notifyStakeholders(order); // OK — few statements, delegates to helpers
}
```

```dart
// Long due to a single multi-line widget expression, not many statements —
// should NOT be additionally flagged by the statement-count check (may still
// be flagged by the existing line-count check, unchanged).
Widget build(BuildContext context) {
  return Column( // one statement/expression, just visually long
    children: [
      Text('a'),
      Text('b'),
      // ... 90 more lines of widget tree, still one `return` statement
    ],
  );
}
```

## Proposed Tier

Tier: Professional

Justification: keep parity with the existing rule's tier — `avoid_long_functions` is in `professionalOnlyRules` (`lib/src/tiers.dart` line 2062). The statement-count variant is a refinement of the same complexity signal at the same audience level; splitting it into a different tier would mean the two ceilings on "is this function too big" disagree on which teams see them.

## Edge Cases

1. **Statement-counting definition** — must match DCM's granularity: count `Statement` AST nodes in the body (`ExpressionStatement`, `IfStatement`, `ForStatement`, `WhileStatement`, `SwitchStatement`, `VariableDeclarationStatement`, `TryStatement`, `ReturnStatement`, etc.), but count a compound statement's own header once (e.g. `if (...) { ... }` counts as 1 for the `if` plus its nested block's own statements — not double-counted for the condition expression).
2. **Widget-tree-heavy `build()` methods** — a single `return Scaffold(...)` is one statement regardless of how many lines the nested widget tree spans; this is precisely the case the statement-count ceiling should NOT flag, differentiating it from the line-count rule (see "Should pass" example).
3. **Switch expressions / pattern matching (`switch` as an expression)** — an expression-form `switch` inside a single `return` statement should count as one statement, not one per `case`, to avoid penalizing idiomatic Dart 3 pattern matching.
4. **Default threshold** — DCM's `max-statements` default is commonly cited around 20 statements; pick a default independently calibrated against saropa's existing fixture corpus rather than assuming DCM's exact number, and expose it via the same kind of config surface `avoid_long_functions` would use if made configurable.
5. **Comments/blank lines** — irrelevant to a statement count by construction (unlike the line-count sibling, which explicitly excludes them), so no special-casing needed here.

## Alternatives Considered

- **New standalone rule** (`avoid_too_many_statements`) instead of extending `avoid_long_functions` — considered, and reasonable given the two metrics are orthogonal enough that a user might want to disable one without the other. However, per this proposal batch's `Related rules` framing (parity extension of an existing PARTIAL match) and to keep one rule id for "function does too much" the same way DCM keeps `max-statements` as a distinct rule *name* but conceptually adjacent to `avoid_long_functions`'s DCM analogue (`prefer-max-lines`/similar), extending `avoid_long_functions` to run both checks under one rule id keeps the tier and reporting story unified. If implementation shows the two checks have very different false-positive profiles, splitting into a sibling rule remains the fallback.
- **Cyclomatic complexity instead of raw statement count** — closer to some complexity linters, but diverges from DCM's actual `max-statements` semantics (a flat statement count, not weighted branches), so raw statement count is the more accurate parity target.

---

## Decision

---

## Implementation Notes

Add a `_countStatements(FunctionBody body)` helper alongside `_countCodeLinesInTokenRange` in `lib/src/rules/architecture/structure_rules.dart`, walked via a `RecursiveAstVisitor<void>` limited to `Statement` node types, invoked from the existing `_checkFunctionBody` alongside the current line-count check, each with its own threshold constant and its own message clause.

---

## Commits
