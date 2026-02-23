# Migration Candidate Results

Reviewed 2026-02-22. Source: Flutter/Dart SDK and Dart-Code release notes.

---

## Implemented (3 of 10)

| # | Rule Name | Tier | Why implemented |
|---|-----------|------|-----------------|
| **003** | `avoid_asset_manifest_json` | Essential | `AssetManifest.json` removed in Flutter 3.38.0. User code that loads this path via `rootBundle.loadString('AssetManifest.json')` will crash at runtime. Detectable via string literal in Dart AST. |
| **007** | `prefer_dropdown_initial_value` | Recommended | `DropdownButtonFormField(value:)` deprecated in Flutter 3.35.0 in favor of `initialValue`. Widely-used widget, clear named-parameter rename, auto-fixable. |
| **008** | `prefer_on_pop_with_result` | Recommended | `Route.onPop` deprecated in Flutter 3.35.0 in favor of `onPopWithResult`. Detectable as named argument or method override, auto-fixable. |

---

## Rejected (7 of 10)

### #001 — Mouse cursor default change for Material buttons

**Source:** [PR #171796](https://github.com/flutter/flutter/pull/171796) (Flutter 3.41.0)
**Category:** Framework behavior change
**Rejection reason:** No user API was deprecated or removed.

This PR changed the *default* mouse cursor of Material buttons from a click cursor to a basic arrow (except on web). This is a framework-level behavior change — the default simply changed. There is no deprecated API, no renamed parameter, and no code pattern in user applications to detect or fix. Users who want the old click cursor can explicitly set `mouseCursor: SystemMouseCursors.click`, but that's a design choice, not a migration.

**Not actionable as a lint rule:** No AST pattern to detect.

---

### #002 — Drawer.child docstring fix (ListView vs SliverList)

**Source:** [PR #180326](https://github.com/flutter/flutter/pull/180326) (Flutter 3.41.0)
**Category:** Documentation-only fix
**Rejection reason:** Zero user code impact.

This PR corrected a docstring in the Flutter SDK source from mentioning `SliverList` to `ListView` as the typical child of `Drawer`. No API was changed, deprecated, or removed. The documentation was simply inaccurate. User code is unaffected regardless of whether they use `ListView` or `SliverList` inside a `Drawer`.

**Not actionable as a lint rule:** No code change for users to make.

---

### #004 — New getter for Project gradle-wrapper.properties

**Source:** [PR #175485](https://github.com/flutter/flutter/pull/175485) (Flutter 3.38.0)
**Category:** Flutter tool internal refactoring
**Rejection reason:** Not a user-facing API.

This PR added a convenience getter to the `Project` class in Flutter's internal tool code (`flutter_tools`). The `Project` class is part of the Flutter CLI's internal implementation and is not exposed to end-user Dart/Flutter applications. There is no user code that references `Project.gradleWrapperProperties` or would benefit from this change.

**Not actionable as a lint rule:** Internal Flutter SDK API, not available to user code.

---

### #005 — gradle_utils.dart: const instead of final

**Source:** [PR #175443](https://github.com/flutter/flutter/pull/175443) (Flutter 3.38.0)
**Category:** Flutter SDK internal code style
**Rejection reason:** Internal Flutter SDK refactoring.

This PR changed `final` declarations to `const` in the Flutter SDK's own `gradle_utils.dart` file. This is a code style improvement within the Flutter tooling codebase. The general principle ("prefer const over final") is already covered by Dart's built-in `prefer_const_declarations` lint. There is nothing for end-user applications to migrate.

**Not actionable as a lint rule:** Already covered by existing Dart lints; this specific change is SDK-internal.

---

### #006 — PowerShell script: $flutterRoot instead of $gitTopLevel

**Source:** [PR #172786](https://github.com/flutter/flutter/pull/172786) (Flutter 3.38.0)
**Category:** Shell script change
**Rejection reason:** Not Dart code.

This PR modified `last_engine_commit.ps1`, a PowerShell script in the Flutter SDK, to use `$flutterRoot` instead of `$gitTopLevel`. Our linter operates on Dart AST — it cannot analyze PowerShell scripts. This is also an SDK-internal script that end users don't interact with.

**Not actionable as a lint rule:** Not Dart code; our linter only analyzes Dart AST.

---

### #009 — Gradle: toLowerCase → lowercase

**Source:** [PR #171397](https://github.com/flutter/flutter/pull/171397) (Flutter 3.35.0)
**Category:** Groovy/Gradle code change
**Rejection reason:** Not Dart code.

This PR changed `toLowerCase()` calls to `lowercase()` in Flutter's Gradle build scripts (Groovy/Kotlin DSL). This prepares for the removal of `toLowerCase` in Gradle v9. Our linter analyzes Dart source files via the Dart AST — it has no capability to parse or lint Groovy or Kotlin Gradle scripts.

**Not actionable as a lint rule:** Groovy/Gradle code, not Dart. Outside our linter's scope.

---

### #010 — addMachineOutputFlag / outputsMachineFormat

**Source:** [PR #171459](https://github.com/flutter/flutter/pull/171459) (Flutter 3.35.0)
**Category:** Flutter tool internal refactoring
**Rejection reason:** Not a user-facing API.

This PR replaced string-based `--machine` flag handling in Flutter CLI tool commands with typed methods (`addMachineOutputFlag` / `outputsMachineFormat`). These methods are part of the Flutter tool's internal `FlutterCommand` base class and are not exposed to end-user applications. No user code references these APIs.

**Not actionable as a lint rule:** Internal Flutter CLI API, not available to user code.

---

---

## Rejected #021–134 (114 of 114)

Batch reviewed 2026-02-22. Sources: Flutter SDK v3.0.0–v3.27.0, Dart SDK v3.0.0–v3.11.0, Dart-Code extensions.

### Already removed — compile error on current SDK (27 candidates)

| # | API | SDK removed | Rejection |
|---|-----|-------------|-----------|
| **033** | `TextTheme` old members (`headline1`, etc.) | Flutter 3.22 | Compile error + `dart fix` |
| **034** | `KeepAliveHandle.release` | Flutter 3.22 | Compile error |
| **035** | `InteractiveViewer.alignPanAxis` | Flutter 3.22 | Compile error |
| **036** | `CupertinoContextMenu.previewBuilder` | Flutter 3.22 | Compile error |
| **038** | `PlatformMenuBar.body` | Flutter 3.19 | Compile error |
| **055** | `AppBar.color`, `AppBar.backwardsCompatibility` | Flutter 3.10 | Compile error |
| **073** | `NullThrownError` | Dart 3.0 | Compile error |
| **097** | `Deprecated.expires` → `.message` | Dart 3.0 | Compile error |
| **098** | `List()` constructor | Dart 3.0 | Compile error |
| **099** | `proxy`, `Provisional` annotations | Dart 3.0 | Compile error |
| **100** | `Deprecated.expires` getter | Dart 3.0 | Compile error |
| **101** | `CastError` | Dart 3.0 | Compile error |
| **102** | `FallThroughError` | Dart 3.0 | Compile error |
| **103** | `AbstractClassInstantiationError` | Dart 3.0 | Compile error |
| **104** | `CyclicInitializationError` | Dart 3.0 | Compile error |
| **105** | `NoSuchMethodError` default constructor | Dart 3.0 | Compile error |
| **106** | `BidirectionalIterator` | Dart 3.0 | Compile error |
| **107** | `DeferredLibrary` | Dart 3.0 | Compile error |
| **109** | `MAX_USER_TAGS` | Dart 3.0 | Compile error |
| **110** | `Metrics`, `Metric`, `Counter`, `Gauge` | Dart 3.0 | Compile error |
| **112** | `Deprecated.expires` → `.message` (dup of #097) | Dart 3.0 | Compile error |
| **113** | `CastError` → `TypeError` (dup of #101) | Dart 3.0 | Compile error |
| **114** | `MAX_USER_TAGS` → `maxUserTags` (dup of #109) | Dart 3.0 | Compile error |
| **080** | `dart:html` native classes can't be extended | Dart 3.8 | Compile error; `dart:html` superseded by `package:web` |
| **081** | `SecurityContext` now `final` | Dart 3.5 | Compile error; nobody subclasses this |
| **090** | `JSNumber.toDart` removed | Dart 3.2 | Compile error; niche JS interop |
| **078** | `RenderObjectElement` methods | Flutter 3.0 | Compile error + `dart fix` |

### Standard deprecation warnings already cover it (12 candidates)

These APIs have `@Deprecated` annotations that the Dart analyzer already warns about. Our lint would be redundant.

| # | Deprecated API | Replacement | Why redundant |
|---|---------------|-------------|---------------|
| **039** | `RawKeyEvent`, `RawKeyboard` et al. | `KeyEvent`, `HardwareKeyboard` | `@Deprecated` fires; migration guide exists |
| **048** | `useMaterial3` in `ThemeData.copyWith()` | Set in `ThemeData()` directly | `@Deprecated` fires |
| **056** | `TestWindow` | View-based testing APIs | `@Deprecated` fires; test-only |
| **057** | `@alwaysThrows` annotation | Return type `Never` | `@Deprecated` fires |
| **064** | `AnimatedListItemBuilder` typedef | `AnimatedItemBuilder` | `@Deprecated` fires; simple rename |
| **082** | `FileSystemDeleteEvent.isDirectory` | Remove the call (always `false`) | `@Deprecated` fires; niche |
| **087** | Core `Pointer` type operations | New `-`/`+` operators | `@Deprecated` fires; FFI niche |
| **089** | `Service.getIsolateID` | `Service.getIsolateId` | `@Deprecated` fires; VM service niche |
| **094** | `Platform()` constructor | Static members | `@Deprecated` fires |
| **108** | `HasNextIterator` | Standard `Iterator` | `@Deprecated` fires; niche |
| **111** | `NetworkInterface.listSupported` | Remove call (always `true`) | `@Deprecated` fires; niche |

### Already handled by `dart fix` (5 candidates)

| # | Change | Why redundant |
|---|--------|---------------|
| **022** | Deprecate `ButtonBar` → `OverflowBar` | PR includes `dart fix` output; fully automated |
| **033** | Remove deprecated `TextTheme` members | `dart fix` + compile error |
| **052** | Advise `OverflowBar` instead of `ButtonBar` | Same as #022 |
| **054** | Use `ListenableBuilder` over `AnimatedBuilder` | Template change; `AnimatedBuilder` not deprecated |
| **078** | Remove `RenderObjectElement` deprecated methods | `dart fix` supported; already removed |

### Already covered by existing Dart lints (2 candidates)

| # | Change | Existing lint |
|---|--------|--------------|
| **027** | Use `super.key` instead of manual `Key` passing | `use_super_parameters` (built-in) |
| **070** | Use `double.isNaN` instead of `== double.nan` | Dart analyzer built-in warning |

### Flutter SDK / engine internal changes (25 candidates)

Not user-facing. Changes to framework implementation, engine C++ code, or internal APIs.

#021, #023, #024, #025, #026, #029, #030, #037, #040, #042, #045, #051, #058, #060, #061, #062, #063, #065, #066, #067, #069, #072, #076

### CI / infrastructure / build system / CLI (7 candidates)

Not Dart code. Changes to CI pipelines, build tools, or CLI flags.

#028, #031, #032, #044, #046, #047, #053

### Documentation and typo fixes (4 candidates)

Zero user code impact.

#043, #068, #071, #075

### New features — not migrations (7 candidates)

New APIs or options added. No old pattern to detect or replace.

#049, #083, #084, #085, #086, #088, #095

### JS interop breaking changes — compiler catches (4 candidates)

Compile errors on affected SDK versions. Niche JS interop users.

#091, #092, #093, #096

### Vague or insufficient context (4 candidates)

Release note fragment too vague to identify a specific API or migration path.

#059, #079, #115, #116, #117

### VS Code extension / Dart-Code changes (17 candidates)

Changes to the Dart-Code VS Code extension. Not user Dart code — our linter doesn't analyze IDE settings or extension internals.

#118, #119, #120, #121, #122, #123, #124, #125, #126, #127, #128, #129, #130, #131, #132, #133, #134

### Internal framework behavior changes (2 candidates)

| # | Change | Why not viable |
|---|--------|---------------|
| **041** | `--timeline_recorder=systrace` flag | VM flag, not Dart code |
| **077** | Update examples to use `Focus` over `RawKeyboardListener` | Example/docs update; #039 covers the deprecation |

---

## Summary

| Outcome | Count | Candidates |
|---------|-------|------------|
| **Implemented** | 3 | #003, #007, #008 |
| **Rejected: already removed (compile error)** | 27 | #033–036, #038, #055, #073, #078, #080, #081, #090, #097–107, #109, #110, #112–114 |
| **Rejected: standard deprecation covers it** | 12 | #039, #048, #056, #057, #064, #082, #087, #089, #094, #108, #111 |
| **Rejected: `dart fix` handles it** | 5 | #022, #033, #052, #054, #078 |
| **Rejected: existing Dart lint covers it** | 2 | #027, #070 |
| **Rejected: SDK/engine internal** | 25 | #021, #023–026, #029, #030, #037, #040, #042, #045, #051, #058, #060–063, #065–067, #069, #072, #076 |
| **Rejected: CI/build/CLI** | 7 | #028, #031, #032, #044, #046, #047, #053 |
| **Rejected: documentation only** | 4 | #043, #068, #071, #075 |
| **Rejected: new feature, not migration** | 7 | #049, #083–086, #088, #095 |
| **Rejected: JS interop (compiler catches)** | 4 | #091–093, #096 |
| **Rejected: vague/insufficient** | 4 | #059, #079, #115–117 |
| **Rejected: VS Code extension** | 17 | #118–134 |
| **Rejected: not user-facing (#001–010)** | 7 | #001, #002, #004–006, #009, #010 |
| **Rejected: behavior change/other** | 2 | #041, #077 |

### Why existing implemented rules succeed where these fail

Our 3 implemented rules detect patterns the **standard Dart analyzer doesn't warn about**:

| Rule | Why it works | Why these candidates don't |
|------|-------------|--------------------------|
| `avoid_asset_manifest_json` | String literal `'AssetManifest.json'` — no `@Deprecated` annotation exists on a string | Most candidates: `@Deprecated` annotation already fires warnings |
| `prefer_dropdown_initial_value` | Named parameter where deprecation may not fire in all contexts | Most candidates: entire classes/methods are deprecated → always warns |
| `prefer_on_pop_with_result` | Method override detection for a specific renamed callback | Most candidates: compile errors or `dart fix` already handles them |

### Criteria for viable migration rules

A migration candidate is only viable as a lint rule if ALL of these hold:
- The change affects **user-facing Dart code** (not SDK internals)
- There is a **detectable AST pattern** (constructor call, method name, string literal, etc.)
- The migration has a **clear before/after** that can be expressed as a lint + fix
- The standard Dart analyzer **does NOT already warn** about the pattern (`@Deprecated`, compile error, or built-in lint)
- `dart fix` does **NOT already automate** the migration
