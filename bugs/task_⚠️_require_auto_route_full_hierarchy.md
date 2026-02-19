# Task: `require_auto_route_full_hierarchy`

## Summary
- **Rule Name**: `require_auto_route_full_hierarchy`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.27 auto_route Rules

## Problem Statement

In `auto_route`, when navigating to a nested route, you must provide the **full parent hierarchy**. If you navigate to a child route without including the parent route in the navigation stack, the auto_route framework may:

1. Silently fail (on some versions)
2. Navigate to an incorrect route
3. Break the back navigation stack
4. Cause unexpected tab behavior in tabbed navigation

Example:
```dart
// Route hierarchy:
// AppRouter → ProductsRoute → ProductDetailRoute

// BAD: navigating to child without full hierarchy
context.router.push(ProductDetailRoute(id: 123));
// ← may fail if ProductsRoute is not in the current stack
// Should be:
context.router.navigate(ProductsRoute(children: [ProductDetailRoute(id: 123)]));
```

## Description (from ROADMAP)

> Navigate with full parent hierarchy. Detect child route without parent.

## Trigger Conditions

This rule is complex because it requires knowledge of the auto_route route configuration, which is in generated code. The detection is necessarily heuristic:

1. A `push()` call with a route class that is a **deeply nested child route** (not a top-level route)
2. Without the parent routes being included in the call

**IMPLEMENTATION CHALLENGE**: Detecting "is this route a child route" requires analyzing the `@AutoRouter()` configuration annotation, which is in generated code. This is very difficult without cross-file type analysis.

**Phase 1 (Documentation lint)**: Always warn when using `push()` with any route class and suggest using `navigate()` with full hierarchy instead. This is overly conservative but raises awareness.

**Phase 2 (Accurate)**: Analyze the `@AutoRouter(routes: [...])` annotation to build a route hierarchy map, then verify that `push()` calls for non-top-level routes include parent route wrappers.

## Implementation Approach

### Phase 1 (Conservative)
```dart
context.registry.addMethodInvocation((node) {
  if (!_isAutoRouterPush(node)) return; // context.router.push(...)
  if (!_firstArgIsNestedRoute(node)) return; // heuristic: ends with Route
  // Suggest navigate() with full hierarchy
  reporter.atNode(node, code);
});
```

### Phase 2 (Accurate but complex)
Would require:
1. Finding the `@AutoRouter` annotation on the router class
2. Parsing the `routes` list to build a parent-child map
3. Checking `push()` calls against this map

## Code Examples

### Bad (Should trigger — Phase 1)
```dart
// Navigating to a nested route with push() instead of navigate()
context.router.push(ProductDetailRoute(id: 123)); // ← may trigger (heuristic)
```

### Good (Should NOT trigger)
```dart
// Full hierarchy with navigate()
context.router.navigate(
  ProductsRoute(children: [ProductDetailRoute(id: 123)])
);

// For tab navigation, push to the correct tab router
context.tabsRouter.setActiveIndex(1); // switch tab
context.router.push(ProductDetailRoute(id: 123)); // then push within tab
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Top-level route pushed with `push()` | **Suppress** — push is correct for top-level | Phase 1 can't distinguish |
| `navigateTo()` helper method | **Suppress** — auto_route's own navigate API | |
| `pushAll()` for multiple routes | **Complex** | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `context.router.push(SomeNestedRoute())` (heuristic detection) → 1 lint (Phase 1)

### Non-Violations
1. `context.router.navigate(ParentRoute(children: [ChildRoute()]))` → no lint

## Quick Fix

Offer "Use `navigate()` with full hierarchy":
```dart
// Before
context.router.push(ProductDetailRoute(id: id));

// After (template — user must fill in parent route)
context.router.navigate(
  ProductsRoute(children: [ProductDetailRoute(id: id)])
);
```

## Notes & Issues

1. **auto_route-only**: Only fire if `ProjectContext.usesPackage('auto_route')`.
2. **HIGH FALSE POSITIVE RISK in Phase 1**: `push()` is correct for top-level routes. Phase 1 would flag all `push()` calls, which is too aggressive. Consider only flagging when the route class name suggests nesting (e.g., contains "Detail", "Sub", "Inner").
3. **This rule is fundamentally hard**: The route hierarchy is defined in generated code. Without analyzing the generated `*.router.dart` file, we can't know which routes are top-level vs. nested. Consider this a documentation/awareness lint rather than a precision lint.
4. **auto_route version differences**: Route configuration APIs changed between auto_route versions. Ensure detection works for v3+ (current major version).
5. **ROADMAP_DEFERRED candidate**: Given the cross-file analysis requirement, this rule may be better deferred to ROADMAP_DEFERRED.md. Note this in the task doc and reassess during implementation.
