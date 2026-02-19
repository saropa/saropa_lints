# Task: `avoid_suspicious_global_reference`

## Summary
- **Rule Name**: `avoid_suspicious_global_reference`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.61 Code Quality Rules

## Problem Statement

Accessing mutable global state (top-level variables, static mutable fields) inside instance methods introduces hidden coupling and makes code hard to test, reason about, and parallelize. Suspicious patterns include:

1. Instance methods that read or write `static` mutable fields on OTHER classes
2. Methods that depend on top-level `var` variables (not constants)
3. Static setter calls inside instance logic (e.g., `AppState.currentUser = user`)

This is different from using dependency injection (constructing objects with their dependencies passed in) — the rule targets undeclared global dependencies.

## Description (from ROADMAP)

> Detect suspicious references to global state in methods.

## Trigger Conditions

1. Instance method body accesses a `static` field (not `const`) of a DIFFERENT class
2. Instance method reads/writes a top-level `var` (not `const` or `final`)
3. Method contains `SomeClass.mutableStaticField = value` (static setter)

**Exemptions**:
- `const` static fields (no mutation possible)
- Well-known singletons: `Navigator.of(context)`, `ScaffoldMessenger.of(context)` (these use context)
- `kDebugMode`, `kReleaseMode` (compile-time constants)
- Logger singletons: accessing `Logger.root` or similar established patterns

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addPropertyAccess((node) {
  final element = node.propertyName.staticElement;
  if (element == null) return;
  if (!element.isStatic) return;
  if (element is PropertyAccessorElement && element.isConst) return;
  // Check if this is a different class's static member
  final ownerClass = element.enclosingElement;
  final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
  if (ownerClass == enclosingClass?.declaredElement) return;
  // Check if it's a known-safe singleton
  if (_isKnownSafeGlobal(ownerClass?.name)) return;
  reporter.atNode(node, code);
});
```

## Code Examples

### Bad (Should trigger)
```dart
// Instance method accessing global state
class UserService {
  void login(String username) {
    final user = authenticate(username);
    AppState.currentUser = user;  // ← trigger: global state mutation
    AppState.isLoggedIn = true;  // ← trigger
  }
}

// Top-level var access
var globalCounter = 0;

class Counter {
  void increment() {
    globalCounter++;  // ← trigger: top-level var mutation
  }
}
```

### Good (Should NOT trigger)
```dart
// Dependency injected ✓
class UserService {
  final AppState _appState;
  UserService(this._appState);

  void login(String username) {
    final user = authenticate(username);
    _appState.currentUser = user;  // ✓ injected dependency
  }
}

// Const global — not mutable ✓
const kMaxRetries = 3;

class RetryService {
  void retry() {
    for (int i = 0; i < kMaxRetries; i++) { ... }  // ✓ const
  }
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `kDebugMode`, `kReleaseMode`, `kProfileMode` | **Suppress** — Flutter compile-time constants | Whitelist |
| `Platform.isAndroid` | **Suppress** — read-only getter | Static read-only access |
| `Navigator.of(context)` | **Suppress** — uses context, not truly global | Context-based access pattern |
| `DateTime.now()` | **Suppress** — well-known pattern | Whitelist |
| `Random()` | **Suppress** — common pattern | Whitelist |
| Singleton `get instance` pattern | **Suppress if `final`** — immutable singletons are OK | Check if the field is `final` |
| `Completer.sync` | **Complex** | Case by case |
| `ChangeNotifier.notifyListeners()` via static | **Trigger** — accessing ChangeNotifier state statically is bad | |
| Static fields accessed in static methods | **Suppress** — static methods accessing own static fields is normal | Only flag instance methods |
| Test files | **Suppress** | |

## Unit Tests

### Violations
1. Instance method writing `AnotherClass.staticMutableField = value` → 1 lint
2. Top-level `var` mutated inside instance method → 1 lint

### Non-Violations
1. Instance method accessing `const` static → no lint
2. Instance method accessing `kDebugMode` → no lint
3. Static method accessing own static field → no lint
4. Test file → no lint

## Quick Fix

No automated fix — refactoring to dependency injection is architectural.

```
correctionMessage: 'Avoid accessing mutable global state in instance methods. Inject dependencies via constructor parameters instead.'
```

## Notes & Issues

1. **HIGH false positive risk** — many legitimate patterns use static fields (`Navigator.of()`, `Theme.of()`, `MediaQuery.of()`). The exemption list needs to be comprehensive.
2. **`of(context)` pattern**: All InheritedWidget accessors (`Theme.of(context)`, `MediaQuery.of(context)`) use the context parameter, making them NOT truly global. These should all be suppressed.
3. **The rule's scope needs careful definition**: Is accessing `Scaffold.of(context).openDrawer()` suspicious? It IS a static method but context-scoped. The rule should only flag TRULY global state (no context parameter).
