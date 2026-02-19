# Task: `avoid_auto_route_keep_history_misuse`

## Summary
- **Rule Name**: `avoid_auto_route_keep_history_misuse`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.27 auto_route Rules

## Problem Statement

In `auto_route`, `keepHistory: false` in a route's `push()` call (or equivalent configuration) removes all intermediate routes from the navigation stack when navigating to the new route. This is intentional for login/logout flows but is a common source of bugs when used unintentionally:

```dart
// BUG: Using replaceAll or keepHistory: false unintentionally
context.router.replaceAll([HomeRoute()]); // ← clears entire navigation stack!
// Now the user can't go back to where they were
```

Or when using `AutoRouteDelegate`'s stack modification:
```dart
context.router.navigate(SomeRoute()); // ← can clear history depending on config
```

The problem: developers use `replaceAll`, `popUntilRoot`, or `keepHistory: false` for convenience navigation but unintentionally destroy the user's navigation history, breaking the back button.

## Description (from ROADMAP)

> Understand keepHistory: false behavior. Detect unintended stack modification.

## Trigger Conditions

1. `context.router.replaceAll([...])` called outside of an authentication flow context
2. `context.router.popUntilRoot()` in a context that suggests it's being used for general navigation rather than stack cleanup
3. Route annotation with `keepHistory: false` on a non-authentication route

**High subjectivity** — what constitutes "legitimate" use of `replaceAll` vs. "accidental" use is a judgment call.

## Implementation Approach

### Phase 1 (Conservative): Flag `replaceAll` calls
```dart
context.registry.addMethodInvocation((node) {
  if (node.methodName.name != 'replaceAll') return;
  if (!_isAutoRouterCall(node)) return;
  reporter.atNode(node, code);
});
```

Every `replaceAll` should be reviewed — the developer should be aware they're clearing the stack.

### Phase 2 (Contextual)
Suppress if inside an auth-related function:
- Function name contains `logout`, `signOut`, `login`, `onboarding`
- Inside a `FirebaseAuth.instance.signOut()` chain

## Code Examples

### Bad (Should trigger)
```dart
// Accidentally clearing stack for general navigation
onTap: () {
  context.router.replaceAll([  // ← trigger: clearing entire stack unintentionally
    const HomeRoute(),
    const ProductsRoute(),
  ]);
}

// popUntilRoot as a back-to-home shortcut
homeButton.onPressed = () {
  context.router.popUntilRoot(); // ← may be intentional, but warrants review
};
```

### Good (Should NOT trigger)
```dart
// Legitimate use: post-login navigation
void _onLoginSuccess() {
  context.router.replaceAll([const DashboardRoute()]); // ← OK: auth flow
}

// Legitimate use: logout
void _onLogout() {
  context.router.replaceAll([const LoginRoute()]); // ← OK: clear stack on logout
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `replaceAll` in auth-related function (login/logout) | **Suppress** | Heuristic: function name |
| `replaceAll` in onboarding completion | **Suppress** | Heuristic: function name contains "onboarding" |
| `popUntilRoot` in a back-to-home action | **Trigger** with note | Review is appropriate |
| `keepHistory: false` on a route annotation | **Complex** — annotation on class | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `context.router.replaceAll(...)` in generic navigation context → 1 lint

### Non-Violations
1. `context.router.replaceAll(...)` inside a function named `_onLogout` → no lint (heuristic)
2. `context.router.push(...)` → no lint
3. Non-auto_route project → no lint

## Quick Fix

No automated fix — the developer must decide whether `replaceAll` is intentional. Suggest adding a comment: `// Intentionally clearing navigation stack`.

Or offer "Use `push()` instead":
```dart
// Before
context.router.replaceAll([SomeRoute()]);

// After
context.router.push(SomeRoute());
```

## Notes & Issues

1. **auto_route-only**: Only fire if `ProjectContext.usesPackage('auto_route')`.
2. **HIGH FALSE POSITIVE RISK**: `replaceAll` has many legitimate uses (auth flows, onboarding, error recovery). A blanket warning on `replaceAll` will be annoying in projects that use it correctly.
3. **The real fix is education**: This rule is primarily about making developers aware of what `replaceAll` and `keepHistory: false` do. A WARNING with a clear correction message is more valuable than precision detection.
4. **Consider INFO tier**: Given the high false positive rate, downgrading to INFO may be appropriate. The ROADMAP says WARNING (Professional tier) — flag this for discussion during implementation.
5. **`navigate()` vs `push()` vs `replace()` vs `replaceAll()`**: auto_route has many navigation methods with subtle differences. The rule should focus on the most destructive ones (`replaceAll`, `popUntilRoot`) rather than all navigation methods.
