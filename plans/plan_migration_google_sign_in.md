# Plan: `google_sign_in_7` migration pack

**Status:** ready to implement. **Value: MEDIUM** — the v7 break **removed** the
old API (`GoogleSignIn()` constructor, `signIn()`), so on v7 the old code does NOT
compile and `dart analyze` already errors. A *post-upgrade cleanup* pack would
find nothing. The useful framing is **pre-upgrade readiness**: gate on the **old**
major and flag v6 code that will break when the team bumps to v7.
**Gate type:** pre-upgrade readiness. **Gate:** `google_sign_in < 7.0.0`.
**Driving app:** Saropa Contacts ships `google_sign_in: ^7.2.0` — already migrated
(compiler-forced); this pack helps the general user base still on 6.x.

## 1. The migration (verified)

v7.0.0 is a major refactor for Android Credential Manager + modern Google Identity
Services:

| v6 (removed in v7) | v7 |
|---|---|
| `GoogleSignIn(scopes: [...])` constructor | `GoogleSignIn.instance` singleton + `await initialize()` |
| `signIn()` | `authenticate()` |
| `signInSilently()` | `attemptLightweightAuthentication()` |
| auth returns `accessToken` directly | authentication and **authorization** split — tokens via `authorizationClient` and explicit scope requests |

This is a **structural** change (required async `initialize()`, separated
auth/authorize), not a symbol rename — so it is **not mechanically auto-fixable**.

## 2. Rules (`lib/src/rules/packages/google_sign_in_rules.dart`, new file)

Single rule `avoid_pre_v7_google_sign_in` (report-only, no fix) with sub-detections:

- `GoogleSignIn(...)` constructor invocation (becomes the singleton in v7).
- `.signIn()` / `.signInSilently()` method calls on a `GoogleSignIn` instance.

**Detection (type-safe):** match on the element's library URI =
`package:google_sign_in`; verify the target's static type is `GoogleSignIn`. The
`signIn` name is generic — the type check is essential to avoid flagging unrelated
`.signIn()` methods.

**No fix.** The correctionMessage names the v7 replacement per call
(`GoogleSignIn()` → `GoogleSignIn.instance` + `initialize()`; `signIn()` →
`authenticate()`; access-token retrieval → `authorizationClient`) and links the
migration guide. Auto-rewriting the auth/authorize split would silently drop scope
handling — report-only is the correct, safe choice (do NOT ship an insert-TODO or
half fix per CLAUDE.md).

## 3. Wiring (recipe steps 2–6)

- `kRulePackDependencyGates`: `'google_sign_in_7': RulePackDependencyGate(dependency: 'google_sign_in', constraint: '<7.0.0')`
  — note the **`<`** constraint (pre-upgrade gate). Confirm `packPassesDependencyGate`
  handles `<` ranges; `pub_semver` `VersionConstraint.parse('<7.0.0')` does. Add a
  `test/config` case for the `<`-form if none exists.
