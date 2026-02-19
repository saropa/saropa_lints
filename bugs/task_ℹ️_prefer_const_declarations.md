# Task: `prefer_const_declarations`

## Summary
- **Rule Name**: `prefer_const_declarations`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality / Performance

## Problem Statement
Variables holding compile-time constant values should use `const` rather than `final` or `var`. Using `const` on a variable that could be `const` has two benefits: it communicates immutability and compile-time knowability to the reader, and it allows the Dart compiler/runtime to share the canonical constant instance rather than allocating a new object. When developers habitually use `final` for everything, they miss opportunities to signal stronger guarantees. A `const` variable participates in constant folding and constant propagation, which can improve performance in tight loops or frequently-called code.

## Description (from ROADMAP)
Flags `final` variable declarations where the initializer is a compile-time constant expression that could be declared `const` instead.

## Trigger Conditions
- A `VariableDeclarationList` has the `final` keyword (not `const`, not `var`).
- The variable has an initializer expression.
- The initializer expression is a valid compile-time constant expression (can be evaluated at compile time).
- The variable is NOT of a type that disallows `const` (e.g., `late` declarations cannot be `const`).
- The variable is NOT inside an instance field that is not `static` (instance fields cannot be `const`; only static fields or local variables can).

## Implementation Approach

### AST Visitor
```dart
context.registry.addVariableDeclarationList((node) {
  // inspection happens here
});
```

### Detection Logic
1. Check that `node.keyword` is the `final` keyword token. If it is `const` or `var`, skip.
2. Check that `node.isLate` is false (late + const is invalid).
3. For each `VariableDeclaration` in `node.variables`:
   a. Check that `variable.initializer` is non-null.
   b. Check that `variable.initializer` is a constant expression. Use `variable.initializer.accept(ConstantEvaluator())` or check `variable.declaredElement?.constantValue` (works for top-level and static fields). For local variables, use `variable.initializer.isConstantExpression` if the analyzer API exposes it, or attempt constant evaluation.
   c. Check that the variable is not an instance (non-static) field: inspect whether the parent of the `VariableDeclarationList` is a `FieldDeclaration` with `isStatic == false`. If so, skip (instance fields cannot be `const`).
4. If all variables in the list could be `const`, report the `VariableDeclarationList` node.
5. If only some variables in the list could be `const` (mixed), report individual `VariableDeclaration` nodes.

## Code Examples

### Bad (triggers rule)
```dart
// Local variable with constant literal
void compute() {
  final pi = 3.14159;        // LINT: should be const
  final greeting = 'Hello';  // LINT: should be const
  final maxItems = 100;      // LINT: should be const
  final flag = true;         // LINT: should be const
}

// Top-level final with constant value
final defaultTimeout = Duration(seconds: 30);  // LINT: Duration is const-capable

// Static field
class Config {
  static final maxRetries = 3;           // LINT: should be const
  static final appName = 'MyApp';        // LINT: should be const
  static final timeout = Duration(seconds: 5); // LINT: const-capable
}

// Constant list/map/set
void collections() {
  final colors = ['red', 'green', 'blue']; // LINT: all elements are const strings
  final primes = {2, 3, 5, 7, 11};         // LINT: all const ints
}
```

### Good (compliant)
```dart
// Already const
const pi = 3.14159;
const greeting = 'Hello';

// Cannot be const: instance field
class MyClass {
  final name = 'Alice'; // OK: instance fields cannot be const
}

// Cannot be const: runtime value
void dynamic() {
  final now = DateTime.now(); // OK: DateTime.now() is not a constant
  final input = readLine();   // OK: runtime I/O
}

// Cannot be const: late
late final String lazyValue; // OK: late cannot be const

// Cannot be const: mutable (var)
var counter = 0; // OK: var is intentionally mutable

// Cannot be const: contains non-const elements
void mixed() {
  final name = getName(); // OK: function call is not const
  final items = [name, 'fixed']; // OK: name is not const
}

// Static field already const
class Config {
  static const maxRetries = 3;
}
```

