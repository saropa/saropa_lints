# Task: `avoid_accessing_other_classes_private_members`

## Summary
- **Rule Name**: `avoid_accessing_other_classes_private_members`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.58 Class & Inheritance Rules

## Problem Statement

In Dart, "private" members (prefixed with `_`) are private to the **library** (file), not to the class. This means a class `Foo` in `foo.dart` can access `Bar._privateField` if `Bar` is also defined in `foo.dart`, or if you use `extension` tricks.

Developers sometimes exploit this same-file access to reach into other classes' internal state, which violates encapsulation. When the code is later refactored (classes split into different files), these accesses break, creating maintenance debt.

This rule detects when code accesses another class's private members within the same file — a workaround that should be avoided.

## Description (from ROADMAP)

> Detect access to private members of other classes through workarounds.

## Trigger Conditions

1. `PropertyAccess` or `MethodInvocation` accessing a member starting with `_` where:
   - The target's static type is a class OTHER than the class currently being analyzed
   - The access is to an `_underscore` member

2. Extension methods on a class that access `_private` members of that class

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addPropertyAccess((node) {
  final memberName = node.propertyName.name;
  if (!memberName.startsWith('_')) return;
  // Check if the target class is different from the enclosing class
  final targetType = node.target?.staticType;
  final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
  if (enclosingClass == null) return;
  if (_isSameClass(targetType, enclosingClass)) return;
  reporter.atNode(node, code);
});
```

`_isSameClass`: compare the target type's element with the enclosing class's element — if they're different classes (even in the same file), the access is a cross-class private access.

### Extension Method Check
```dart
context.registry.addMethodDeclaration((node) {
  final parent = node.parent;
  if (parent is! ExtensionDeclaration) return;
  // Check if the extension's on-type has _private members being accessed
  // Walk node.body for _private member access on the ExtendedType
});
```

## Code Examples

### Bad (Should trigger)
```dart
// In the same file — Dart allows this but it's bad practice
class Foo {
  final int _secret = 42;
}

class Bar {
  void doSomething(Foo foo) {
    print(foo._secret);  // ← trigger: accessing Foo's private member
  }
}
```

### Good (Should NOT trigger)
```dart
// Accessing your own class's private member ✓
class Foo {
  final int _secret = 42;

  void printSecret() {
    print(_secret);  // ✓ same class
  }
}

// Accessing public member ✓
class Bar {
  void doSomething(Foo foo) {
    print(foo.publicMember);  // ✓ public
  }
}

// Test accessing internals via @visibleForTesting ✓
@visibleForTesting
int get secretForTesting => _secret;
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `@visibleForTesting` annotated members | **Suppress** — intentionally exposed for tests | Check annotation |
| `@visibleForOverriding` | **Suppress** | Check annotation |
| Test file accessing private members | **Suppress with note** — test files commonly access internals | `ProjectContext.isTestFile` |
| Extension on a class accessing its private members | **Trigger** — extensions shouldn't access privates of the extended type | Strong signal for workaround |
| Subclass accessing parent's private | **Trigger** — Dart privates are file-level, so this is cross-class | Important case |
| Same class accessing own private in nested class | **Suppress** | |
| `copyWith` pattern using `._field` | **False positive** — common pattern for immutable copy | May need to suppress `copyWith`-named methods |
| Generated code | **Suppress** | `.g.dart`, `.freezed.dart` |

## Unit Tests

### Violations
1. `bar.doSomething(foo)` where `doSomething` accesses `foo._secret` → 1 lint
2. Extension on `Foo` that accesses `_privateField` → 1 lint

### Non-Violations
1. Accessing own `_private` member → no lint
2. Accessing public member → no lint
3. `@visibleForTesting` member accessed in test → no lint
4. Generated file → no lint

## Quick Fix

No automated fix — accessing private members requires an architectural refactoring to expose a proper public API.

```
correctionMessage: 'Avoid accessing private members of other classes. Add a public method or property to expose the needed functionality, or consider @visibleForTesting for test access.'
```

## Notes & Issues

1. **Dart's library privacy** is different from class privacy — this distinction should be clearly explained in the rule's doc comment, as many developers don't know this.
2. **`copyWith` pattern in Freezed** — Freezed's generated `copyWith` accesses private fields via `_copyWith` methods. Ensure generated files are suppressed.
3. **Companion rule**: This is related to `avoid_referencing_subclasses` (§1.58) and `avoid_renaming_representation_getters` (§1.58).
