# Task: `prefer_null_aware_method_calls`

## Summary
- **Rule Name**: `prefer_null_aware_method_calls`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Explicit null-guard patterns such as `if (x != null) { x.method(); }` or the ternary
`x != null ? x.method() : null` are more verbose than necessary in modern Dart. The
null-aware operator `?.` was introduced precisely to express "call this method only if
the receiver is non-null, otherwise evaluate to null." Using the explicit null-check form
adds three extra tokens (`if`, the condition, and the braces) for no additional safety or
clarity. The `?.` form is idiomatic Dart, easier to read, and less error-prone (no risk
of accidentally referencing a different variable in the guarded block).

## Description (from ROADMAP)
Flag `if (x != null) { x.method(); }` patterns that can be collapsed into `x?.method();`.

## Trigger Conditions
1. An `IfStatement` with no `else` clause whose condition is `expr != null` (or
   `null != expr`), and whose then-body contains a single expression statement that is a
   method call or property access on the same expression.
2. A `ConditionalExpression` of the form `expr != null ? expr.member : null` (or
   `null != expr ? expr.member : null`).
3. The guarded expression must be a simple identifier or `this.member` access — not a
   complex expression with side effects that would be evaluated twice.

## Implementation Approach

### AST Visitor
```dart
context.registry.addIfStatement((node) { ... });
context.registry.addConditionalExpression((node) { ... });
```

### Detection Logic

**For `addIfStatement`:**
1. Check that `node.elseStatement` is null.
2. Inspect `node.expression` — it must be a `BinaryExpression` with operator `!=` and
   one operand being a `NullLiteral`.
3. Extract the non-null operand as the guarded expression `G`.
4. Require `G` to be a `SimpleIdentifier` or a `PrefixedIdentifier` (`this.field`) to
   avoid double evaluation risk.
5. Inspect `node.thenStatement`: it must be a `Block` containing exactly one
   `ExpressionStatement`, or an `ExpressionStatement` directly.
6. The inner expression must be a `MethodInvocation` or `PropertyAccess` whose target
   is a `SimpleIdentifier` referencing the same element as `G`.
7. If all conditions hold, report the `IfStatement`.

**For `addConditionalExpression`:**
1. The condition must be a `BinaryExpression` with `!=` and a `NullLiteral`.
2. Extract guarded expression `G` (must be simple identifier or prefixed).
3. The then-expression must be a member access on `G`.
4. The else-expression must be a `NullLiteral`.
5. If all conditions hold, report the `ConditionalExpression`.

## Code Examples

### Bad (triggers rule)
```dart
void example(StreamController? controller) {
  if (controller != null) {
    controller.close();         // single statement guarded by null check
  }
}

String? maybePrefix(String? prefix, String value) {
  return prefix != null ? prefix.toUpperCase() : null;
}

void onEvent(Listener? listener) {
  if (null != listener) {
    listener.onComplete();
  }
}
```

### Good (compliant)
```dart
void example(StreamController? controller) {
  controller?.close();
}

String? maybePrefix(String? prefix, String value) {
  return prefix?.toUpperCase();
}

void onEvent(Listener? listener) {
  listener?.onComplete();
}

// ok: else branch has meaningful value — not just null
String label(String? name) {
  return name != null ? name.trim() : 'Unknown';
}

// ok: guarded block has multiple statements — can't collapse to one ?.
void setup(Config? config) {
  if (config != null) {
    config.init();
    config.validate();
  }
}

// ok: guarded expression is complex — evaluating twice has side effects
void process(List<Widget> widgets) {
  if (widgets.removeLast() != null) {  // complex expr, skip
    // ...
  }
}
```

## Edge Cases & False Positives
- **Multiple statements in then-block**: If the guarded block contains more than one
  statement, it cannot be reduced to a single `?.` call — do not flag.
- **Non-null else branch**: `x != null ? x.foo() : fallback` where `fallback` is not
  `null` — the ternary has semantic value and must not be flagged.
- **Complex guarded expressions**: If the guarded expression is a function call, index
  access, or any expression with potential side effects, evaluating it twice (in the
  condition and in the guarded call) would change behavior — skip.
- **Type promotion after null check**: In some cases code relies on type promotion after
  the null check to access a more specific API — after `?.` the promotion is lost inside
  the call chain. Rare but worth noting; conservative approach is to only flag single-call
  patterns where the call target is identical to the condition operand.
- **`null != x` order**: Yoda conditions `null != x` are equivalent; both forms must be
  detected.
- **Nullable type vs non-nullable after promotion**: If the variable is already known
  non-null via Dart flow analysis (e.g., inside an outer null check), this inner check is
  redundant for a different reason (`avoid_redundant_null_check` rule). These two rules
  should not double-report.
- **`!` cast after null check**: `if (x != null) { x!.method(); }` — the `!` is
  redundant here too, but the `?.` fix supersedes it.

## Unit Tests

### Should Trigger (violations)
```dart
void test1(Completer? c) {
  if (c != null) {          // LINT
    c.complete();
  }
}

String? test2(String? s) {
  return s != null ? s.trim() : null;  // LINT
}

void test3(Timer? t) {
  if (null != t) {          // LINT (yoda)
    t.cancel();
  }
}
```

### Should NOT Trigger (compliant)
```dart
// ok: else is not null literal
String test4(String? s) => s != null ? s.trim() : 'default';

// ok: two statements in block
void test5(Config? c) {
  if (c != null) {
    c.init();
    c.apply();
  }
}

// ok: already using null-aware
void test6(Timer? t) => t?.cancel();

// ok: complex guarded expression
void test7(List<int> list) {
  if (list.removeAt(0) != null) {
    // cannot simplify
  }
}
```

## Quick Fix
**Replace the if-statement or ternary with a null-aware `?.` operator call.**

```dart
// Before (if-statement)
if (controller != null) {
  controller.close();
}

// After
controller?.close();

// Before (ternary)
final result = prefix != null ? prefix.toUpperCase() : null;

// After
final result = prefix?.toUpperCase();
```

## Notes & Issues
- This rule interacts with `avoid_redundant_null_check` (file 5 in this batch). Coordinate
  so they report on different patterns without overlap.
- The fix must preserve leading whitespace/indentation when replacing an if-statement with
  an expression statement.
- Consider whether the generated `?.` expression still needs a trailing `;` when replacing
  an `ExpressionStatement` wrapper — it always will.
- When replacing an if-statement at the block level, the fix removes the if and inserts a
  single expression statement. Take care with the source range to not remove surrounding
  blank lines aggressively.