- generator: `'google_sign_in_7': {'google_sign_in'}` + title `'google_sign_in 7.x (pre-upgrade)'`
- `kRelocatedRulePackCodes`: `'avoid_pre_v7_google_sign_in': (fromPack: 'google_sign_in', toPack: 'google_sign_in_7')`
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_google_sign_in_test.dart`: gate passes at 6.x, **fails at
  7.2.0** (already migrated) and when absent; ownership; merge override. This is the
  first `<`-constraint gate — assert the direction explicitly.
- `test/rules/packages/google_sign_in_rules_test.dart`: `GoogleSignIn(...)` and
  `.signIn()` trigger with the correct correctionMessage; an unrelated class with a
  `signIn()` method does NOT trigger.

## 5. Open decision (needs maintainer call)

The `<`-constraint "pre-upgrade readiness" gate is a **new pack archetype** (all
existing gates — `dio_5`, `riverpod_2` — are `>=` post-upgrade). Confirm the pack
system should support both directions before landing; if not, this pack is dropped
(low post-upgrade value). See the Build recipe section below (gate-direction note).

## Sources

- [google_sign_in changelog](https://pub.dev/packages/google_sign_in/changelog)
- [Migration guide pre-7.0 → v7 (Adariku)](https://isaacadariku.medium.com/google-sign-in-flutter-migration-guide-pre-7-0-versions-to-v7-version-cdc9efd7f182)
- [v7 new auth flow (dev.to)](https://dev.to/_ashish_tandon_/flutter-google-sign-in-with-googlesignin-7-understanding-the-new-authentication-flow-2pbe)

---

## Correctness & best-practice rules (v7 usage, non-migration)

> **VALIDATION (2026-06-11) — NOTE:** This entire pack depends on the unresolved `<`-constraint gate-archetype decision (§5 "Open decision"). If pre-upgrade `<` gates are rejected, the migration rule is dropped; confirm the gate direction is supported before landing any of the rules below.

**Gate:** `google_sign_in >= 7.0.0`. These rules apply ONLY on v7 — the APIs they reference do not exist on v6.

All detections are type-safe: match on the static type's library URI == `package:google_sign_in` (or `package:google_sign_in/google_sign_in.dart`). Never match on bare method name alone; `authenticate()` and `signIn()` are common English words that appear in unrelated classes.

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `google_sign_in_missing_exception_handler` | correctness | `authenticate()` / `attemptLightweightAuthentication()` call not wrapped in try/catch that catches `GoogleSignInException` | no | WARNING | only flag when the enclosing scope has no catch clause whose type is `GoogleSignInException` or a supertype |
| `google_sign_in_unchecked_supports_authenticate` | correctness | `authenticate()` called without a reachable `supportsAuthenticate()` guard in the same function or conditional branch | no | WARNING | only flag when there is no enclosing `if (…supportsAuthenticate()…)` guard |
| `google_sign_in_auth_token_from_authenticate` | correctness | property access `.accessToken` on the return value of `authenticate()` (or on `GoogleSignInAccount` in a branch that came directly from `authenticate()`) | yes — delete the accessor; insert comment directing to `authorizationClient.authorizeScopes()` | ERROR | only flag on `GoogleSignInAccount` type from `package:google_sign_in`; do NOT flag legitimate `.idToken` accesses |
| `google_sign_in_canceled_not_handled` | correctness | catch clause for `GoogleSignInException` that does not contain a branch checking `exception.code == GoogleSignInExceptionCode.canceled` | no | INFO | only inside catch clauses whose caught type is `GoogleSignInException`; if the catch block re-throws or calls a general error handler, do not flag |
| `google_sign_in_authenticate_before_initialize` | correctness | `authenticate()` or `attemptLightweightAuthentication()` called on `GoogleSignIn.instance` at a call site that is NOT inside a function whose body contains a prior `await …initialize()` call, AND that is not inside an `authenticationEvents` listener callback | no | WARNING | only flag top-level or widget `initState`/`build` call sites; do not flag inside callbacks passed to `.then()` or stream handlers where initialization ordering is implied |

---

### `google_sign_in_missing_exception_handler`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** Wrapper-method-catches-downstream is a known FP class the plan waves through with `// ignore:`. Tighten detection (e.g. recognize delegation to a method whose signature throws/handles `GoogleSignInException`) or explicitly demote to advisory (INFO) — WARNING with a known FP class is weak.

**What/why:** `authenticate()` throws `GoogleSignInException` for every non-success outcome, including user cancellation (`GoogleSignInExceptionCode.canceled`). On v7, there is no null-return path — the only way to know the user dismissed the picker is to catch the exception. An unhandled `GoogleSignInException` propagates to the Flutter error handler as an unhandled async error, producing a red-screen or a silent crash depending on `FlutterError.onError`. This is the most common v7 porting mistake because v6's `signIn()` returned `null` on cancellation.

