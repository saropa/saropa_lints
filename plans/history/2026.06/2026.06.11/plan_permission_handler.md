# Plan: new `permission_handler` lint rules

**Package:** permission_handler ^12.0.3 (Saropa Contacts). **saropa_lints coverage:** none (new file).

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `permission_handler_unchecked_permanently_denied` | correctness | `.request()` result used without a branch for `isPermanentlyDenied` / `permanentlyDenied` | report-only | WARNING | skip if result is not stored (fire-and-forget); skip if parent switch exhausts all PermissionStatus values |
> **VALIDATION (2026-06-11) — DROP (overlap):** overlaps `require_permission_permanent_denial_handling` (error_handling_rules.dart:2080). Do not implement.
| `permission_handler_request_in_build` | correctness | `.request()` or `.status` awaited directly inside an overridden `build()` method | report-only | ERROR | skip if call is inside a nested callback / closure that is merely defined in build, not executed synchronously |
| `permission_handler_status_without_request` | best-practice | `.isGranted` / `.isDenied` / `.status` checked but no `.request()` call exists anywhere in the same file | report-only | WARNING | skip test files; skip files whose purpose is clearly a status-display widget (check for `Text`/`Icon` consumers only) |
> **VALIDATION (2026-06-11) — RECONCILE:** overlaps `require_permission_status_check` (api_network_rules.dart:3078); de-conflict before build. GUARD: file-level "no .request() anywhere" is too coarse (centralized request services) — keep at INFO.
| `permission_handler_location_always_before_when_in_use` | correctness | `Permission.locationAlways.request()` called in a file that never calls `Permission.locationWhenInUse.request()` or `Permission.location.request()` | report-only | WARNING | skip if `locationWhenInUse`/`location` request is in another file in the same package (file-level check is a floor, not a ceiling) |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** same-function-body scope misses two-method split flows; keep as a floor.
| `permission_handler_deprecated_calendar` | migration | `Permission.calendar` access (any member access on the `calendar` enum value) | mechanical fix: replace with `Permission.calendarFullAccess` | WARNING | only fire on the exact `calendar` identifier resolved to `package:permission_handler_platform_interface`; do NOT match string literals |
| `permission_handler_deprecated_storage` | migration | `Permission.storage` on Android 13+ targets (compileSdkVersion ≥ 33 detected) | report-only | WARNING | skip if `compileSdkVersion` cannot be determined; note it as speculative below |
> **VALIDATION (2026-06-11) — INFEASIBLE:** gate needs compileSdkVersion from build.gradle; only AndroidManifestChecker exists (no gradle reader in lib/src/). Drop or build new infra.
| `permission_handler_should_show_rationale_ios` | correctness | `shouldShowRequestRationale` getter accessed without a platform guard (`Platform.isAndroid` / `defaultTargetPlatform == TargetPlatform.android`) | mechanical fix: wrap the access in an `if (Platform.isAndroid)` guard | WARNING | skip if the call site is already inside a `Platform.isAndroid` / `TargetPlatform.android` branch |
> **VALIDATION (2026-06-11) — DROP (overlap):** duplicate of `require_permission_rationale` (api_network_rules.dart:2989); same shouldShowRequestRationale flow. Do not implement.
| `permission_handler_batched_request_preferred` | best-practice | two or more separate `Permission.X.request()` calls in the same function body that are not inside a `[Permission.X, Permission.Y].request()` list call | report-only | INFO | skip if calls are separated by `await` + result handling (sequential is intentional); skip if only one permission is requested |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** sequential-by-design (ordered, not result-gated) calls will FP.
| `permission_handler_missing_open_app_settings` | best-practice | a `permanentlyDenied` or `isPermanentlyDenied` branch that performs no `openAppSettings()` call anywhere in the same branch | report-only | WARNING | only trigger inside an explicit `if (status.isPermanentlyDenied)` or `case permanentlyDenied:` block; skip if block calls a helper that wraps `openAppSettings` (cannot see through call) |
> **VALIDATION (2026-06-11) — DROP (overlap):** dup of `require_permission_permanent_denial_handling` (error_handling_rules.dart:2080) + `require_permission_denied_handling` (api_network_rules.dart:2555).

---

## Rule detail

### `permission_handler_unchecked_permanently_denied`

