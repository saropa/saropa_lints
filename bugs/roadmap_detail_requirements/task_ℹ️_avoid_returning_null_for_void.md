# Task: `avoid_returning_null_for_void`

## Summary
- **Rule Name**: `avoid_returning_null_for_void`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality / Unnecessary Code

## Problem Statement
Explicitly writing `return null;` inside a function whose return type is `void` is pure noise. `void` functions implicitly return `null` — there is no observable difference between `return;`, `return null;`, and falling off the end of the function. The explicit `return null;` misleads readers into thinking the return value is meaningful, clutters the code, and may indicate copy-paste from a non-void function. Removing these statements makes intent clearer: the function produces no value worth examining.

## Description (from ROADMAP)
Flags explicit `return null;` statements inside `void`-returning functions where the `null` return value is implicit and the explicit statement is dead weight.

## Trigger Conditions
- The enclosing function, method, or closure has a declared return type of `void` (including `Future<void>` — see edge cases).
- The return statement contains an explicit `NullLiteral` expression (`null`).
- This includes top-level functions, instance methods, static methods, operator overloads, and anonymous functions/closures with inferred or explicit `void` return type.

## Implementation Approach

### AST Visitor
```dart
context.registry.addReturnStatement((node) {
  // inspection happens here
});
```

### Detection Logic
1. Check whether `node.expression` is a `NullLiteral`. If not, skip immediately.
2. Walk up the AST to find the nearest enclosing function body. Candidate ancestors: `FunctionBody`, found via `node.thisOrAncestorOfType<FunctionBody>()`.
3. From the function body, get the enclosing `FunctionDeclaration`, `MethodDeclaration`, `FunctionExpression`, or `ConstructorDeclaration`.
4. Obtain the declared return type element:
   - For `FunctionDeclaration`: `declaration.returnType?.type`.
   - For `MethodDeclaration`: `declaration.returnType?.type`.
   - For `FunctionExpression`: infer from context or enclosing element's type.
5. Check if the return type's `isVoid` property is `true` (use `DartType.isVoid`).
6. If `isVoid` is true, report the `ReturnStatement` node.

**Note on `Future<void>`**: `Future<void>.isVoid` is `false` because the outer type is `Future`. Treat `Future<void>` as a separate edge case — see below.

## Code Examples

### Bad (triggers rule)
```dart
// Top-level void function
void reset() {
  counter = 0;
  return null; // LINT
}

// Instance method
class Counter {
  int _count = 0;

  void increment() {
    _count++;
    return null; // LINT
  }

  void decrement() {
    if (_count > 0) {
      _count--;
      return null; // LINT — inside conditional
    }
  }
}

// Static method
class Logger {
  static void log(String message) {
    print(message);
    return null; // LINT
  }
}

// Anonymous function assigned to void-typed variable
final VoidCallback onTap = () {
  doSomething();
  return null; // LINT
};

// Callback parameter typed void
void runWithCallback(void Function() callback) {}
void callIt() {
  runWithCallback(() {
    doSomething();
    return null; // LINT
  });
}
```

### Good (compliant)
```dart
// OK: bare return with no value
void reset() {
  counter = 0;
  return; // fine — bare return for early exit
}

// OK: fall-off (no return statement at all)
void increment() {
  _count++;
}

// OK: Future<void> — different analysis applies
Future<void> asyncReset() async {
  counter = 0;
  // returning null here may be intentional in some contexts
}

// OK: returning a non-null non-void expression
// (would be a different compile error if void, so not reachable normally)
```

## Edge Cases & False Positives
- **`Future<void>` return type**: The outer type is `Future`, not `void`. `return null;` in a non-async `Future<void>` function is similar to the `avoid_returning_null_for_future` rule. Do NOT flag under this rule; let the other rule handle it. For async `Future<void>` methods, `return null;` is equivalent to `return;` (async wraps in Future.value). This rule should NOT flag async `Future<void>` methods.
- **`void` return type on callbacks**: Closures passed to higher-order functions where the callback signature is `void Function()` — the closure's return type is inferred as `void`. Flag these.
- **Inferred void from context**: If a closure has no explicit return type annotation but is inferred as `void` from context (e.g., assigned to `VoidCallback`), the type system knows it is void. Flag these using the element's type, not just the annotation.
- **`Null` (capital N) type**: `Null` is the type of `null`. It is distinct from `void`. A method declared as returning `Null` (unusual but valid) should not be flagged by this rule.
- **`dynamic` return type**: `return null;` in a `dynamic`-returning function is valid and intentional. Do NOT flag.
- **No return type annotation**: If there is no explicit return type and it cannot be inferred as `void`, skip (err on the side of caution).
- **Override of non-void base**: Unlikely, because overriding a non-void with void would be a type error. Safe to ignore.
- **Operator overloads with void**: Rare but possible: `void operator []=(int index, String value)` — flag if `return null;` appears.
- **Setters**: Dart setters always return `void`. `return null;` in a setter body should be flagged.

## Unit Tests

### Should Trigger (violations)
```dart
// Violation: top-level void function
void doWork() {
  print('working');
  return null; // LINT
}

// Violation: void method
class Foo {
  void bar() {
    return null; // LINT
  }
}

// Violation: void setter
class Baz {
  String _name = '';
  set name(String value) {
    _name = value;
    return null; // LINT
  }
}

// Violation: void closure assigned to VoidCallback
typedef VoidCallback = void Function();
void test() {
  VoidCallback cb = () {
    return null; // LINT
  };
}
```

### Should NOT Trigger (compliant)
```dart
// OK: bare return
void ok1() {
  return;
}

// OK: no return statement
void ok2() {
  print('done');
}

// OK: dynamic return type
dynamic ok3() {
  return null;
}

// OK: nullable non-void return type
String? ok4() {
  return null;
}

// OK: Future<void> async — handled by separate rule
Future<void> ok5() async {
  return null;
}

// OK: Null return type (unusual but valid, different from void)
Null ok6() {
  return null;
}
```

## Quick Fix
Remove the `return null;` statement entirely.

- If the statement is `return null;`, delete it completely (including trailing newline if it leaves a blank line).
- If the `return null;` is an early return inside an `if` block (e.g., `if (x) { return null; }`), replace it with a bare `return;` to preserve the early-exit semantics.

**Fix logic:**
1. Check if `node.expression` is `NullLiteral`.
2. If the `ReturnStatement` is a standalone statement in the function's top-level block (last statement or followed by other statements), delete the entire statement.
3. If the `ReturnStatement` is inside a conditional branch and removing it would change control flow (early return), replace `return null;` with `return;` instead.

The heuristic for step 3: if the `ReturnStatement`'s parent is a `Block` whose parent is a conditional (`IfStatement`, `WhileStatement`, etc.) and the return is not the last statement of the enclosing function, use `return;`.

## Notes & Issues
- Dart SDK: 2.0+ (null safety not required for this rule — it applies even in pre-null-safety code where `void` functions accepting `return null;` is redundant).
- The `DartType.isVoid` property is the authoritative check for the `void` type. Use this rather than `type.toString() == 'void'`.
- Lint rule `unnecessary_null_in_if_null_operators` is a different concern. This rule is specifically about `return null` in void functions.
- Existing Dart SDK lint: `avoid_returning_null` exists in the official Dart linting package and covers a similar (but broader) scenario. Verify whether the saropa_lints rule should complement or replace it. If the SDK rule already exists and is enabled in `analysis_options.yaml`, this saropa rule should add value by providing a better problem message or fix — otherwise it may be redundant.
- Severity should be INFO (style improvement) rather than WARNING (potential bug), because the code is correct — just unnecessarily verbose.
