# Task: `avoid_shadowing_type_parameters`

## Summary
- **Rule Name**: `avoid_shadowing_type_parameters`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §2 Miscellaneous Rules

## Problem Statement

When a generic method or class declares a type parameter with the same name as an outer type parameter, the inner parameter shadows the outer one, making code confusing and potentially hiding bugs.

```dart
class Box<T> {
  T get<T>(String key) { ... }  // ← inner T shadows class T!
}
```

Inside `get<T>`, the `T` refers to the METHOD's type parameter, not the CLASS's. This is almost never intentional and leads to confusion.

## Description (from ROADMAP)

> Avoid shadowing type parameters in generics.

## Trigger Conditions

1. A method declares a type parameter `T` that matches a type parameter `T` in the enclosing class
2. A nested class declares a type parameter that matches an enclosing class's type parameter

## Implementation Approach

```dart
context.registry.addMethodDeclaration((node) {
  if (node.typeParameters == null) return;
  final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
  if (classDecl?.typeParameters == null) return;
  final classTypeParams = classDecl!.typeParameters!.typeParameters
      .map((tp) => tp.name.lexeme)
      .toSet();
  for (final methodTypeParam in node.typeParameters!.typeParameters) {
    if (classTypeParams.contains(methodTypeParam.name.lexeme)) {
      reporter.atNode(methodTypeParam, code);
    }
  }
});
```

## Code Examples

### Bad (Should trigger)
```dart
class Box<T> {
  // Method's T shadows class T — confusing!
  T getValue<T>(T defaultValue) => defaultValue;  // ← trigger
}
```

### Good (Should NOT trigger)
```dart
class Box<T> {
  // Different name for method type parameter
  T getBoxedValue() => _value;  // no shadowing
  R convertTo<R>(R Function(T) converter) => converter(_value);  // R != T
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Extension type parameters shadowing class type params | **Trigger** | |
| Same letter but different case (`T` vs `t`) | **Suppress** — Dart is case-sensitive, no actual shadow | |
| `E` in class, `E` in method but they extend different bounds | **Trigger** — still confusing | |
| Generated code | **Suppress** | |

## Unit Tests

1. `class Box<T>` with `method<T>()` → 1 lint
2. `class Box<T>` with `method<R>()` → no lint
3. Generated file → no lint

## Notes & Issues

1. **Check built-in rule**: Dart may have a related rule. Verify before implementing.
2. The fix is to rename the method's type parameter to a different letter.