**Detection (AST):**
1. Register `addMethodInvocation`.
2. Check `node.methodName.name == 'authenticate'` AND the receiver's static type has library URI containing `package:google_sign_in`.
3. Walk up the AST to find the nearest `TryStatement`. If none exists, or if the nearest try has no `CatchClause` whose caught type is assignable from `GoogleSignInException`, report.
4. Same check for `attemptLightweightAuthentication` (see that rule's note: some exception codes are suppressed by default, but `clientConfigurationError` and `providerConfigurationError` are always thrown, so the try/catch is still required).

**Fix:** No auto-fix — the shape of the catch body is application-specific. `correctionMessage` directs to wrap in `try { } on GoogleSignInException catch (e) { }` and switch on `e.code`.

**False positives:**
- A caller that delegates to a wrapper method which itself catches `GoogleSignInException` will be flagged (the rule only sees the local scope). This is acceptable: the rule is conservative, and a `// ignore:` with a one-line justification is correct here.
- `attemptLightweightAuthentication()` suppressible codes (`canceled`, `interrupted`, `uiUnavailable`) are already swallowed when `reportAllExceptions` is false (the default). However, configuration errors ARE always thrown, so requiring a catch clause is still correct.

---

### `google_sign_in_unchecked_supports_authenticate`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** Android/iOS-only apps (never web) are still flagged, and indirect `_isWebPlatform()` helpers that call `supportsAuthenticate()` internally are invisible to AST analysis. "Report and let them ignore" is weak for WARNING — gate by platform target or demote.

**What/why:** `supportsAuthenticate()` returns `false` on platforms where the OS provides its own authentication UI (web, and potentially future platforms). Calling `authenticate()` when `supportsAuthenticate()` is false throws `UnsupportedError` at runtime — not a `GoogleSignInException`, so it bypasses any sign-in error handler. The web platform is the primary victim: web requires a rendered Google Identity Services button from `google_sign_in_web`, not a programmatic `authenticate()` call.

**Detection (AST):**
1. Register `addMethodInvocation` for `authenticate` where receiver static type library URI is `package:google_sign_in`.
2. Walk up the AST. If no ancestor `IfStatement` or conditional expression has a condition that contains a `supportsAuthenticate()` invocation on the same receiver (or on `GoogleSignIn.instance`), report.
3. Also accept a negative guard: `if (!…supportsAuthenticate()) { return/throw; } … authenticate()` — the `authenticate()` call is below the early-exit, so it IS guarded.

**Fix:** No auto-fix; the fallback path is app-specific. `correctionMessage` directs to check `GoogleSignIn.instance.supportsAuthenticate()` and, on web, use the `GoogleSignInButton` widget from `google_sign_in_web`.

**False positives:**
- Apps targeting only Android/iOS and never the web will still be flagged. This is a **Comprehensive**-tier rule (not Essential) for that reason — teams that do not ship web can suppress at the file level with justification.
- Indirect guards (e.g., `_isWebPlatform()` helper that internally calls `supportsAuthenticate()`) are not visible to AST analysis; suppress with comment.

---

### `google_sign_in_auth_token_from_authenticate`

> **VALIDATION (2026-06-11) — FIX (fix mechanics):** The fix deletes a `.accessToken` accessor + inserts an instructional comment. Deleting a property access mid-expression risks leaving invalid code (`final t = account.accessToken;` → `final t = account;`), and delete+comment is close to a no-op-with-comment. Make it report-only or design a safe transform that leaves valid Dart.

**What/why:** In v7 the authentication/authorization split means `GoogleSignInAccount` (returned by `authenticate()`) carries an `idToken` (identity) but **not** an `accessToken` for calling Google APIs. Access tokens require a separate explicit call to `account.authorizationClient.authorizeScopes(scopes)`. A developer who migrated from v6 and tries to read `.accessToken` directly on the account will get `null` at runtime with no exception — a silent data bug. The Firebase `GoogleAuthProvider.credential(idToken: …, accessToken: …)` pattern makes this especially dangerous: passing a null `accessToken` produces a credential that Firebase may accept or reject unpredictably depending on the backend configuration.

**Detection (AST):**
1. Register `addPropertyAccess` (and `addPrefixedIdentifier` for non-chained forms).
2. Check `node.propertyName.name == 'accessToken'`.
3. Verify the receiver's static type is `GoogleSignInAccount` from library URI `package:google_sign_in`.
4. Report.

**Fix (yes):** Replace `.accessToken` accessor with a comment directing the developer to call `await account.authorizationClient.authorizeScopes(['…'])` and read `.accessToken` from the returned `GoogleSignInClientAuthorization`. This IS a real code change (deletion + instructional replacement), not a TODO insert, per CLAUDE.md.

**Severity:** ERROR — this silently produces null where the developer expects a token; the downstream failure (failed API call, broken Firebase credential) may not surface immediately.

**False positives:**
- `.accessToken` on a non-`GoogleSignInAccount` type — the static-type check in step 3 prevents this.
- Code that legitimately stores a `GoogleSignInClientAuthorization` in a variable named with a type that widens to `Object` — the rule should check the declared static type, not the variable name; if the static type is not `GoogleSignInAccount`, do not flag.

---

### `google_sign_in_canceled_not_handled`

> **VALIDATION (2026-06-11) — FEASIBILITY:** Needs the class-hierarchy fact "GoogleSignInException extends Exception" (self-flagged speculative in the plan — verify against the actual API) plus catch-body branch-walking for the `canceled` code. Confirm both before implementing.

**What/why:** `GoogleSignInExceptionCode.canceled` means the user tapped away from the account picker — an expected, normal flow. If a catch block swallows all `GoogleSignInException` values uniformly (e.g., `log(e.toString()); return;`) without separately handling `canceled`, the UX typically fails silently or re-enters a broken auth state. The correct behavior is to detect `canceled` and return cleanly to the pre-sign-in UI without showing an error to the user. This is a usability correctness rule, not a crash rule.

**Detection (AST):**
1. Register `addCatchClause`.
2. Check that the caught type (or on-clause type) is `GoogleSignInException` (or a supertype that includes it — `Exception`, `Object` both count because `GoogleSignInException` extends `Exception` (speculative — verify exact class hierarchy)).
3. Inspect the catch body: walk its `SwitchStatement`s and `IfStatement`s for a branch that compares `exceptionVariable.code` (or `e.code`) to `GoogleSignInExceptionCode.canceled`.
4. If no such branch exists AND the catch body does not re-throw (or call an opaque handler), report an INFO.

**Fix:** No auto-fix. `correctionMessage` directs to add a branch: `if (e.code == GoogleSignInExceptionCode.canceled) { /* user dismissed — return to previous state */ return; }`.

**False positives:**
- Catch blocks that re-throw (`rethrow`) or pass to a centralized error handler that may internally handle `canceled` — the rule cannot see inside opaque method calls, so it would incorrectly flag. Limit detection to catch blocks that do NOT contain `rethrow` and do NOT invoke a method that itself has `GoogleSignInException` in its signature.
- INFO severity means the false-positive cost is low.

---

### `google_sign_in_authenticate_before_initialize`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** Detection is function-body-local only, so any app extracting `initialize()` into a helper is flagged. The plan accepts this at WARNING — tighten (recognize a helper-call ordering) or demote, since "suppress with a justification comment" is weak for a WARNING.

**What/why:** `GoogleSignIn.instance.initialize()` must be called and awaited exactly once before any call to `authenticate()` or `attemptLightweightAuthentication()`. Skipping or not awaiting it causes the authentication sheet not to appear, or a runtime error from the underlying SDK being in an unready state. This is the most common setup bug for developers porting from v6, where construction of `GoogleSignIn()` was synchronous and immediate.

**Detection (AST):** This rule operates at the function-body level, not cross-function — a deliberate limitation to keep false-positive rates low.
1. Register `addMethodInvocation` for `authenticate` / `attemptLightweightAuthentication` on `GoogleSignIn` from `package:google_sign_in`.
2. Collect all `AwaitExpression` ancestors (or `await`ed calls) in the same function body that target a `initialize()` call on the same receiver (or on `GoogleSignIn.instance`).
3. If no such preceding `await initialize()` exists in the function body BEFORE the flagged call site (by statement order), report.
4. Do NOT flag calls inside `.then()` callbacks, `authenticationEvents.listen()` callbacks, or any function passed as a closure — the ordering guarantee is structural in those contexts.

**Fix:** No auto-fix — where to place `await initialize()` is architectural. `correctionMessage` directs to call `await GoogleSignIn.instance.initialize()` at app startup (e.g., in `main()` before `runApp()`, or in the root widget's `initState` before the first auth call).

**False positives:**
- Apps that extract `initialize()` into a helper method — the rule only sees within one function body, so it will flag. This is acceptable at WARNING severity; teams should suppress with a justification comment explaining the initialization path.
- `attemptLightweightAuthentication()` is intended to be called as part of the startup sequence alongside `initialize()`, so the ordering requirement is real; the rule is correct to flag it.

---

### Rule summary table (pack wiring)

All five rules share the gate `google_sign_in >= 7.0.0`.

| rule | tier | severity | file |
|---|---|---|---|
| `google_sign_in_missing_exception_handler` | Recommended | WARNING | `lib/src/rules/packages/google_sign_in_rules.dart` |
| `google_sign_in_unchecked_supports_authenticate` | Comprehensive | WARNING | same |
| `google_sign_in_auth_token_from_authenticate` | Recommended | ERROR | same |
| `google_sign_in_canceled_not_handled` | Professional | INFO | same |
| `google_sign_in_authenticate_before_initialize` | Recommended | WARNING | same |

Pack generator entry: `'google_sign_in': {'google_sign_in'}` (existing or new `google_sign_in` pack, gate `>= 7.0.0`).

## Sources (v7 correctness section)

- [google_sign_in pub.dev README](https://pub.dev/packages/google_sign_in)
- [GoogleSignInExceptionCode API docs](https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignInExceptionCode.html)
- [supportsAuthenticate() API docs](https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignIn/supportsAuthenticate.html)
- [attemptLightweightAuthentication() API docs](https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignIn/attemptLightweightAuthentication.html)
- [Migration guide pre-7.0 → v7 (Adariku)](https://isaacadariku.medium.com/google-sign-in-flutter-migration-guide-pre-7-0-versions-to-v7-version-cdc9efd7f182)
- [v7 new auth flow (dev.to)](https://dev.to/_ashish_tandon_/flutter-google-sign-in-with-googlesignin-7-understanding-the-new-authentication-flow-2pbe)
- [google_sign_in web v7.2.0 (Spillecke)](https://medium.com/@thomas.spillecke/flutter-and-google-sign-in-for-web-applications-v7-2-0-a64b8e5b5a5c)

---

## Build recipe (self-contained)

The reusable steps every migration pack follows; the package-specific values are
in the Wiring section above. Extracted from the shipped `riverpod_2` and `dio_5`
packs.

1. **Rule(s) + fix.** Add detection rule(s) for the *old* API to
   `lib/src/rules/packages/<package>_rules.dart` (create the file if absent),
   extending `SaropaLintRule`. Add a `DartFix` that rewrites old → new where the
   transform is mechanical.
2. **Register.** Add `MyRule.new` to `_allRuleFactories` in
   `lib/saropa_lints.dart`; add the rule code to a tier set in `lib/src/tiers.dart`.
3. **Dependency gate.** Add to `kRulePackDependencyGates` in
   `lib/src/config/rule_packs.dart`:
   `'<package>_<major>': RulePackDependencyGate(dependency: '<package>', constraint: '>=X.0.0')`.
4. **Pack definition.** Add the gated pack id + its dependency name(s) and title in
   `tool/generate_rule_pack_registry.dart` (the gate-dep map and title map,
   alongside the `dio_5` / `riverpod_2` entries).
5. **Relocate the rule code into the gated pack.** Add to `kRelocatedRulePackCodes`
   in `tool/rule_pack_audit.dart`:
   `'<rule_code>': (fromPack: '<package>', toPack: '<package>_<major>')`. This is the
   load-bearing step — it moves the version-gated rule out of the ungated package
   pack so a project on the *old* version is never told to adopt an API that does
   not exist there.
6. **Regenerate.** `dart run tool/generate_rule_pack_registry.dart` (run twice — the
   TS writer reads the compiled registry), then `dart format`.
7. **Test.** `test/config/` — gate + ownership + merge (mirror
   `rule_packs_semver_test.dart`). `test/rules/packages/<package>_rules_test.dart` —
   detection + fix.
8. **Verify.** `dart run tool/rule_pack_audit.dart` exit 0; `dart analyze --fatal-infos` clean.

**Gate-direction — two archetypes.** The right gate direction depends on whether the
old API still compiles on the new version.

- **Post-upgrade cleanup (`>=` gate).** Old API is *deprecated but still compiles*.
  The analyzer is silent, so the lint is the only nudge. Gate on the **new** major;
  flag lingering old-API usage. Matches `dio_5`, `riverpod_2`, `share_plus_11`,
  `sensors_plus_4`, `flutter_svg_2`. Highest value — the gap the compiler does not
  already cover.
- **Pre-upgrade readiness (`<` gate).** Old API is *removed* in the new major, so on
  the new version it does not compile and `dart analyze` already errors — a `>=` pack
  would find nothing. Gate on the **old** major instead; flag current (valid) code
  that will break on the bump, as opt-in upgrade prep. Used by `google_sign_in_7`,
  `webview_flutter_4`, `connectivity_plus_6`. Medium value, and depends on a
  maintainer decision to support `<` gates (a new archetype — all shipped gates are
  `>=`).
