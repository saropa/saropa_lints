# Task: `avoid_single_cascade_in_expression_statements`

## Summary
- **Rule Name**: `avoid_single_cascade_in_expression_statements`
- **Tier**: Stylistic
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Style

## Problem Statement
The cascade operator (`..`) in Dart allows chaining multiple method calls or property assignments on the same receiver without repeating the receiver expression. Its value comes from the chaining — reducing repetition across multiple operations on the same object.

When a cascade is used for only a single operation (`list..add(item)`), it provides no advantage over a direct method call (`list.add(item)`). The single-cascade form:

1. **Is harder to read**: Readers must know what `..` does and recognize that only one operation follows.
2. **Adds visual weight**: The `..` prefix looks like a potential multi-operation chain, creating a false expectation that more cascades follow.
3. **Is semantically different**: A cascade expression returns the receiver, not the result of the operation. `list..add(item)` returns `list`, not `void`. This difference is irrelevant in a statement context but could mislead readers about what the expression evaluates to.
4. **Blocks IntelliJ/VS Code quick-actions**: Some IDE refactoring tools treat cascades specially; a single-cascade that should be a method call can break "Extract Method" and other refactors.

The cascade operator is justified when two or more operations are chained on the same receiver.

## Description (from ROADMAP)
Detects cascade expressions with exactly one cascade section used as an expression statement, recommending a direct method call instead.

## Trigger Conditions
- A `CascadeExpression` node
- The cascade has exactly one entry in its `cascadeSections` list
- The cascade expression is used as an `ExpressionStatement` (standalone statement, not part of a larger expression such as an assignment, return, or argument)

## Implementation Approach

### AST Visitor
```dart
context.registry.addCascadeExpression((node) {
  // ...
});
```

### Detection Logic
1. Check `node.cascadeSections.length == 1`.
2. Walk up to the parent node and check whether it is an `ExpressionStatement`. If the cascade is used in an assignment (`variable = obj..method()`), a return statement (`return obj..method()`), or as an argument, it is NOT flagged — in those contexts the cascade's "return receiver" semantic may be intentional.
3. Specifically check that `node.parent is ExpressionStatement`.
4. Report the cascade expression node.

### What Counts as a Cascade Section
A cascade section can be:
- `..methodCall(args)` — method invocation
- `..property = value` — property assignment
- `..property` — property access (read)
- `..index[i]` — index access

All are covered by checking `node.cascadeSections.length`.

## Code Examples

### Bad (triggers rule)
```dart
// Single method cascade in statement — use direct call.
void addItem(List<String> list, String item) {
  list..add(item); // LINT — use list.add(item)
}

// Single property assignment cascade in statement.
void configure(Config config) {
  config..timeout = 30; // LINT — use config.timeout = 30
}

// Single index assignment via cascade.
void setFirst(List<String> items) {
  items..[0] = 'first'; // LINT — use items[0] = 'first'
}

// Cascade as statement in a method chain (still single cascade).
void process(MyObject obj) {
  obj..run(); // LINT — use obj.run()
}
```

### Good (compliant)
```dart
// Multiple cascades — cascade is justified.
void setup(List<String> list) {
  list
    ..add('first')
    ..add('second')
    ..sort();
}

// Builder pattern with multiple cascades.
final paint = Paint()
  ..color = Colors.red
  ..style = PaintingStyle.fill
  ..strokeWidth = 2.0;

// Single cascade in assignment context — returns receiver, may be intentional.
final result = list..add(item); // Not flagged — assignment context

// Single cascade in return context — returns receiver, may be intentional.
List<String> addAndReturn(List<String> list, String item) {
  return list..add(item); // Not flagged — return context
}

// Single cascade as argument — may be intentional.
process(list..add(item)); // Not flagged — argument context

// Direct method call — preferred for single operations.
void addItem(List<String> list, String item) {
  list.add(item);
}
```

## Edge Cases & False Positives
- **Assignment context**: `final x = obj..method()` — the cascade returns the receiver `obj`. In an assignment, this is a legitimate use: it sets `x` to `obj` and calls `method()` as a side effect. Do NOT flag.
- **Return context**: `return obj..method()` — returns the receiver. May be intentional in builder or fluent interface patterns. Do NOT flag.
- **Argument context**: `process(obj..method())` — passes the receiver to `process` while also calling `method()`. May be intentional. Do NOT flag.
- **Builder pattern conventions**: Some libraries (e.g., `CanvasKit`, `dart:ui`) use the cascade convention for building objects even with a single property. However, `Paint()..color = red` is typically multi-cascade, so single-cascade Paint use is genuinely rare.
- **Null-safe cascade (`?..`)**: The null-safe cascade `obj?..method()` is a single cascade — it should also be flagged since `obj?.method()` is the direct equivalent and clearer.
- **Index cascade**: `list..[0]` (reading, not assigning) — a read-only index cascade has no side effect and is definitely useless. Flag this.
- **Generated code**: Skip `*.g.dart`, `*.freezed.dart`.
- **Test code**: Some test setup code uses single cascades conventionally. Consider a configuration to skip test files.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: single method cascade as statement
void t1(List<int> list) {
  list..add(1); // LINT
}

// Test 2: single property assignment cascade as statement
class Cfg { int timeout = 0; }
void t2(Cfg c) {
  c..timeout = 30; // LINT
}

// Test 3: null-safe single cascade as statement
void t3(List<int>? list) {
  list?..add(1); // LINT — use list?.add(1)
}
```

### Should NOT Trigger (compliant)
```dart
// Test 4: multiple cascades
void t4(List<int> list) {
  list..add(1)..add(2); // No lint
}

// Test 5: single cascade in assignment
void t5(List<int> list) {
  final result = list..add(1); // No lint
}

// Test 6: single cascade in return
List<int> t6(List<int> list) => list..add(1); // No lint

// Test 7: single cascade as argument
void t7(List<int> list) {
  print(list..add(1)); // No lint
}

// Test 8: direct call — already compliant
void t8(List<int> list) {
  list.add(1); // No lint
}
```

## Quick Fix
**Message**: "Replace single cascade with a direct method call or property access"

The fix for `obj..method(args)` as an expression statement:
1. Replace `obj..method(args)` with `obj.method(args)`.
2. For property assignments `obj..prop = value`: replace with `obj.prop = value`.
3. For index access/assignment `obj..[i] = value`: replace with `obj[i] = value`.
4. For null-safe cascade `obj?..method()`: replace with `obj?.method()`.

The transformation is a simple text replacement of `..` with `.` (or `?.` for null-safe cascade `?..`).

Special care:
- Do not apply the fix if the cascade has more than one section (detection logic prevents this, but verify in the fix).
- Preserve all whitespace and formatting around the replaced operator.

## Notes & Issues
- The Stylistic tier is appropriate — this is a pure style concern. However, the readability argument is strong enough to consider Recommended tier. The final tier should be decided after surveying how frequently this pattern appears in real Flutter/Dart codebases.
- The null-safe cascade `?..` is relatively uncommon but follows the same logic. Make sure the fix correctly handles the `?..` → `?.` transformation.
- Dart's official linter does not currently have a rule for this specific pattern — this is an opportunity for saropa_lints to provide unique value.
- When reporting, the diagnostic message should give a concrete example of the replacement: "Use `list.add(item)` instead of `list..add(item)`" — referencing the actual receiver and method name from the code makes the message much more actionable.
- Consider a future enhancement that auto-merges a flagged single cascade with adjacent cascade expressions on the same receiver: if `list..add(a);` is followed immediately by `list..add(b);`, suggest merging to `list..add(a)..add(b);`.
