# Plan: new `flutter_map` lint rules

**Package:** flutter_map ^8.3.0 (Saropa Contacts)
**saropa_lints coverage:** none (new file — `lib/src/rules/packages/flutter_map_rules.dart`)
**Status:** draft — pending implementation

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `flutter_map_missing_user_agent` | correctness | `TileLayer(...)` instance creation without `userAgentPackageName` named argument | yes — inserts `userAgentPackageName: 'com.example.app'` stub | WARNING | Only fires when `urlTemplate` contains an OSM domain (`tile.openstreetmap.org`) or is absent; skip when `tileProvider` is an `AssetTileProvider` or `FileTileProvider` literal |
| `flutter_map_undisposed_controller` | resource-leak | `MapController()` constructed in a `State` class body without a matching `dispose()` call | no | WARNING | Only fires in `State<T>` subclasses; skips if the variable is passed to a `dispose()` call anywhere in the same class |
| `flutter_map_deprecated_tile_size` | migration | `TileLayer(tileSize: ...)` — `tileSize` was deprecated in v8.0 in favor of `tileDimension` | yes — replaces `tileSize: <double>` with `tileDimension: <int>` | INFO | None — pure deprecation; `tileSize` still compiles, so no crash risk |
| `flutter_map_legacy_map_options_center` | migration | `MapOptions(center: ..., zoom: ...)` — `center`/`zoom`/`bounds`/`rotation` were removed in v6 and replaced by `initialCenter`/`initialZoom`/`initialCameraFit`/`initialRotation` | yes — renames the argument labels | WARNING | Only fires when the named argument label is literally `center:` or `zoom:` inside a `MapOptions(...)` constructor call; skips renamed/new arg labels |
| `flutter_map_missing_error_tile_callback` | robustness | `TileLayer(...)` without an `errorTileCallback` or `fallbackUrl` argument | no | INFO | Skips when `tileProvider` is `AssetTileProvider`/`FileTileProvider` (failure modes differ); skips test files |
| `flutter_map_deprecated_polygon_label_placement` | migration | `Polygon(labelPlacement: PolygonLabelPlacement.xxx)` — deprecated in v8.2 in favor of `labelPlacementCalculator` | yes — replaces with the documented equivalent `PolygonLabelPlacementCalculator` object | INFO | Only fires on `Polygon(...)` constructor calls with the `labelPlacement:` named argument |
| `flutter_map_fallback_url_disables_cache` | correctness | `TileLayer(fallbackUrl: ..., tileProvider: NetworkTileProvider(...))` — documented: specifying any `fallbackUrl` silently disables in-memory tile caching for `NetworkTileProvider` | no | INFO | Only fires when `tileProvider` is (or defaults to) a `NetworkTileProvider`; skips asset/file providers where the concern is different |

---

## Rule detail

### `flutter_map_missing_user_agent`

**What/why:** OpenStreetMap's tile servers identify application traffic via the HTTP `User-Agent` header. When `userAgentPackageName` is omitted, flutter_map sends `User-Agent: flutter_map (unknown)`. In May 2025, OSM observed >99 million daily tile requests from unidentified apps and blocked all traffic using the `unknown` identifier. Apps that ship without a real package name have their tiles silently fail in production on non-web platforms.

**Detection (AST):** Register on `InstanceCreationExpression`. Check that the static type's library URI starts with `package:flutter_map/` and the constructor element name is `TileLayer`. Then check the `argumentList` for the presence of a named argument with label `userAgentPackageName`. If absent, report at the node. Additionally, suppress when the `tileProvider` argument resolves to an `AssetTileProvider` or `FileTileProvider` instance (those never make HTTP requests).

**Fix:** Insert `userAgentPackageName: 'com.example.app'` as a new named argument. The fix is a stub — the developer must replace the placeholder with their real bundle ID. The fix message must say "Insert userAgentPackageName — replace 'com.example.app' with your app's bundle identifier".

