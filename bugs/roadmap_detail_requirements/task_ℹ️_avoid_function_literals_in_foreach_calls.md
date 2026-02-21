# Task: `avoid_function_literals_in_foreach_calls`

## Summary
- **Rule Name**: `avoid_function_literals_in_foreach_calls`
- **Tier**: Stylistic
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Style

## Problem Statement
Dart's `.forEach()` method accepts a callback and invokes it for each element. While this pattern works, it has a fundamental limitation compared to a `for` loop: you cannot use `break`, `continue`, or `return` (from the enclosing function) inside the callback. The callback is a separate function scope, so `return` exits the callback, not the outer method, and `break`/`continue` are compile errors.

Additionally, in `async` contexts, using `.forEach()` with an `async` callback (`items.forEach((e) async { await ... })`) does not await the futures — the loop completes immediately and all futures run concurrently, which is almost always a bug.

The `for (final item in items)` loop:
1. Supports `break` and `continue` for flow control.
2. Supports `return` to exit the enclosing function.
3. Works correctly with `await` in async functions.
4. Is equally readable, and arguably more so for multi-line bodies.
5. Is the idiomatic Dart way to iterate.

This rule is Stylistic tier (opt-in) rather than Recommended because the `.forEach()` + method tearoff pattern (`items.forEach(print)`) is a valid and concise Dart idiom that should not be flagged. Only the function-literal form (`.forEach((e) => ...)` and `.forEach((e) { ... })`) is targeted.

## Description (from ROADMAP)
Flag `.forEach()` method calls where the argument is a function literal (arrow function `(e) => expr` or block function `(e) { ... }`), suggesting replacement with a `for (final e in collection)` loop. Method tearoffs (`items.forEach(print)`) are explicitly excluded.

## Trigger Conditions
The rule triggers when:
1. A `MethodInvocation` is found with the method name `forEach`.
2. The single argument to `forEach` is a `FunctionExpression` (i.e., an inline function literal, either arrow or block form).
3. The target of the invocation is a `List`, `Set`, `Iterable`, or similar collection type (detected via static type, not string matching).

It does NOT trigger when:
- The argument is a method tearoff (a `SimpleIdentifier` or `PrefixedIdentifier` referencing an existing function/method).
- The target is a `Map` — `Map.forEach` has a two-parameter callback `(key, value)` with different semantics.
- The call is in a `const` context (impossible, but guard against it).
- The file is a generated file.

## Implementation Approach

### AST Visitor
```dart
context.registry.addMethodInvocation((node) {
  if (node.methodName.name != 'forEach') return;
  _checkForEachCall(node, reporter);
});
```

### Detection Logic

**Step 1 — Verify the argument is a function literal (not a tearoff):**

```dart
void _checkForEachCall(MethodInvocation node, ErrorReporter reporter) {
  final args = node.argumentList.arguments;
  if (args.length != 1) return;

  final arg = args.first;
  if (arg is! FunctionExpression) return; // tearoffs are SimpleIdentifier — excluded

  // Step 2 — Verify target is not a Map
  final targetType = node.realTarget?.staticType;
  if (targetType != null && _isMapType(targetType)) return;

  reporter.atNode(node, code);
}

bool _isMapType(DartType type) {
  return type.isDartCoreMap ||
      type.element?.name == 'Map';
}
```

**Step 3 — Distinguish arrow vs block form (for fix generation):**

```dart
final body = (arg as FunctionExpression).body;
final isArrow = body is ExpressionFunctionBody;
```

This is used in the quick fix to reconstruct the loop body appropriately.

**Step 4 — Detect async function literals (higher severity case):**

If the function literal has an `async` modifier, the pattern is not just stylistically suboptimal — it is likely a bug (futures not awaited). The rule could emit a higher-severity report in this case:

```dart
final isAsyncCallback = (arg as FunctionExpression).body.isAsynchronous;
if (isAsyncCallback) {
  // This is a potential bug — unawaited async forEach
  reporter.atNode(node, _asyncCode); // separate LintCode with WARNING severity
}
```

## Code Examples

### Bad (triggers rule)
```dart
void processItems(List<String> items) {
  // Arrow function literal — should be for loop
  items.forEach((item) => print(item));

  // Block function literal — should be for loop
  items.forEach((item) {
    final processed = item.trim();
    print(processed);
  });

  // Async function literal — likely a bug
  items.forEach((item) async {
    await saveToDatabase(item); // futures not awaited!
  });
}

void processSet(Set<Widget> widgets) {
  widgets.forEach((w) => w.build(context)); // triggers
}
```

### Good (compliant)
```dart
void processItems(List<String> items) {
  // For loop — supports break, continue, return, await
  for (final item in items) {
    print(item);
  }

  // Multi-line body in for loop
  for (final item in items) {
    final processed = item.trim();
    print(processed);
  }

  // Async-safe iteration
  for (final item in items) {
    await saveToDatabase(item); // properly awaited
  }
}

// Method tearoff — acceptable, not flagged
void logAll(List<String> items) {
  items.forEach(print); // OK — tearoff, not function literal
}

// Map.forEach — not flagged (different semantics)
void logMap(Map<String, int> map) {
  map.forEach((key, value) => print('$key: $value')); // OK — Map
}
```

