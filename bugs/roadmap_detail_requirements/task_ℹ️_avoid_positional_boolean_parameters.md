# Task: `avoid_positional_boolean_parameters`

## Summary
- **Rule Name**: `avoid_positional_boolean_parameters`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Positional boolean parameters create completely unreadable call sites. When a reader encounters `login(true, false)`, `setPermissions(true, true, false)`, or `configure(false, true)`, they have no idea what the booleans mean without inspecting the function signature. This is a well-known code smell documented in "Clean Code" (Martin) and the Google Dart style guide.

The problem is compounded by:
1. **Refactoring risk**: Adding or reordering parameters silently changes call semantics without a compile error.
2. **Review blindness**: Code reviewers miss incorrect argument order because both `true` and `false` are valid values.
3. **IDE friction**: Even with IDE tooltips, positional args require extra navigation to understand.

Named parameters eliminate all of these problems: `login(rememberMe: true, staySignedIn: false)` is self-documenting.

## Description (from ROADMAP)
Detects function and method declarations with positional `bool` parameters, encouraging named parameters for clarity at call sites.

## Trigger Conditions
- A `FunctionDeclaration`, `MethodDeclaration`, or `ConstructorDeclaration`
- The formal parameter list contains at least one required positional parameter OR optional positional parameter (`[bool x]`) whose declared type is `bool` or `bool?`
- The enclosing entity is not an operator overload
- The parameter is not a function-typed parameter (i.e., a callback like `bool Function() predicate`)

## Implementation Approach

### AST Visitor
```dart
context.registry.addFormalParameterList((node) {
  // ...
});
```

### Detection Logic
1. Retrieve the parent of the `FormalParameterList` node.
2. Skip if the parent is an `FunctionTypedFormalParameter`, `GenericFunctionType`, or `FunctionExpression` (anonymous functions / lambdas — these are commonly short and positional bool is acceptable).
3. Skip if the parent is a `MethodDeclaration` that is an operator (`isOperator == true`).
4. Skip if the parent is a `MethodDeclaration` or `FunctionDeclaration` annotated with `@override` — the signature is forced by the parent type.
5. Iterate over `node.parameters` and collect those where:
   - `parameter.isPositional == true` (not named)
   - The resolved type of the parameter is `bool` or `bool?`
   - The parameter is not a function type (check `parameter is SimpleFormalParameter` and its type is not `GenericFunctionType`)
6. Report each offending positional bool parameter with a message pointing to it specifically.

## Code Examples

### Bad (triggers rule)
```dart
// Three positional bools — completely opaque at the call site.
void setPermissions(bool canRead, bool canWrite, bool canDelete) { // LINT x3
  // ...
}
// Call site: setPermissions(true, false, true)

// Optional positional bool — still unreadable.
void configure(String host, [bool useTls = true]) { // LINT on useTls
  // ...
}
// Call site: configure('example.com', false)

// Constructor with positional bool.
class Connection {
  Connection(String host, bool secure); // LINT on secure
}
// Call site: Connection('example.com', true)

// Single positional bool — simple but still unclear.
void toggle(bool on) { // LINT
  // ...
}
// Call site: toggle(true)
```

### Good (compliant)
```dart
// Named parameters — self-documenting at every call site.
void setPermissions({
  required bool canRead,
  required bool canWrite,
  required bool canDelete,
}) {
  // ...
}
// Call site: setPermissions(canRead: true, canWrite: false, canDelete: true)

// Named optional with default.
void configure(String host, {bool useTls = true}) {
  // ...
}
// Call site: configure('example.com', useTls: false)

// Constructor with named bool.
class Connection {
  Connection(String host, {required bool secure});
}
// Call site: Connection('example.com', secure: true)

// Lambda / anonymous function — exempt.
final predicate = (bool x) => !x; // OK

// Setter — always positional by language design.
set active(bool value) { // OK: setters must be positional
  _active = value;
}

// Override — signature is forced.
@override
bool shouldRepaint(bool oldValue) => true; // OK: override
```

## Edge Cases & False Positives
- **Setters**: Dart setters (`set foo(bool value)`) are always positional by language syntax. Do not flag.
- **Overrides**: Methods annotated with `@override` have their signature determined by the supertype. Do not flag — the fix should be applied at the declaration site in the supertype.
- **Operators**: Operator overloads are positional by convention and language syntax. Do not flag.
- **Anonymous functions / lambdas**: Short lambdas and callbacks (`list.where((bool x) => x)`) use positional params by convention. Skip `FunctionExpression` nodes.
- **`typedef` declarations**: `typedef Predicate = bool Function(bool);` — skip typedef bodies.
- **`external` functions**: Functions marked `external` (FFI/platform channels) have signatures dictated by native APIs. Do not flag.
- **Single-parameter functions where the name is clear**: `void enable(bool value)` — while technically flagged, the name "enable" with one bool is arguably readable. Consider severity INFO to reduce noise, or add a minimum-of-2-bools threshold option.
- **Test files**: In test files, helper functions often use positional bools for brevity. Consider a configurable option to skip test files.
- **Generated code**: Skip files matching `*.g.dart`, `*.freezed.dart`, `*.gen.dart`.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: multiple positional bools
void f1(bool a, bool b) {} // LINT x2

// Test 2: optional positional bool
void f2(String s, [bool flag = false]) {} // LINT on flag

// Test 3: constructor positional bool
class C1 {
  C1(bool active); // LINT
}

// Test 4: mixed positional params, only bool flagged
void f3(String name, bool active, int count) {} // LINT on active only
```

### Should NOT Trigger (compliant)
```dart
// Test 5: named bool param
void f4({required bool active}) {}

// Test 6: setter — exempt
set active(bool value) {}

// Test 7: lambda — exempt
final fn = (bool x) => x;

// Test 8: override — exempt
class Base { void run(bool x) {} }
class Sub extends Base {
  @override
  void run(bool x) {} // No lint — forced by override
}

// Test 9: non-bool positional
void f5(String a, int b) {}
```

## Quick Fix
**Message**: "Convert positional bool parameter to a named parameter"

The fix should:
1. Wrap the parameter in a named form by adding `{required` before and `}` wrapping the parameter list section, or simply add `{` and `}` around the bool parameter if other params are positional.
2. If the parameter has a default value (optional positional), convert to optional named: `[bool x = false]` → `{bool x = false}`.
3. Note in the correction message that all call sites must be updated to use the named argument syntax — the fix cannot automatically update call sites across the project.

Optionally, offer a secondary fix: "Wrap in a descriptive type alias or enum" with a TODO stub.

## Notes & Issues
- This rule is closely related to `prefer_named_bool_params` (File 4). Evaluate whether they should be merged into a single rule with a shared code. The distinction is: this rule is about forbidding the anti-pattern; the other promotes the positive pattern. If merged, keep one canonical rule name.
- Consider making the minimum number of boolean parameters triggering the lint configurable (default: 1).
- Dart's own linter has `avoid_positional_boolean_parameters` as an experimental rule — review its implementation for edge cases before implementing from scratch.
- The rule should be disabled for projects that heavily use platform channel interop or FFI, where positional parameters mirror native APIs.
