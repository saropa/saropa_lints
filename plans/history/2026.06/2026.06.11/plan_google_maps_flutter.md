# Plan: new `google_maps_flutter` lint rules

**Package:** google_maps_flutter ^2.17.1 (Saropa Contacts). **saropa_lints coverage:** none (new file).

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `google_maps_controller_not_disposed` | correctness | `GoogleMapController` stored in a `State` field (via `onMapCreated`) with no `dispose()` call on the controller in the widget's `dispose()` override | report-only | WARNING | skip if file already contains a `dispose()` call whose body calls `.dispose()` on the same field name, or if the field type is not resolvable to `GoogleMapController` |
> **VALIDATION (2026-06-11) — KEEP (verified not redundant):** generic `require_dispose_implementation` (disposal_rules.dart:2109) uses a hardcoded _disposableTypes set that EXCLUDES GoogleMapController. GUARD: helper/mixin disposal bypasses local dispose()-body scan.
| `google_maps_completer_not_completed_on_dispose` | correctness | `Completer<GoogleMapController>` field used as the onMapCreated sink but not `.future.then(…controller.dispose())` (or equivalent await) in `dispose()` | report-only | WARNING | only fire when `Completer` static type param resolves to `GoogleMapController`; skip if an enclosing try/catch around dispose is already present |
| `google_maps_markers_rebuilt_in_build` | performance | `Set<Marker>` (or `Set<Polyline>`, `Set<Polygon>`, `Set<Circle>`) constructed with a set-literal or `{}.toSet()`/`.map(…).toSet()` directly inside a `build()` method body | report-only | WARNING | only fire when the enclosing method is `build(BuildContext)`; skip if the `Set` literal is `const {}` (empty and const-safe) |
| `google_maps_missing_initial_camera_position` | correctness | `GoogleMap(…)` constructor call where no `initialCameraPosition:` named argument is present | mechanical fix: insert `initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 1)` placeholder | ERROR | `initialCameraPosition` is `@required` — the Dart compiler enforces this at compile time; this rule catches it only if analysis somehow reaches it; primary value is as an early-warning + fix during editing |
> **VALIDATION (2026-06-11) — LOW VALUE:** `initialCameraPosition` is `required` so the analyzer already errors; rule only adds an editing-time fix.
| `google_maps_cloud_map_id_deprecated` | migration | `GoogleMap(cloudMapId: …)` named argument usage | mechanical fix: rename argument to `mapId:` | WARNING | only fire when the named argument label text is exactly `cloudMapId` inside a `GoogleMap` constructor call whose resolved type library URI starts with `package:google_maps_flutter` |
| `google_maps_set_map_style_deprecated` | migration | `GoogleMapController.setMapStyle(…)` method call | report-only | WARNING | resolve element to `GoogleMapController.setMapStyle`; library URI must start with `package:google_maps_flutter`; skip if the project's `google_maps_flutter` version is <2.6 (not yet deprecated there) |
> **VALIDATION (2026-06-11) — FIX API:** the in-rule "check pubspec version < 2.6" does NOT exist; route the version guard through the pack gate (`kRulePackDependencyGates`, rule_packs.dart:62). Detection (element → setMapStyle) is feasible.
| `google_maps_bitmap_descriptor_in_build` | performance | `BitmapDescriptor.fromAssetImage(…)` or `BitmapDescriptor.fromBytes(…)` called directly inside `build()` | report-only | WARNING | resolve element to the static methods on `BitmapDescriptor` in `package:google_maps_flutter`; only fire when enclosing method name is `build` with `BuildContext` param; skip if result is stored in a `static const` or `static final` field |
| `google_maps_unknown_map_id_error_unchecked` | correctness | `GoogleMapController` method calls (`showMarkerInfoWindow`, `hideMarkerInfoWindow`, `isMarkerInfoWindowShown`) not wrapped in `try`/`catch` — since 2.0 they throw `UnknownMapObjectIDError` on unknown IDs | report-only | INFO | resolve element to the specific method on `GoogleMapController`; skip if the enclosing expression is already inside a `try` block |
| `google_maps_animate_camera_in_build` | correctness | `GoogleMapController.animateCamera(…)` or `moveCamera(…)` called synchronously inside `build()` | report-only | ERROR | resolve element library URI; only fire when the enclosing method is `build(BuildContext)` |

