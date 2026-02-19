# Task: `avoid_auto_route_context_navigation`

## Summary
- **Rule Name**: `avoid_auto_route_context_navigation`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.27 auto_route Rules

## Problem Statement

In `auto_route`, nested navigation should use the **router** object directly, not `context.push()` / `context.go()`. When using `context.push()` inside a nested route, the navigation operates on the **nearest router** in the widget tree, which may not be the root router:

```dart
// Inside a nested navigation context:
context.push('/products/123');  // ← WARNING: pushes on nested router, not root
```

This causes:
1. Navigation goes to the wrong router (nested shell's router vs. root router)
2. Deep links may not work correctly
3. Back navigation becomes confusing
4. The URL may not update correctly on web

The correct approach for nested navigation:
```dart
// Use the specific router instance
context.router.push(ProductDetailRoute(id: 123)); // or
AutoRouter.of(context).push(ProductDetailRoute(id: 123));
```

For navigating to a root-level route from a nested context:
```dart
context.navigateTo(HomeRoute()); // auto_route's root navigation
// or
AutoRouterDelegate.of(context).navigate(HomeRoute());
```

## Description (from ROADMAP)

> Use router instead of context for nested navigation. Detect context.push in nested route.

## Trigger Conditions

1. `context.push(...)` or `context.go(...)` called inside a widget that is a child of `AutoTabsScaffold`, `AutoTabsRouter`, or similar nested auto_route structure
2. String-based navigation (`context.push('/some/path')`) inside an auto_route project (auto_route prefers typed routes)

**Phase 1 (Conservative)**: Flag string-based `context.push('/...')` and `context.go('/...')` in auto_route projects (string navigation is an anti-pattern in auto_route regardless of nesting).

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isContextNavigation(node)) return; // context.push, context.go
  if (!_projectUsesAutoRoute(context)) return;
  // Phase 1: any string-based navigation in auto_route project
  if (_isStringBasedNavigation(node)) {
    reporter.atNode(node, code);
  }
});
```

`_isContextNavigation`: check if `node.realTarget` resolves to `BuildContext` and method name is `push`, `go`, `replace`, `pop`.
`_isStringBasedNavigation`: check if first argument is a string literal (or string interpolation).
`_projectUsesAutoRoute`: `ProjectContext.usesPackage('auto_route')`.

## Code Examples

### Bad (Should trigger)
```dart
// String-based navigation in auto_route project
onTap: () {
  context.push('/products/123');  // ← trigger: string navigation in auto_route project
}

// context.go bypasses auto_route's router
ElevatedButton(
  onPressed: () {
    context.go('/settings');  // ← trigger: bypasses auto_route nesting
  },
  child: const Text('Settings'),
)
```

### Good (Should NOT trigger)
```dart
// Typed route navigation
onTap: () {
  context.router.push(ProductDetailRoute(id: 123)); // ← OK: typed
}

// AutoRouter.of pattern
onTap: () {
  AutoRouter.of(context).push(const SettingsRoute()); // ← OK
}

// context.navigateTo (auto_route's own extension)
onTap: () {
  context.navigateTo(const SettingsRoute()); // ← OK: auto_route typed navigation
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| GoRouter project (not auto_route) | **Suppress** — `context.go()` is correct in go_router | |
| `context.push(MaterialPageRoute(...))` | **Trigger** — raw Navigator in auto_route project | |
| `Navigator.of(context).push(...)` | **Separate rule** | |
| `context.router.push(...)` | **Suppress** — using router object correctly | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `context.push('/products')` in auto_route project → 1 lint
2. `context.go('/home')` in auto_route project → 1 lint

### Non-Violations
1. Same code in go_router project (no auto_route) → no lint
2. `context.router.push(ProductRoute())` → no lint
3. `AutoRouter.of(context).push(...)` → no lint

## Quick Fix

Offer "Replace with typed `context.router.push(RouteClass())`":
```dart
// Before
context.push('/products/123');

// After
context.router.push(ProductDetailRoute(id: 123));
```

Note: the auto-fix requires knowing which Route class corresponds to the string path — this requires static analysis of the route configuration.

## Notes & Issues

1. **auto_route-only**: Only fire if `ProjectContext.usesPackage('auto_route')`.
2. **GoRouter coexistence**: Some projects use BOTH auto_route and go_router. `context.go()` is correct for go_router but wrong for auto_route. Package detection must be specific.
3. **String vs typed routes**: auto_route supports both string paths (for deep linking) and typed routes. The typed route API is strongly preferred within the app code. String paths are used for deep link configuration only.
4. **Nested router context**: The lint's title says "nested navigation" but the most valuable detection is simply "string navigation in auto_route project" — this is always wrong in auto_route (use typed routes).
5. **`pushNamed` vs `push`**: Also detect `context.pushNamed('/path')` — same issue with string-based navigation.
