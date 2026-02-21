# Task: `avoid_firebase_user_data_in_auth`

## Summary
- **Rule Name**: `avoid_firebase_user_data_in_auth`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.29 Firebase Advanced Rules

## Problem Statement

Firebase custom claims (set via Firebase Admin SDK on the server) are embedded in the JWT token. The total size of all custom claims is limited to **1000 bytes**. Exceeding this limit causes the token to be rejected by Firebase.

Common mistake: storing large user profile data in custom claims instead of Firestore:
```dart
// Server-side (pseudo-code) — BAD
await admin.auth().setCustomUserClaims(uid, {
  'role': 'admin',
  'permissions': [...long list...],     // ← large data
  'profile': {...entire profile...},    // ← huge
  'preferences': {...user prefs...},   // ← even more
  // Total: may exceed 1000 bytes → token rejected!
});
```

The correct approach:
- Custom claims: **only small, immutable, security-relevant data** (role, subscription tier, account type)
- User profile data: store in **Firestore** and fetch separately

## Description (from ROADMAP)

> Auth claims limited to 1000 bytes. Detect large data in custom claims.

## Trigger Conditions

This rule operates on the **client-side** detection of custom claims, not the server-side setting. The client-side trigger is:

1. Reading many different custom claim keys (`claims['key1']`, `claims['key2']`, `claims['key3']`, ...) — suggests large claims data
2. Reading claims with large expected value types (lists, nested objects accessed from claims)

**Primary use case**: Detecting over-reliance on claims for data that should be in Firestore.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  // Look for getIdTokenResult() calls
  if (!_isGetIdTokenResult(node)) return;

  // Find the claims usage after this call
  // If many different keys are accessed, that suggests large claims
  _analyzeClaimsUsageNearby(node, reporter);
});
```

`_analyzeClaimsUsageNearby`: within the enclosing function, count distinct keys accessed from `claims[...]`. If > 5 distinct keys, flag as potential large claims.

## Code Examples

### Bad (Should trigger — heuristic: many claim keys)
```dart
Future<void> loadUserProfile() async {
  final tokenResult = await user.getIdTokenResult();
  final claims = tokenResult.claims;

  // Many distinct keys — suggests too much data in claims
  final role = claims['role'];
  final tier = claims['subscription_tier'];
  final permissions = claims['permissions']; // ← list?
  final preferences = claims['theme_preference'];
  final country = claims['country'];
  final language = claims['language'];  // ← 6+ keys accessed → trigger
}
```

### Good (Should NOT trigger)
```dart
// Minimal claims usage (role + one more)
final tokenResult = await user.getIdTokenResult();
final isAdmin = tokenResult.claims['role'] == 'admin';
final tier = tokenResult.claims['subscription_tier'];
// ← only 2 claim keys — lightweight, appropriate

// User profile data from Firestore (correct approach)
final profileDoc = await FirebaseFirestore.instance
    .collection('users').doc(uid).get();
final profile = UserProfile.fromJson(profileDoc.data()!);
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| 3-4 claim keys (reasonable) | **Suppress** — threshold-based | Use threshold of 5+ keys |
| Claims in test/mock data | **Suppress** | |
| Claims accessed in separate places (not counted together) | **Complex** — need function-level aggregation | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `getIdTokenResult()` followed by 6+ distinct `claims['key']` accesses → 1 lint

### Non-Violations
1. Only `claims['role']` accessed → no lint
2. 2-3 claim keys accessed → no lint

## Quick Fix

No automated fix. Suggest:
1. Move profile data to Firestore
2. Keep only security-critical, small data (role, subscription tier) in claims

## Notes & Issues

1. **firebase_auth-only**: Only fire if `ProjectContext.usesPackage('firebase_auth')`.
2. **Server-side vs client-side**: This rule detects client-side over-reliance (too many distinct claim keys). The actual bug is on the server (setting too much data). The client-side detection is a heuristic proxy.
3. **OWASP**: Maps to **M1: Improper Platform Usage** — misusing platform features (custom claims for data storage).
4. **Threshold question**: 5 keys is arbitrary. A better threshold might be based on the total expected data size, but that requires value type analysis. Simple key counting is the practical Phase 1 approach.
5. **The 1000-byte limit**: This is a hard Firebase limit. Exceeding it causes silent authentication failures that are hard to debug. The rule aims to prevent this.
6. **Custom claims vs firestore**: The recommended Firebase architecture is:
   - Custom claims: role, tier, featureFlags (booleans) — < 200 bytes ideally
   - User profile: Firestore `users/{uid}` document — unlimited
