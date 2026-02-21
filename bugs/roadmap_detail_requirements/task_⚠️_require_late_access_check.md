# Task: `require_late_access_check`

## Summary
- **Rule Name**: `require_late_access_check`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.50 Late Initialization Rules

## Problem Statement

`late` variables in Dart delay initialization until first access. If a `late` variable is accessed before it is initialized, Dart throws a `LateInitializationError` at runtime. This is worse than a null pointer in some ways — it's a crash that the static type system claims is safe.

```dart
class UserService {
  late String currentUserId; // ← Dart says this is non-nullable

  void initialize(String id) {
    currentUserId = id;
  }

  void processUser() {
    // BUG: if processUser() is called before initialize(), runtime crash!
    final user = _repository.getUser(currentUserId); // ← LateInitializationError
  }
}
```

Common scenarios where this is a problem:
1. Service locator initialization order is uncertain
2. `initState()` sets up a `late` field but the widget can be accessed before `initState()` completes
3. `late` factory dependencies that may not be registered

## Description (from ROADMAP)

> Check isInitialized before late access when uncertain. Detect late access without context guarantee.

## Trigger Conditions

1. A `late` non-final field that is:
   - Initialized in a method OTHER than the constructor, `initState`, or `init()` equivalent
   - Accessed in another method without a prior null-check or initialization check
2. Specifically: `late` fields that are assigned in methods like `initialize()`, `setup()`, `configure()` but accessed without checking if those methods were called

**Note**: `late final` fields (final after first assignment) have a specific guarantee: they can only be set once and throw if set again. This rule is about detecting potentially-uninitialized access.

## Implementation Approach

```dart
context.registry.addFieldDeclaration((node) {
  if (!_isLateMutableField(node)) return; // late, non-final

  // Check if the field has any assignment outside of constructors/initState
  final assignments = _findNonConstructorAssignments(node.fields, node.parent);
  if (assignments.isEmpty) return; // initialized in constructor — safe

  // Find accesses in other methods
  final unsafeAccesses = _findUncheckedAccesses(node.fields, node.parent);
  for (final access in unsafeAccesses) {
    reporter.atNode(access, code);
  }
});
```

`_isLateMutableField`: check `node.fields.isLate && !node.fields.isFinal`.
`_findNonConstructorAssignments`: look for assignments in methods that aren't constructors.
`_findUncheckedAccesses`: find accesses that aren't guarded by an initialized check.

## Code Examples

### Bad (Should trigger)
```dart
class AuthService {
  late String _token; // ← late mutable

  // Initialized in a method, not constructor
  void setToken(String token) {
    _token = token;
  }

  // ← trigger: _token may not be initialized when getHeaders() is called
  Map<String, String> getHeaders() {
    return {'Authorization': 'Bearer $_token'}; // ← LateInitializationError risk
  }
}
```

### Good (Should NOT trigger)
```dart
// Option 1: Use nullable instead of late
class AuthService {
  String? _token; // ← nullable — forces null check

  Map<String, String> getHeaders() {
    final token = _token; // ← forced to handle null case
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }
}

// Option 2: Throw meaningful error
class AuthService {
  late String _token;
  bool _initialized = false;

  void initialize(String token) {
    _token = token;
    _initialized = true;
  }

  Map<String, String> getHeaders() {
    if (!_initialized) throw StateError('AuthService not initialized');
    return {'Authorization': 'Bearer $_token'};
  }
}

// Option 3: late final (set once in constructor alternative)
class AuthService {
  final String _token; // ← non-late, set in constructor

  AuthService(this._token);
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `late final` (immutable after set) | **Different rule** — about double-assignment | |
| `late` field initialized in `initState` | **Suppress** — Flutter lifecycle guarantees initState runs first | |
| `late` field with `isInitialized` guard at access point | **Suppress** | |
| `late` field in abstract class | **Complex** | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `late String _token` initialized in `setToken()` method, accessed in `getHeaders()` without check → 1 lint

### Non-Violations
1. `late String _token` initialized in constructor → no lint
2. `late String _token` with `_initialized` guard at access point → no lint
3. `late final` (final after set) → no lint (different concern)

## Quick Fix

Offer "Convert to nullable (`String?`)":
```dart
// Before
late String _token;

// After
String? _token;
// (requires updating access sites to handle null)
```

Or "Add initialization check":
```dart
// Before
String getToken() => _token;

// After
String getToken() {
  if (!_isInitialized) {
    throw StateError('Service not initialized. Call initialize() first.');
  }
  return _token;
}
```

## Notes & Issues

1. **Dart-general**: Applies to all Dart code, not just Flutter.
2. **`late final` vs `late`**: `late final` is much safer (can only be set once, but will crash if read before set). `late` (mutable) is more dangerous since it can be re-assigned and read in any order.
3. **The real fix**: The Dart team recommends using `late` only when:
   - The field is definitely initialized before first access (lifecycle guarantee)
   - The field is expensive to compute and may not be needed (lazy initialization)
   For service locator patterns, prefer constructor injection or factory methods.
4. **Static analysis limitation**: True "possibly uninitialized" detection requires control flow analysis (is there any execution path that reads the field before it's set?). This is beyond simple AST analysis. Phase 1 uses a heuristic: "field is set in non-constructor method AND accessed in other non-constructor methods."
5. **Riverpod/get_it context**: Service locators with `late` initialization are a common pattern. The lint must avoid flagging correctly-ordered initialization in DI containers.