---

## Rule detail

### `google_maps_controller_not_disposed`

- **What/why:** `GoogleMapController` holds a platform view handle and a stream subscription (fixed in early 2.x but the native view still requires explicit release). The `dispose()` method is documented as "Disposes of the platform resources." Leaving it uncalled causes a leaked platform view that keeps the native map surface alive, consuming memory and potentially causing `PlatformException` on the next map creation. Confirmed in GitHub issues [#35243](https://github.com/flutter/flutter/issues/35243), [#155340](https://github.com/flutter/flutter/issues/155340), [#139114](https://github.com/flutter/flutter/issues/139114).
- **Detection (AST, type-safe):** visit `ClassDeclaration` nodes that extend `State<…>`. Within the class, look for a field declaration whose static type resolves to `GoogleMapController` (library URI `package:google_maps_flutter/google_maps_flutter.dart`). If found, look for a `MethodDeclaration` named `dispose` in the same class. If `dispose` is absent, OR if `dispose` is present but contains no `MethodInvocation` whose `methodName.name == 'dispose'` on the same field's identifier, report at the field declaration.
- **Fix:** report-only. The correct disposal depends on whether the field is nullable, whether a `Completer` is used, and whether the controller is assigned asynchronously — a mechanical insertion would produce wrong code in the Completer pattern.
- **False positives:** (a) Classes that store the controller in a parent mixin that handles disposal — guard by checking if the field is declared locally, not inherited. (b) Classes that intentionally hold a long-lived controller (e.g., a singleton service) — skip if the enclosing class does not extend `State`.

---

### `google_maps_completer_not_completed_on_dispose`

- **What/why:** The idiomatic `onMapCreated` pattern is `final _controller = Completer<GoogleMapController>()`. Without calling `controller.dispose()` in the widget's `dispose()` override, the native map controller is leaked. The additional nuance is that the `Completer` itself may never complete if `dispose()` races with map creation — the fix must call `.future.then((c) => c.dispose())` unconditionally so it runs whenever the future resolves. Confirmed pattern in [flutter/flutter#74345](https://github.com/flutter/flutter/issues/74345) and [#141503](https://github.com/flutter/flutter/issues/141503).
- **Detection (AST, type-safe):** visit `ClassDeclaration` nodes extending `State<…>`. Find field declarations whose static type is `Completer<GoogleMapController>` (check the type argument's resolved element library URI). If found, check the `dispose()` method body for any call chain that resolves to `GoogleMapController.dispose` (the controller retrieved from the completer). If no such call exists, report at the completer field declaration.
- **Fix:** report-only. The safe disposal snippet is non-trivial (`_c.future.then((c) => c.dispose())`) and depends on the field name, which varies per file.
- **False positives:** (a) The completer may be wrapped in a helper mixin that owns disposal — check only locally-declared fields. (b) Tests and example files — skip via `ProjectContext.isTestFile`.

---

### `google_maps_markers_rebuilt_in_build`

- **What/why:** The `markers`, `polylines`, `polygons`, and `circles` parameters on `GoogleMap` accept `Set<T>`. When the `Set` is constructed inline in `build()`, a brand-new `Set` object is created on every frame. The platform-channel diff algorithm compares old vs new sets by value equality, which requires iterating the entire set — for hundreds of markers this blocks the UI thread noticeably. Best practice is to store the `Set` in `State` or a `ValueNotifier` and mutate it only when the underlying data changes. Confirmed performance issue in [#146041](https://github.com/flutter/flutter/issues/146041) and [Medium analysis of 150k markers](https://medium.com/@eraprimax/boosting-flutter-google-maps-performance-from-500-to-150-000-markers-with-partial-rendering-23ba15b15a3e).
- **Detection (AST, type-safe):** visit `MethodDeclaration` nodes where `name.lexeme == 'build'` and the single parameter type resolves to `BuildContext`. Within the body, find `SetOrMapLiteral` nodes (set literals `{…}`) or `MethodInvocation` nodes where `methodName.name` is `toSet` and the receiver's static type's `element.library.uri` starts with `dart:core`. For each, check whether the inferred static type is `Set<Marker>`, `Set<Polyline>`, `Set<Polygon>`, or `Set<Circle>` with the element library URI starting with `package:google_maps_flutter`. If the set is not `const` (empty set is fine), report.
- **Fix:** report-only. Moving marker state out of `build()` requires understanding the State class structure; a mechanical fix would be incorrect in too many cases.
- **False positives:** `const <Marker>{}` (an empty const set) is zero-overhead and should be excluded. Also skip if the set literal is directly assigned to a `static const` or `static final` — those aren't rebuilt.

---

### `google_maps_missing_initial_camera_position`

- **What/why:** `initialCameraPosition` is the sole `@required` parameter of the `GoogleMap` constructor. Omitting it is a compile error, but IDEs sometimes provide partial completions that generate incomplete constructor calls. Catching it at lint-time with an actionable fix gives the developer a starting-point camera position immediately rather than a bare compile error message.
- **Detection (AST, type-safe):** match `InstanceCreationExpression` where the resolved constructor element's enclosing library URI starts with `package:google_maps_flutter` and the class name is `GoogleMap`. Check `argumentList.arguments` for any `NamedExpression` with label `initialCameraPosition`. If absent, report on the constructor name.
- **Fix:** mechanical — insert `initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 1)` as a named argument. This is a placeholder the developer must update; the comment in the correction message says "Replace with your app's starting location."
- **False positives:** almost none — `initialCameraPosition` is declared `required` in the constructor so the analyzer already errors; this rule adds fix availability and a clearer message. Skip if the expression is in an `example*/` path.

---

### `google_maps_cloud_map_id_deprecated`

- **What/why:** `GoogleMap(cloudMapId: …)` was deprecated in the 2.x series in favor of `GoogleMap(mapId: …)`. The two are equivalent (the old getter literally returns `mapId`'s value), but `cloudMapId` will be removed in a future major version, and mixing both in the same call is asserted-against at runtime. Migration is mechanical — rename the argument label.
- **Detection (AST, type-safe):** match `InstanceCreationExpression` for `GoogleMap` (library URI `package:google_maps_flutter`). Inspect `argumentList.arguments` for a `NamedExpression` whose label text is `cloudMapId`. Report at the label.
- **Fix:** mechanical — replace the label `cloudMapId:` with `mapId:`. No changes to the value expression.
- **False positives:** near zero. The constructor assertion prevents both from being present simultaneously, so there is no ambiguity. The only edge case is a generated file that uses `cloudMapId` — skip files matching `*.g.dart` / `*.freezed.dart`.

---

### `google_maps_set_map_style_deprecated`

- **What/why:** `GoogleMapController.setMapStyle(jsonString)` was deprecated in version 2.6.0 in favor of passing the `style` parameter directly to the `GoogleMap` widget constructor. The new approach avoids the brief flash of the default style during map initialization. Continued use of `setMapStyle` is a migration debt that will become a breaking change in a future major.
- **Detection (AST, type-safe):** match `MethodInvocation` where `methodName.name == 'setMapStyle'` and the resolved method's enclosing class library URI starts with `package:google_maps_flutter`. Do NOT match bare-name: require that the target type resolves to `GoogleMapController`.
- **Fix:** report-only. Migrating requires adding `style:` to a `GoogleMap` widget that may not be in the same file, and potentially managing dynamic theme changes (a known complication — see [#144524](https://github.com/flutter/flutter/issues/144524)). A mechanical fix cannot safely handle dynamic style-toggling.
- **False positives:** (a) Projects using `google_maps_flutter` <2.6 where `setMapStyle` is NOT yet deprecated — use `ProjectContext` to check the pubspec dependency version and skip if <2.6.0. (b) Test doubles that shadow the name — type resolution prevents this if the enclosing library URI check is strict.

---

### `google_maps_bitmap_descriptor_in_build`

- **What/why:** `BitmapDescriptor.fromAssetImage(imageConfig, assetPath)` and `BitmapDescriptor.fromBytes(bytes)` are synchronous but involve data copying and object allocation. Calling them inside `build()` creates a new `BitmapDescriptor` on every rebuild, which causes the map platform channel to receive a new marker icon on each frame — triggering a native icon re-decode and a marker flicker (confirmed in [#147153](https://github.com/flutter/flutter/issues/147153) and [#41731](https://github.com/flutter/flutter/issues/41731)). Descriptors should be created once in `initState` or cached in a `static final` map.
- **Detection (AST, type-safe):** match `MethodInvocation` where `methodName.name` is `fromAssetImage` or `fromBytes`, the resolved static method's enclosing class is `BitmapDescriptor`, and the library URI starts with `package:google_maps_flutter`. Only fire when the enclosing `MethodDeclaration` is named `build` with a `BuildContext` parameter.
- **Fix:** report-only. Caching strategy (field, static map, provider, inherited widget) depends on app architecture.
- **False positives:** (a) `build()` methods in test files — skip via `ProjectContext.isTestFile`. (b) The async `BitmapDescriptor.asset()` variant is already discouraged in `build()` by the async constraint; this rule catches the synchronous variants only. (c) A `const` result (not possible for these methods — none are `const`) would be safe, but since no `const` constructors exist here, this case cannot arise.

---

### `google_maps_unknown_map_id_error_unchecked`

- **What/why:** Since `google_maps_flutter` 2.0.0 (null-safety migration), calling `showMarkerInfoWindow`, `hideMarkerInfoWindow`, or `isMarkerInfoWindowShown` with a `MarkerId` that does not correspond to a currently visible marker on the map throws `UnknownMapObjectIDError` instead of silently doing nothing. Code written for pre-2.0 that stores `MarkerId` references and calls these methods without a try/catch will crash at runtime when markers are removed, updated, or not yet added. Documented in the 2.0.0 breaking-change changelog entry.
- **Detection (AST, type-safe):** match `MethodInvocation` where `methodName.name` is `showMarkerInfoWindow`, `hideMarkerInfoWindow`, or `isMarkerInfoWindowShown`, and the resolved method's enclosing class library URI starts with `package:google_maps_flutter`. Walk the parent chain; if no ancestor is a `TryStatement` or the call is not inside a `catch` clause, report at the method name.
- **Fix:** report-only. A mechanical `try/catch` insertion would swallow real errors. The correct fix is either a guard that checks whether the marker exists in the current `markers` set, or a catch of `UnknownMapObjectIDError` specifically.
- **False positives:** code that is already inside an outer try/catch at a higher call level — walk the full parent chain up to the enclosing `FunctionBody`, not just the immediate parent.

---

### `google_maps_animate_camera_in_build`

- **What/why:** Calling `controller.animateCamera(…)` or `controller.moveCamera(…)` inside `build()` is a common misunderstanding of Flutter's rendering model. `build()` may be called many times per second (on every `setState`, layout, or parent rebuild). Calling `animateCamera` on each call causes an animation storm — rapid-fire platform-channel calls that queue behind each other, resulting in severe jank and potentially a `PlatformException` when the queue overflows. Camera manipulation must happen in response to user events or lifecycle callbacks, never in `build()`.
- **Detection (AST, type-safe):** match `MethodInvocation` where `methodName.name` is `animateCamera` or `moveCamera`, the resolved method's enclosing class library URI starts with `package:google_maps_flutter`, and the enclosing `MethodDeclaration` is named `build` with a single `BuildContext` parameter.
- **Fix:** report-only. The camera call needs to be moved to an event handler (button tap, `onMapCreated`, `initState`), which requires understanding the developer's intent.
- **False positives:** almost none — there is no valid reason to call `animateCamera` inside `build()`. Tests that wrap `build()` calls in a test harness would not call the real `GoogleMapController`.

---

## Implementation note

New file `lib/src/rules/packages/google_maps_flutter_rules.dart`; register all rule classes in `lib/saropa_lints.dart` `_allRuleFactories`; add all rule code names to an appropriate tier set in `lib/src/tiers.dart`.

**Suggested tier assignments:**

| rule_name | tier |
|---|---|
| `google_maps_controller_not_disposed` | `recommendedOnlyRules` |
| `google_maps_completer_not_completed_on_dispose` | `recommendedOnlyRules` |
| `google_maps_markers_rebuilt_in_build` | `recommendedOnlyRules` |
| `google_maps_missing_initial_camera_position` | `essentialRules` |
| `google_maps_cloud_map_id_deprecated` | `recommendedOnlyRules` |
| `google_maps_set_map_style_deprecated` | `professionalOnlyRules` |
| `google_maps_bitmap_descriptor_in_build` | `professionalOnlyRules` |
| `google_maps_unknown_map_id_error_unchecked` | `professionalOnlyRules` |
| `google_maps_animate_camera_in_build` | `essentialRules` |

**Detection library URI anchor:** every rule must verify the resolved element's enclosing library URI starts with `package:google_maps_flutter/` (NOT `package:google_maps_flutter_platform_interface/`). Use `element.library?.source.uri.toString().startsWith('package:google_maps_flutter/')` — this prevents false matches against the platform-interface layer and against unrelated classes that share method names.

**ProjectContext gate:** all rules must early-return when `!fileImportsPackage(node, {'package:google_maps_flutter/'})` (import_utils.dart:24) to avoid false positives in projects that do not depend on the package at all.

**Not lint-able (runtime-only concerns):**
- API key validity (runtime network error, not statically detectable).
- Map tile loading failures due to network — entirely runtime.
- Marker clustering configuration — no statically-checkable misuse pattern.
- `BitmapDescriptor.asset()` being called inside an async `initState` without `await` — distinguishable only with full data-flow analysis beyond standard AST visitor scope.

---

## Sources

- [GoogleMapController API docs — dispose() confirmed](https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/GoogleMapController-class.html)
- [GoogleMap widget constructor — initialCameraPosition required, cloudMapId deprecated](https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/GoogleMap-class.html)
- [google_maps_flutter changelog — setMapStyle deprecated 2.6.0, cloudMapId deprecated, 2.0 UnknownMapObjectIDError breaking change](https://pub.dev/packages/google_maps_flutter/changelog)
- [Memory leak issue #35243 — controller not disposed](https://github.com/flutter/flutter/issues/35243)
- [Memory leak issue #155340 — 2.9.0 memory leaks](https://github.com/flutter/flutter/issues/155340)
- [GoogleMapController lifecycle explanation request #74345](https://github.com/flutter/flutter/issues/74345)
- [Controller disposed before map ready #141503](https://github.com/flutter/flutter/issues/141503)
- [Markers flickering on setState #122401](https://github.com/flutter/flutter/issues/122401)
- [Markers flickering on rebuild #147153](https://github.com/flutter/flutter/issues/147153)
- [Performance drop loading markers from bytes #41731](https://github.com/flutter/flutter/issues/41731)
- [Imperative map updates feature request — confirms declarative Set diff cost #146041](https://github.com/flutter/flutter/issues/146041)
- [setMapStyle deprecated prevents theme toggling #144524](https://github.com/flutter/flutter/issues/144524)
- [150,000 markers performance analysis — confirms Set rebuild cost (Medium, Nov 2025)](https://medium.com/@eraprimax/boosting-flutter-google-maps-performance-from-500-to-150-000-markers-with-partial-rendering-23ba15b15a3e)
- [google_maps_flutter pub.dev package page — bounded widget requirement](https://pub.dev/packages/google_maps_flutter)
- [google_map.dart source — cloudMapId @Deprecated annotation verified](https://github.com/flutter/packages/blob/main/packages/google_maps_flutter/google_maps_flutter/lib/src/google_map.dart)


---

## Finish Report (2026-06-11)

## google_maps_flutter rules — validation reconciliation

Before writing, grepped `lib/src/rules/` for `google_maps_flutter` / `GoogleMap` / `GoogleMapController`. There is no existing `google_maps_flutter_rules.dart`, but two existing files carry load-bearing knowledge about the package:

- **`widget/widget_lifecycle_rules.dart:1368-1373`** — `GoogleMapController` is listed in a `_neverDisposeTypes` set, with a documented comment that the plugin manages its lifecycle and it must NOT be flagged for missing disposal.
- **`packages/firebase_rules.dart`** — only `GoogleMap(...)` examples in dartdoc; no rule logic. Not coverage.

### Proposals dropped (3 of 9)

| Proposed rule | Why dropped |
|---|---|
| `google_maps_controller_not_disposed` | Contradicts shipped policy — `widget_lifecycle_rules.dart` `_neverDisposeTypes` deliberately classifies `GoogleMapController` as never-dispose. The plan's VALIDATION note only checked `require_dispose_implementation`'s narrower list and missed this. A rule flagging this disposal would conflict head-on with a rule that says never flag it. |
| `google_maps_completer_not_completed_on_dispose` | Same conflict — the controller drained from the `Completer<GoogleMapController>` is the same never-dispose type. |
| `google_maps_missing_initial_camera_position` | Redundant with the analyzer: `initialCameraPosition` is `required`, so omission is already a compile error (`missing_required_argument`). Plan's own VALIDATION marks it LOW VALUE. |

### Rules kept (6)

| rule_name | tier | severity | fix | rationale |
|---|---|---|---|---|
| `google_maps_animate_camera_in_build` | recommended | ERROR | — | Crash/correctness: `animateCamera`/`moveCamera` in `build()` queues per-frame platform calls → jank + possible PlatformException. ERROR crash class → recommended. |
| `google_maps_cloud_map_id_deprecated` | recommended | WARNING | yes | Migration with a mechanical, safe label rename (`cloudMapId:` → `mapId:`); near-zero FP, so recommended despite WARNING. |
| `google_maps_markers_rebuilt_in_build` | professional | WARNING | — | Performance best-practice: per-frame `Set<Marker/Polyline/Polygon/Circle>` literal forces an O(n) value-equality diff each frame. Best-practice WARNING → professional. |
| `google_maps_set_map_style_deprecated` | professional | WARNING | — | Migration (deprecated 2.6.0); report-only because the replacement `style:` lives on a `GoogleMap` that may be in another file. In-rule version gate omitted per the plan note (route version gating through pack dependency gates). |
| `google_maps_bitmap_descriptor_in_build` | professional | WARNING | — | Performance: `BitmapDescriptor.fromAssetImage`/`fromBytes` in `build()` re-decodes the icon and flickers. Best-practice WARNING → professional. |
| `google_maps_unknown_map_id_error_unchecked` | comprehensive | INFO | — | Heuristic/INFO: unguarded info-window calls throw `UnknownMapObjectIDError` since 2.0; an outer guard may exist, so INFO → comprehensive. |

### Detection notes

- All six gate on `fileImportsPackage(node, PackageImports.googleMapsFlutter)` (constant added during merge).
- `build()` narrowing checks the method is named `build` AND takes a `BuildContext` param, stopping at any non-method function boundary so closures/event handlers (the GOOD path) are not matched.
- Method-call rules (`setMapStyle`, info-window, camera) require a receiver (`realTarget != null`) to avoid bare-name collisions with unrelated helpers.
- `markers_rebuilt` skips `isMap`, `const`, and untyped set literals; matches only `<Marker|Polyline|Polygon|Circle>{...}` typed literals.
- `cloudMapId` fix (`_RenameCloudMapIdFix extends ReplaceNodeFix`) preserves the value source and only rewrites the label.

### Files written

- `lib/src/rules/packages/google_maps_flutter_rules.dart` (6 rules + 1 fix)
- `example_packages/lib/google_maps_flutter/<rule>_fixture.dart` (6 fixtures, each with `bad()` + near-miss `good()`)
- `test/rules/packages/google_maps_flutter_rules_test.dart` (6 instantiation pins + 6 fixture-existence checks)

`dart analyze` on the rules file reports only the 6 expected `PackageImports.googleMapsFlutter` undefined-getter errors (resolved at merge); no other diagnostics. Shared files (import_utils, all_rules, saropa_lints, tiers, CHANGELOG) untouched per instructions.
