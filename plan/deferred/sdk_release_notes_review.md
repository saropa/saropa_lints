# SDK Release-Note Auto-Plans — Consolidated Review

> **Last reviewed:** 2026-04-19
> **Reviewer:** full pass over every `0XX-*.md` and `1XX-*.md` file in this folder.

## What this is

A batch of 66 numbered plan files (`005-*.md` through `134-*.md`) was auto-generated from Dart, Flutter, and Dart-Code release notes. Each file proposes a lint rule for "old pattern → new pattern" or a deprecation. **They are not equal in value.** Most describe changes *inside* the Flutter or Dart repos (gradle scripts, CI config, engine C++, fuchsia routing, ninja invocations, doc typos) or inside the Dart-Code VS Code extension — none of which a `custom_lint` plugin can analyze in user code.

The full individual files are preserved in [`_archive/`](_archive/) for forensic reference. This document is the source of truth for *why each one was deferred* and what (if anything) can still be salvaged.

## Related deferral docs in this folder

This review only covers the auto-generated numbered plans. Other deferred rules live in topic-specific files — check these *before* proposing or re-proposing a rule:

| File | Scope |
|---|---|
| [`compiler_diagnostics.md`](compiler_diagnostics.md) | Checks the Dart compiler already performs — duplicating them adds no value and risks divergence. |
| [`cross_file_analysis.md`](cross_file_analysis.md) | Rules that need to see more than one file at a time. `custom_lint` is single-file. |
| [`external_dependencies.md`](external_dependencies.md) | Rules that need a live pub.dev call or a maintained metadata database. Not available inside the analyzer plugin. |
| [`framework_limitations.md`](framework_limitations.md) | Optimizations and features blocked by missing analyzer-server / custom_lint hooks. |
| [`unreliable_detection.md`](unreliable_detection.md) | Rules where the concept is real but the AST signal is too subjective / abstract to fire without huge false-positive rates. |
| [`not_viable.md`](not_viable.md) | Individually reviewed and permanently rejected candidates (by rule name, not by SDK version). |
| [`plan_additional_rules_41_through_50.md`](plan_additional_rules_41_through_50.md) | Original "Additional rules 41–50" batch — all 10 duplicate compiler diagnostics. |

## Why entries are separated

- **Dart-Code (IDE)**: settings, LSP client, widget preview, command execution, telemetry, DTD sidebar. These are IDE/extension behavior; a lint package does not analyze VS Code settings or extension internals.
- **Flutter / Dart repo and tooling**: changes inside Flutter itself (CI, build scripts, engine, docs, triage labels, gradle, ninja, Skia, `flutter_tools`). Not user-facing API.
- **Runtime / SDK environment**: Observatory, pub cache location, SDK version file parsing. Behavior of the runtime or tooling, not patterns in user code.

---

## Verdict summary

| Verdict | Count | Meaning |
|---|---|---|
| **Promoted** | 1 | Moved back to `plan/` — viable lint rule |
| Rejected — Flutter engine / tooling internal | 14 | Changes inside `flutter/flutter` repo (gradle, engine, fuchsia, template refactors) — user code never sees them |
| Rejected — CI / build / orchestrator | 15 | CI infra: Linux orchestrators, Chrome-for-Testing, ninja, Android firebase test lanes, pub cache location, `dart compile wasm` flags |
| Rejected — Docs only | 5 | Release notes describing doc/comment fixes |
| Rejected — Dart-Code VS Code extension | 17 | Extension settings, LSP client updates, sidebar behavior, telemetry — not Dart code |
| Rejected — Additive / no migration pattern | several | New API added alongside the old one; no "before/after" to detect |
| Rejected — Duplicate of analyzer built-ins | several | `@Deprecated` + `deprecated_member_use` already cover it |

