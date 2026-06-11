# Plan: new `in_app_review` lint rules

**Package:** in_app_review ^2.0.11 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**Verified API surface (2.0.12, the current version — source read from britannio/in_app_review):**

`InAppReview` — singleton accessed via `InAppReview.instance` (static final field; private constructor `InAppReview._()`). Import: `package:in_app_review/in_app_review.dart`.

Methods:
- `Future<bool> isAvailable()` — checks if the current device/platform can show the native review dialog (requires Android 5+ with Play Store, iOS 10.3+, macOS 10.14+). NOT available on Windows.
- `Future<void> requestReview()` — asks the OS to show the review dialog. The OS silently ignores calls that exceed the quota. No return value signals whether the dialog actually appeared. Not supported on Windows.
- `Future<void> openStoreListing({String? appStoreId, String? microsoftStoreId})` — opens the store page unconditionally; `appStoreId` required on iOS/macOS, `microsoftStoreId` required on Windows. Supported on all platforms.

**Platform quotas (verified from official docs + package README):**
- **Apple (iOS/macOS):** OS hard-caps at **3 prompts per app per 365-day period**. Calls beyond the cap are silently discarded — no error, no callback. Users can also disable review prompts entirely in App Store settings.
- **Google Play (Android):** time-bound opaque quota (Google does not publish the exact number; third-party sources cite ~3–5 per year per user). `launchReviewFlow()` beyond the cap silently returns without showing the dialog. The specific value is subject to change without notice.
- **Both platforms:** no API exists to query remaining quota or confirm the dialog was shown.

**Documented footguns (verified from official docs + package README + GitHub issues):**
1. Calling `requestReview()` without first `await`-ing `isAvailable()` — succeeds on iOS even when conditions aren't met (it's advisory), but is explicitly listed in the README as the required pattern.
2. Calling `requestReview()` directly inside a button `onPressed`/`onTap` callback — the package README and both Apple HIG and Google Play guidelines explicitly prohibit this. The quota is wasted if already consumed, and the user sees nothing with no explanation.
3. Calling `requestReview()` in `initState` / inside an `initState`-like lifecycle method — prompting on every launch burns quota immediately without a positive engagement signal.
4. Calling `openStoreListing()` without providing `appStoreId` on iOS — the parameter is typed `String?` (nullable) but at runtime this causes an assertion failure / silent no-op depending on platform implementation.
5. Assuming the dialog appeared (no success signal exists) and then branching on "user reviewed" state — there is no API to distinguish "dialog shown and user submitted review" from "quota exceeded / OS suppressed".
6. Not providing an `openStoreListing()`-based fallback for an explicit "rate this app" button — when the quota is exhausted the `requestReview()` call silently no-ops, leaving the user with a broken tap and no feedback.

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `in_app_review_missing_availability_check` | correctness | `requestReview()` called with no `isAvailable()` call in the same function body | no | WARNING | only fire when no `isAvailable` identifier appears anywhere in the enclosing function body |
| `in_app_review_button_callback_request` | best-practice | `requestReview()` call whose direct enclosing closure is a button callback argument (`onPressed`, `onTap`, `onSubmitted`, `onChanged` named arg) | no | WARNING | only fire on the `requestReview` call when the named-arg wrapping the closure is one of the canonical Flutter/Material callback names |
| `in_app_review_request_in_init_state` | best-practice | `requestReview()` called inside `initState()` or any override of `initState` | no | WARNING | fire only when the enclosing method declaration name is exactly `initState` and its enclosing class mixes-in/extends `State` |
| `in_app_review_missing_store_listing_fallback` | best-practice | an explicit review-request button (`onPressed`/`onTap`) calls `requestReview()` but the same widget/class has no `openStoreListing()` call anywhere | no | INFO | fire only when `requestReview` appears in a button callback and no `openStoreListing` identifier is reachable in the same class body; lower severity because the fallback is a UX improvement, not a correctness bug |
| `in_app_review_ios_store_listing_missing_app_id` | correctness | `openStoreListing()` called with no `appStoreId` argument (omitted or explicitly `null`) in a Flutter project that has iOS as a target platform | no | WARNING | fire only when the call omits `appStoreId` entirely OR passes `appStoreId: null`; skip when `ProjectContext.isFlutterProject` is false or when no iOS platform files are present (speculative — verify via `ProjectContext`) |

**Total: 5 rules** (2 correctness, 3 best-practice)

---

## Rule detail

### `in_app_review_missing_availability_check`

> **VALIDATION (2026-06-11) — FIX (type-safe) / GUARD:** the guard uses a source-text substring scan for `isAvailable` — violates the project's "type-safe AST, never bare-name" mandate. Rework to resolve `isAvailable` to the package element. Also blind to parent-widget gating.

