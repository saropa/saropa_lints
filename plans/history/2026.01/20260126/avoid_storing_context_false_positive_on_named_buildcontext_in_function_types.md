# Bug: `avoid_storing_context` false positive on function type fields with named `BuildContext` parameters

## Summary

The `avoid_storing_context` rule incorrectly flags fields whose type is a function signature with `BuildContext` as a **named** parameter. The field stores a function/callback, not an actual `BuildContext` instance. The existing exclusion logic in `_isContextType` (which checks for `Function` in the type string) works for **positional** parameters but fails for **named** parameters.

## Severity

**High** — ERROR-level false positive on a standard Flutter builder callback pattern. Named `BuildContext` parameters in function types are safe and common, particularly in builder widgets with multiple callback parameters.

## Affected Rule

- **Rule**: `avoid_storing_context`
- **File**: `lib/src/rules/context_rules.dart` (lines 55-146)
- **Detection path**: `addFieldDeclaration` handler (lines 81-88) calls `_isContextType` (lines 115-127)

## Reproduction

### Triggering code (from `contacts` project)

File: `lib/components/user/user_settings/user_preference_stream_builder_list.dart` (line 20)

```dart
class UserPreferenceStreamBuilderList extends StatelessWidget {
  const UserPreferenceStreamBuilderList({
    required this.preferenceTypes,
    required this.builder,
    this.shouldFireImmediately = true,
    super.key,
  });

  final List<UserPreferenceType> preferenceTypes;
  final bool shouldFireImmediately;
  final Widget Function({required BuildContext context}) builder; // <-- FALSE POSITIVE
}
```

IDE error reported:
```
avoid_storing_context [ERROR]
Line 20, columns 58-65 (highlights "builder" variable name)
```

### Non-triggering code (positional parameter variant)

These equivalent fields do NOT trigger the lint, confirming the bug is specific to named parameters:

```dart
final Widget Function(BuildContext) builder;          // OK
final Widget Function(BuildContext context) builder;  // OK
final void Function(BuildContext context, String message) onShowDialog; // OK
```

### Why the lint is wrong

The field stores a **function reference**, not a `BuildContext`. The `BuildContext` in the type signature is a parameter declaration describing the function's input contract. At call time, a fresh `BuildContext` is passed from the current widget tree:

```dart
@override
Widget build(BuildContext context) {
  return builder(context: context); // fresh context, not stored
}
```

This is functionally identical to Flutter's built-in `WidgetBuilder` typedef.

## Root Cause

The `_isContextType` method (lines 115-127) uses string matching on `node.fields.type?.toSource()`:

```dart
bool _isContextType(String type) {
  // Function types with BuildContext parameters are fine
  if (type.contains('Function')) {
    return false;
  }

  return type == 'BuildContext' ||
      type == 'BuildContext?' ||
      type == 'late BuildContext' ||
      type.contains('BuildContext');
}
```

The `contains('Function')` guard (line 119) is intended to exclude function types. This works for positional-parameter function types where `toSource()` returns strings like `Widget Function(BuildContext)`.

For **named-parameter** function types like `Widget Function({required BuildContext context})`, one of the following is occurring:

1. **`toSource()` returns an unexpected string** for `GenericFunctionType` nodes with named parameters, potentially omitting the `Function` keyword or using a different representation
2. **`node.fields.type` resolves to a different AST node type** when the function type has named parameters, causing `toSource()` to behave differently
3. **Analyzer version difference** in how `GenericFunctionType.toSource()` serializes named vs positional parameters

The exact mechanism requires debugging with `print(node.fields.type.runtimeType)` and `print(node.fields.type?.toSource())` for the failing case, but the outcome is clear: the `Function` keyword check does not prevent the false positive for named-parameter function types.

## Proposed Fix

### Fix 1: Use AST node type checking instead of string matching (Recommended)

Replace string-based `_isContextType` with AST-aware type checking:

```dart
bool _isContextType(FieldDeclaration node) {
  final TypeAnnotation? typeAnnotation = node.fields.type;

  // Function types with BuildContext parameters are fine - they declare
  // callback signatures, not store actual context instances
  if (typeAnnotation is GenericFunctionType) {
    return false;
  }

  // Check if the type annotation is a BuildContext NamedType
  if (typeAnnotation is NamedType) {
    final String name = typeAnnotation.name2.lexeme;
    return name == 'BuildContext';
  }

  return false;
}
```

This eliminates the fragile string matching entirely. `GenericFunctionType` is the AST node for all function type annotations (both positional and named parameter variants), so this correctly excludes all function-typed fields regardless of parameter style.

### Fix 2: Defensive string matching (Simpler, less robust)

If AST-based checking isn't feasible, add a more defensive string check:

```dart
bool _isContextType(String type) {
  // Function types with BuildContext parameters are fine
  if (type.contains('Function') || type.contains('(') || type.contains('=>')) {
    return false;
  }

  return type == 'BuildContext' || type == 'BuildContext?';
}
```

This removes the overly broad `type.contains('BuildContext')` fallback (line 126) which matches any string containing `BuildContext`, including function type strings that somehow bypass the `Function` check.

### Fix 3: Add debugging output to diagnose exact cause

As a diagnostic step before fixing, add logging to see what `toSource()` actually returns for named-parameter function types:

```dart
context.registry.addFieldDeclaration((node) {
  for (final variable in node.fields.variables) {
    final typeAnnotation = node.fields.type;
    final type = typeAnnotation?.toSource() ?? '';
    // Temporary: log for diagnosis
    print('avoid_storing_context: type=${typeAnnotation.runtimeType}, '
        'source="$type", variable=${variable.name}');
    if (_isContextType(type)) {
      reporter.atNode(variable, code);
    }
  }
});
```

## Test Cases to Add

Add to `example/lib/context/context_rules_fixture.dart` after line 98:

```dart
// GOOD: Function type with NAMED BuildContext parameter is NOT storing context
// This is a builder callback signature, not an actual stored context instance
class GoodFunctionTypeWithNamedContext extends StatelessWidget {
  const GoodFunctionTypeWithNamedContext({
    required this.builder,
    required this.builderWithValue,
    this.optionalCallback,
    super.key,
  });

  // These should NOT trigger avoid_storing_context - they are function signatures
  // with named (not positional) BuildContext parameters
  final Widget Function({required BuildContext context}) builder;
  final Widget Function({required BuildContext context, required bool value}) builderWithValue;
  final void Function({BuildContext? context})? optionalCallback;

  @override
  Widget build(BuildContext context) {
    return builder(context: context);
  }
}

// GOOD: WidgetBuilder typedef (positional BuildContext) is NOT storing context
class GoodWidgetBuilderField extends StatelessWidget {
  const GoodWidgetBuilderField({required this.builder, super.key});

  final WidgetBuilder builder; // WidgetBuilder = Widget Function(BuildContext)

  @override
  Widget build(BuildContext context) {
    return builder(context);
  }
}
```

## Impact Assessment

- **False positive rate**: Any field with a function type using named `BuildContext` parameters will be falsely flagged. This affects builder-pattern widgets and callback-style APIs.
- **Workaround**: Add `// ignore: avoid_storing_context` or change to positional parameters
- **Fix complexity**: Low for Fix 2 (tighten string matching), Medium for Fix 1 (switch to AST-based checking)
- **Regression risk**: Low — the fix only narrows the detection scope for function-typed fields, which are always safe

## Related

- Existing test fixture `GoodFunctionTypeWithContext` (context_rules_fixture.dart:80-98) covers only positional-parameter function types
- The `_isContextType` method (line 115) comment explicitly acknowledges function types should be excluded
- The `type.contains('BuildContext')` fallback on line 126 is overly broad and likely the root cause when the `Function` check fails to match
