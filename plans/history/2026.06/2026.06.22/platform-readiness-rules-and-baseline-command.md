# Platform-readiness lint rules + extension "Create Baseline" command

Four platform-build-readiness lint rules were added (one cross-platform plugin-compatibility rule plus three Android/Web requirement rules), backed by a new pub.dev-verified plugin platform-support knowledge base. Separately, the VS Code extension gained a "Create Baseline" command so the Suggestions view's long-standing baseline prompt invokes the baseline tool directly instead of opening the config editor and dead-ending.

## Finish Report (2026-06-22)

### Motivation

A review of the `flutter-ios-check` CLI raised the question of whether saropa_lints
should add equivalent platform-readiness coverage. Investigation found the
structural/file-presence and readiness-score parts of that tool are project-level
(no Dart AST node to anchor a diagnostic) and do not fit the custom_lint model, while
the analysis parts (plugin -> iOS permission cross-checks) were already covered and
exceeded. The net-new, lint-shaped opportunities were: a plugin platform-support
compatibility rule, and newer Android/Web platform requirements not yet covered.

### Lint rules added

1. `avoid_platform_incompatible_dependency` (Comprehensive) — warns when an import
   resolves to a plugin with no native implementation for a platform the project
   builds for. A Flutter plugin compiles into every target regardless of native
   coverage, so importing e.g. `sqflite` (no web) into a project with a `web/`
   directory builds cleanly and throws at runtime on web only. Fires only when the
   project has the matching `flutter create` platform directory and the import is
   unconditional. Backed by `lib/src/platform_support_utils.dart`.

2. `require_android_exact_alarm_permission` (Essential) — flags exact-alarm
   scheduling (`zonedSchedule` with an exact `AndroidScheduleMode`, or
   `AndroidAlarmManager.*(exact: true)`) when AndroidManifest.xml declares neither
   `SCHEDULE_EXACT_ALARM` nor `USE_EXACT_ALARM`. Android 14 (API 34) denies the
   capability by default and silently downgrades the alarm to inexact. Inexact modes
   are not flagged (the regex anchors on the literal mode name after the dot).

3. `require_android_partial_media_permission` (Professional, INFO) — suggests
   `READ_MEDIA_VISUAL_USER_SELECTED` when the manifest declares broad media
   permissions (`READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`) and a gallery plugin is used.
   Gated on the broad permissions already being present, so Photo-Picker-only apps
   are not flagged.

4. `avoid_package_js_for_wasm` (Comprehensive) — flags `package:js` imports, which
   have no WebAssembly implementation and break `flutter build web --wasm`. Distinct
   from the existing `dart:js`/`dart:html` rules, which do not cover the third-party
   `package:js`. Gated on web support.

### Knowledge base and infrastructure

- `lib/src/platform_support_utils.dart` — `PluginPlatformSupport`: a curated map of
  package name -> set of unsupported tracked platforms (`web`, `windows`, `macos`,
  `linux`). Every entry was verified against the package's official pub.dev platform
  tags on 2026-06-22; entries are deliberately conservative because a wrong entry is a
  false positive in every consumer's editor. Verified data:
  `sqflite` -> {web, windows, linux}; `local_auth` -> {web, linux}; `path_provider` ->
  {web}; `firebase_messaging` -> {windows, linux}; `camera` -> {windows, macos, linux};
  `permission_handler` -> {macos, linux}. `geolocator` and
  `flutter_local_notifications` support all tracked platforms and are intentionally
  absent (the latter corrected a memory-based assumption that would have been a false
  positive).
- `ProjectContext.targetsPlatform(filePath, platformId)` + `_ProjectInfo.targetPlatforms`
  — exposes the project's concrete non-mobile build targets from the platform
  directories present. Defaults to `false`/empty on unknown (the opposite of the
  assume-strict `hasWebSupport` family) so the rule never asserts incompatibility with
  a target the project may not have.

### Candidates investigated and rejected (dedup)

- POST_NOTIFICATIONS Android rule — `require_notification_permission_android13` exists.
- `dart:io`-on-web rule — `avoid_platform_specific_imports` covers it.
- `dart:js`-for-wasm — `prefer_js_interop_over_dart_js` covers it.
- url_launcher `<queries>` and in_app_purchase `BILLING` — those manifest entries are
  injected by the plugins' own manifest merge at build time and are not visible to the
  analyzer reading the app manifest, so a cross-check would false-positive.
- PendingIntent mutability and macOS network entitlement — not statically detectable
  from Dart.

### Registration and tiers

All four rules registered in `_allRuleFactories` (`lib/saropa_lints.dart`), assigned to
tiers in `lib/src/tiers.dart`, and added to the platform-pack registry: the
cross-platform and wasm rules to `webPlatformRules` (and the former also to the shared
`_desktopPlatformRules`); the Android rules to `androidPlatformRules`.

### Extension: Create Baseline command

`saropaLints.createBaseline` runs `dart run saropa_lints:baseline` via the existing
async cancellable runner, streams to the shared output channel, and refreshes views on
success. The Suggestions view's "Create baseline" item, previously bound to
`openConfig`, now invokes it. Wired across `setup.ts` (`runCreateBaseline`),
`extension.ts`, `package.json`, `package.nls.json`, `suggestionsTree.ts`, and three new
`en.json` keys. The extension typecheck passed.

### Verification

- `dart test --no-pub` on the registration-integrity test plus the android/web/
  plugin-platform-support rule tests: all passed.
- Extension `npm run check-types`: passed.
- Per the no-`dart analyze` policy, verification relied on the compiling test run and
  live IDE diagnostics; no analyzer errors outstanding.

### Follow-ups not done here

- The three new `en.json` keys leave the translated locale catalogs stale; regenerating
  them is a machine-translation job left to a separate, explicitly-authorized run.
