> **========================================================**
> **IMPLEMENTED -- v5.1.0**
> **========================================================**
>
> `AvoidExpensiveDidChangeDependenciesRule` in
> `lib/src/rules/widget_lifecycle_rules.dart`. Professional tier.
>
> **========================================================**

# Task: `avoid_expensive_did_change_dependencies`

## Summary
- **Rule Name**: `avoid_expensive_did_change_dependencies`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.23 Widget Lifecycle Rules

## Problem Statement

`didChangeDependencies()` is called:
1. Once after `initState()` — always
2. **Every time an inherited widget that the widget depends on changes** — can be very frequent

This is much more frequent than `initState()`. If you put expensive operations in `didChangeDependencies()`, they will run repeatedly:

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  // BUG: This runs every time ANY inherited widget changes!
  _heavyComputation();     // ← expensive work
  _fetchDataFromAPI();     // ← network call
  _parseJsonData(data);    // ← CPU-intensive
}
```

Common triggers for `didChangeDependencies()`:
- `MediaQuery` changes (keyboard appearance, screen rotation)
- `Theme` changes
- Locale changes
- Navigation (when the route provides an InheritedWidget)

## Description (from ROADMAP)

> didChangeDependencies runs often. Detect heavy work in didChangeDependencies.

## Trigger Conditions

1. `didChangeDependencies()` override that contains:
   - Network calls (`http.get`, `dio.get`, `apiClient.fetch`)
   - CPU-intensive operations (detected via heuristic: large loops, recursive calls, JSON parsing)
   - `setState()` with heavy computation
   - Database reads (`db.query`, `prefs.getString`, etc.)

**Conservative approach**: Only flag network calls and explicit async operations in `didChangeDependencies()`.

## Implementation Approach

```dart
context.registry.addMethodDeclaration((node) {
  if (node.name.lexeme != 'didChangeDependencies') return;
  if (!_isStateMember(node)) return; // must be in a State class

  final body = node.body;
  // Check for network calls
  body.accept(ExpensiveOperationVisitor(reporter));
});
```

`ExpensiveOperationVisitor`: walks the method body looking for:
- `http.get/post/put` etc.
- `dio.get/post/put` etc.
- `await` expressions (any async work is expensive if called repeatedly)
- Database query methods

## Code Examples

### Bad (Should trigger)
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _loadUserData();  // ← trigger: if this makes a network call
  fetchProducts();   // ← trigger: likely an async operation
}

// Or with direct async call
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  http.get(Uri.parse('/api/products')); // ← trigger: direct network call
}
```

### Good (Should NOT trigger)
```dart
// Option 1: Guard with a flag (only run once or when truly needed)
bool _initialized = false;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_initialized) {
    _initialized = true;
    _loadUserData(); // ← only runs once
  }
}

// Option 2: Move to initState()
@override
void initState() {
  super.initState();
  _loadUserData(); // ← only runs once
}

// Option 3: Light work only
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  // Reading from InheritedWidget is fine — it's O(1)
  final theme = Theme.of(context);
  _currentTheme = theme; // ← cheap assignment
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `_initialized` guard around heavy work | **Suppress** — protected from re-runs | |
| Light work (reading from context, assignment) | **Suppress** | |
| `Theme.of(context)` or `MediaQuery.of(context)` | **Suppress** — O(1) lookups | |
| Provider/Riverpod `watch` calls | **Suppress** — these are expected in didChangeDependencies | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `didChangeDependencies` with `http.get` call → 1 lint
2. `didChangeDependencies` with any `await` expression → 1 lint

### Non-Violations
1. `didChangeDependencies` with only `super.didChangeDependencies()` + variable assignment → no lint
2. `didChangeDependencies` with guarded `if (!_initialized)` → no lint
3. Empty `didChangeDependencies` → no lint

## Quick Fix

Offer "Move to `initState()`" or "Add initialization guard":
```dart
// Before
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _loadData();
}

// After: Option A - Move to initState
@override
void initState() {
  super.initState();
  _loadData();
}

// After: Option B - Add guard
bool _initialized = false;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_initialized) {
    _initialized = true;
    _loadData();
  }
}
```

## Notes & Issues

1. **The `_initialized` guard**: This is the most common Flutter pattern for doing one-time work in `didChangeDependencies`. The lint should suppress if an `if (_initialized)` check wraps the heavy work.
2. **Context-dependent initialization**: Some work legitimately belongs in `didChangeDependencies` because it depends on `InheritedWidget` values (e.g., reading `Provider.of(context)` for initial data). The lint must not flag reads from `context` — only computation/async work.
3. **Riverpod `ref.read()` in didChangeDependencies**: With Riverpod's `ConsumerStatefulWidget`, `ref.read()` in `didChangeDependencies` is fine but `ref.watch()` should be in `build()`. A separate rule could enforce this.
4. **`Localizations.of(context)`**: This is a legitimate `didChangeDependencies` use case — reading the locale when it changes. Don't flag.
5. **FALSE POSITIVE**: Any method call could be expensive. Limiting to detected async/network calls is more conservative than checking for ALL method calls.