- **What/why:** The package README and the `requestReview()` doc comment both state: "It's recommended to first check if the device supports this feature via [isAvailable]." Without the check the call silently fails on Windows (unsupported platform), on Android devices without the Play Store, or on iOS before 10.3. The recommended pattern is `if (await inAppReview.isAvailable()) { inAppReview.requestReview(); }`. Omitting the check wastes the quota on unsupported devices and produces a confusing no-op.
- **Detection (AST, type-safe):** Register `addMethodInvocation`. For each `MethodInvocation` node:
  1. Confirm the file imports `package:in_app_review/` via `fileImportsPackage(node, {'package:in_app_review/'})` — never bare-name match.
  2. Resolve the invocation's static element; confirm the enclosing class library URI contains `package:in_app_review` and the method name is `requestReview`.
  3. Walk up the AST to find the enclosing `FunctionBody` (the nearest `FunctionBody` ancestor).
  4. Convert the function body to source and check whether the string `isAvailable` appears anywhere in it (word-boundary safe: the method name is unique in this package).
  5. If `isAvailable` is absent, flag the `requestReview` call node.
- **Fix:** report-only. The fix requires inserting an async guard with its own null-handling path; that is caller-intent logic that cannot be mechanically generated.
- **False positives:** Apps that call `isAvailable()` inside a helper method called before `requestReview()` at a higher frame will trigger a FP because the check is outside the local function body. This is an acceptable rate for WARNING severity. The correctionMessage should note this pattern so teams can suppress with a verified `// ignore:` plus a comment explaining the centralized check.

---

### `in_app_review_button_callback_request`

- **What/why:** The package README explicitly states: "Do NOT trigger requestReview() via a button in your app as it will only work when the quota enforced by the underlying API has not been exceeded." Both Apple's HIG and Google Play guidelines prohibit attaching `requestReview()` to a call-to-action element. When the quota is exhausted the user taps "rate this app" and nothing happens — no dialog, no error, no feedback. The correct pattern for an explicit button is `openStoreListing()`, which has no quota restriction.
- **Detection (AST, type-safe):** Register `addMethodInvocation`. For each `MethodInvocation` resolving to `InAppReview.requestReview` (library URI `package:in_app_review`, verified via `fileImportsPackage`):
  1. Walk up the AST looking for the nearest `FunctionExpression` ancestor (the closure/lambda).
  2. If found, check the `FunctionExpression`'s parent:
     - If the parent is a `NamedExpression`, check whether the name (`.name.label.name`) is one of the canonical Flutter callback names: `onPressed`, `onTap`, `onLongPress`, `onDoubleTap`, `onSubmitted`, `onEditingComplete`. The set is exhaustive for Material/Cupertino button callbacks — do not expand it speculatively.
     - If the parent is a `NamedExpression` whose enclosing `ArgumentList` parent is a constructor call or method call named `GestureDetector`, `InkWell`, or `TextButton` — also flag (belt-and-suspenders for non-named-callback wrappers). (speculative — verify that GestureDetector uses `onTap:` named arg, which it does; the named-arg check above covers this already.)
  3. Flag the `requestReview()` invocation node.
- **Fix:** report-only. Replacing with `openStoreListing()` requires knowing `appStoreId`, which is caller-context. Do NOT offer a TODO-insert fix.
- **False positives:** Low. The check is scoped to the exact named callback argument names used by the Flutter framework. Custom callback parameters with matching names (e.g., `onPressed` in a bespoke widget) could trigger; this is an acceptable FP rate at WARNING severity.

---

### `in_app_review_request_in_init_state`

- **What/why:** Calling `requestReview()` from `initState()` fires the review prompt every time the widget is first mounted. On cold launch this burns quota immediately, before the user has engaged with the app — violating both Apple HIG ("don't prompt on first run") and Google Play guidelines ("after the user has experienced enough of your app to provide useful feedback"). The quota is silently consumed; the user may see the prompt once and then never again for a year, triggered at the worst possible moment.
- **Detection (AST, type-safe):** Register `addMethodInvocation`. For each `MethodInvocation` resolving to `InAppReview.requestReview` (library URI check via `fileImportsPackage`):
  1. Walk up the AST to find the enclosing `MethodDeclaration`.
  2. If the `MethodDeclaration.name.lexeme` is `initState`, check whether the enclosing `ClassDeclaration` extends or mixes in a type whose name is `State` (verify via the element's supertype chain — do not bare-string-match the class name `State`; resolve the element's supertype library URI to `package:flutter/src/widgets/framework.dart` or `dart:ui`).
  3. If both conditions hold, flag the `requestReview()` call.
