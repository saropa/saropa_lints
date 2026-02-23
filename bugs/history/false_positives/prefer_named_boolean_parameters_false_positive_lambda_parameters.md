# Bug: `prefer_named_boolean_parameters` false positive on lambda/closure parameters

## Resolution

**Fixed.** Skip when `FormalParameterList` parent is `FunctionExpression` — lambda parameter signatures are constrained by the expected function type.


## Summary

The `prefer_named_boolean_parameters` rule incorrectly flags boolean parameters
in lambda expressions and closures passed to higher-order functions like `any()`,
`where()`, `map()`, and `every()`. These are callback parameters whose signature
is determined by the iterable's generic type, not by API design choices. The rule
is intended for method/function signatures where callers write `doThing(true)`,
but lambdas like `(bool e) => e` are a fundamentally different context.

## Severity

**False positive** -- the rule's advice ("Convert to a named parameter") is
impossible to follow for lambda parameters. The signature of the callback is
dictated by the higher-order function's typedef. Developers cannot change
`any((bool e) => e)` to `any(({required bool e}) => e)` because `any()`
expects `bool Function(bool)`, not `bool Function({required bool e})`.

## Reproduction

### Minimal example

```dart
extension BoolIterableExtensions on Iterable<bool> {
  // FLAGGED: prefer_named_boolean_parameters at column 28
  //          "Positional boolean parameter detected"
  bool get anyTrue => any((bool e) => e);

  // FLAGGED: prefer_named_boolean_parameters at column 29
  bool get anyFalse => any((bool e) => !e);

  // FLAGGED: prefer_named_boolean_parameters at column 31
  int get countTrue => where((bool e) => e).length;

  // FLAGGED: prefer_named_boolean_parameters at column 32
  int get countFalse => where((bool e) => !e).length;

  // FLAGGED: prefer_named_boolean_parameters at column 34
  List<bool> get reverse => map((bool b) => !b).toList();
}
```

### Why this cannot be fixed

The `any()` method on `Iterable<bool>` has the signature:
```dart
bool any(bool test(E element));  // where E = bool
```

The callback MUST accept a single positional `bool` parameter. Converting it
to a named parameter would change the function signature to a type incompatible
with `any()`'s expected callback type.

```dart
// This is what the lint suggests, but it DOES NOT COMPILE:
bool get anyTrue => any(({required bool e}) => e);
// Error: The argument type 'bool Function({required bool e})'
//        can't be assigned to 'bool Function(bool)'
```

### Lint output

```
line 55 col 28 • [prefer_named_boolean_parameters] Positional boolean
parameter detected. Call sites like doThing(true) give no indication what
the boolean controls, forcing readers to look up the function signature
to understand the intent. {v5}
```

### All affected locations (5 instances)

| File | Line | Lambda | Parent HOF |
|------|------|--------|------------|
| `lib/bool/bool_iterable_extensions.dart` | 55 | `(bool e) => e` | `any()` |
| `lib/bool/bool_iterable_extensions.dart` | 68 | `(bool e) => !e` | `any()` |
| `lib/bool/bool_iterable_extensions.dart` | 78 | `(bool e) => e` | `where()` |
| `lib/bool/bool_iterable_extensions.dart` | 88 | `(bool e) => !e` | `where()` |
| `lib/bool/bool_iterable_extensions.dart` | 98 | `(bool b) => !b` | `map()` |

## Root cause

The rule detects any `FormalParameter` node with a `bool` type annotation and
flags it if it's positional. It does not check whether the parameter belongs to:

1. A **function/method declaration** (where the rule is appropriate), or
2. A **lambda/closure expression** (where the parameter signature is constrained
   by the expected function type)

### AST distinction

```
// Method declaration parameter (rule SHOULD apply):
MethodDeclaration
  └─ FormalParameterList
       └─ SimpleFormalParameter(type: bool, name: 'verbose')

// Lambda/closure parameter (rule should NOT apply):
FunctionExpression
  └─ FormalParameterList
       └─ SimpleFormalParameter(type: bool, name: 'e')
```

The rule needs to check the parent node: if the parameter belongs to a
`FunctionExpression` (lambda/closure), it should be skipped. The lambda's
parameter signature is not under the developer's control -- it must match
the typedef expected by the higher-order function.

## Suggested fix

Skip the rule when the parameter is inside a `FunctionExpression` (lambda):

```dart
void checkFormalParameter(SimpleFormalParameter node) {
  // Only check bool parameters
  if (node.type?.type?.isDartCoreBool != true) return;

  // Skip lambda/closure parameters -- their signature is constrained
  // by the expected function type
  final parent = node.thisOrAncestorOfType<FunctionExpression>();
  if (parent != null) {
    return; // Do not flag lambda parameters
  }

  // ... existing logic for method/function declaration parameters
}
```

### Alternative: More targeted skip

If the rule wants to be more precise, it can check whether the lambda is passed
as an argument to a function call (meaning the signature is externally constrained):

```dart
// Check if the FunctionExpression is an argument to a method/function call
final funcExpr = node.thisOrAncestorOfType<FunctionExpression>();
if (funcExpr != null) {
  final callParent = funcExpr.parent;
  if (callParent is ArgumentList) {
    return; // Lambda passed as argument -- signature is constrained
  }
}
```

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Lambda passed to any()
final result1 = bools.any((bool e) => e);

// Lambda passed to where()
final result2 = bools.where((bool e) => !e);

// Lambda passed to map()
final result3 = bools.map((bool b) => !b);

// Lambda passed to every()
final result4 = bools.every((bool e) => e);

// Lambda assigned to a typed variable
final bool Function(bool) predicate = (bool x) => x;

// Lambda in collection method chains
final filtered = items.where((bool active) => active).toList();

// Should STILL flag (true positives, no change):

// Method with positional bool parameter
void doThing(bool verbose) { }  // FLAGGED: call site is doThing(true)

// Function with positional bool parameter
String format(String input, bool uppercase) { }  // FLAGGED

// Constructor with positional bool parameter
class Config {
  Config(bool debugMode);  // FLAGGED
}

// Named constructors
class Settings {
  Settings.create(bool enabled);  // FLAGGED
}
```

## Impact

Every use of `Iterable<bool>` methods (`any`, `where`, `map`, `every`,
`firstWhere`, `singleWhere`, etc.) with an explicit type annotation on the
callback parameter will be falsely flagged. This also affects:

- `List<bool>.sort((bool a, bool b) => ...)` comparators
- `Set<bool>.where((bool e) => ...)` filters
- Custom higher-order functions that accept `bool Function(bool)` callbacks
- Event handlers: `stream.listen((bool value) => ...)`

The rule produces noise on idiomatic, correct Dart code where the developer
has no ability to change the parameter to a named parameter.
