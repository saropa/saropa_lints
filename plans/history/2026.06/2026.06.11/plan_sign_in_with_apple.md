# Plan: new `sign_in_with_apple` lint rules

**Package:** sign_in_with_apple ^8.1.0 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**Verified API surface (8.1.0):**

`SignInWithApple` static methods:
- `static Future<AuthorizationCredentialAppleID> getAppleIDCredential({ required List<AppleIDAuthorizationScopes> scopes, WebAuthenticationOptions? webAuthenticationOptions, String? nonce, String? state })`
- `static Future<bool> isAvailable()`
- `static Future<CredentialState> getCredentialState(String userIdentifier)` — Apple platforms only; throws `SignInWithAppleNotSupportedException` elsewhere

`AuthorizationCredentialAppleID` fields (all nullable except `authorizationCode`):
- `String? userIdentifier`
- `String? givenName`
- `String? familyName`
- `String? email`
- `String authorizationCode` — the only non-nullable field; must be sent to the server
- `String? identityToken` — JWT; contains the nonce hash embedded by Apple; also required for server validation
- `String? state`

`SignInWithAppleAuthorizationException`:
- `const SignInWithAppleAuthorizationException({ required AuthorizationErrorCode code, required String message })`
- Implements `SignInWithAppleException`

`AuthorizationErrorCode` enum values (7.0.0+, verified):
`canceled`, `failed`, `invalidResponse`, `notHandled`, `notInteractive`, `unknown`, `credentialExport`, `credentialImport`, `matchedExcludedCredential`

`CredentialState` enum values: `authorized`, `revoked`, `notFound`

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `apple_sign_in_missing_nonce` | security | `getAppleIDCredential` called with no `nonce:` named argument | no (inserting a nonce requires the caller to generate and SHA256-hash a random string — not a mechanical substitution) | WARNING | only fire when `nonce:` is absent from the call's named argument list; skip calls where `webAuthenticationOptions` is also absent and the call is clearly web-only (speculative — verify) |
| `apple_sign_in_unhandled_authorization_exception` | correctness | `getAppleIDCredential` call not inside a `try/catch` that catches `SignInWithAppleAuthorizationException` or a broad `Object`/`Exception` catch | no | WARNING | fire only when no enclosing `TryStatement` in the function body has a catch clause covering the exception type |
| `apple_sign_in_unhandled_cancel` | correctness | `catch` for `SignInWithAppleAuthorizationException` present but the catch body does NOT reference `AuthorizationErrorCode.canceled` | no | WARNING | check catch body for any `PrefixedIdentifier` or `PropertyAccess` resolving to `AuthorizationErrorCode.canceled`; absent = flag |
| `apple_sign_in_unchecked_availability` | correctness | `getAppleIDCredential` invoked in a file that contains no call resolving to `SignInWithApple.isAvailable()` | no | INFO | FP: availability check may be in a separate service file; lower to INFO; fire only when the file also contains direct use of `SignInWithApple.getAppleIDCredential` |
| `apple_sign_in_null_identity_token` | security | `credential.identityToken` is used without a null check (i.e., accessed as non-nullable via `!` or directly passed to a function that takes `String`) when the static type is `String?` | mechanical fix: insert null guard / assert | WARNING | rely on the Dart static type `String?`; flag `!`-force-unwrap or direct assignment to `String` non-nullable without null check |
| `apple_sign_in_relying_on_name_email` | correctness | code unconditionally reads `credential.givenName`, `credential.familyName`, or `credential.email` without a null check — Apple only delivers these on the first authorization | no | WARNING | flag when field access is used in an assignment or expression where the left-hand type is `String` (non-nullable), meaning null would crash; do NOT flag `credential.email?.isNotEmpty` or similar null-aware forms |
| `apple_sign_in_unchecked_credential_state` | best-practice | `getCredentialState` return value is discarded (expression statement with no assignment) | no | WARNING | register `addExpressionStatement`; flag when the expression is an `AwaitExpression` of a `MethodInvocation` resolving to `SignInWithApple.getCredentialState` |