- **Fix:** report-only. The fix is to move the call to a post-engagement trigger point, which is product logic, not mechanical code.
- **False positives:** Low. The `initState` method name is a well-known Flutter lifecycle override. The only realistic FP is a non-Flutter class that happens to have a method named `initState`; the supertype check eliminates this.

---

### `in_app_review_missing_store_listing_fallback`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** class-scoped, blind to service-helper fallbacks; INFO mitigates.

- **What/why:** When a developer places `requestReview()` inside a button callback (the anti-pattern flagged by `in_app_review_button_callback_request`), the recommended remedy is to replace it with `openStoreListing()` for the explicit "rate us" button. A broader best-practice: any widget/class that contains an explicit review-request button AND uses `requestReview()` without also providing an `openStoreListing()` escape hatch gives users no way to actually leave a review once the quota is consumed. `openStoreListing()` has no quota and reliably reaches the store review form.
- **Detection (AST, type-safe):** Register `addClassDeclaration`. For each class body:
  1. Confirm the file imports `package:in_app_review/` (via `fileImportsPackage`).
  2. Walk all descendant `MethodInvocation` nodes; check if any resolves to `InAppReview.requestReview`.
  3. If found, also walk all descendant `MethodInvocation` nodes for `InAppReview.openStoreListing`.
  4. If `requestReview` is present but `openStoreListing` is absent, check whether any descendant `NamedExpression` argument has a callback name from the set `{onPressed, onTap, onLongPress, onDoubleTap}` — confirming the widget exposes at least one interactive control. If confirmed, flag the class declaration.
- **Fix:** report-only. The remediation (adding a fallback path) is UI architecture; no mechanical insert is safe.
- **False positives:** A class that calls `requestReview()` only at a post-milestone moment (not tied to a button) does not need an `openStoreListing()` sibling. The step 4 button-callback guard reduces this. Classes that call `openStoreListing()` via a service/helper method (not directly in the class body) will produce a FP — accept this at INFO severity. Developers can suppress with a verified `// ignore:` plus a comment pointing to the service.

---

### `in_app_review_ios_store_listing_missing_app_id`

> **VALIDATION (2026-06-11) — FEASIBILITY:** iOS-target detection is self-flagged speculative; pin the concrete API or use `InfoPlistChecker.forFile` (info_plist_utils.dart) as the iOS-presence signal before building.

- **What/why:** `openStoreListing()` has `appStoreId` typed as `String?`. On iOS and macOS the parameter is **required at runtime** — the platform implementation will fail or silently no-op without it (the Play Store on Android auto-resolves the app ID from the manifest; iOS has no equivalent). Passing `null` or omitting the argument produces a runtime defect that is invisible at compile time because the parameter is nullable. The App Store ID is a 9–10 digit numeric string found in App Store Connect under General → App Information → Apple ID.
- **Detection (AST, type-safe):**
  1. Confirm the file imports `package:in_app_review/` via `fileImportsPackage`.
  2. Register `addMethodInvocation`. For each invocation resolving to `InAppReview.openStoreListing`:
     a. Check the named arguments for `appStoreId`. If the argument is absent OR is a `NullLiteral`, flag the call.
  3. FP guard: only fire when `ProjectContext.of(context).isFlutterProject` is true (the method exists in `ProjectContext`) and there is evidence the project targets iOS — check for `ios/` directory presence via `ProjectContext` or import graph. (speculative — verify the exact `ProjectContext` API for platform detection; fall back to checking whether `platform: ios` appears in any pubspec dependency if direct detection is unavailable.)
- **Fix:** report-only. The correct `appStoreId` value is known only to the app developer (it is an App Store Connect configuration value, not derivable from code).
- **False positives:** Android-only apps that call `openStoreListing()` without `appStoreId` are not broken. The `ProjectContext` iOS guard eliminates this class of FP. If `ProjectContext` platform detection is not available, lower to INFO and note the Android-only FP class in the correctionMessage.

---

## Implementation note

New file: `lib/src/rules/packages/in_app_review_rules.dart`

Add to `PackageImports` in `lib/src/import_utils.dart`:
```dart
/// in_app_review package imports.
static const Set<String> inAppReview = {'package:in_app_review/'};
```

Register all 5 rule classes in `lib/saropa_lints.dart` — add to `_allRuleFactories`:
```dart
InAppReviewMissingAvailabilityCheckRule.new,
InAppReviewButtonCallbackRequestRule.new,
InAppReviewRequestInInitStateRule.new,
InAppReviewMissingStoreListingFallbackRule.new,
InAppReviewIosStoreListingMissingAppIdRule.new,
```

Add to tier in `lib/src/tiers.dart` — all 5 belong in `comprehensiveOnlyRules` (package-specific, best-practice / correctness, not universally applicable):
```dart
'in_app_review_missing_availability_check',
'in_app_review_button_callback_request',
'in_app_review_request_in_init_state',
'in_app_review_missing_store_listing_fallback',
'in_app_review_ios_store_listing_missing_app_id',
```