- **What/why:** `Permission.X.request()` returns a `Future<PermissionStatus>`. When the user selects "Don't ask again" (Android) or revokes from Settings (iOS), the OS returns `permanentlyDenied` — subsequent `.request()` calls silently return the same status without showing a dialog. An app that only checks `.isGranted` / `.isDenied` enters an infinite silent loop where the user taps "Allow" and nothing happens. The only recovery is `openAppSettings()`. This is the most common broken permission flow in production Flutter apps.
- **Detection (AST, type-safe):** match `MethodInvocation` where `methodName.name == 'request'` AND the resolved element's enclosing library URI starts with `package:permission_handler`. Walk the parent chain to find the `await` expression and its enclosing block. Inspect all `if`/`switch` branches that consume the awaited result. Report if no branch in the enclosing block references `isPermanentlyDenied`, `permanentlyDenied`, or calls `openAppSettings`. Library URI check: resolve the target type of the method call to `PermissionActions` from `package:permission_handler/permission_handler.dart`.
- **Fix:** report-only. The recovery UI (dialog explaining the settings detour) is app-specific; a mechanical insertion would be misleading.
- **False positives:** (a) if the result is stored in a variable and the `isPermanentlyDenied` check happens in a different function called from the same flow — a file-level walk for any `isPermanentlyDenied` reference reduces the FP rate. (b) if the developer uses a `switch` on `PermissionStatus` that exhausts all cases (compiler-enforced exhaustiveness would cover it) — check whether the switch target resolves to `PermissionStatus` and contains a `permanentlyDenied` case.

---

### `permission_handler_request_in_build`

