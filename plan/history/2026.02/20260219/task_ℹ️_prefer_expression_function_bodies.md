# Task: `prefer_expression_function_bodies`

## Summary
- **Rule Name**: `prefer_expression_function_bodies`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality / Style

## Problem Statement
Functions and methods whose body consists solely of `{ return expression; }` should use the more concise expression body syntax (`=> expression`). The block body form with a single return statement adds five characters of boilerplate (`{`, space, `return`, `;`, `}`) and forces the reader to scan for the return statement instead of seeing the value immediately after `=>`. Expression bodies convey "this function is just a value" clearly and concisely, reduce visual noise, and are idiomatic in Dart for simple getters, delegates, and short computations. This applies to functions, methods, getters, and named constructors.

## Description (from ROADMAP)
Flags functions and methods with a block body containing only a single `return` statement, suggesting conversion to expression body (`=>`) syntax.

## Trigger Conditions
- A `FunctionDeclaration`, `MethodDeclaration`, `FunctionExpression`, or similar declaration has a `BlockFunctionBody`.
- The block body contains **exactly one statement**.
- That single statement is a `ReturnStatement` with a non-null expression.
- The function is NOT a setter (setters cannot use `=>` with a value — they use `=> void`).
- The function is NOT `async` returning `void` (see edge cases).

## Implementation Approach

### AST Visitor
```dart
context.registry.addBlockFunctionBody((node) {
  // inspection happens here
});
```

### Detection Logic
1. Check that `node.block.statements.length == 1`.
2. Check that `node.block.statements.first` is a `ReturnStatement`.
3. Get the `ReturnStatement`; check that `returnStatement.expression != null` (not a bare `return;`).
4. Walk up the AST to find the enclosing declaration. Determine the type of function:
   - `FunctionDeclaration` (top-level or local function).
   - `MethodDeclaration` (instance/static method, getter, setter, operator).
   - `FunctionExpression` (anonymous function or closure).
5. If the enclosing declaration is a setter (`MethodDeclaration.isSetter == true`), skip — setters use block bodies by convention or use `=> void`.
6. If the function is `async` AND the return type is `void` or `Future<void>`, consider skipping (see edge cases — `async` functions CAN use `=>`).
7. Report the `BlockFunctionBody` node (or the containing declaration).

**Alternatively**: Use `context.registry.addFunctionDeclaration` and `addMethodDeclaration` and check the body type, which may be cleaner for associating the fix with the correct node.

## Code Examples

### Bad (triggers rule)
```dart
// Getter with block body
class User {
  String _name = '';

  String get name {    // LINT: use => _name;
    return _name;
  }
}

// Method with block body
int add(int a, int b) {   // LINT: use => a + b;
  return a + b;
}

// Top-level function
String greet(String name) {   // LINT: use => 'Hello, $name!';
  return 'Hello, $name!';
}

// Named method delegate
class Logger {
  void _log(String message) {}

  void info(String message) {   // LINT: use => _log(message);
    return _log(message);
  }
}

// Async function with single return
Future<String> fetchName() async {   // LINT: use => Future.value('Alice');
  return Future.value('Alice');
}

// Lambda / closure assigned to variable
final square = (int x) {   // LINT: use => x * x;
  return x * x;
};
```

### Good (compliant)
```dart
// Already expression body
String get name => _name;
int add(int a, int b) => a + b;
String greet(String name) => 'Hello, $name!';

// Setter — block body is conventional and cannot have a meaningful =>
set name(String value) {
  _name = value;
}

// Multi-statement body — cannot convert
String formatUser(User user) {
  final prefix = user.isAdmin ? '[ADMIN]' : '';
  return '$prefix${user.name}';
}

// Bare return (void) — no expression to extract
void reset() {
  return;
}

// async void — technically can use => but conventionally uses block
Future<void> initialize() async {
  await _db.open();
  return;
}
```

