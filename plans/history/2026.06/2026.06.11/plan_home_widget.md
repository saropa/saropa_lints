# Plan: new `home_widget` lint rules

**Package:** home_widget 0.9.1 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**API baseline (v0.9.x, verified against pub.dev API docs + official docs site + codelab):**

- `HomeWidget.setAppGroupId(String groupId) → Future<bool?>` — Required on iOS to establish the App Group shared container used by `saveWidgetData`/`getWidgetData`. Must be called before any data read/write; without it, iOS widget data sharing silently fails.
- `HomeWidget.saveWidgetData<T>(String id, T? data, {bool deleteFile, String? appGroupId}) → Future<bool?>` — persists a key-value pair to the shared widget storage. Does **not** refresh the on-screen widget; `updateWidget` must be called separately.
- `HomeWidget.updateWidget({String? name, String? androidName, String? iOSName, String? qualifiedAndroidName}) → Future<bool?>` — signals the OS to re-render the home screen widget. Android resolves: `qualifiedAndroidName` → `<packageName>.androidName` → `<packageName>.name`. iOS resolves: `iOSName` → `name`. All params optional; if all are null, the update silently targets no widget.
- `HomeWidget.getWidgetData<T>(String id, {T? defaultValue, String? appGroupId}) → Future<T?>` — retrieves a previously stored value. Generic type `T` must match the type used when saving; a mismatch causes a silent cast failure or null return.
- `HomeWidget.registerInteractivityCallback(FutureOr<void> Function(Uri?) callback) → Future<bool?>` — registers the Dart callback invoked when a widget view is tapped. The callback **must** be a top-level or static function annotated `@pragma('vm:entry-point')`; without the annotation the Dart AOT compiler tree-shakes the function and widget interaction silently does nothing in release builds.
- `HomeWidget.registerBackgroundCallback(FutureOr<void> Function(Uri?) callback) → Future<bool?>` — older API (still present in 0.9.x alongside `registerInteractivityCallback`); same `@pragma` requirement applies.
- `HomeWidget.widgetClicked` (Stream<Uri?>) — stream of tap events when the app is already in the foreground/background.
- `HomeWidget.initiallyLaunchedFromHomeWidget() → Future<Uri?>` — checks whether the app was cold-started by a widget tap.
- `HomeWidget.renderFlutterWidget(Widget widget, {required String key, Size logicalSize, double? pixelRatio, String? appGroupId}) → Future<String>` — renders a Flutter widget to a PNG and saves it in the App Group container; the returned path is passed to `saveWidgetData` so the native widget can load it.

**Primary library URI:** `package:home_widget/home_widget.dart`

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `home_widget_callback_missing_pragma` | correctness | function passed to `registerInteractivityCallback` / `registerBackgroundCallback` lacks `@pragma('vm:entry-point')` | yes — insert annotation | WARNING | only when the argument is a direct function reference or tear-off pointing to a resolvable declaration; skip closures/lambdas |
| `home_widget_callback_not_top_level` | correctness | function passed to `registerInteractivityCallback` / `registerBackgroundCallback` is a local function or instance method (not top-level or static) | report-only | WARNING | only when the argument's referent element is a `LocalFunctionElement` or non-static `MethodElement` |
| `home_widget_save_without_update` | correctness | `saveWidgetData` call in a function body with no subsequent `updateWidget` call in the same body | report-only | WARNING | single `FunctionBody` scope; skip if `updateWidget` appears anywhere after the `saveWidgetData` call in the same body |
| `home_widget_update_no_name` | correctness | `updateWidget()` invoked with all name parameters null/absent | report-only | WARNING | literal call-site check; skip when any of `name`, `androidName`, `iOSName`, or `qualifiedAndroidName` is provided |
| `home_widget_ios_missing_app_group` | correctness | `saveWidgetData` or `getWidgetData` called at class scope with no `setAppGroupId` call visible in the same class | report-only | WARNING | class-scoped; skip if `setAppGroupId` appears in any method of the same class or the per-call `appGroupId:` named argument is provided |
| `home_widget_widget_clicked_without_initial_launch` | correctness | `widgetClicked` stream is listened to without a paired `initiallyLaunchedFromHomeWidget()` call in the same class | report-only | INFO | class-scoped; misses delegation to mixins/base-classes (documented) |

---

## Rule detail

### `home_widget_callback_missing_pragma`

> **VALIDATION (2026-06-11) — FEASIBILITY (fix):** the quick fix must edit the function DECLARATION file (cross-file), not the call-site builder in the standard template; use element.source targeting.