- **What/why:** `build()` is called on every widget rebuild. Calling `.request()` (an async side-effect that shows a system dialog) synchronously in `build()` causes the permission dialog to pop up repeatedly — on scroll, on parent rebuilds, on hot-reload — breaking user experience and violating the Flutter contract that `build()` must be pure. The correct pattern is `initState()` + `WidgetsBinding.instance.addPostFrameCallback()`, or request on a user-initiated gesture.
- **Detection (AST, type-safe):** match `MethodDeclaration` where `name.lexeme == 'build'` AND the parent class overrides `Widget.build` (verify: enclosing class extends `State` or `StatelessWidget` — check `extendsClause` element library URI for `package:flutter/src/widgets/framework.dart`). Walk the method body for any `MethodInvocation` where `methodName.name == 'request'` AND the resolved element belongs to `package:permission_handler`. Only flag invocations that are direct children of the `build` body (not inside a `GestureDetector.onTap` / `onPressed` callback — check that the invocation's nearest enclosing function is the `build` method itself, not a nested `FunctionExpression`).
- **Fix:** report-only. The correct migration point (to `initState`, `addPostFrameCallback`, or a button handler) is context-dependent.
- **False positives:** a `.request()` inside a `Builder` or `LayoutBuilder` callback defined in `build()` is technically a nested closure — skip it. Check the nearest enclosing `FunctionExpression` or `FunctionDeclaration` ancestor: only fire when there is no such ancestor between the call site and the `build` method boundary.

---

### `permission_handler_status_without_request`

- **What/why:** Checking `Permission.X.isGranted` (or `.status`) without ever calling `.request()` in the same file means the app can never transition from `denied` to `granted` within that code path. This is often a forgotten call: the developer wired up the status check but not the request, and the feature silently never works after first install. This differs from `image_picker_camera_source_without_support_check` — here the concern is that the status is read but the permission can never be elevated.
- **Detection (AST, type-safe):** collect all `MethodInvocation` and `PropertyAccess` nodes in the compilation unit that resolve to `PermissionCheckShortcuts.isGranted`, `isDenied`, `isPermanentlyDenied`, `isRestricted`, `isLimited` or `PermissionActions.status` (library URI `package:permission_handler/permission_handler.dart`). Also collect all `MethodInvocation` nodes whose `methodName.name == 'request'` resolved to the same library. If the status-check set is non-empty and the request set is empty, report at the first status-check site.
- **Fix:** report-only.
- **False positives:** (a) test files — skip via `ProjectContext.isTestFile(path)`. (b) files that are pure UI display of a pre-computed status value (the request is elsewhere) — this is a file-level heuristic; mark INFO not WARNING to reduce noise. (c) files that only read `.serviceStatus` (location/bluetooth service enabled check) — `serviceStatus` is NOT the same as requesting access, but excluding it avoids conflation.

---

### `permission_handler_location_always_before_when_in_use`

- **What/why:** Android 10 (API 29) and later enforces a two-step flow: the app must hold `locationWhenInUse` (foreground) before it can request `locationAlways` (background). If `locationAlways` is requested first, the OS silently ignores the request and returns `denied` — no dialog appears, the user sees nothing, and the app cannot recover without the user navigating to Settings. This is documented in the official permission_handler FAQ and confirmed in GitHub issue #1118.
- **Detection (AST, type-safe):** within a `FunctionBody` (function or method), collect all `MethodInvocation` nodes where `methodName.name == 'request'` and the target resolves to `Permission` from `package:permission_handler`. Among those, check whether any target is `Permission.locationAlways` without a preceding (earlier in textual order within the same function body) call on `Permission.locationWhenInUse` or `Permission.location`. To resolve `Permission.locationAlways`: the target of `.request()` is a `PropertyAccess` whose `propertyName.name == 'locationAlways'` and whose target resolves to the `Permission` class element in library `package:permission_handler_platform_interface`.
- **Fix:** report-only. Inserting a `locationWhenInUse` request requires await + status check — not safe to auto-insert.
- **False positives:** if the `locationWhenInUse` request is in a different method that is known to be called first, this rule fires a FP. Scope to same function body; document the limitation explicitly in the rule's `correctionMessage`.

---

### `permission_handler_deprecated_calendar`

- **What/why:** `Permission.calendar` was deprecated in permission_handler 11.4.0 when iOS 17 introduced split calendar access levels (`writeOnly` vs `fullAccess`). The old `calendar` value now silently behaves like `calendarFullAccess`, which is the most permissive level — apps using the deprecated value request broader access than they may need. The deprecation is annotated with `@Deprecated('Use [calendarWriteOnly] and [calendarFullAccess].')` in the platform interface source.
- **Detection (AST, type-safe):** match `PrefixedIdentifier` or `PropertyAccess` where the identifier resolves to the `calendar` field on the `Permission` class element in library `package:permission_handler_platform_interface`. The `@Deprecated` annotation on the element is readable via `element.metadata`; use it as the trigger rather than matching by bare name. Alternatively, check `element.hasDeprecated` (Dart analyzer API).
- **Fix:** mechanical. Replace `Permission.calendar` with `Permission.calendarFullAccess`. This is the documented behavior-equivalent migration path. A quick-fix is appropriate because the transform is a single identifier replacement and the behavior is unchanged (the deprecated value already delegates to `calendarFullAccess` internally).
- **False positives:** any string literal `'calendar'` must not be matched. Restrict to resolved element identity only.

---

### `permission_handler_deprecated_storage`

- **What/why (speculative — verify):** `Permission.storage` (mapping to `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`) was deprecated for Android 13 (API 33+) when Google introduced granular media permissions: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`. On a `compileSdkVersion >= 33` build, requesting `Permission.storage` returns `denied` on Android 13+ devices without showing a dialog. Developers must migrate to `Permission.photos`, `Permission.videos`, or `Permission.audio` based on the media type their app accesses, or to `Permission.manageExternalStorage` for broad filesystem access (which requires Play Store approval).
- **Detection (AST, type-safe):** match `PrefixedIdentifier` / `PropertyAccess` where the resolved element is `Permission.storage` from `package:permission_handler_platform_interface`. Cross-reference `AndroidManifestUtils` or the `compileSdkVersion` field in `android/app/build.gradle` (which `ProjectContext` or a file-read utility can inspect) to gate the rule on `compileSdkVersion >= 33`. If `compileSdkVersion` cannot be determined, report at INFO level only.
- **Fix:** report-only. The replacement (`photos`, `videos`, `audio`, or `manageExternalStorage`) depends on what media type the app handles — a mechanical single-replacement would be wrong in most cases.
- **False positives:** (a) if the project's `compileSdkVersion` is below 33 the rule must not fire — gate strictly. (b) `Permission.storage` is still valid for `compileSdkVersion < 33` targets. If detection of `compileSdkVersion` is unreliable, lower to INFO with an advisory message.

---

### `permission_handler_should_show_rationale_ios`

- **What/why:** `shouldShowRequestRationale` is an Android-only API (maps to `ActivityCompat.shouldShowRequestPermissionRationale`). The permission_handler source explicitly returns `false` on all non-Android platforms without throwing. Calling it outside an Android guard produces dead code on iOS — the rationale UI is never shown, silently making the user experience worse. iOS has a different convention (show rationale before the first-ever request dialog, not after a denial).
- **Detection (AST, type-safe):** match `PropertyAccess` or `PrefixedIdentifier` where the resolved element is `PermissionActions.shouldShowRequestRationale` from `package:permission_handler/permission_handler.dart`. Walk the ancestor chain to find the nearest `IfStatement` or conditional. If none of the ancestors is an `IfStatement` whose condition resolves to a `Platform.isAndroid` comparison or a `defaultTargetPlatform == TargetPlatform.android` expression, report the access as unguarded.
- **Fix:** mechanical when the access site is an `ExpressionStatement` or simple `await` expression — wrap in `if (Platform.isAndroid) { ... }`. Where the result is consumed in a ternary or larger expression, report-only (transformation is non-trivial).
- **False positives:** if the file already imports `dart:io` and the call is already inside a platform-guarded block that the ancestor walk doesn't detect (e.g., a helper method whose name implies Android) — the ancestor walk is intentionally conservative; only suppress when an `IfStatement` condition directly contains `Platform.isAndroid` or `TargetPlatform.android`.

---

### `permission_handler_batched_request_preferred`

- **What/why:** Calling `Permission.X.request()` in N sequential `await` calls shows N separate system dialogs — one per permission. The permission_handler package provides `[Permission.X, Permission.Y, ...].request()` which batches all requests into the fewest dialogs the OS allows and returns a `Map<Permission, PermissionStatus>`. Batching is both a better user experience (fewer interruptions) and more performant (one round-trip to the platform channel). Requesting permissions sequentially when they are not logically dependent is a best-practice violation.
- **Detection (AST, type-safe):** within a single `FunctionBody`, collect all `MethodInvocation` nodes where `methodName.name == 'request'` resolves to `PermissionActions.request` from `package:permission_handler`. If two or more such calls appear in the same function body WITHOUT any intervening result-dependent `if`/`switch`/`return` between them (i.e., they are fired regardless of the previous result), report the second and subsequent calls. Distinguish from intentional sequential flows by checking for any `IfStatement` or `SwitchStatement` between the calls that uses the result of the first request.
- **Fix:** report-only. Mechanically merging two `await Permission.X.request()` calls into a single `[Permission.X, Permission.Y].request()` map requires rewriting the downstream result consumption, which is non-trivial.
- **False positives:** if the second `.request()` call is inside a branch conditioned on the first call's result (e.g., `locationAlways` only after `locationWhenInUse` is granted) it should NOT be flagged — that is intentional sequential logic. Check that no `IfStatement`/`SwitchStatement` consumes the earlier result between the two calls.

---

### `permission_handler_missing_open_app_settings`

- **What/why:** When `PermissionStatus.permanentlyDenied` is detected, `openAppSettings()` is the only mechanism that can restore permission — no dialog will appear on a future `.request()`. An app that detects `permanentlyDenied` and shows a message but never calls `openAppSettings()` leaves the user with no path to resolution. The production-grade pattern is: detect `isPermanentlyDenied` → show an explanatory dialog → call `openAppSettings()` on confirmation.
- **Detection (AST, type-safe):** match `IfStatement` whose condition is (or contains) a call/getter resolving to `FuturePermissionStatusGetters.isPermanentlyDenied` or a `SwitchStatement` case with label `permanentlyDenied` (resolving to `PermissionStatus.permanentlyDenied` from `package:permission_handler_platform_interface`). Inspect the branch body for any `MethodInvocation` whose `methodName.name == 'openAppSettings'` AND which resolves to `package:permission_handler/permission_handler.dart`. If no such call appears in the branch (or in a method directly called from the branch — one level deep via resolved element lookup), report.
- **Fix:** report-only. The placement of the `openAppSettings()` call relative to a confirmation dialog is product-specific.
- **False positives:** (a) if the branch calls a helper method that internally calls `openAppSettings()`, the one-level-deep element lookup should catch direct calls but may miss deeply wrapped helpers — document as a known limitation. (b) if the branch explicitly shows a `showDialog` or similar call — the developer may be prompting the user first before directing to Settings, which is correct behavior. Only flag when the branch contains no `openAppSettings` call AND no call to any function named `openAppSettings` (direct or via helper name ending in `AppSettings`).

---

## Not lint-able

The following concerns are real misuse patterns but are not statically detectable from the AST:

- **Not declaring permissions in AndroidManifest.xml / Info.plist:** manifest and plist validation require reading XML/plist configuration files, not Dart AST nodes. This is better addressed by a separate configuration-file lint (like `InfoPlistUtils`-backed rules elsewhere in saropa_lints) or by build-time tooling.
- **Requesting permissions at app launch with no contextual trigger:** determining whether a call site is "at app launch" versus "triggered by user intent" requires control-flow analysis that spans widget trees and navigation graphs — not statically deterministic.
- **Re-prompting after user denial (spammy UX):** detecting frequency or repetition of request calls requires runtime state; no AST signal.
- **Vague iOS usage description strings:** validating the quality of natural-language strings in Info.plist is not an AST check.
- **Users revoking permissions after grant (assumptions of permanence):** no static signal; purely runtime behavior.

---

## Implementation note

New file: `lib/src/rules/packages/permission_handler_rules.dart`

Register each rule class in `lib/saropa_lints.dart` `_allRuleFactories` (one entry per class).

Add rule codes to a tier in `lib/src/tiers.dart`:
- Correctness rules (`request_in_build`, `unchecked_permanently_denied`, `location_always_before_when_in_use`, `should_show_rationale_ios`): `recommendedOnlyRules` or `professionalOnlyRules`
- Best-practice rules (`status_without_request`, `batched_request_preferred`, `missing_open_app_settings`): `comprehensiveOnlyRules`
- Migration rules (`deprecated_calendar`, `deprecated_storage`): `recommendedOnlyRules` — these are factual API deprecations, not style preferences

Migration rules (`deprecated_calendar`, `deprecated_storage`) also belong in a version-gated pack per the recipe in `plans/plan_migration_plugin_system.md`:
- Pack id: `permission_handler_11` (calendar deprecation landed in 11.4.0)
- Pack id: `permission_handler_12` (compileSdkVersion 35 / storage guidance in 12.0.0)
- Add gates to `kRulePackDependencyGates` in `lib/src/config/rule_packs.dart`
- Add relocated codes to `kRelocatedRulePackCodes` in `tool/rule_pack_audit.dart`

Detection note on library URI: the `Permission` enum and `PermissionStatus` enum are defined in `package:permission_handler_platform_interface`, but they are re-exported through `package:permission_handler`. When resolving element library URIs from the analyzer, both URIs may appear depending on how the consumer imported the package. Guard against both:
- `package:permission_handler/permission_handler.dart`
- `package:permission_handler_platform_interface/src/permissions.dart`
- `package:permission_handler_platform_interface/permission_handler_platform_interface.dart`

Use a URI prefix check (`libraryUri.startsWith('package:permission_handler')`) rather than an exact match to handle both the main and platform-interface packages.

---

## Sources

- [permission_handler pub.dev page](https://pub.dev/packages/permission_handler)
- [permission_handler changelog](https://pub.dev/packages/permission_handler/changelog)
- [permission_handler GitHub repository](https://github.com/Baseflow/flutter-permission-handler)
- [Changes in 6.0.0 wiki (PermissionStatus.undetermined removal)](https://github.com/Baseflow/flutter-permission-handler/wiki/Changes-in-6.0.0)
- [Permission.calendar deprecation PR #1151](https://github.com/Baseflow/flutter-permission-handler/pull/1151)
- [locationAlways ordering issue #1118](https://github.com/Baseflow/flutter-permission-handler/issues/1118)
- [Android 13 storage permission migration (Sreyas IT)](https://sreyas.com/blog/permission-for-storage-in-android-13-or-higher/)
- [Handling Permissions Correctly in Flutter — production-grade guide (AppsonAir)](https://www.appsonair.com/blogs/handling-permissions-correctly-in-flutter-production-grade-guide)
- [Best Practices for Handling Permissions in Flutter (Medium — Hicham Boudanes)](https://medium.com/@hicham.boudanes/best-practices-for-handling-permissions-in-flutter-0ce2779238fe)
- [Flutter Permission Handler Not Opening App Settings (copyprogramming.com)](https://copyprogramming.com/howto/flutter-permission-handler-package-not-opening-app-settings-when-permission-is-permanently-denied)