**Total: 7 rules** (2 security, 3 correctness, 1 best-practice, 1 correctness/availability)

---

## Rule detail

### `apple_sign_in_missing_nonce`

> **VALIDATION (2026-06-11) — DROP (exact duplicate):** `require_apple_signin_nonce` already exists (package_specific_rules.dart:152) — same detection (getAppleIDCredential missing nonce:), same ERROR severity, same replay-attack/OWASP framing. Do NOT add.

- **What/why:** Apple's Sign in with Apple bakes a SHA256 hash of the caller-supplied nonce into the signed `identityToken`. When no nonce is supplied, the token is unauthenticated with respect to the current session: an attacker who intercepts a valid token from a different session or device can replay it against the server. The `nonce` parameter has been available since package version 2.1.0 (pre-dating 8.x); omitting it is an active security gap, not a missing feature. Apple's own documentation on authenticating users specifies the nonce round-trip as the primary replay-attack mitigation.
- **Detection (AST, type-safe):** Register `addMethodInvocation`. For each `MethodInvocation` where the method name is `getAppleIDCredential`, resolve the enclosing class's library URI to `package:sign_in_with_apple/sign_in_with_apple.dart`. Check `node.argumentList.arguments` for any `NamedExpression` whose `name.label.name == 'nonce'`. If none is found, report at the `MethodInvocation` node.
- **Fix:** Report-only. A correct fix requires generating a cryptographically random raw nonce, computing its SHA256 hex digest, passing the digest as `nonce:`, and storing the raw nonce to verify against the `identityToken` server-side. This is a multi-step logical operation that cannot be expressed as a mechanical single-node replacement.
- **False positives:** None expected for the named-argument presence check. The nonce is always meaningful regardless of platform (iOS/Android/web).
- **OWASP:** [M3:Insecure Authentication] — nonce omission allows credential replay.

---

### `apple_sign_in_unhandled_authorization_exception`