## Edge Cases & False Positives
- **Method tearoffs**: `items.forEach(print)` or `items.forEach(_handler)` — these are `SimpleIdentifier` or `PrefixedIdentifier` nodes, not `FunctionExpression`. The check `if (arg is! FunctionExpression) return;` correctly excludes these. Verify this in tests.
- **Map.forEach**: `Map.forEach((k, v) => ...)` has two parameters and different semantics — no `break`/`continue` from a loop is ever expected for maps in the same way. The static type check for `Map` excludes these. Note that `Map.forEach` is not interchangeable with a `for (final entry in map.entries)` loop without rewriting the callback.
- **Custom forEach implementations**: A user class may define its own `forEach` method that is not an `Iterable.forEach`. The static type check limits triggering to iterable/collection types. If the target type is unknown or user-defined, be conservative and do not report.
- **Chained calls**: `items.where((e) => e.isNotEmpty).forEach((e) => print(e))` — the target of `forEach` here is the result of `.where()`, which returns an `Iterable`. This should still trigger because the pattern is replaceable with a for loop with a condition.
- **Function literals with captures**: Some function literals capture variables from the outer scope in ways that a for loop would also handle naturally (`for (final item in items) { process(item, outerVariable); }`). No special handling needed.
- **Async forEach on iterables from streams**: This is a rarer but valid pattern. `stream.forEach(handler)` is a `Stream` method with different semantics from `Iterable.forEach`. Check that `Stream.forEach` is excluded — it cannot be replaced with a for loop.
- **`Iterable.forEach` vs `Stream.forEach`**: Check the static type of the target. If `isDartAsyncStream`, exclude.

## Unit Tests

### Should Trigger (violations)
```dart
void main() {
  final list = ['a', 'b', 'c'];

  list.forEach((e) => print(e));                  // LINT — arrow literal
  list.forEach((e) { print(e); });                // LINT — block literal

  final set = <int>{1, 2, 3};
  set.forEach((n) => print(n));                   // LINT

  final iterable = list.where((e) => e.isNotEmpty);
  iterable.forEach((e) => doSomething(e));        // LINT
}
```

### Should NOT Trigger (compliant)
```dart
void main() {
  final list = ['a', 'b', 'c'];

  list.forEach(print);          // OK — method tearoff
  list.forEach(_myHandler);     // OK — tearoff

  // Map.forEach — excluded
  final map = {'a': 1, 'b': 2};
  map.forEach((k, v) => print('$k=$v')); // OK — Map

  // For loop form — this is what we want
  for (final e in list) {
    print(e);
  }
}
```

## Quick Fix
Convert `.forEach((e) => body)` to `for (final e in collection) { body }`:

```dart
class _AvoidForEachFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.methodName.name != 'forEach') return;

      final arg = node.argumentList.arguments.first;
      if (arg is! FunctionExpression) return;

      final param = arg.parameters?.parameters.first;
      final paramName = param?.name?.lexeme ?? 'element';
      final targetSource = resolver.source.contents.data
          .substring(node.target!.offset, node.target!.end);
      final body = arg.body;

      String loopBody;
      if (body is ExpressionFunctionBody) {
        final exprSource = resolver.source.contents.data
            .substring(body.expression.offset, body.expression.end);
        loopBody = '  $exprSource;';
      } else if (body is BlockFunctionBody) {
        // Extract statements from block
        loopBody = resolver.source.contents.data
            .substring(body.block.offset + 1, body.block.end - 1).trim();
      } else {
        return;
      }

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace .forEach() with a for loop',
        priority: 75,
      );

      changeBuilder.addDartFileEdit((builder) {
        final replacement = 'for (final $paramName in $targetSource) {\n$loopBody\n}';
        builder.addSimpleReplacement(node.sourceRange, replacement);
      });
    });
  }
}
```

Note: The fix must handle the enclosing statement context (removing the trailing `;` from the expression statement).

## Notes & Issues
- The Dart core lints package's `avoid_function_literals_in_foreach_calls` rule already exists in `package:lints`. This implementation in saropa_lints should be documented as redundant if the team uses `package:lints`. Consider whether to implement it anyway for teams that do not use `package:lints`.
- If the existing core rule is available, this task can be closed as "duplicate of core lints" and teams can simply enable `avoid_function_literals_in_foreach_calls: true` in their `analysis_options.yaml`.
- The async function literal detection (unawaited forEach) is a separate concern and should potentially be a separate, higher-severity rule (`avoid_async_foreach` or similar) rather than a variant of this rule.
- The Stylistic tier placement means this rule is opt-in. Teams that prefer the functional style for simple one-liners can disable it without affecting other rules.