**Only one of the 66 numbered plans (#054) had a defensible lint story.** It has been promoted to [`../054-prefer_listenable_builder_over_animated_builder.md`](../054-prefer_listenable_builder_over_animated_builder.md).

---

## Promoted

### #054 — `prefer_listenable_builder_over_animated_builder`

**Source:** Flutter SDK 3.13.0. Original file archived as [`_archive/054-fluttertools_modify_skeleton_template_to_use_listenablebuild.md`](_archive/054-fluttertools_modify_skeleton_template_to_use_listenablebuild.md) (*later moved during promotion; see full new plan at [`../054-prefer_listenable_builder_over_animated_builder.md`](../054-prefer_listenable_builder_over_animated_builder.md)*).

**Why viable:** `AnimatedBuilder(animation: x, ...)` where `x` is a non-`Animation` `Listenable` (e.g. `ValueNotifier`, `ChangeNotifier`) should use `ListenableBuilder`. Detection is an `InstanceCreationExpression` visitor with static-type resolution on the `animation:` argument. Quick fix is a single constructor rename. Needs a min-SDK gate at Flutter 3.13.0.

**Why it is not a duplicate of existing rules:** [`animation_rules.dart`](../../lib/src/rules/ui/animation_rules.dart) already references both widgets in *scope*-focused rules (`avoid_animation_rebuild_waste`, large-builder detection). None target the *widget choice*.

---

## Rejected — full catalog

Every rejected plan below is filed under the category that describes *why* a custom_lint plugin cannot implement it. Each entry keeps the plan number, SDK source, and one-line release note. For full PR descriptions and body text, see `_archive/`.

### Flutter engine / internal repo refactors (14)

A `custom_lint` plugin analyzes user `.dart` code. It cannot migrate changes inside the Flutter repo itself (engine C++, `flutter_tools`, fuchsia platform code, template files, internal classes).

| # | Source | Release note |
|---|---|---|
| 005 | Flutter 3.38.0 | `gradle_utils.dart`: use `const` instead of `final` (internal refactor) |
| 014 | Flutter 3.32.0 | Developer ergonomics: `fail` instead of `throw StateError` inside `flutter_tools` |
| 015 | Flutter 3.32.0 | Fuchsia: remove explicit `LogSink`/`InspectSink` routing (platform internal) |
| 019 | Flutter 3.29.0 | Native assets: produce `NativeAssetsManifest.json` instead of kernel embedding |
| 020 | Flutter 3.27.0 | `fake_codec.dart` test util: use `Future.value` instead of `SynchronousFuture` |
| 021 | Flutter 3.27.0 | Flutter GPU (experimental): `vm.Vector4` clear color instead of `ui.Color` — if the engine marks the old API `@Deprecated`, the analyzer's built-in `deprecated_member_use` catches it. Adding a hand-rolled rule is duplicative |
| 023 | Flutter 3.24.0 | Engine C++: `fml::ScopedCleanupClosure` instead of `DeathRattle` |
| 026 | Flutter 3.24.0 | "Switch to relevant `Remote` constructors" — `Remote` here is internal, not a user-facing Flutter API |
| 029 | Flutter 3.24.0 | Tool-chain: promote an INFO to an ERROR for a non-working Android API (tool behavior, not user code) |
| 045 | Flutter 3.19.0 | Windows: move to `FlutterCompositor` for rendering (engine internal) |
| 051 | Flutter 3.16.0 | Windows IME: use `start` instead of `extent` for cursor position (engine internal) |
| 060 | Flutter 3.10.0 | Skia build arg: `skia_enable_ganesh` instead of legacy GN name (engine build) |
| 063 | Flutter 3.10.0 | Switch from Noto Emoji to Noto Color Emoji and update font data (engine asset) |
| 072 | (was rejected already) | — |

### CI / build scripts / orchestrator changes (15)

These change how Flutter/Dart are *built and tested*, not how user code is written.

| # | Source | Release note |
|---|---|---|
| 006 | Flutter 3.38.0 | `last_engine_commit.ps1`: use `$flutterRoot` instead of `$gitTopLevel` |
| 009 | Flutter 3.35.0 | Android gradle: use `lowercase` instead of `toLowerCase()` |
| 010 | Flutter 3.35.0 | `--machine-output` flag / `outputsMachineFormat` wiring inside `flutter_tools` |
| 011 | Flutter 3.35.0 | Switch to Linux orchestrators for Windows releasers (CI) |
| 028 | Flutter 3.24.0 | `dart compile wasm`: `--no-strip-wams` instead of `--no-name-section` (CLI flag) |
| 032 | Flutter 3.24.0 | Triage labels: `triage-*` for platform package triage (GitHub labels) |
| 041 | Flutter 3.19.0 | `--timeline_recorder=systrace` instead of `--systrace_timeline` (tool CLI flag) |
| 044 | Flutter 3.19.0 | Switch to Chrome for Testing instead of vanilla Chromium (CI) |
| 046 | Flutter 3.19.0 | Same, different file (CI) |
| 047 | Flutter 3.19.0 | Switch to Android 14 for physical device Firebase tests (CI) |
| 053 | Flutter 3.13.0 | `flutter channel` descriptions: use branch instead of upstream (tool output) |
| 062 | Flutter 3.10.0 | Windows: invoke `ninja` instead of `ninja.exe` (build script) |
| 074 | Flutter 3.3.0 | `flutter_tools`: migrate off deprecated `package:coverage` parameters (tool internal) |
| 116 | Dart 3.0.0 | Windows `PUB_CACHE` moved to `%LOCALAPPDATA%` (environment change) |
| 127 | Dart-Code v3-96 | Parse new `bin/cache/flutter.version.json` (extension) |

### Documentation-only release notes (5)

| # | Source | Release note |
|---|---|---|
| 031 | Flutter 3.24.0 | Use more reliable flutter.dev link destinations in the tool |
| 068 | Flutter 3.7.0 | Fix references to symbols: brackets instead of backticks |
| 071 | Flutter 3.7.0 | Doc typo: `CustomPaint` vs `CustomPainter` |
| 075 | Flutter 3.3.0 | Mention that `NavigationBar` is a new widget (docstring tweak) |
| 117 | Dart 3.0.0 | Observatory no longer served by default — advisory text, no code pattern |

### Dart-Code (VS Code extension) release notes (17)

Not Dart code at all — these describe IDE extension behavior. The extension we ship has its own code review path; custom_lint rules cannot reach it.

| # | Source | Release note |
|---|---|---|
| 118 | Dart-Code 128 | Related to a deprecation (no immediate problem), extension-side |
| 119 | Dart-Code 128 | Use `flutterRoot` instead of looking in `.package_config.json` |
| 120 | Dart-Code 126 | Switch to LSP client v10.0.0-next.18, enable `delayOpenNotifications` |
| 121 | Dart-Code 124 | Use `package:foo` instead of folder names in command execution |
| 122 | Dart-Code 124 | Widget Preview works for all projects in a Pub Workspace |
| 123 | Dart-Code 122 | Inform user to prefer USB over WiFi when developing against iOS device |
| 124 | Dart-Code 122 | Widget Preview sidebar icon appears after extension activation |
| 125 | Dart-Code 104 | New settings `dart.getFlutterSdkCommand` / `dart.getDartSdkCommand` |
| 126 | Dart-Code 100 | `customDevTools`: assume `dt` instead of `devtools_tool` |
| 128 | Dart-Code v3-96 | Switch to DTD sidebar when using a new enough SDK |
| 129 | Dart-Code v3-84 | Hover for enum values reports `List<EnumType>` correctly |
| 130 | Dart-Code v3-82 | `dart.previewSdkDaps` replaced by `dart.useLegacyDebugAdapters` |
| 131 | Dart-Code v3-72 | Suggest `flutter pub get` instead of `dart pub get` for Flutter projects |
| 132 | Dart-Code v3-62 | Switch to VS Code's telemetry classes |
| 133 | Dart-Code v3-60 | New setting `dart.addSdkToTerminalPath` |
| 134 | Dart-Code v3-54 | `flutter create --empty` flag exists — CLI flag, no Dart code to lint |

### Already-rejected in earlier passes (preserved for reference)

The following were reviewed *before* this consolidation and had individual `Status: Rejected` statements. Keeping the rationale here so nobody re-proposes them:

| # | Original rejection reason |
|---|---|
| 025 | Copy previous `IconThemeData` instead of overwriting — Material `IconTheme` data merge is handled by the framework; no user migration |
| 040 | Change `ValueNotifier` vs force-rebuild — semantic design decision, not mechanical migration |
| 042 | `OverlayPortal.overlayChild` semantics routing — internal semantics-tree routing fix, no user-facing API change |
| 061 | `ThemeData.visualDensity` initialization using `ThemeData.platform` — default-value change, no caller migration |
| 072 | Default value of `effectiveInactivePressedOverlayColor` changed — internal color-resolution detail |
| 076 | `InputDecorator`: `Opacity` instead of `AnimatedOpacity` for hint — Material internal |
| 083 / 085 | `parallelWaitError` metadata option — additive API, no migration |
| 084 / 086 | Breaking: `stdout.lineTerminator` field — add a field; existing code still compiles |
| 088 | `JSAnyOperatorExtension` rename — release note explicitly says "shouldn't make a difference unless the extension names were explicitly used"; `deprecated_member_use` covers the rare case |
| 095 | New class `SameSite` — additive; no old pattern to detect |
| 096 | Generic "use that instead" — vague, no concrete pattern |

### Deprecations already covered by `deprecated_member_use` (2)

The Dart analyzer emits `deprecated_member_use` for any `@Deprecated`-annotated API. A custom rule that duplicates this for one specific symbol adds noise, not value.

| # | Source | Release note |
|---|---|---|
| 089 | Dart 3.2.0 | `Service.getIsolateID` deprecated → use `getIsolateId`. Already `@Deprecated` in the SDK itself |
| 115 | Dart 3.0.0 | `dart:js_util` `callMethod` parameter widened from `String` to `Object` — `String` is already an `Object`, so existing call sites stay valid. No migration. Also covered by library-owner annotations if anything breaks |

---

## Changes to `deferred/` in this pass (2026-04-19)

- **Promoted out:** #054 → [`../054-prefer_listenable_builder_over_animated_builder.md`](../054-prefer_listenable_builder_over_animated_builder.md) with full lint plan, detection strategy, and false-positive guards.
- **Consolidated:** this file replaces the need to grep 66 individual plan files.
- **Archived:** every numbered plan file (`005-*.md` … `134-*.md`) is now in [`_archive/`](_archive/). Nothing was deleted; original PR descriptions, labels, and generated boilerplate are all preserved there.

If the criteria for "viable" change (for example, if `custom_lint` adds a multi-file analysis phase or the extension gains a pub.dev metadata channel), re-open this review and reconsider the rejected entries — the per-file detail is still in `_archive/` to do that against.

---

## Before adding a new entry to `deferred/`

1. Check the verdict table above to see if the SDK release note is already covered.
2. If it is a rule proposal by name (not an SDK-delta), check `not_viable.md` and the five category files listed under [Related deferral docs](#related-deferral-docs-in-this-folder).
3. If the verdict has changed (new analyzer API, new `custom_lint` feature, new extension capability), **update the existing entry** instead of adding a duplicate.