- **What/why:** `HomeWidget.registerInteractivityCallback` (and the older `registerBackgroundCallback`) uses `PluginUtilities.getCallbackHandle` internally to marshal the Dart function reference across the platform channel. In release (AOT) mode, functions not annotated with `@pragma('vm:entry-point')` are eligible for tree-shaking: the compiler drops them from the binary or removes them from the VM's callback lookup dictionary, making `getCallbackHandle` return `null`. The result is that widget button taps call back into the engine but find no registered handler — no exception is thrown, no log is emitted, the interaction simply does nothing. This failure is invisible in debug (JIT) builds and only surfaces after a production build, making it a silent release-mode regression. The official documentation and every authoritative tutorial cite this annotation as mandatory.
- **Detection (AST, type-safe):**
  1. Match `MethodInvocation` nodes where the method name is `registerInteractivityCallback` or `registerBackgroundCallback` and the static type of the receiver is `HomeWidget` from library URI `package:home_widget/home_widget.dart`.
  2. Extract the single positional argument.
  3. If the argument is a `FunctionReference` (tear-off), resolve its `staticElement` to a `FunctionElement` or `MethodElement`.
  4. Walk the element's `metadata` list looking for an `ElementAnnotation` whose `element` or `toSource()` contains `pragma` with value `vm:entry-point`. If none is found, report at the argument node.
  5. If the argument is an inline `FunctionExpression` (closure/lambda), do NOT flag — the function has no declaration site to annotate; report `home_widget_callback_not_top_level` instead.
- **Fix (mechanical):** Insert `@pragma('vm:entry-point')\n` immediately before the target function declaration. Priority: 90.
- **False positives:**
  - Function declared in a generated file (`*.g.dart`, `*.freezed.dart`) where annotation insertion is not safe — skip when the element's source path ends with `.g.dart` or `.freezed.dart`.
  - Test stubs that mock the callback and are never serialized — low risk; acceptable over-report in test files (developers can add `// ignore:` with explanation).

---

### `home_widget_callback_not_top_level`

- **What/why:** `PluginUtilities.getCallbackHandle` can only locate top-level functions and static methods. An instance method carries implicit `this` context that cannot be serialized across platform-channel boundaries; a local (nested) function is not registered in the VM's top-level symbol table. Passing either to `registerInteractivityCallback` returns `null` from `getCallbackHandle`, silently preventing widget interactions from ever reaching Dart. Even in debug mode the behavior is undefined; in release mode it always fails.
- **Detection (AST, type-safe):**
  1. Match `MethodInvocation` for `registerInteractivityCallback` / `registerBackgroundCallback` on `HomeWidget` (same library URI guard as above).
  2. Inspect the single positional argument's `staticElement`.
  3. Report if the element is a `LocalFunctionElement` (nested/local function) or a non-static `MethodElement` (instance method tear-off). Top-level `FunctionElement` and `static MethodElement` are compliant.
  4. If the argument is an inline `FunctionExpression`, report here too — closures cannot be serialized.
- **Fix:** report-only. The developer must extract the function to top-level or declare it `static` — no mechanical replacement is safe without knowing the captured state.
- **False positives:**
  - Tear-off of a `static` method that the static type system resolves to a `MethodElement` without the `isStatic` flag being set correctly in some analyzer edge cases — guard with `element is MethodElement && !element.isStatic` for the instance check.

---

### `home_widget_save_without_update`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** flat-offset "any updateWidget later in same FunctionBody" both under-reports (matches updateWidget in an unrelated branch) and over-reports (helper-method pattern); needs flow-order detection, not flat offset.

- **What/why:** `HomeWidget.saveWidgetData` writes a key-value pair to the shared widget storage file but does NOT trigger the OS to re-render the home screen widget. The home screen widget reads storage only when explicitly told to reload, which happens via `HomeWidget.updateWidget`. A call to `saveWidgetData` without a subsequent `updateWidget` in the same logical flow leaves the on-screen widget displaying stale data indefinitely — the change is persisted but invisible until the next unrelated reload event (app foregrounding, system widget refresh, etc.). This is the most common home_widget integration mistake: developers familiar with reactive state management expect persistence to be enough, but home screen widgets require an explicit refresh signal. The official documentation states: "To initiate a reload of the Home Screen Widget, you need to call `HomeWidget.updateWidget()`" — it presents these as a required pair.
- **Detection (AST, type-safe):**
  1. Within a single `FunctionBody`, collect all `MethodInvocation` nodes where the method name is `saveWidgetData` and receiver static type is `HomeWidget` from `package:home_widget/home_widget.dart`.
  2. For each such call at source offset `S`, scan the remaining statements in the same `FunctionBody` for a `MethodInvocation` of `updateWidget` on the same receiver type at any offset `> S`.
  3. If no `updateWidget` call exists at a later offset, report at the `saveWidgetData` node.
