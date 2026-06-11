# Plan: new `local_auth` lint rules

**Package:** local_auth ^3.0.0 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**Verified API surface (3.0.1, the shipping version):**

`LocalAuthentication` methods/getters:
- `Future<bool> get canCheckBiometrics` — hardware present but may have nothing enrolled
- `Future<bool> isDeviceSupported()` — hardware present OR device PIN/passcode fallback available
- `Future<List<BiometricType>> getAvailableBiometrics()` — enrolled biometrics (not just hardware)
- `Future<bool> authenticate({required String localizedReason, Iterable<AuthMessages> authMessages = …, bool biometricOnly = false, bool sensitiveTransaction = true, bool persistAcrossBackgrounding = false})` — returns `true` = authenticated; `false` = user canceled; throws `LocalAuthException` for all other failures
- `Future<bool> stopAuthentication()` — cancels in-progress auth

`LocalAuthExceptionCode` enum (14 values, verified from source):
`authInProgress`, `uiUnavailable`, `userCanceled`, `timeout`, `systemCanceled`, `noCredentialsSet`, `noBiometricsEnrolled`, `noBiometricHardware`, `biometricHardwareTemporarilyUnavailable`, `temporaryLockout`, `biometricLockout`, `userRequestedFallback`, `deviceError`, `unknownError`

**3.0 breaking changes (verified):**
- Throws `LocalAuthException` instead of `PlatformException` — old catch clauses silently fail to fire
- `AuthenticationOptions` class removed; options promoted to direct `authenticate()` named params — `AuthenticationOptions(...)` usage is a compile error on 3.x but a lint in code gated on 2.x
- `stickyAuth` renamed to `persistAcrossBackgrounding`
- `useErrorDialogs` removed entirely — callers must build their own error UI
- `authenticateWithBiometrics()` removed (was removed in 2.0, reconfirmed absent in 3.x)
- Android min SDK 24, iOS min 13.0

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `local_auth_unchecked_result` | correctness | `authenticate()` return value discarded (not assigned / not awaited into a variable used for a branch) | no (report-only — fixing requires inserting non-trivial logic) | WARNING | only fire when the entire `await auth.authenticate(…)` expression is a statement, not an assignment |
| `local_auth_missing_capability_check` | correctness | `authenticate()` call with no reachable `canCheckBiometrics` / `isDeviceSupported()` getter read anywhere in the same file | WARNING | report-only | FP: file may import a service that centralizes the check; guard by only firing when the call is in the same expression scope as a direct `auth.authenticate()` invocation AND neither check appears at file level |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** centralized capability service → FP; keep at INFO.
| `local_auth_unhandled_exception` | correctness | `authenticate()` not inside a try/catch that catches `LocalAuthException` (or a bare-`on Object`/`catch`) | WARNING | report-only | FP: outer try block at a higher call frame cannot be statically seen — fire only on direct call sites not wrapped in any `try` in the same function body |
| `local_auth_missing_lockout_handling` | best-practice | `authenticate()` inside a try/catch that catches `LocalAuthException` but does NOT branch on `.code == LocalAuthExceptionCode.temporaryLockout` or `.biometricLockout` | INFO | report-only | FP guard: check the catch body for any reference to `temporaryLockout` or `biometricLockout` via element resolution; if absent, flag |
| `local_auth_biometric_only_sensitive` | best-practice | calls `authenticate()` without `biometricOnly: true` where the call site is inside a widget/method that by naming convention or adjacent comment signals a "secure" / "sensitive" context | INFO | mechanical fix: add `biometricOnly: true` arg | FP: named-context heuristic (see rule detail); mark speculative |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** fires on enclosing method/class NAME containing secure/payment/sensitive — naming heuristic the project distrusts; keep only if pedantic-tier + quick-fix, else drop.
| `local_auth_platform_exception_catch` | migration | a `catch` clause targeting `PlatformException` from `services.dart` is co-located with an `authenticate()` call — on 3.x the exception is `LocalAuthException`, so the `PlatformException` catch is dead | WARNING | mechanical fix: replace `on PlatformException` with `on LocalAuthException` (verify import) | FP: `PlatformException` is legitimately thrown by the platform for non-auth failures; fire only when catch is in the same try block that contains the `authenticate()` call |
> **VALIDATION (2026-06-11) — NOTE:** migration rule — symbols resolve only on local_auth <3.x; route via a `<3.0.0` pack gate (first `<`-gate archetype, awaits maintainer decision).
| `local_auth_use_error_dialogs_removed` | migration | references `AuthenticationOptions(useErrorDialogs: …)` — `useErrorDialogs` was removed in 3.0; client must provide its own error UI | ERROR | report-only (the rewrite is non-trivial: the caller must build UI) | FP: none; the symbol does not exist in 3.x, analyzer will catch compile errors on 3.x but this fires as a migration-readiness lint on 2.x codebases |
> **VALIDATION (2026-06-11) — NOTE:** migration rule — symbols resolve only on local_auth <3.x; route via a `<3.0.0` pack gate (first `<`-gate archetype, awaits maintainer decision).
| `local_auth_sticky_auth_renamed` | migration | references `AuthenticationOptions(stickyAuth: …)` or `.stickyAuth` — renamed to `persistAcrossBackgrounding` in 3.0 | WARNING | mechanical fix: replace `stickyAuth:` kwarg / property access with `persistAcrossBackgrounding:` | FP: none for the exact symbol |
> **VALIDATION (2026-06-11) — NOTE:** migration rule — symbols resolve only on local_auth <3.x; route via a `<3.0.0` pack gate (first `<`-gate archetype, awaits maintainer decision).
| `local_auth_deprecated_options_class` | migration | constructs `AuthenticationOptions(…)` — the class was removed in 3.0 and its fields promoted to direct `authenticate()` named params | WARNING | mechanical fix: inline each recognized field as a named arg; unrecognized fields: report-only | FP: none; symbol exists only in 2.x platform interface |
> **VALIDATION (2026-06-11) — NOTE:** migration rule (AuthenticationOptions) — symbols resolve only on local_auth <3.x; route via a `<3.0.0` pack gate (first `<`-gate archetype, awaits maintainer decision).

