# Task: `prefer_named_bool_params`

## Summary
- **Rule Name**: `prefer_named_bool_params`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Functions with boolean parameters should prefer named parameters to improve call-site readability. This rule promotes the positive form of the principle that `avoid_positional_boolean_parameters` enforces negatively: wherever a bool appears as a positional argument, naming it makes the code self-documenting.

The motivation is identical to `avoid_positional_boolean_parameters` but the framing differs. This rule is specifically focused on the sweet spot of functions with 1–2 parameters where naming is low-friction but high-value — small helpers and utility functions where developers most commonly reach for positional params because "it seems obvious from context." It is almost never obvious once the code ages.

## Description (from ROADMAP)
Encourages the use of named boolean parameters in function and method declarations, especially for functions with 1–2 parameters where the positional form tempts developers away from clarity.

## Trigger Conditions
- A `FunctionDeclaration` or `MethodDeclaration` with a formal parameter list
- At least one parameter is positional (required positional or optional positional)
- That parameter's declared type is `bool` or `bool?`
- The function is not an operator, setter, or anonymous function
- The function is not annotated with `@override`
- The total parameter count is between 1 and a configurable maximum (default: 3) — focusing on cases where the rename is low-effort

## Implementation Approach

### AST Visitor
```dart
context.registry.addFormalParameterList((node) {
  // ...
});
```

### Detection Logic
1. Check that the parent is a `FunctionDeclaration` or `MethodDeclaration`.
2. Skip if the parent is annotated with `@override`.
3. Skip if the method is an operator or setter.
4. Count total positional parameters. If more than the configured maximum, skip (the heavier `avoid_positional_boolean_parameters` rule should handle that case).
5. For each positional parameter:
   - Check whether its declared type is `bool` or `bool?`.
   - Skip function-typed parameters.
6. Report each matching parameter, suggesting conversion to a named parameter.

Note: This rule intentionally overlaps with `avoid_positional_boolean_parameters`. If both rules are enabled, they will fire on the same code. Package maintainers should enable one or the other, not both. The `prefer_` prefix signals a stylistic preference; the `avoid_` prefix signals a stronger prohibition. Both should not be in the same tier.

## Code Examples

### Bad (triggers rule)
```dart
// Single bool — the toggle() call is unclear.
void toggle(bool value) { // LINT
  _isActive = value;
}
// toggle(true) — true what?

// Two params, one bool — still opaque.
void animate(Duration duration, bool reverse) { // LINT on reverse
  // ...
}
// animate(const Duration(milliseconds: 300), true) — reverse? forward?

// Named but positional in practice — this is the target.
void setVisible(bool visible) { // LINT
  _visible = visible;
}
// setVisible(false) — false visible? invisible? disabled?
```

### Good (compliant)
```dart
// Named parameter — call site is self-documenting.
void toggle({required bool value}) {
  _isActive = value;
}
// toggle(value: true) — explicit

void animate(Duration duration, {required bool reverse}) {
  // ...
}
// animate(const Duration(milliseconds: 300), reverse: true)

void setVisible({required bool visible}) {
  _visible = visible;
}
// setVisible(visible: false)

// Callbacks / lambdas — exempt.
final negate = (bool x) => !x;
list.where((bool x) => x).toList();

// Setter — exempt (always positional).
set visible(bool value) {
  _visible = value;
}

// Override — exempt (signature is fixed).
@override
bool shouldRepaint(bool oldDelegate) => true;
```

## Edge Cases & False Positives
- **Overlap with `avoid_positional_boolean_parameters`**: These two rules target the same pattern. If `avoid_positional_boolean_parameters` is enabled at a stricter tier, `prefer_named_bool_params` may be redundant. The package should document which rule to enable and at which tier, and the rules should share logic via a shared utility.
- **Setters**: `set foo(bool value)` — Dart requires setters to have exactly one positional parameter. Do not flag.
- **Operator overloads**: Operators are positional by definition. Do not flag.
- **Anonymous functions and lambdas**: Short anonymous functions are commonly positional for brevity. Do not flag `FunctionExpression` nodes.
- **`@override` methods**: The signature is determined by the supertype. Do not flag.
- **`typedef` declarations**: Skip type alias / function type declarations.
- **`external` declarations**: FFI and platform-channel bridge methods must match native signatures. Do not flag.
- **Test helper functions**: Consider a configuration option to exclude test files from this rule.
- **Generated code**: Exclude `*.g.dart`, `*.freezed.dart`, `*.gen.dart`.
- **Threshold for "small" function**: The rule targets functions with ≤3 parameters by default to avoid overlap with the stronger `avoid_positional_boolean_parameters`. This threshold should be configurable.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: single-param bool function
void show(bool visible) {} // LINT

// Test 2: two-param function with one bool
void load(String url, bool cached) {} // LINT on cached

// Test 3: optional positional bool
void configure([bool debug = false]) {} // LINT on debug
```

### Should NOT Trigger (compliant)
```dart
// Test 4: already named
void show({required bool visible}) {}

// Test 5: setter
set visible(bool v) {}

// Test 6: lambda
final fn = (bool x) => !x;

// Test 7: override
class Base { void run(bool x) {} }
class Child extends Base {
  @override
  void run(bool x) {}
}

// Test 8: function with >3 params (threshold)
void configure(bool a, bool b, bool c, bool d) {} // Handled by avoid_positional_boolean_parameters
```

## Quick Fix
**Message**: "Convert to a named boolean parameter"

The fix should:
1. Wrap the positional `bool` parameter with `{required bool paramName}` if it is required.
2. Wrap optional positional `[bool paramName = default]` with `{bool paramName = default}`.
3. Preserve any default value.
4. Add a correction note that all call sites must be updated to use `paramName: value` syntax — the quick fix cannot update cross-file call sites automatically.

## Notes & Issues
- The relationship between `prefer_named_bool_params` and `avoid_positional_boolean_parameters` must be clearly documented so package users do not enable both simultaneously.
- A shared implementation helper (e.g., `_isPositionalBoolParameter(FormalParameter param)`) should be extracted into `lib/src/` utilities and used by both rules.
- Consider whether this rule is better expressed as a configuration variant of `avoid_positional_boolean_parameters` (e.g., `minParameters: 1`) rather than a separate rule.
- If the Dart analyzer's own `avoid_positional_boolean_parameters` lint is already enabled by a project, this rule adds no value. Check for that lint being enabled in `ProjectContext` and suppress this rule accordingly.