## Edge Cases & False Positives
- **Instance fields**: `const` is illegal for instance fields (only static or local). Skip non-static field declarations entirely.
- **`late final`**: `late` and `const` are mutually exclusive. Do not flag `late final`.
- **`final` with type annotation**: `final int x = 42;` should also be flagged — the `final` keyword is in `VariableDeclarationList.keyword`.
- **Const-capable types**: Not all types can be `const`. The type must have a `const` constructor. Primitive types (int, double, String, bool) are always const-capable. `Duration`, `Color`, `RegExp` have const constructors. `DateTime.now()` does not.
- **Collection literals**: `[1, 2, 3]` is const-capable only if all elements are const. `{'key': value}` is const-capable only if all keys and values are const.
- **Cascade expressions**: `final x = SomeClass()..method()` is never const (cascades are not constant expressions).
- **Conditional expressions**: `final x = condition ? 1 : 2;` is const-capable only if `condition` is also const.
- **String interpolation**: `'Hello $name'` is not const if `name` is not const. `'Hello ${'World'}'` is debatable — the interpolated value is a literal but the interpolation syntax is not a const expression in Dart. Flag only pure string literals.
- **Tear-offs**: `final fn = myFunction;` — function tear-offs are const in Dart 2.15+. Respect the effective language version.
- **Multiple variables in one declaration**: `final a = 1, b = 2;` — both are const-capable. Report the whole list.
- **Mixed const-capability in one declaration**: `final a = 1, b = DateTime.now();` — `a` could be const but `b` cannot. In this case, the declaration must be split first. Do not flag the whole list; instead note this as a suggestion that requires splitting.
- **`@pragma('vm:never-inline')` and similar**: Rare but some annotations interact with const. Ignore unless proven problematic.

## Unit Tests

### Should Trigger (violations)
```dart
// Violation: final local with int literal
void localInt() {
  final x = 42; // LINT
}

// Violation: final local with String literal
void localString() {
  final s = 'hello'; // LINT
}

// Violation: top-level final with Duration const constructor
final kTimeout = Duration(seconds: 5); // LINT

// Violation: static final with string
class Foo {
  static final label = 'foo_label'; // LINT
}

// Violation: final list of constants
void constList() {
  final primes = [2, 3, 5, 7]; // LINT
}
```

### Should NOT Trigger (compliant)
```dart
// OK: already const
const k = 42;

// OK: instance field
class Bar {
  final name = 'bar'; // instance field — cannot be const
}

// OK: late
late final String lazy;

// OK: runtime value
void runtime() {
  final now = DateTime.now();
  final random = Random().nextInt(10);
}

// OK: non-const constructor
void obj() {
  final sb = StringBuffer(); // StringBuffer has no const constructor
}

// OK: var
var counter = 0;
```

## Quick Fix
Replace `final` keyword with `const` in the variable declaration.

- Simple case: `final pi = 3.14159;` → `const pi = 3.14159;`
- With type annotation: `final int x = 42;` → `const int x = 42;`
- Top-level: same substitution.
- Static field: same substitution (`static final` → `static const`).

**Fix steps:**
1. Find the `final` keyword token in `node.keyword`.
2. Replace the token's source range with `const`.
3. If the variable has a type annotation (e.g., `final String s = 'x'`), the `const` placement before the type is valid (`const String s = 'x'`).

**Note**: For list/set/map literals that need a `const` prefix on the literal itself (not just the declaration), the fix should also add `const` to the collection literal if not already present. Example: `final x = [1, 2, 3];` → `const x = [1, 2, 3];` (the collection literal is implicitly const when the variable is const).

## Notes & Issues
- Dart SDK: 2.0+ (const in general), but const tear-offs require 2.15+. Respect the effective language version for tear-off cases.
- The canonical Dart lint rule is `prefer_const_declarations` in `package:lints`. Verify whether the saropa package should wrap or extend this. If the SDK lint covers this, the saropa rule should only add value through better fix quality or more precise detection.
- The `isConstantExpression` property may not be directly available on `Expression` nodes in all analyzer versions. Alternative: attempt `expression.accept(ConstantEvaluator())` and check for non-null result.
- Static field vs local variable: `static final` on a class field can be `const`; non-static instance fields cannot. This distinction must be made by checking `FieldDeclaration.isStatic`.
- Performance: `addVariableDeclarationList` is called for every variable declaration in the file. The constant evaluation check may be slow if the initializer is complex. Consider short-circuiting for clearly non-constant initializer types (method calls, instance creations without `const`, etc.).