- **Fix:** report-only. The update call requires widget name arguments specific to the project's native setup.
- **False positives:**
  - `saveWidgetData` called as a batch-prepare step in a helper method that is always called from a parent that calls `updateWidget` afterward — the rule will report the helper. Developers can annotate with `// ignore: home_widget_save_without_update` once they verify the parent pattern.
  - `saveWidgetData` called inside a loop or conditional with `updateWidget` inside a different branch — the rule uses a flat offset scan so it will find `updateWidget` even across branches; this is acceptable (the combined path updates).
  - Test files — exclude via `ProjectContext.isTestFile(path)`.

---

### `home_widget_update_no_name`

- **What/why:** `HomeWidget.updateWidget()` accepts four optional string parameters: `name`, `androidName`, `iOSName`, and `qualifiedAndroidName`. If the call is made with all four absent (or all null), there is no widget identifier: Android has no `qualifiedAndroidName`/`androidName`/`name` to look up in the `AppWidgetManager`, and iOS has no `iOSName`/`name` to match. The result is a silent no-op on both platforms — the native side receives a null/empty identifier, cannot find the widget provider, and returns `false` without throwing. This is a common mistake when developers copy the API skeleton without filling in the platform-specific names.
- **Detection (AST, type-safe):**
  1. Match `MethodInvocation` where the method name is `updateWidget` and the receiver static type is `HomeWidget` from `package:home_widget/home_widget.dart`.
  2. Inspect the `argumentList`. The call is flagged if ALL of the following named parameters are either absent from the argument list OR present with a `NullLiteral` value: `name`, `androidName`, `iOSName`, `qualifiedAndroidName`.
  3. A call that provides at least one non-null-literal named argument is compliant.
- **Fix:** report-only. The correct widget provider name is project-specific and cannot be inferred mechanically.
- **False positives:**
  - Arguments provided through `const String.fromEnvironment(...)` or computed expressions — these are not `NullLiteral` nodes, so they are not flagged. Intentional: a non-literal value shows deliberate assignment.
  - The call is guarded by platform detection and intentionally passes null for one platform (e.g., `iOSName: null` explicitly) — still flagged if all four are absent/null. This is an acceptable over-report; developers can use `// ignore:` with an explanation.

---

### `home_widget_ios_missing_app_group`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** class-scope presence check misses mixin/base-class/DI setAppGroupId; moderate FP. (No Info.plist parsing needed — it checks Dart setAppGroupId presence.)

- **What/why:** On iOS, `HomeWidget.saveWidgetData` and `HomeWidget.getWidgetData` use the App Group shared container (`group.<bundle_id>.*`) to exchange data with the widget extension. Without a configured app group, the storage path resolves to a location the widget extension cannot access, and data reads/writes either fail or return stale/empty values silently. The package documentation states explicitly: "Required on iOS to set the AppGroupId `groupId` in order to ensure communication between the App and the Widget Extension." The official codelab shows `setAppGroupId` called in `initState` before all other `HomeWidget` operations. Omitting this call is the most common iOS-specific integration error: the app may appear to work on Android but silently fails to share data on iOS.
- **Detection (AST, type-safe):**
  1. Within a `ClassDeclaration`, collect all `MethodInvocation` nodes across all methods where the method name is `saveWidgetData` or `getWidgetData` and the receiver static type is `HomeWidget` from `package:home_widget/home_widget.dart`.
  2. Check each call: if it provides a non-null `appGroupId:` named argument, that call is individually guarded and is not flagged.
  3. For any `saveWidgetData`/`getWidgetData` call without a per-call `appGroupId:` argument, scan all methods in the same class for a `setAppGroupId` invocation on `HomeWidget`. If none is found, report each unguarded call site.
- **Fix:** report-only. The app group identifier string is project-specific.
- **False positives:**
  - `setAppGroupId` called in a mixin, base class, or dependency-injected initializer — not visible to the rule; developers can add `// ignore:` once verified.
  - Android-only apps where iOS is explicitly excluded — the rule still fires. Acceptable: the comment required for suppression serves as documentation that iOS is intentionally unsupported.
  - Test files — exclude via `ProjectContext.isTestFile(path)`.

---

### `home_widget_widget_clicked_without_initial_launch`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** class-scoped, misses cross-class router/lifecycle handler (common). INFO mitigates.