**False positives:** Web platform apps — Dart cannot set the `User-Agent` header on web (browser restriction), so the parameter has no effect there. However, the same `TileLayer` widget code runs on all platforms, and the fix is harmless on web. Accept the minor over-fire rather than attempting platform-conditional AST detection (speculative — no reliable AST-visible platform guard exists at the call site).

---

### `flutter_map_undisposed_controller`

> **VALIDATION (2026-06-11) — CONDITIONAL DROP:** MapController extends ChangeNotifier, so `require_change_notifier_dispose` (disposal_rules.dart:1351) may already fire IF it walks the supertype chain. Verify that rule's detection before implementing — likely drop-for-overlap.

**What/why:** `MapController` extends `ValueNotifier<_MapControllerState>` (via `MapControllerImpl`), which extends `ChangeNotifier`. Failing to call `dispose()` leaks the notifier's listener list. GitHub issue #1892 documents lifecycle bugs when a `MapController` created externally is not disposed when the owning widget is destroyed — the controller retains internal stream subscriptions that cannot be garbage-collected.

**Detection (AST):** Register on `ClassDeclaration`. Check that the class has `State` in its superclass chain (via `extendsClause` / `implementsClause` resolved element). Within the class body, collect all `VariableDeclaration` nodes whose initializer is an `InstanceCreationExpression` whose static type's library URI starts with `package:flutter_map/` and whose constructor element is `MapController`. For each such variable, check whether any `MethodDeclaration` named `dispose` in the same class body contains a `MethodInvocation` on that variable name with method name `dispose`. If no such call exists, report at the variable declaration.

**Fix:** No automated fix — inserting disposal requires knowing the correct location in an existing or new `dispose()` override, which is too context-sensitive to do mechanically without risk of breaking existing disposal chains.

**False positives:** `MapController` created via `MapController.of(context)` (static factory) should not be reported — the caller does not own the instance. Only flag variables initialized with `MapController()` (the default constructor) to limit ownership-assumption errors.

---

### `flutter_map_deprecated_tile_size`

**What/why:** `TileLayer.tileSize` (a `double`) was deprecated in v8.0.0 and replaced by `tileDimension` (an `int`). The change was made to enforce integer tile dimensions, matching the actual pixel dimensions of tile images. Using `tileSize` still compiles but generates a deprecation warning and will be removed in a future version.

**Detection (AST):** Register on `InstanceCreationExpression` for `TileLayer`. Check the `argumentList` for a named argument with label `tileSize`. If found, report at that argument.

**Fix:** Replace the named argument label `tileSize` with `tileDimension`. If the value expression is a `DoubleLiteral` (e.g. `256.0`), convert it to an `IntegerLiteral` (e.g. `256`) as part of the same edit. If it's an arbitrary expression, apply the label rename only and leave the value for the developer.

**False positives:** None — `tileSize` is only meaningful on `TileLayer` from `package:flutter_map/`.

---

### `flutter_map_legacy_map_options_center`

**What/why:** In v6.0.0 (breaking), `MapOptions` removed the `center`, `zoom`, `bounds`, and `rotation` constructor parameters and replaced them with `initialCenter`, `initialZoom`, `initialCameraFit`, and `initialRotation`. Code using the old names fails to compile on v6+. Because Saropa Contacts is on ^8.3.0, any dependency that bundles its own flutter_map widget code on the old API will fail at compile time. This rule is most useful as a migration guard during upgrades — it helps codebases that copy-pasted old tutorial code.

**Detection (AST):** Register on `InstanceCreationExpression` where the static type library URI starts with `package:flutter_map/` and the constructor element name is `MapOptions`. Walk the `argumentList` for named arguments with labels matching: `center`, `zoom`, `bounds`, `rotation`. Report each offending argument label.

**Fix:** Rename:
- `center:` → `initialCenter:`
- `zoom:` → `initialZoom:`
- `rotation:` → `initialRotation:`
- `bounds:` → `initialCameraFit:` (note: the value type also changes — `LatLngBounds` → `CameraFit.bounds(bounds: ...)` — so for `bounds`, emit the label rename only and add a correction message instructing the developer to wrap the value in `CameraFit.bounds()`).

