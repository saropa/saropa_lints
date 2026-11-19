# BUG: `require_apple_signin_nonce` — flags `getAppleIDCredential(scopes: [])` used only to get a one-time authorization code for token revocation

**Status: Open**

Created: 2026-10-29
Rule: `require_apple_signin_nonce`
File: `lib/src/rules/packages/sign_in_with_apple_rules.dart` (class at line 861)
Severity: False positive
Rule version: see diagnostic | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule reports every `getAppleIDCredential` call without a `nonce` argument. The reported call requests no scopes and uses only `authorizationCode`, which a server exchanges with Apple to revoke the user's token (account deletion). No identity token is read or trusted, so there is nothing a nonce could protect.

---

## Attribution Evidence

```bash
grep -rn "'require_apple_signin_nonce'" lib/src/rules/
# lib/src/rules/packages/sign_in_with_apple_rules.dart:877:    'require_apple_signin_nonce',
```

**Rule class:** `RequireAppleSigninNonceRule` (`lib/src/rules/packages/sign_in_with_apple_rules.dart:861`)
**Diagnostic as seen in Problems panel:** `[require_apple_signin_nonce] Omitting a cryptographic nonce when using Apple Sign-In exposes your app to replay attacks. ... {v4} (line 138, col 7)` (source: saropa_lints)

---

## Reproducer

Standalone (needs `package:sign_in_with_apple`). Real code: `lib/service/supabase/providers/supabase_account_apple_utils.dart` lines 104-139 (`getAppleRevocationCode`, `_fetchRevocationCredential`). The sign-in call in the same file passes a nonce.

```dart
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// Account deletion: the one-time authorization code is sent to a server that
// exchanges it with Apple to revoke the token. The identity token is not used.
Future<String> revocationCode() async {
  final AuthorizationCredentialAppleID credential =
      await SignInWithApple.getAppleIDCredential(scopes: const <AppleIDAuthorizationScopes>[]); // LINT
  return credential.authorizationCode;
}
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when `scopes` is an empty list and only `authorizationCode` is consumed |
| **Actual** | `[require_apple_signin_nonce]` on the call |

---

## AST Context

`ClassDeclaration(SupabaseAccountAppleUtils)` > `MethodDeclaration(_fetchRevocationCredential)` > `ExpressionFunctionBody` > `MethodInvocation(SignInWithApple.getAppleIDCredential)` > `ArgumentList` > `NamedArgument(scopes: const <AppleIDAuthorizationScopes>[])`. No `nonce` argument.

---

## Root Cause

`sign_in_with_apple_rules.dart` (lines 889-905): `context.addMethodInvocation` checks only `methodName == 'getAppleIDCredential'` and whether a `NamedArgument` called `nonce` exists. It does not look at `scopes`, at which credential fields are read, or at the method name.

---

## Why the code is correct

A nonce binds an identity token to a login request so a captured token cannot be replayed. This call asks for no scopes and the app reads only the authorization code. The code is single-use, valid for 5 minutes, and is spent by the revocation request. The identity token is never validated, so a nonce would add nothing.

## Affected project locations

- `lib/service/supabase/providers/supabase_account_apple_utils.dart:138`

---

## Suggested Fix

Skip the report when the `scopes` argument is a list literal that is empty. Optionally also skip when the enclosing function never reads `identityToken`.

---

## Fixture Gap

- GOOD: `getAppleIDCredential(scopes: const [])`
- GOOD: `getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email], nonce: n)`
- BAD: `getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email])` followed by use of `identityToken`

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed, hosted); rule logic cross-checked against the repo source (17.0.1-beta.3)
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