## Edge Cases & False Positives
- **Setters**: `set name(String v) { _name = v; }` — setters have no return value (implicitly void). The `return;` case has no expression. Do NOT flag setters. Even `set name(String v) { return; }` should not be converted (though it is arguably redundant).
- **`async` functions**: `async` functions CAN use `=>` syntax: `Future<String> fetchName() async => 'Alice';`. This is valid Dart. Flag these if the body is `async { return expr; }` because `async => expr` is equivalent. However, some teams prefer the explicit `async {}` form for async functions for readability. Consider making this configurable.
- **Generators (`sync*`, `async*`)**: Generator functions (`sync*` and `async*`) CANNOT use `=>` syntax. Skip these.
- **`void` return type**: A method declared `void` can technically return an expression if the expression is void: `void doWork() { return someVoidFn(); }` → `void doWork() => someVoidFn();`. This is valid. Flag these.
- **Anonymous functions / closures**: `(x) { return x * 2; }` → `(x) => x * 2`. These are common in Flutter `onPressed`, map, where, etc. Flag these.
- **Constructor bodies**: Constructors cannot use `=>` syntax. Skip `ConstructorDeclaration` bodies entirely.
- **Operator overloads**: Operators CAN use `=>`: `operator +(other) => Point(x + other.x, y + other.y);`. Flag operator overloads with single return.
- **Return expression spanning multiple lines**: The expression body `=>` supports multi-line expressions (e.g., a ternary spread across lines). This is not a problem for the fix — the expression content is preserved as-is.
- **Early returns mixed with single return**: If the block has only one statement and it is a return, we have already confirmed this. But ensure that the block truly has ONE statement (check `statements.length == 1` exactly, not "the last statement is a return").
- **Labeled statements**: If the sole statement is a labeled return (`label: return expr;`) — unusual but possible. Skip or handle carefully since `=>` cannot have labels.
- **`if` with implicit return**: `{ if (x) return a; return b; }` has TWO statements — do not flag.
- **Comments inside the body**: Comments (`//`, `/* */`) are not AST statements. A body with `{ // comment\n return expr; }` still has one statement. Flag these — the comment will be lost in the conversion (or moved). Decide: flag and note comment loss, or skip when comments are present. Recommend: flag but note in fix description that inline comments will be removed.

## Unit Tests

### Should Trigger (violations)
```dart
// Violation: simple getter
class Box {
  double _size = 0;
  double get size {
    return _size; // LINT
  }
}

// Violation: instance method
class Calculator {
  int multiply(int a, int b) {
    return a * b; // LINT
  }
}

// Violation: top-level function
String repeat(String s, int n) {
  return s * n; // LINT
}

// Violation: operator overload
class Vec {
  final int x, y;
  const Vec(this.x, this.y);
  Vec operator +(Vec other) {
    return Vec(x + other.x, y + other.y); // LINT
  }
}

// Violation: async function single return
Future<int> getCount() async {
  return 42; // LINT: could be async => 42
}

// Violation: closure assigned to variable
int Function(int) doubler = (int x) {
  return x * 2; // LINT
};
```

### Should NOT Trigger (compliant)
```dart
// OK: already expression body
double get size => _size;

// OK: setter
set size(double v) {
  _size = v;
}

// OK: multi-statement body
String formatUser(String name, int age) {
  final label = age > 18 ? 'adult' : 'minor';
  return '$label: $name';
}

// OK: bare return (no expression)
void log(String msg) {
  print(msg);
  return;
}

// OK: generator function
Iterable<int> gen() sync* {
  yield 1;
  return;
}

// OK: constructor
class Foo {
  Foo(this.x) {
    return; // constructors cannot use =>
  }
  final int x;
}
```

## Quick Fix
Convert the block function body to an expression body.

**Fix steps:**
1. Extract the expression from `returnStatement.expression`.
2. Determine the source of the expression (preserving any multi-line formatting).
3. Replace the `BlockFunctionBody` source range with `=> expressionSource;`.
4. If the enclosing function is `async`, the expression body becomes `async => expressionSource;` (insert `async` keyword before `=>`).
5. Preserve the trailing semicolon for declarations (function declarations end with `;` after `=>`).

**Example transformations:**
```dart
// Before
String get name {
  return _name;
}

// After
String get name => _name;

// Before (async)
Future<String> fetchData() async {
  return _service.getData();
}

// After (async)
Future<String> fetchData() async => _service.getData();
```

**Edge case — comments**: If there are inline comments in the removed block body, they are lost. The fix should warn in its description: "This removes the block body; any comments inside will be lost." Consider not offering the fix if comments are detected inside the block.

**Semicolon handling**: For method declarations inside classes, expression bodies end with `;` (no `{}`). Ensure the fix correctly replaces `{ return expr; }` with `=> expr;` including the semicolon.

## Notes & Issues
- Dart SDK: 2.0+ (expression bodies have always existed in Dart).
- The fix for `FunctionExpression` (anonymous function) differs: closures use `=> expr` without trailing `;` when used inline (e.g., as an argument). When assigned to a variable, they use `=> expr;` with a semicolon from the `VariableDeclaration`. Be careful about the trailing semicolon source range.
- The official Dart lint `prefer_expression_function_bodies` exists in `package:lints/recommended.yaml`. Verify whether this rule is already enabled in the project's `analysis_options.yaml`. If it is, implementing a duplicate rule adds no value. The saropa version would only be useful if it has a better quick fix or is more precise.
- Performance: `addBlockFunctionBody` fires for every block body in the codebase. The check is O(1) (check statement count = 1 and type of first statement), so it is fast.
- Configurable option consideration: Some teams prefer block bodies for async functions even when an expression body is valid. Consider a `prefer_expression_function_bodies_for_async: false` configuration option in the rule's options.
- The `=>` expression body style is idiomatic Dart and heavily used in Flutter widget overrides (`build`, `createState`) and getters. High signal-to-noise ratio in Flutter projects.