**False positives:** None for the label rename itself; the `bounds` fix is intentionally conservative (label only) to avoid mangling the value expression.

---

### `flutter_map_missing_error_tile_callback`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** fires on the majority of real TileLayer uses (most apps set neither errorTileCallback nor fallbackUrl); thin guard, pedantic tier is the only mitigation.

**What/why:** When a tile request fails (network timeout, 404, server error), flutter_map calls `errorTileCallback` if provided. Without it, errors are silently swallowed and users see a blank tile grid. Similarly, `fallbackUrl` allows specifying a secondary tile server. Both are optional but their absence is a common cause of confusing "blank map" production bugs, especially on mobile where network conditions are unpredictable.

**Detection (AST):** Register on `InstanceCreationExpression` for `TileLayer`. If neither `errorTileCallback` nor `fallbackUrl` named arguments are present, report at the node. Suppress when a `tileProvider` argument resolves to `AssetTileProvider` or `FileTileProvider` (these do not make network requests and have different failure modes).

**Fix:** No automated fix — the correct handler is application-specific.

**False positives:** `AssetTileProvider` / `FileTileProvider` cases (guarded). Test files (suppress via `ProjectContext.isTestFile`).

---

### `flutter_map_deprecated_polygon_label_placement`

> **VALIDATION (2026-06-11) — FEASIBILITY (fix):** the replacement names (PolygonLabelPlacementCalculator.polylabel()) are self-flagged speculative/unverified against the v8.2 API; detection is fine, verify the fix strings.

**What/why:** In v8.2.0, `Polygon.labelPlacement` (using the `PolygonLabelPlacement` enum) was deprecated in favor of `Polygon.labelPlacementCalculator` (using `PolygonLabelPlacementCalculator`). The new system is extensible and uses an improved "signed area centroid" algorithm as the default. Old enum values still compile but the annotation indicates they will be removed.

**Detection (AST):** Register on `InstanceCreationExpression` for `Polygon` (library URI starts with `package:flutter_map/`). Check for a named argument with label `labelPlacement`. If found, report.

**Fix:** Rename the argument label from `labelPlacement:` to `labelPlacementCalculator:` and replace enum value references:
- `PolygonLabelPlacement.centroid` → `PolygonLabelPlacementCalculator.centroid()`
- `PolygonLabelPlacement.polylabel` → `PolygonLabelPlacementCalculator.polylabel()` (speculative — verify exact new name against v8.2 API)
- `PolygonLabelPlacement.centroidWithMultiWorld` → `PolygonLabelPlacementCalculator.simpleMultiWorldCentroid()` (verified name per v8.2 docs)

**False positives:** None; `labelPlacement` named arg only appears on `flutter_map`'s `Polygon`.

---

### `flutter_map_fallback_url_disables_cache`

> **VALIDATION (2026-06-11) — NOTE:** the "absent tileProvider = NetworkTileProvider default" branch is the common case and will fire widely.

**What/why:** The `NetworkTileProvider` documentation states: "Specifying any `fallbackUrl` (even if it is not used) in the `TileLayer` will prevent loaded tiles from being cached in memory." This is a non-obvious performance footgun — developers add `fallbackUrl` for resilience and unknowingly eliminate the in-memory tile cache, doubling network traffic and increasing render latency on slow connections.

**Detection (AST):** Register on `InstanceCreationExpression` for `TileLayer`. Check that `fallbackUrl` is present as a named argument. Then check the `tileProvider` argument: if it is absent (default is `NetworkTileProvider`) or resolves to a `NetworkTileProvider` instance creation, report at the `fallbackUrl` argument node.

**Fix:** No automated fix — the developer must decide whether to remove `fallbackUrl`, switch to a `CancellableNetworkTileProvider`-style approach, or accept the cache trade-off. The correction message should state: "fallbackUrl disables in-memory tile caching for NetworkTileProvider; consider whether the resilience trade-off is acceptable."

**False positives:** `AssetTileProvider` / `FileTileProvider` — guarded by checking `tileProvider`. The issue only affects `NetworkTileProvider`.

---

