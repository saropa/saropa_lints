# Task: `require_auto_route_guard_resume`

## Summary
- **Rule Name**: `require_auto_route_guard_resume`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.27 auto_route Rules
- **Priority**: ⭐ Next in line for implementation (also ⚠️ WARNING severity)

## Problem Statement

`auto_route` navigation guards implement the `AutoRouteGuard` interface and must call `resolver.next(true)` (or `resolver.next(false)`) to allow or deny navigation. If `resolver.next(...)` is never called, the navigation silently hangs — the user sees a loading state or the app freezes on the route transition, with no error message. This is a particularly nasty bug because it's silent and depends on the execution path through the guard.

A guard that conditionally calls `resolver.next(true)` only when the user is authenticated but never calls `resolver.next(false)` for the unauthenticated case will hang for unauthenticated users. Every code path through `onNavigation` MUST call `resolver.next`.

## Description (from ROADMAP)

> Call `resolver.next(true)` after guard condition met. Detect guard without resume.

## Trigger Conditions

1. A class implements `AutoRouteGuard`
2. The `onNavigation` method does NOT call `resolver.next(...)` on all code paths
3. OR: `resolver.next` is only called in one branch of an `if/else` (the other branch is missing the call)

## Implementation Approach

### Package Detection
Only fire if `ProjectContext.usesPackage('auto_route')`.

### Class Detection
```dart
context.registry.addClassDeclaration((node) {
  if (!_implementsAutoRouteGuard(node)) return;
  final onNav = _findOnNavigationMethod(node);
  if (onNav == null) return;  // abstract/not overridden
  if (!_allPathsCallResolverNext(onNav)) {
    reporter.atNode(onNav, code);
  }
});
```

`_implementsAutoRouteGuard`: check `node.implementsClause` for `AutoRouteGuard`.

`_allPathsCallResolverNext`: walk the method body and verify that every execution path (every `return` statement, end of method, all `if/else` branches) has `resolver.next(...)` called before it.

### Simplified Version (Phase 1)
Instead of full control flow analysis, use a conservative heuristic:
- Count the number of `resolver.next` calls in the method body
- Count the number of `return` statements
- If `resolver.next` call count < (return count + 1), warn (the +1 is for the implicit return at end)

This is conservative — it will have false negatives when `resolver.next` is in a nested function/callback. But it's a starting point.

### Full Version (Phase 2)
Use `resolver.getResult(unitNode)` to get control flow analysis and verify all paths call `resolver.next`.

## Code Examples

### Bad (Should trigger)
```dart
class AuthGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (isAuthenticated) {
      resolver.next(true);  // ← only called in one branch
    }
    // ← missing: resolver.next(false) for unauthenticated case
    // Navigation hangs for unauthenticated users!
  }
}

// No resolver.next at all
class EmptyGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    log('checking guard...');
    // ← trigger: resolver.next never called
  }
}
```

### Good (Should NOT trigger)
```dart
// Both branches call resolver.next ✓
class AuthGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (isAuthenticated) {
      resolver.next(true);
    } else {
      resolver.next(false);
      router.push(const LoginRoute());
    }
  }
}

// Async guard with await ✓
class AsyncAuthGuard extends AutoRouteGuard {
  @override
  Future<void> onNavigation(NavigationResolver resolver, StackRouter router) async {
    final isAuth = await authService.isAuthenticated();
    if (isAuth) {
      resolver.next(true);
    } else {
      resolver.next(false);
    }
  }
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `resolver.next(true)` inside a nested `Future` callback | **Trigger** — the outer method may return before the future resolves | Async guards need `await` |
| Guard that calls a helper method which calls `resolver.next` | **False negative** — can't trace into helper without inter-method analysis | Phase 1 limitation; document as known limitation |
| Guard that throws instead of calling `resolver.next` | **Trigger** — throwing is not a valid substitute | Walk for throw statements as alternative exit |
| Abstract base guard that implements the check | **Suppress** — abstract methods have no body | Check if method is abstract |
| Test mock of `AutoRouteGuard` | **Suppress** — test mocks are not real guards | `ProjectContext.isTestFile` |
| `resolver.next(someCondition)` — single call covering both branches | **Suppress** — single call is valid | Count `resolver.next` calls; 1 is fine if no early returns |
| Guard with complex switch statement | **Phase 2** — Phase 1 heuristic may miss this | Note as Phase 2 improvement |
| `resolver.next` called inside a `.then()` callback | **Trigger** — `.then()` is not `await` | Proper pattern requires `await` |
| Guard that redirects via router.push and never calls `resolver.next` | **Trigger** — must still call `resolver.next(false)` | |

## Unit Tests

### Violations
1. `AutoRouteGuard` subclass with `if (auth) resolver.next(true)` but no else → 1 lint
2. `AutoRouteGuard` subclass with no `resolver.next` call at all → 1 lint
3. Guard with two `return` statements but only one `resolver.next` → 1 lint

### Non-Violations
1. Guard with `if/else` where both call `resolver.next(...)` → no lint
2. Guard with `resolver.next(isAuthenticated)` single call → no lint
3. Abstract `AutoRouteGuard` method → no lint
4. Test mock of `AutoRouteGuard` → no lint
5. Project does not use `auto_route` package → no lint

## Quick Fix

Offer "Add missing `resolver.next(false)` to else branch":
```dart
// Adds else { resolver.next(false); } when a single-branch if is detected
```

This is a conservative fix — the resolver.next(false) may not be the right action (they may want to redirect), but it unblocks navigation.

## Notes & Issues

1. **Essential tier** — this is a silent hang bug. The severity should arguably be ERROR, but WARNING allows teams to gradually adopt.
2. **`auto_route` version compatibility**: The `NavigationResolver` API has changed between auto_route v6 and v7. Check the current API surface.
3. **Async guards**: When `onNavigation` is `async`, the `resolver.next` call inside the async body is fine — the guard awaits it properly. The false positive to avoid is flagging async guards correctly.
4. **Helper method tracing** is a known limitation of Phase 1. Document this in the rule's doc comment.
5. **Related rules**: `avoid_auto_route_context_navigation` and `require_auto_route_full_hierarchy` should be implemented alongside this one.