Document all 5 entries in `ROADMAP.md` under a new `### in_app_review` subsection.

---

## Sources

- [in_app_review pub.dev page](https://pub.dev/packages/in_app_review) — package README, API, warnings
- [in_app_review Dart API docs](https://pub.dev/documentation/in_app_review/latest/) — method signatures, platform matrix
- [britannio/in_app_review GitHub source](https://github.com/britannio/in_app_review) — `InAppReview` class source, exact method signatures, singleton pattern
- [Apple: Requesting App Store reviews](https://developer.apple.com/documentation/StoreKit/requesting-app-store-reviews) — official guidance on when NOT to call, 3-per-year quota, silent discard
- [Apple: RequestReviewAction](https://developer.apple.com/documentation/storekit/requestreviewaction) — SwiftUI API reference (quota confirmed)
- [Google: Google Play In-App Reviews API](https://developer.android.com/guide/playcore/in-app-review) — quota guidance, "do not use a button" rule, silent discard on quota exceeded
- [Code With Andrea: Flutter in-app review prompt](https://codewithandrea.com/articles/flutter-in-app-review-prompt/) — FP-reduction patterns, `isAvailable` guard necessity, engagement-threshold guidance

---

## Finish Report (2026-06-11)

**Scope:** (A) Dart lint rules. All 5 proposed rules implemented; both validation
callouts resolved.

### Validation fixes applied

- `in_app_review_missing_availability_check` — reworked from the planned
  **source-substring** scan to **element-based** detection: it collects
  `MethodInvocation`s in the enclosing member and looks for an `isAvailable()`
  call whose receiver resolves (static type) to `InAppReview`. No bare-name or
  `toSource().contains` match.
- `in_app_review_ios_store_listing_missing_app_id` — the planned speculative
  iOS-target detection is replaced with the concrete probe `geolocator_rules`
  already uses: `ProjectContext.getProjectInfo(...).isFlutterProject` +
  `Directory('$root/ios'|'$root/macos').existsSync()`. No INFO downgrade needed —
  the Apple-only FP class is eliminated, so the rule ships at WARNING.

### Delivered

| Rule | Severity | Detection |
|---|---|---|
| `in_app_review_missing_availability_check` | WARNING | `requestReview()` on a resolved `InAppReview` receiver with no `isAvailable()` call in the enclosing member. |
| `in_app_review_button_callback_request` | WARNING | `requestReview()` whose nearest enclosing `FunctionExpression` is a `NamedExpression` callback (`onPressed`/`onTap`/…). |
| `in_app_review_request_in_init_state` | WARNING | `requestReview()` inside a method named `initState` whose class's `allSupertypes` include `State`. |
| `in_app_review_missing_store_listing_fallback` | INFO | class with a button-bound `requestReview()` and no `openStoreListing()` anywhere. |
| `in_app_review_ios_store_listing_missing_app_id` | WARNING | `openStoreListing()` with `appStoreId` omitted/`null` on an iOS/macOS-targeting project. |

All use `RuleType.bug` (4) / `RuleType.codeSmell` (the INFO fallback rule), keyed
by `fileImportsPackage(PackageImports.inAppReview)` and resolved receiver type
`InAppReview` — never bare-name. `RuleType.correctness` from the plan does not
exist; corrected. Comprehensive tier.

### Files

- NEW `lib/src/rules/packages/in_app_review_rules.dart` (5 rules).
- `lib/src/import_utils.dart` — `PackageImports.inAppReview`.
- `lib/src/rules/all_rules.dart` — export.
- `lib/saropa_lints.dart` — 5 factories.
- `lib/src/tiers.dart` — 5 names in `comprehensiveOnlyRules`; new `inAppReviewPackageRules`; `packageRuleSets` + `allPackages` entries.
- NEW `test/rules/packages/in_app_review_rules_test.dart` (10 tests pass).
- NEW `example_packages/lib/in_app_review/*_fixture.dart` (5 fixtures, BAD+GOOD).
- `CHANGELOG.md` — extended the `[Unreleased]` overview + Added bullet.

### Verification

- `dart analyze --fatal-infos` → No issues found.
- `dart test …/in_app_review_rules_test.dart` → 10/10. Integrity (registration) pass.

### Not yet verified

- Positive scan-firing: all 5 rules key on the resolved `InAppReview` type, so
  (like quick_actions' init-contract rules) they fire only in a project that
  actually depends on `in_app_review`. Logic verified by review; not positively
  triggered in a local mock (the mock type name collides with the package import
  the file-gate needs). No fix-application test (rules are report-only).