## Implementation note

**New file:** `lib/src/rules/packages/flutter_map_rules.dart`

**Registration:**
1. Add `MyRule.new` entries to `_allRuleFactories` in `lib/saropa_lints.dart` (~line 157)
2. Add rule codes to a tier set in `lib/src/tiers.dart`

**Tier assignments (recommended):**
- `flutter_map_missing_user_agent` → `comprehensiveOnlyRules` (WARNING — high real-world impact, not universally applicable)
- `flutter_map_undisposed_controller` → `recommendedOnlyRules` (WARNING — resource leak)
- `flutter_map_deprecated_tile_size` → `comprehensiveOnlyRules` (INFO — pure deprecation)
- `flutter_map_legacy_map_options_center` → `professionalOnlyRules` (WARNING — compile-break migration)
- `flutter_map_missing_error_tile_callback` → `pedanticOnlyRules` (INFO — good practice, not critical)
- `flutter_map_deprecated_polygon_label_placement` → `comprehensiveOnlyRules` (INFO — deprecation)
- `flutter_map_fallback_url_disables_cache` → `professionalOnlyRules` (INFO — silent perf footgun)

**Migration rules note:** `flutter_map_legacy_map_options_center`, `flutter_map_deprecated_tile_size`, and `flutter_map_deprecated_polygon_label_placement` are candidates for a `flutter_map_6` / `flutter_map_8` migration pack per `plans/plan_migration_plugin_system.md §2`. The v6 rename (`center`→`initialCenter`) is version-gated at `>=6.0.0 <9.0.0`; the v8 deprecations (`tileSize`, `labelPlacement`) are gated at `>=8.0.0`. Add each to `kRulePackDependencyGates` in `lib/src/config/rule_packs.dart` when implementing.

**Library URI guard (all rules):** All type-resolution checks MUST use:
```dart
element.library?.uri.toString().startsWith('package:flutter_map/')
```
Never match on bare class name strings (e.g. `contains('TileLayer')`) — that would fire on any class named `TileLayer` in any package.

---

## Sources