**Total: 9 rules** (3 correctness, 2 best-practice, 4 migration)

---

## Rule detail

### `local_auth_unchecked_result`

- **What/why:** `authenticate()` returns `Future<bool>`. `false` means the user canceled; `true` means authenticated. An expression-statement `await auth.authenticate(…);` throws the return value away — authentication silently "passes" even when the user tapped Cancel, because no guard blocks the subsequent action. This is a correctness bug in security-sensitive code.
- **Detection (AST, type-safe):** Register `addExpressionStatement`. If the expression is an `AwaitExpression` whose operand is a `MethodInvocation`, resolve the invoked method's enclosing class library URI to `package:local_auth/local_auth.dart` (or `package:local_auth/src/local_auth.dart`) and the method name to `authenticate`. If the `ExpressionStatement` is NOT the right-hand side of an assignment or variable declaration, flag it.
- **Fix:** report-only. The mechanical fix would require inserting an `if (result)` branch, which requires understanding the caller's intent.
- **False positives:** A rare pattern `unawaited(auth.authenticate(…))` is intentionally fire-and-forget; to guard, also skip when the expression is wrapped in a call to `unawaited`.

---

### `local_auth_missing_capability_check`

- **What/why:** Calling `authenticate()` without first confirming `isDeviceSupported()` on a device that has no PIN and no biometrics will immediately throw `LocalAuthExceptionCode.noCredentialsSet`. The recommended pattern per the official docs is to guard with `canCheckBiometrics || isDeviceSupported()` before presenting auth UI. Skipping this check produces an unhandled exception path in apps that skip the exception handler too.
- **Detection (AST, type-safe):** Register `addMethodDeclaration` and `addFunctionDeclaration`. Walk the body for `MethodInvocation` nodes. If any invocation resolves to `LocalAuthentication.authenticate` (library URI `package:local_auth`), check whether the same body (or its enclosing class body) also contains a `PropertyAccess` or `PrefixedIdentifier` that resolves to `LocalAuthentication.canCheckBiometrics` OR a `MethodInvocation` resolving to `LocalAuthentication.isDeviceSupported`. If neither is found, flag the `authenticate` call.
- **Fix:** report-only. Correcting requires inserting an async pre-check, which varies with the widget structure.
- **False positives:** Apps that centralize capability checking in a service class will have the check invisible at this call site. To reduce FP rate, lower to INFO or scope to files that also instantiate `LocalAuthentication` directly. The rule is deliberately conservative — it fires only when the entire file contains no reference to either check.

