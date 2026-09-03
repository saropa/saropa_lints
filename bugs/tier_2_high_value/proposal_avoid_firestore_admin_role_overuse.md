# PROPOSAL: Avoid Firestore Admin Role Overuse

**Status: Open**

Created: 2026-09-02

## Summary

Flags code that grants an admin/elevated Firestore role (via custom claims, IAM role strings, or security-rule role checks) to a user or service context where a narrower, scoped role would suffice.

## Existing Coverage

`lib/src/rules/packages/firebase_rules.dart` has `AvoidStoringUserDataInAuthRule` / `AvoidFirebaseUserDataInAuthRule`, which flag large or non-access-control data placed in Firebase custom claims (a data-volume/claims-hygiene check), and `RequireFirestoreSecurityRulesRule`, which requires security rules to exist at all. Neither inspects the *scope* of a granted role — this is a genuine extension: it targets over-privileged role assignment (admin where scoped would do), not claims size or rule presence.

## Motivation

Firebase custom claims and Firestore security rules are commonly written with a single blanket `admin` or `isAdmin: true` flag because it's the fastest path to "it works," rather than a scoped role (`isEditor`, `isModerator`, `orgRole: 'billing'`) matched to the actual operation. An over-privileged claim/role means a compromised token, a leaked admin credential, or a logic bug in one feature grants full read/write across the entire database — violating least privilege and turning any single vulnerability into a full data breach.

## Detection / Behavior

Flags `setCustomClaims` calls (or equivalent role-assignment helpers) that set a known elevated-role key (`admin`, `isAdmin`, `superuser`, `root`) without any narrower role also being present, and flags Firestore security-rule expressions (`request.auth.token.admin == true`) gating operations that only need read/write on a single collection or document owned by the caller.

```dart
// Bad:
await FirebaseAuth.instance.currentUser
    ?.getIdTokenResult(); // later, in a Cloud Function:
await admin.auth().setCustomUserClaims(uid, {'admin': true}); // LINT: grants full admin for a feature that only needs 'canModerateComments'

// Good:
await admin.auth().setCustomUserClaims(uid, {'canModerateComments': true});
```

## Security Mapping

OWASP Mobile M6: Insecure Authorization (excessive privilege granted beyond what the authenticated identity requires).

## Quick Fix

None — manual refactor required. Determining the correct scoped role name is an application-specific decision the rule cannot make; the correction message points the developer to define and use a narrower claim/role for the operation.

## Alternatives Considered

Scoping the rule to Cloud Functions admin-SDK code only (excluding client-side security-rule text, which is not Dart) was considered; the client-side detection instead targets Dart wrappers that construct or check role strings passed to security rules, keeping the rule Dart-analyzable while still catching the common overuse pattern.
