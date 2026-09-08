# BUG: `google_sign_in_auth_token_from_authenticate` — PrefixedIdentifier branch flags already-correct `.accessToken` reads

**Status: Fixed**

Created: 2026-09-08
Rule: `google_sign_in_auth_token_from_authenticate`
File: `lib/src/rules/packages/google_sign_in_rules.dart` (line ~518)
Severity: False positive
Rule version: v1 | Since: v4.20.0 | Updated: v4.20.0

---

## Summary

The `PropertyAccess` visitor (chained form, e.g. `account.accessToken`) correctly
guards with `_looksLikeGsiAccount(target)` before reporting. The
`PrefixedIdentifier` visitor (simple form, e.g. `acct.accessToken`) has **no
such guard at all** — it fires on `.accessToken` for ANY receiver in any file
that imports `google_sign_in`, including variables that are already the
correct v7 `GoogleSignInClientAuthorization` result (i.e. code that already
implements the rule's own suggested fix) and variables of wholly unrelated
types (e.g. a local DB model that happens to have an `accessToken` field).

This produced 17 false-positive findings in a downstream project
(`d:/src/contacts`) across 6 files where every single flagged site already
calls `account.authorizationClient.{authorizeScopes,authorizationForScopes}(...)`
and reads `.accessToken` off the returned `GoogleSignInClientAuthorization` (or,
in two sites, off an unrelated `AuthProviderModel` DB row) — never off the raw
`GoogleSignInAccount`.

---

## Attribution Evidence

```bash
grep -rn "'google_sign_in_auth_token_from_authenticate'" lib/src/rules/
# lib/src/rules/packages/google_sign_in_rules.dart:480:    'google_sign_in_auth_token_from_authenticate',
```

**Emitter registration:** `lib/src/rules/packages/google_sign_in_rules.dart:480`
**Rule class:** `GoogleSignInAuthTokenFromAuthenticateRule` — defined at
`lib/src/rules/packages/google_sign_in_rules.dart:464`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
import 'package:google_sign_in/google_sign_in.dart';

Future<String?> example(GoogleSignInAccount account) async {
  // Correct v7 pattern — exactly what the rule's own "GOOD" example shows.
  final GoogleSignInClientAuthorization authorization =
      await account.authorizationClient.authorizeScopes(<String>['scope']);

  // Simple (non-chained) property read on the AUTHORIZATION object, not the
  // account. This should NOT lint — but PrefixedIdentifier fires anyway
  // because it never checks the receiver.
  final String token = authorization.accessToken; // LINT (false positive) — should be OK

  return token;
}
```

A second, unrelated-type variant also fires:

```dart
import 'package:google_sign_in/google_sign_in.dart';

class StoredAuth {
  StoredAuth(this.accessToken);
  final String accessToken;
}

void example2(StoredAuth storedAuth) {
  // storedAuth is not a GoogleSignInAccount or GoogleSignInClientAuthorization
  // at all — it's an unrelated model. Flags anyway because the file imports
  // google_sign_in and the property name matches.
  final String t = storedAuth.accessToken; // LINT (false positive) — should be OK
}
```

**Frequency:** Always, for any `.accessToken` PrefixedIdentifier read in a file
that imports `google_sign_in`, regardless of receiver type.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the receiver is a `GoogleSignInClientAuthorization` (or an unrelated type), not a `GoogleSignInAccount` |
| **Actual** | `[google_sign_in_auth_token_from_authenticate] ...` reported on both `authorization.accessToken` and `storedAuth.accessToken` |

---

## AST Context

```
MethodInvocation / VariableDeclarationStatement
  └─ VariableDeclaration (token)
      └─ PrefixedIdentifier (authorization.accessToken)  ← node reported here
          ├─ SimpleIdentifier (authorization)  — declared type GoogleSignInClientAuthorization
          └─ SimpleIdentifier (accessToken)
```

---

## Root Cause

`lib/src/rules/packages/google_sign_in_rules.dart:516-522`:

```dart
context.addPrefixedIdentifier((PrefixedIdentifier node) {
  if (!_importsGsi(node)) return;
  if (node.identifier.name != 'accessToken') return;
  reporter.atNode(node);
});
```

Unlike the `PropertyAccess` visitor a few lines above (which calls
`_looksLikeGsiAccount(target)` before reporting), this branch has no receiver
check whatsoever. It reports on file-import + property-name match alone, so it
cannot distinguish:

1. `account.accessToken` where `account` is `GoogleSignInAccount` — TRUE
   positive, this is the bug the rule exists to catch.
2. `authorization.accessToken` where `authorization` is
   `GoogleSignInClientAuthorization` — the CORRECT, already-migrated pattern
   the rule's own "GOOD" example recommends.
3. `storedAuth.accessToken` where `storedAuth` is an unrelated model class
   that happens to have a field named `accessToken`.

### Hypothesis A (confirmed): missing receiver-type/heuristic check on the PrefixedIdentifier path

The fix is to run the same (or a stronger, type-based) receiver check used in
the `PropertyAccess` branch against `node.prefix` before reporting. Ideally
resolve `node.prefix.staticType` and only flag when it is (or could be)
`GoogleSignInAccount` — excluding `GoogleSignInClientAuthorization` explicitly,
since that is the documented correct-migration return type this rule tells
users to switch to.

---

## Suggested Fix

In `lib/src/rules/packages/google_sign_in_rules.dart`, change:

```dart
context.addPrefixedIdentifier((PrefixedIdentifier node) {
  if (!_importsGsi(node)) return;
  if (node.identifier.name != 'accessToken') return;
  reporter.atNode(node);
});
```

to reuse `_looksLikeGsiAccount` (or a proper `staticType` check) against
`node.prefix`, and additionally exclude receivers whose static type is
`GoogleSignInClientAuthorization`:

```dart
context.addPrefixedIdentifier((PrefixedIdentifier node) {
  if (!_importsGsi(node)) return;
  if (node.identifier.name != 'accessToken') return;
  final DartType? receiverType = node.prefix.staticType;
  if (receiverType?.getDisplayString() == 'GoogleSignInClientAuthorization') {
    return; // already the correct v7 pattern
  }
  if (!_looksLikeGsiAccount(node.prefix)) return;
  reporter.atNode(node);
});
```

Prefer resolving `node.prefix.staticType` over the name heuristic where
possible, since the name heuristic (`contains('account')` etc.) is itself
fragile (e.g. `storedAuth` doesn't match "account" but still false-positived
downstream via the *unguarded* path — once guarded by name heuristic alone it
would correctly stop matching `storedAuth`, so the heuristic reuse alone fixes
both repro cases above).

---

## Fixture Gap

The fixture at
`example_packages/lib/google_sign_in/google_sign_in_fixture.dart` should
include:

1. **`final token = authorization.accessToken;`** where `authorization` is a
   `GoogleSignInClientAuthorization` obtained via
   `account.authorizationClient.authorizeScopes(...)` — expect NO lint.
2. **`final token = auth?.accessToken;`** off the nullable result of
   `authorizationClient.authorizationForScopes(...)` — expect NO lint.
3. **`final t = someUnrelatedModel.accessToken;`** where the receiver type is
   an unrelated local class — expect NO lint.
4. Keep existing **`final token = account.accessToken;`** (raw
   `GoogleSignInAccount`) — expect LINT (already covered, must still fire).

---

## Changes Made

`lib/src/rules/packages/google_sign_in_rules.dart` — added the same
`_looksLikeGsiAccount(node.prefix)` guard to the `PrefixedIdentifier` branch
that the `PropertyAccess` branch already had. No new type-check was needed
(the suggested `staticType == 'GoogleSignInClientAuthorization'` exclusion is
redundant — the name heuristic alone already excludes `authorization`, since
it contains neither `account` nor `Account`).

## Tests Added

`example_packages/lib/google_sign_in/google_sign_in_fixture.dart`:
- Existing `authTokenGood`'s `authorization.accessToken` (line ~176,
  PrefixedIdentifier form) now correctly produces no lint — this was
  previously an unflagged FP because the rule only has instantiation-pin
  tests (`test/rules/packages/google_sign_in_rules_test.dart`), not
  scan-based `expect_lint` verification, so it never surfaced.
- Added `_UnrelatedAuthModel` + `authTokenGoodUnrelatedType()` covering the
  unrelated-model-class case (`storedAuth.accessToken`).

Verified via `dart run saropa_lints scan example_packages/lib/google_sign_in
--tier comprehensive --files google_sign_in_fixture.dart --format json`:
`google_sign_in_auth_token_from_authenticate` count is 1 (only the true
positive at line 164), down from firing on every `.accessToken` read in the
file.

---

## Commits

<!-- Add commit hash once committed. -->

---

## Environment

- saropa_lints version: v4.20.0 (rule `Since`)
- Triggering project/file: `d:/src/contacts` —
  `lib/service/google_people/google_people_api_utils.dart:250,279,396,445,482,491`,
  `lib/service/supabase/providers/supabase_account_google_calendar_utils.dart:81,85,119,124`,
  `lib/service/supabase/providers/supabase_account_google_drive_utils.dart:76,97`,
  `lib/service/supabase/providers/supabase_account_google_meet_utils.dart:80,103`,
  `lib/service/supabase/providers/supabase_account_google_utils.dart:306,315,334`
