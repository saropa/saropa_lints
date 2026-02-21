# Task: `avoid_firestore_admin_role_overuse`

## Summary
- **Rule Name**: `avoid_firestore_admin_role_overuse`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.29 Firebase Advanced Rules

## Problem Statement

Firebase custom claims allow setting roles on user tokens, including "admin" roles. Over-assigning admin roles creates security risks:

1. **Principle of least privilege**: Users should only have the minimum access needed
2. **Hard to revoke**: Admin claims are embedded in JWT tokens — revoking requires token refresh
3. **Client-side checking**: Checking admin status client-side (`user.claims['admin']`) is not secure — anyone can modify local claims
4. **Firebase Security Rules bypass**: Admin claims should trigger server-side rule bypasses, not client-side feature unlocks

Common mistake:
```dart
// Client-side admin check — can be bypassed
if (user.claims['admin'] == true) {
  _showAdminPanel(); // ← any user can fake this in debug mode
}

// Over-assigning admin:
await FirebaseAuth.instance.currentUser?.getIdToken(true);
// ← refreshing tokens for admin checks on every page is also a sign of over-reliance
```

## Description (from ROADMAP)

> Limit admin roles. Detect excessive admin claims assignment.

## Trigger Conditions

1. `user.getIdTokenResult()` called frequently (in `initState`, in `StreamBuilder` without caching) to check admin status
2. `user.claims['admin']` (or similar) checked on the client side to show/hide UI elements without server-side verification
3. Multiple distinct admin-level custom claims detected in the same project

**Phase 1 (Conservative)**: Flag client-side custom claims access for UI decisions (`if (claims['admin'])` → show admin panel).

## Implementation Approach

```dart
context.registry.addIndexExpression((node) {
  // Looking for patterns like: claims['admin'], token.claims['role']
  if (!_isClaimsAccess(node)) return;
  // Check if inside an if-condition affecting UI
  if (_isInsideUiDecision(node)) {
    reporter.atNode(node, code);
  }
});
```

`_isClaimsAccess`: check if `node.target` is `claims` (from `IdTokenResult.claims` or similar) and the index is a string literal.

## Code Examples

### Bad (Should trigger)
```dart
// Client-side admin UI decision
final idTokenResult = await user.getIdTokenResult();
if (idTokenResult.claims['admin'] == true) {  // ← trigger: client-side admin check for UI
  setState(() => _isAdmin = true);
  _showAdminPanel(); // ← UI change based on client-side claim
}

// Over-refreshing for admin status
@override
void initState() {
  super.initState();
  _checkAdminStatus(); // ← refreshing JWT in initState on every page load
}
```

### Good (Should NOT trigger)
```dart
// Server-side verification via Firestore Security Rules
// Client only reads data; Firebase rules enforce admin access
await FirebaseFirestore.instance.collection('admin_config').get();
// ← if user isn't admin, Firestore rules deny access

// Minimal client-side check for UI HINTING only (not security)
final token = await user.getIdTokenResult(false); // don't force refresh
if (token.claims['role'] == 'admin') {
  _showAdminHint(); // ← just a UI hint, security enforced server-side
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Claims checked for analytics/logging only | **Suppress** | |
| Claims stored and used for non-security UI personalization | **Complex** | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `if (idTokenResult.claims['admin'] == true)` affecting UI state → 1 lint

### Non-Violations
1. Claims check for logging only → no lint
2. Firebase Security Rules enforcement (server-side) → no lint (not visible to lint)

## Quick Fix

No automated fix. Suggest:
1. Move admin checks to Firebase Security Rules (server-side)
2. If client-side check needed, clearly comment it's for UI hints only, not security

## Notes & Issues

1. **firebase_auth-only**: Only fire if `ProjectContext.usesPackage('firebase_auth')` or `ProjectContext.usesPackage('cloud_firestore')`.
2. **OWASP**: Maps to **M1: Improper Platform Usage** — client-side security enforcement.
3. **Very high false positive risk**: Many legitimate patterns check claims client-side for UI personalization. The lint must be conservative — only flag when the claim check directly affects security-sensitive operations (not just UI showing/hiding).
4. **Custom claims size limit**: Firebase custom claims are limited to 1000 bytes. A companion rule could detect when too many custom claims are being set.
5. **getIdToken(true) in production**: Forcing token refresh (`getIdToken(forceRefresh: true)`) frequently is expensive. Detect this as a potential performance issue.