- [flutter_map pub.dev changelog](https://pub.dev/packages/flutter_map/changelog) — v6 and v8 breaking changes, deprecations
- [TileLayer class — Dart API](https://pub.dev/documentation/flutter_map/latest/flutter_map/TileLayer-class.html) — constructor parameters, `tileSize` deprecation, `tileDimension`
- [MapController class — Dart API](https://pub.dev/documentation/flutter_map/latest/flutter_map/MapController-class.html) — `dispose()` method confirmation
- [MapControllerImpl class — Dart API](https://pub.dev/documentation/flutter_map/latest/flutter_map/MapControllerImpl-class.html) — extends `ValueNotifier<_MapControllerState>` (ChangeNotifier)
- [MapOptions class — Dart API](https://pub.dev/documentation/flutter_map/latest/flutter_map/MapOptions-class.html) — `initialCenter`, `initialZoom`, `initialCameraFit`, `cameraConstraint`
- [Using OpenStreetMap (direct) — flutter_map docs](https://docs.fleaflet.dev/tile-servers/using-openstreetmap-direct) — `userAgentPackageName` policy, 99M+ daily unidentified requests, OSM blocking
- [Tile Layer — flutter_map docs](https://docs.fleaflet.dev/layers/tile-layer) — `userAgentPackageName` description, `fallbackUrl` cache-disabling behavior
- [Tile Providers — flutter_map docs](https://docs.fleaflet.dev/layers/tile-layer/tile-providers) — `NetworkTileProvider` `fallbackUrl` disables cache
- [What's New in v8.2 — flutter_map docs](https://docs.fleaflet.dev/getting-started/new-in-v8) — `tileDimension`, `PolygonLabelPlacementCalculator` deprecation
- [GitHub issue #1892 — MapController lifecycle not synced](https://github.com/fleaflet/flutter_map/issues/1892) — MapController disposal lifecycle bugs
- [GitHub issue #1292 — User-Agent header](https://github.com/fleaflet/flutter_map/issues/1292) — OSM tile policy, `userAgentPackageName` rationale

---

## Finish Report (2026-06-11)

### Validation reconciliation

Grepped the whole `lib/src/rules/` tree for `flutter_map`, `MapController`, `ChangeNotifier`, and `require_change_notifier_dispose` before writing any rule.

**Existing coverage found:**
- `require_field_dispose` (widget_lifecycle_rules.dart) lists `MapController` in its `_neverDisposeTypes` set. The repo deliberately treats `MapController` as a controller that does NOT require manual disposal because flutter_map manages its lifecycle through the `FlutterMap` widget.

**Dropped:**
- `flutter_map_undisposed_controller` — DROPPED. The plan flagged this as a CONDITIONAL DROP. `MapController` is explicitly curated into `_neverDisposeTypes` in `require_field_dispose`. Adding an undisposed-controller rule would directly contradict that existing decision and produce conflicting guidance for the same type. (No separate `require_change_notifier_dispose` rule walks the supertype chain to MapController either — the curated never-dispose list is the single source of truth.)

All other 6 proposed rules are genuinely new (flutter_map had zero dedicated rule coverage) and not subsumed by a generic rule. Detection is constructor-name + `fileImportsPackage(PackageImports.flutterMap)` gated; no string-`contains` type matching.

### Kept rules

| rule_name | class | tier | severity | fix |
|---|---|---|---|---|
| `flutter_map_missing_user_agent` | FlutterMapMissingUserAgentRule | recommended | WARNING | no |
| `flutter_map_legacy_map_options_center` | FlutterMapLegacyMapOptionsCenterRule | professional | WARNING | yes (label rename) |
| `flutter_map_fallback_url_disables_cache` | FlutterMapFallbackUrlDisablesCacheRule | professional | INFO | no |
| `flutter_map_deprecated_tile_size` | FlutterMapDeprecatedTileSizeRule | comprehensive | INFO | yes (label rename + double→int) |
| `flutter_map_deprecated_polygon_label_placement` | FlutterMapDeprecatedPolygonLabelPlacementRule | comprehensive | INFO | no |
| `flutter_map_missing_error_tile_callback` | FlutterMapMissingErrorTileCallbackRule | pedantic | INFO | no |

### Tier reasoning

- `flutter_map_missing_user_agent` → **recommended**: WARNING with real production impact (OSM blocks unidentified traffic → tiles fail). Promoted from the plan's comprehensive suggestion because a blocked map is a crash-class user-facing failure, fitting the "ERROR/correctness → recommended" guidance even at WARNING severity.
- `flutter_map_legacy_map_options_center` → **professional**: WARNING migration guard for a v6 compile break.
- `flutter_map_fallback_url_disables_cache` → **professional**: INFO silent perf footgun worth surfacing in a stricter-than-default tier.
- `flutter_map_deprecated_tile_size` → **comprehensive**: INFO pure deprecation.
- `flutter_map_deprecated_polygon_label_placement` → **comprehensive**: INFO deprecation.
- `flutter_map_missing_error_tile_callback` → **pedantic**: INFO best-practice that fires on the majority of real TileLayer uses (thin guard); pedantic is the correct opt-in home per the plan's GUARD-NEEDED validation note.

### Notes on the polygon fix

The plan self-flagged the v8.2 `PolygonLabelPlacementCalculator` constructor names as speculative/unverified. Rather than ship an unverified rename fix, `flutter_map_deprecated_polygon_label_placement` ships detection-only (no quick fix). The dartdoc/correction message names the replacement API direction without asserting exact constructor names.

### Files written (non-shared)

- `lib/src/rules/packages/flutter_map_rules.dart` — 6 rule classes + 2 ReplaceNodeFix subclasses.
- `example_packages/lib/flutter_map/*_fixture.dart` — 6 fixtures (one per kept rule).
- `test/rules/packages/flutter_map_rules_test.dart` — 6 instantiation pins + 6 fixture-existence checks.

`dart analyze` on the rules file reports only the 6 expected `PackageImports.flutterMap` undefined-getter errors (resolved at merge); no other issues.