---

### `local_auth_unhandled_exception`

- **What/why:** `authenticate()` throws `LocalAuthException` for 14 distinct failure codes (lockout, no hardware, canceled by system, etc.). A call not wrapped in `try/catch` will propagate uncaught, crashing the app. `false` return only covers user-cancel on Android; all other failure paths are exceptions on both platforms.
- **Detection (AST, type-safe):** Register `addMethodInvocation`. For each invocation resolving to `LocalAuthentication.authenticate` (library URI check), walk up the AST to find an enclosing `TryStatement`. If none is found within the enclosing function body, flag the node. If a `TryStatement` is found, verify at least one `CatchClause` covers `LocalAuthException` (element type check, resolved through `package:local_auth`) or catches `Object`/`Exception`. If none do, also flag.
- **Fix:** report-only. Inserting a try/catch requires knowing which codes the caller wants to surface.
- **False positives:** Propagation via `rethrow` in a wrapper function is invisible; accept this as an acceptable FP rate rather than doing cross-function analysis.

---

### `local_auth_missing_lockout_handling`

- **What/why:** `temporaryLockout` and `biometricLockout` require distinct UI treatment: the user must wait or use an alternative credential. Apps that catch `LocalAuthException` generically but ignore these codes will silently swallow lockout events, leaving users stuck on an auth screen with no explanation. Both codes are among the most common in production bug reports.
- **Detection (AST, type-safe):** Register `addTryStatement`. For each `TryStatement` whose body contains a call resolving to `LocalAuthentication.authenticate`, examine each `CatchClause`. If any clause catches `LocalAuthException` (verified by element type resolution), inspect its body for a reference to `LocalAuthExceptionCode.temporaryLockout` or `LocalAuthExceptionCode.biometricLockout` (as `PrefixedIdentifier` or `PropertyAccess` resolving to the enum value in `package:local_auth`). If neither is referenced, flag the catch clause.
- **Fix:** report-only.
- **False positives:** Apps that treat all `LocalAuthException` cases identically (e.g., show a generic "auth failed" dialog) are not buggy — they just provide coarser UX. Severity INFO reflects this; it is a best-practice nudge, not a correctness violation.

---

### `local_auth_biometric_only_sensitive`

- **What/why:** `biometricOnly: false` (the default) allows fallback to PIN/pattern, which in high-security flows (payment confirmation, PII access) defeats the purpose of requiring a biometric. The parameter is easy to forget because `false` is the default and nothing in the type system requires it.
- **Detection (AST, type-safe):** Register `addMethodInvocation`. For calls resolving to `LocalAuthentication.authenticate`, check named arguments for `biometricOnly`. If absent (default `false`), AND the call site is inside a method or class that contains any of the following in its name (resolved via enclosing class/method element name, NOT bare string matching): `secure`, `payment`, `sensitive`, `confirm`, `verify`, `biometric` — flag INFO. This is a **speculative** heuristic that relies on naming conventions.
- **Fix:** mechanical — insert `biometricOnly: true` as a named argument.
- **False positives:** HIGH — naming heuristic is inherently fragile. Mitigate by: (a) keeping severity at INFO, (b) documenting the naming heuristic in the correctionMessage so users understand why it fired, (c) providing the quick fix so the cost of either accepting or ignoring the lint is low. Consider whether this rule belongs in the `pedantic` tier.

---

### `local_auth_platform_exception_catch`