- **What/why:** `HomeWidget.widgetClicked` is a `Stream<Uri?>` that fires when the app is already running (foreground or background) and the user taps a widget. However, when a widget tap cold-starts the app, `widgetClicked` does NOT fire — only `initiallyLaunchedFromHomeWidget()` can detect that launch. A class that listens to `widgetClicked` but never calls `initiallyLaunchedFromHomeWidget()` misses the cold-start tap entirely: the app opens from the widget but takes no navigational action, appearing to ignore the tap. The official documentation states both must be used together: "To detect if the App has been initially started by clicking the Widget you can call `HomeWidget.initiallyLaunchedFromHomeWidget()` if the App was already running in the Background you can receive these Events by listening to `HomeWidget.widgetClicked`."
- **Detection (AST, type-safe):**
  1. Within a `ClassDeclaration`, find `PropertyAccess` or `PrefixedIdentifier` nodes resolving to `HomeWidget.widgetClicked` (static getter of type `Stream<Uri?>` from `package:home_widget/home_widget.dart`), followed immediately or chained with `.listen(...)`.
  2. Also scan the same class for any `MethodInvocation` where the method name is `initiallyLaunchedFromHomeWidget` on the `HomeWidget` receiver type.
  3. If `widgetClicked` is accessed but `initiallyLaunchedFromHomeWidget` is absent from the class, report at the `widgetClicked` access node.
- **Fix:** report-only. The correct implementation of the cold-start handler is app-specific.
- **False positives:**
  - `initiallyLaunchedFromHomeWidget()` called in a separate class (e.g., a dedicated router or lifecycle handler) — not visible to the rule; suppress with `// ignore:` once verified.
  - Test files — exclude via `ProjectContext.isTestFile(path)`.

---

## Not lint-able (static analysis boundary)

- **`@pragma` missing on a function defined in a different file from the registration call:** When `registerInteractivityCallback(myCallback)` appears in `main.dart` but `myCallback` is declared in `callbacks.dart`, the analyzer resolves the element cross-file. The annotation check still works if the element's `metadata` is loaded; however, generating the fix (inserting the annotation) requires editing the declaration file rather than the call-site file. Report-only in that cross-file case; the fix should still be offered on the declaration site.
- **Runtime-only `setAppGroupId` timing (called after `saveWidgetData` in the same method):** Detecting order within a method is feasible (source offset comparison), but the ordering of async calls across `await` boundaries cannot be fully determined statically — `setAppGroupId` might be `await`-ed in a preceding statement even if it appears first in source offset. The class-scope presence check (rule 5) is a safe conservative approximation.
- **Type mismatch between `saveWidgetData<T>` and `getWidgetData<T>` for the same key:** Verifying that the type parameter `T` at the save site matches the type parameter at the read site for a given `id` string requires cross-call-site string matching with type comparison — a data-flow problem beyond local AST analysis.
- **`renderFlutterWidget` result key not passed to `saveWidgetData`:** The returned path string should be stored via `saveWidgetData` to make it accessible to the native widget. Verifying that the return value flows to `saveWidgetData` is an alias/data-flow problem, not a local pattern.

---

## Implementation note

New file `lib/src/rules/packages/home_widget_rules.dart`. Register all six rule classes in the `_allRuleFactories` list in `lib/saropa_lints.dart` under a `// HomeWidget rules (home_widget_rules.dart)` comment. Add the six rule names to `comprehensiveOnlyRules` in `lib/src/tiers.dart` — rationale: these rules are only relevant on projects that integrate home screen widgets, require understanding of the package's initialization contract and platform-specific constraints, and carry non-trivial FP rates in non-iOS contexts.

Add `static const Set<String> homeWidget = {'package:home_widget/'};` to `PackageImports` in `lib/src/import_utils.dart`. Use `fileImportsPackage(node, PackageImports.homeWidget)` as the early-exit guard in every rule's `runWithReporter`.

All six rules use `SaropaLintRule` base class with:
- `impact`: `LintImpact.warning` (five rules) or `LintImpact.info` (`home_widget_widget_clicked_without_initial_launch`)
- `ruleType`: `RuleType.correctness`
- `tags`: `const {'packages'}`
- `cost`: `RuleCost.low`

`home_widget_callback_missing_pragma` is the only rule with a quick fix; implement via `DartFix` inserting `@pragma('vm:entry-point')\n` at the declaration offset of the resolved function element.

The `home_widget_callback_missing_pragma` and `home_widget_callback_not_top_level` rules share the same `MethodInvocation` match logic; factor the receiver-type guard into a private helper.

---

## Sources