- **What/why:** `getAppleIDCredential` is documented to throw `SignInWithAppleAuthorizationException` for all authorization failures (user cancel, system cancel, invalid response, unknown error, etc.). A call not wrapped in a try/catch propagates uncaught, crashing the app on any sign-in failure path — including the common case where the user simply taps "Cancel" in the Apple sign-in sheet. This is the most frequently reported issue in the official GitHub issue tracker (issues #110, #130, #186, #214).
- **Detection (AST, type-safe):** Register `addMethodInvocation`. For each invocation resolving to `SignInWithApple.getAppleIDCredential` (library URI check), walk the AST parent chain to find an enclosing `TryStatement` within the same function body. If no `TryStatement` is found, flag the invocation. If a `TryStatement` is found, iterate its `catchClauses`; verify at least one clause has an exception type that resolves to `SignInWithAppleAuthorizationException` (from `package:sign_in_with_apple`) or to `Object` / `Exception` (bare catch-all). If none qualifies, also flag.
- **Fix:** Report-only. Inserting a try/catch requires knowing the caller's error-handling intent.
- **False positives:** Callers that propagate the exception via `rethrow` inside a wrapper are invisible; accept this as an acceptable FP rate rather than doing cross-function analysis.

---

### `apple_sign_in_unhandled_cancel`

- **What/why:** `AuthorizationErrorCode.canceled` fires when the user dismisses the Apple sign-in sheet. Apps that catch `SignInWithAppleAuthorizationException` generically but do not branch on `.code == AuthorizationErrorCode.canceled` will treat a deliberate user cancel as an error, typically showing an error message or disabling the sign-in flow. This produces a poor UX pattern that is distinct from a real authentication failure and should be handled silently (or with a gentle "Sign in canceled" notice). The Apple developer forums and issue tracker (#186, #162) identify this as one of the most common integration mistakes.
- **Detection (AST, type-safe):** Register `addTryStatement`. For each `TryStatement` whose body contains a `MethodInvocation` resolving to `SignInWithApple.getAppleIDCredential`, examine each `CatchClause`. For every clause that catches `SignInWithAppleAuthorizationException` (verified by element type resolution), inspect the clause body for any `PrefixedIdentifier` or `PropertyAccess` whose element resolves to `AuthorizationErrorCode.canceled` (from `package:sign_in_with_apple`). If no such reference is found in any qualifying catch clause, flag the catch clause node.
- **Fix:** Report-only.
- **False positives:** Apps that intentionally treat cancel and failure identically (e.g., simply restore the sign-in button) are not buggy — the rule is a best-practice nudge. Severity WARNING because missing cancel handling regularly produces user-visible error UI on a benign action.

---

### `apple_sign_in_unchecked_availability`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** parent-file gating → high FP (correctly INFO).

- **What/why:** `SignInWithApple.isAvailable()` returns `false` on platforms/OS versions where the API is not supported (pre-iOS 13, pre-macOS 10.15, and some Android configurations). Calling `getAppleIDCredential()` on an unsupported platform throws `SignInWithAppleNotSupportedException`. The Sign in with Apple button should only be shown when `isAvailable()` returns `true`; this is the standard pattern recommended by the package documentation. Files that call `getAppleIDCredential` with no surrounding availability check silently crash on unsupported devices.
- **Detection (AST, type-safe):** Register `addMethodInvocation`. For each invocation resolving to `SignInWithApple.getAppleIDCredential` (library URI check), walk the enclosing function body and all enclosing function bodies in the same file to find any `MethodInvocation` that resolves to `SignInWithApple.isAvailable`. If no such call is found in the file, flag the `getAppleIDCredential` invocation.
- **Fix:** Report-only. The availability check requires an async guard that may restructure the surrounding widget, which is not a mechanical replacement.
- **False positives:** Significant: apps that gate the entire sign-in widget on `isAvailable()` in a parent widget (a common Flutter pattern) will have the check in a different file. Severity INFO reflects this; it is a low-confidence nudge rather than a definite error.

---

### `apple_sign_in_null_identity_token`

> **VALIDATION (2026-06-11) — DE-CONFLICT:** its `!`-on-identityToken path double-reports with `avoid_null_assertion` (type_rules.dart:773); scope to the non-`!` (assignment-to-non-nullable-String) path or accept the co-fire.

- **What/why:** `AuthorizationCredentialAppleID.identityToken` is typed `String?` (nullable). The identity token is the artifact that the server must validate to verify the sign-in; if it is null, the server call will fail or silently skip validation. Production code often uses `credential.identityToken!` (force-unwrap) or passes it directly to a function expecting `String`, which crashes at runtime when Apple fails to include the token. Apple's own documentation notes that the `identityToken` may be absent in edge cases.
- **Detection (AST, type-safe):** Register `addPostfixExpression`. For each `PostfixExpression` with operator `!`, if the operand is a `PropertyAccess` or `PrefixedIdentifier` whose element resolves to `AuthorizationCredentialAppleID.identityToken` (from `package:sign_in_with_apple`), flag it. Additionally, register `addAssignmentExpression` to catch direct assignment to a `String` (non-nullable) variable from `credential.identityToken` without null handling.
- **Fix:** Mechanical for the `!`-unwrap case: replace `credential.identityToken!` with a null-guard pattern (e.g., early-return or `?? ''`). Mark as priority 80.
- **False positives:** Code that has already confirmed non-null via an `if (credential.identityToken != null)` guard immediately above may still trigger on the force-unwrap inside the if-block; the Dart type promotion should eliminate the need for `!` inside a null check, so genuine FPs should be rare.
- **OWASP:** [M3:Insecure Authentication] — skipping server validation of the identity token defeats the authentication flow entirely.

---

### `apple_sign_in_relying_on_name_email`

> **VALIDATION (2026-06-11) — DE-CONFLICT:** same `avoid_null_assertion` (type_rules.dart:773) co-fire on the `!` path.

- **What/why:** Apple only returns `givenName`, `familyName`, and `email` in `AuthorizationCredentialAppleID` on the **first** authorization between the app and the Apple ID. On all subsequent sign-ins (which is every sign-in after the first), these fields are `null`. Apps that unconditionally treat these as non-null — for example, by assigning to a `String` variable or interpolating directly without null guards — will crash or silently display blank names for all returning users. This is one of the most commonly reported integration bugs in the package's issue tracker (#172 and others). The data MUST be persisted to the app's own backend on first sign-in and read from there on subsequent sign-ins.
- **Detection (AST, type-safe):** Register `addPropertyAccess` and `addPrefixedIdentifier`. For each access whose element resolves to `AuthorizationCredentialAppleID.givenName`, `AuthorizationCredentialAppleID.familyName`, or `AuthorizationCredentialAppleID.email` (all `String?` in the class definition), check whether the access is:
  - The operand of a `PostfixExpression` with `!` — flag: force-unwrap of a reliably-null field.
  - Directly assigned into a `String` (non-nullable) typed variable — flag.
  - Passed directly to a parameter typed `String` (non-nullable) — flag.
  Do NOT flag accesses already protected by `?.`, `??`, or inside a null-check branch (flow promotion).
- **Fix:** Report-only. The correct fix varies: the caller may need to add a null guard, fall back to a stored value, or restructure to persist the credential fields on first use.
- **False positives:** Low; the rule only flags the subset of accesses that would cause a type-system or runtime crash, not all nullable accesses.

---

### `apple_sign_in_unchecked_credential_state`

- **What/why:** `SignInWithApple.getCredentialState(userIdentifier)` returns `CredentialState.revoked` when Apple has revoked authorization (user signed out via Settings → Apple ID → Password & Security → Apps Using Apple ID → Remove). Apps that do not periodically call `getCredentialState` and react to `revoked` will keep the user "signed in" after they explicitly revoked access. Apple's own documentation specifies that apps should check credential state at launch and sign the user out when the state is `revoked` or `notFound`. Discarding the return value of `getCredentialState` — treating it as a fire-and-forget call — means the result is never acted on.
- **Detection (AST, type-safe):** Register `addExpressionStatement`. If the expression is an `AwaitExpression` whose operand is a `MethodInvocation`, resolve the method element's enclosing class library URI to `package:sign_in_with_apple/sign_in_with_apple.dart` and the method name to `getCredentialState`. If the `ExpressionStatement` is NOT the right-hand side of an assignment or a variable declaration initializer, flag it.
- **Fix:** Report-only. Handling the result requires a state-dependent branch (sign out on `revoked`, handle `notFound`) that is caller-specific.
- **False positives:** Rare; `getCredentialState` has no side effects, so calling it without using its result is almost never intentional.

---

## Implementation note

New file: `lib/src/rules/packages/sign_in_with_apple_rules.dart`

Register all 7 rule classes in `_allRuleFactories` in `lib/saropa_lints.dart` (the `_allRuleFactories` list near line 157).

Add all rule names to an appropriate tier in `lib/src/tiers.dart`:
- `apple_sign_in_missing_nonce` → `professionalOnlyRules` or `comprehensiveOnlyRules` (security, high value)
- `apple_sign_in_unhandled_authorization_exception` → `recommendedOnlyRules` (correctness, broad impact)
- `apple_sign_in_unhandled_cancel` → `recommendedOnlyRules` (correctness/UX, common bug)
- `apple_sign_in_unchecked_availability` → `comprehensiveOnlyRules` (INFO, high FP risk)
- `apple_sign_in_null_identity_token` → `professionalOnlyRules` (security, mechanical fix available)
- `apple_sign_in_relying_on_name_email` → `recommendedOnlyRules` (correctness, common production bug)
- `apple_sign_in_unchecked_credential_state` → `comprehensiveOnlyRules` (best-practice, session hygiene)

Security rules carry OWASP mapping in rule header (see rule detail for `apple_sign_in_missing_nonce` and `apple_sign_in_null_identity_token`).

All detection uses:
- Library URI: `package:sign_in_with_apple/sign_in_with_apple.dart`
- Element resolution via `MethodInvocation.methodName.staticElement?.enclosingElement?.library?.identifier` — NEVER bare name string matching
- Type resolution via `node.staticType` for nullable field checks
- Base class: `SaropaLintRule` (not `DartLintRule`)
- Required overrides: `impact` (`LintImpact`), `cost` (`RuleCost`)

---

## Sources

- pub.dev package page: https://pub.dev/packages/sign_in_with_apple
- pub.dev API docs — `getAppleIDCredential`: https://pub.dev/documentation/sign_in_with_apple/latest/sign_in_with_apple/SignInWithApple/getAppleIDCredential.html
- pub.dev API docs — `AuthorizationErrorCode`: https://pub.dev/documentation/sign_in_with_apple/latest/sign_in_with_apple/AuthorizationErrorCode.html
- pub.dev API docs — `AuthorizationCredentialAppleID`: https://pub.dev/documentation/sign_in_with_apple/latest/sign_in_with_apple/AuthorizationCredentialAppleID-class.html
- pub.dev API docs — `CredentialState`: https://pub.dev/documentation/sign_in_with_apple/latest/sign_in_with_apple/CredentialState.html
- pub.dev API docs — `isAvailable`: https://pub.dev/documentation/sign_in_with_apple/latest/sign_in_with_apple/SignInWithApple/isAvailable.html
- pub.dev API docs — `SignInWithAppleAuthorizationException`: https://pub.dev/documentation/sign_in_with_apple/latest/sign_in_with_apple/SignInWithAppleAuthorizationException-class.html
- pub.dev changelog: https://pub.dev/packages/sign_in_with_apple/changelog
- Official GitHub (aboutyou/dart_packages) — nonce issue #261 pattern: https://github.com/FilledStacks/stacked/issues/261
- GitHub issue — user cancel (#186): https://github.com/aboutyou/dart_packages/issues/186
- GitHub issue — user name null (#172): https://github.com/aboutyou/dart_packages/issues/172
- GitHub issue — unknown error 1000 (#130): https://github.com/aboutyou/dart_packages/issues/130
- Apple Developer Documentation — authenticating users: https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple
- Apple Developer Documentation — nonce field: https://developer.apple.com/documentation/signinwithapplejs/clientconfigi/nonce
- Firebase docs — Sign in with Apple (nonce pattern): https://firebase.google.com/docs/auth/ios/apple
- Firebase Flutter docs — social auth (nonce usage): https://firebase.flutter.dev/docs/auth/social/

---

## Finish Report (2026-06-11)

 Scope (LINTER variant): (A) Dart lint rules / analyzer plugin + (C) docs.

**Shipped.** 6 rules (unhandled_authorization_exception, unhandled_cancel, unchecked_availability, null_identity_token, relying_on_name_email, unchecked_credential_state). Dropped apple_sign_in_missing_nonce (exact duplicate). The two de-conflict rules scoped to the assignment-to-non-nullable path (not the ! path) to avoid co-firing with avoid_null_assertion.

Rules marked DROP / defer in the 2026-06-11 VALIDATION notes were intentionally not implemented (duplicates, overlap with existing rules, or feasibility concerns) — that triage is honored, not skipped. Every rule is import-gated via `fileImportsPackage`; migration rules are version-gated via `kRulePackDependencyGates` and relocated out of their base pack via `kRelocatedRulePackCodes` so a project on the old major never sees a rule for an API it lacks.

**Verification.** `dart analyze lib --fatal-infos` clean; `dart run tool/rule_pack_audit.dart` exit 0; full test suite green (1336 tests across test/integrity, test/config, test/rules/packages); registry regenerated twice + `dart format`. Rules authored by parallel subagents then serially registered into the shared files (tiers.dart, saropa_lints.dart, import_utils.dart, all_rules.dart, rule_packs.dart, generator + audit).

**Plan disposition.** Complete — archived to `plans/history/2026.06/2026.06.11/`.