- **What/why:** In `local_auth` 2.x, `authenticate()` threw `PlatformException` on failure. In 3.0, it throws `LocalAuthException`. A catch clause `on PlatformException` co-located with an `authenticate()` call is now dead code — the exception will never reach it, so failures silently bypass the error handler. This is a migration correctness bug.
- **Detection (AST, type-safe):** Register `addTryStatement`. For each try body containing a `MethodInvocation` resolving to `LocalAuthentication.authenticate`, scan catch clauses for one whose exception type resolves to `PlatformException` from `package:flutter/services.dart` (library URI `dart:ui` or `package:flutter/src/services/platform_channel.dart` — verify the actual URI from the element). If found, flag that catch clause.
- **Fix:** mechanical — replace `on PlatformException` with `on LocalAuthException` (also insert the import `package:local_auth/local_auth.dart` if not present). This is safe because `LocalAuthException` is the 3.x replacement. The fix should be gated on the pubspec dependency version being `>=3.0.0`.
- **False positives:** The same try block may call other APIs that do throw `PlatformException`. Guard by checking that the only `async`/`await` calls in the try body that originate from `package:local_auth` are the authenticate call; if other plugin calls are present, lower to INFO with a note that the `PlatformException` clause may be needed for those.

---

### `local_auth_use_error_dialogs_removed`

- **What/why:** `AuthenticationOptions.useErrorDialogs` was removed in 3.0. In 2.x, setting it to `false` suppressed the platform's built-in error dialog, requiring the app to handle error cases itself. In 3.0, the field does not exist: `AuthenticationOptions` itself is gone, and error dialog behavior is entirely client-controlled. Any 2.x code using this field will fail to compile under 3.0 without remediation, and the remediation is non-trivial (the app must implement its own error UI). This lint flags the pattern so developers know what manual work is needed during migration.
- **Detection (AST, type-safe):** Register `addInstanceCreationExpression`. For each constructor call that resolves to `AuthenticationOptions` (library URI `package:local_auth_platform_interface/local_auth_platform_interface.dart`), check named arguments for `useErrorDialogs`. If present, flag with a correctionMessage explaining that the field was removed, the plugin no longer shows built-in dialogs, and error UI must be built by the caller.
- **Fix:** report-only. The replacement is a UI architecture decision; no mechanical rewrite exists.
- **False positives:** none — the symbol is absent in 3.x; fires only on 2.x consumers.

---

### `local_auth_sticky_auth_renamed`

- **What/why:** `AuthenticationOptions.stickyAuth` was renamed to `persistAcrossBackgrounding` in 3.0. `AuthenticationOptions` as a class was also removed — `persistAcrossBackgrounding` is now a direct named parameter on `authenticate()`. Code using `stickyAuth: true` will not compile on 3.x. The rename is a one-for-one substitution with no semantic change.
- **Detection (AST, type-safe):** Register `addInstanceCreationExpression`. For constructor calls resolving to `AuthenticationOptions`, check named arguments for `stickyAuth`. Also register `addPropertyAccess` / `addPrefixedIdentifier` for references to the `stickyAuth` property on a receiver whose static type resolves to `AuthenticationOptions` from `package:local_auth_platform_interface`.
- **Fix:** mechanical — replace named arg `stickyAuth:` with `persistAcrossBackgrounding:`. If the parent is an `AuthenticationOptions` constructor, also rewrite the call to inline the arg into `authenticate(persistAcrossBackgrounding: …)` (the broader `local_auth_deprecated_options_class` rule covers the full class removal).
- **False positives:** none for the exact symbol name.

---

### `local_auth_deprecated_options_class`

- **What/why:** The `AuthenticationOptions` class was removed entirely in 3.0. Its four fields (`biometricOnly`, `sensitiveTransaction`, `stickyAuth`/`persistAcrossBackgrounding`, `useErrorDialogs`) were either promoted as direct named params on `authenticate()`, renamed, or dropped. Any instantiation of `AuthenticationOptions(…)` passed to `authenticate(options: …)` is a compile error in 3.x. This rule flags the pattern as a migration warning.
- **Detection (AST, type-safe):** Register `addInstanceCreationExpression`. Flag any call whose constructor element resolves to `AuthenticationOptions` from `package:local_auth_platform_interface/local_auth_platform_interface.dart`. Also register `addNamedExpression` for `options:` arguments on `authenticate()` calls (in 2.x the signature had `options: AuthenticationOptions`).
- **Fix:** partial mechanical. For each known field:
  - `biometricOnly: v` → promote to `authenticate(…, biometricOnly: v)`
  - `sensitiveTransaction: v` → promote to `authenticate(…, sensitiveTransaction: v)`
  - `stickyAuth: v` → promote as `persistAcrossBackgrounding: v`
  - `useErrorDialogs: v` → report-only with message (no direct replacement)
  If all fields are mechanically mappable, the fix can remove the `AuthenticationOptions` wrapper and inline the params. If `useErrorDialogs` is present, a partial fix inlines the others and leaves a diagnostic on the `useErrorDialogs` field.