- [home_widget pub.dev package page](https://pub.dev/packages/home_widget)
- [HomeWidget class API docs](https://pub.dev/documentation/home_widget/latest/home_widget/HomeWidget-class.html)
- [registerInteractivityCallback API](https://pub.dev/documentation/home_widget/latest/home_widget/HomeWidget/registerInteractivityCallback.html)
- [setAppGroupId API](https://pub.dev/documentation/home_widget/latest/home_widget/HomeWidget/setAppGroupId.html)
- [updateWidget API](https://pub.dev/documentation/home_widget/latest/home_widget/HomeWidget/updateWidget.html)
- [saveWidgetData API](https://pub.dev/documentation/home_widget/latest/home_widget/HomeWidget/saveWidgetData.html)
- [renderFlutterWidget API](https://pub.dev/documentation/home_widget/latest/home_widget/HomeWidget/renderFlutterWidget.html)
- [Interactive Widgets docs (docs.page)](https://docs.page/abausg/home_widget/features/interactive-widgets)
- [Interactive HomeScreen Widgets article (Anton Borries, Medium)](https://medium.com/@ABausG/interactive-homescreen-widgets-with-flutter-using-home-widget-83cb0706a417)
- [Google Codelab: Adding a Home Screen widget to your Flutter App](https://codelabs.developers.google.com/flutter-home-screen-widgets)
- [Flutter issue #118608: PluginUtilities.getCallbackHandle and tree-shaking](https://github.com/flutter/flutter/issues/118608)
- [home_widget GitHub issue #326: Interactivity NOT working on iOS](https://github.com/ABausG/home_widget/issues/326)
- [home_widget changelog](https://pub.dev/packages/home_widget/changelog)

---

## Finish Report (2026-06-11)

**Scope:** (A) Dart lint rules. All 6 proposed rules implemented; the 4 validation
callouts addressed.

### Validation fixes applied

- `home_widget_callback_missing_pragma` — the cross-file annotation quick fix is
  **deferred (report-only)**, as the validation flagged: a correct fix must edit
  the callback's declaration file via `element.source`, not the call site, which
  the `ReplaceNodeFix`/`SaropaFixProducer` path does not cleanly support. Detection
  is scoped to **same-unit** top-level functions (inspects the `FunctionDeclaration`
  AST metadata); cross-file declarations are skipped to avoid false positives.
- `home_widget_save_without_update` — uses **member-scoped presence** (any
  `updateWidget` in the same member clears it) rather than flat source-offset, and
  the doc/message name the helper-only false-positive class. Full inter-procedural
  flow analysis is out of scope (documented).
- `home_widget_ios_missing_app_group` / `..._widget_clicked_without_initial_launch`
  — class-scoped with the mixin/base-class/cross-class false-positive named in the
  message; the latter is INFO. Both skip test files.

### Delivered (all WARNING except the last, INFO)

`home_widget_callback_missing_pragma`, `home_widget_callback_not_top_level`,
`home_widget_save_without_update`, `home_widget_update_no_name`,
`home_widget_ios_missing_app_group`, `home_widget_widget_clicked_without_initial_launch`.
All key on static `HomeWidget.<method>(...)` calls (`SimpleIdentifier` receiver
named `HomeWidget`) gated by `fileImportsPackage(PackageImports.homeWidget)`.
`RuleType.bug` (5) / `codeSmell` (INFO). Comprehensive tier. No quick fix
(callback-pragma fix deferred per above).

Rule 2 flags closures + `PrefixedIdentifier`/`PropertyAccess` callbacks — the same
accepted approximation the shipped firebase notification-handler rule uses; a
static `Class.method` tear-off may be over-reported (documented).

### Files

- NEW `lib/src/rules/packages/home_widget_rules.dart` (6 rules).
- `lib/src/import_utils.dart` — `PackageImports.homeWidget`.
- `lib/src/rules/all_rules.dart`, `lib/saropa_lints.dart`, `lib/src/tiers.dart`
  (`comprehensiveOnlyRules` + `homeWidgetPackageRules` + `packageRuleSets` + `allPackages`).
- NEW `test/rules/packages/home_widget_rules_test.dart` (12 tests pass).
- NEW `example_packages/lib/home_widget/*_fixture.dart` (6 fixtures).
- `CHANGELOG.md` — `[Unreleased]` Added bullet.

### Verification

- `dart analyze --fatal-infos` → No issues found.
- Unit + registration integrity tests pass.
- **Scan-verified (all 6 fire):** detection is syntactic (static `HomeWidget.x`
  receiver), so a standalone scan triggers every rule on its BAD case while the
  GOOD forms (annotated callback, save+update pair, named updateWidget) stay clean.

### Not yet verified

- Cross-file `@pragma` detection (callback declared in another file) — intentionally
  skipped; the report-only rule covers same-file declarations.
- The deferred cross-file pragma quick fix.