- **False positives:** none — class exists only in 2.x; on 3.x this is already a compile error.

---

## Implementation note

New file: `lib/src/rules/packages/local_auth_rules.dart`

Register all 9 rule classes in `lib/saropa_lints.dart` `_allRuleFactories` (step 2 in the Rule Implementation Checklist).

**Tier assignment** (`lib/src/tiers.dart`):
- Correctness rules (`local_auth_unchecked_result`, `local_auth_unhandled_exception`) → `recommendedOnlyRules`
- `local_auth_missing_capability_check` → `recommendedOnlyRules`
- Best-practice rules (`local_auth_missing_lockout_handling`) → `professionalOnlyRules`
- `local_auth_biometric_only_sensitive` → `pedanticOnlyRules` (high FP heuristic)
- Migration rules (`local_auth_platform_exception_catch`, `local_auth_use_error_dialogs_removed`, `local_auth_sticky_auth_renamed`, `local_auth_deprecated_options_class`) → version-gated migration pack

**Migration pack wiring** (recipe from `plans/plan_migration_plugin_system.md`):
- Pack name: `local_auth_3`
- Gate: `RulePackDependencyGate(dependency: 'local_auth', constraint: '<3.0.0')` — pre-upgrade readiness gate
- Add to `kRulePackDependencyGates` and `kRelocatedRulePackCodes`
- The 4 migration rules belong in this pack; the 5 correctness/best-practice rules belong in the base rules file (no version gate needed — they apply to 3.x correct usage)

**Library URI to verify at detection time:**
- `LocalAuthentication` class: `package:local_auth/local_auth.dart`
- `AuthenticationOptions`: `package:local_auth_platform_interface/local_auth_platform_interface.dart`
- `LocalAuthExceptionCode`: `package:local_auth_platform_interface/local_auth_platform_interface.dart`
- `PlatformException`: element resolves to `package:flutter/src/services/platform_channel.dart` (use `element.library?.identifier` and check for `flutter/services`)

**Test fixtures:** `example/lib/local_auth_example.dart` (add to `analysis_options.yaml` exclude list as `example/lib/local_auth_example.dart` is already under the excluded `example/**` glob — no new entry needed).

**OWASP mapping:** `local_auth_unchecked_result`, `local_auth_unhandled_exception`, `local_auth_missing_capability_check` → M2:Insecure Authentication (OWASP Mobile Top 10).

---

## Sources

- [local_auth on pub.dev](https://pub.dev/packages/local_auth)
- [local_auth changelog](https://pub.dev/packages/local_auth/changelog)
- [local_auth API docs](https://pub.dev/documentation/local_auth/latest/)
- [LocalAuthentication class source (GitHub)](https://raw.githubusercontent.com/flutter/packages/main/packages/local_auth/local_auth/lib/src/local_auth.dart)
- [local_auth_platform_interface types/auth_exception.dart (GitHub)](https://raw.githubusercontent.com/flutter/packages/main/packages/local_auth/local_auth_platform_interface/lib/types/auth_exception.dart)
- [local_auth_platform_interface types/auth_options.dart (GitHub)](https://raw.githubusercontent.com/flutter/packages/main/packages/local_auth/local_auth_platform_interface/lib/types/auth_options.dart)
- [isDeviceSupported() behavior issue #148751](https://github.com/flutter/flutter/issues/148751)
- [getAvailableBiometrics returns empty on some devices #117309](https://github.com/flutter/flutter/issues/117309)
