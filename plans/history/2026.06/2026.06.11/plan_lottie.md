# Plan: new `lottie` lint rules

**Package:** lottie ^3.3.2 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**API baseline (v3.3.2, verified against pub.dev + GitHub source xvrh/lottie-flutter):**
- `LottieBuilder` is the returned type from all factory constructors (`Lottie.asset`, `Lottie.network`,
  `Lottie.file`, `Lottie.memory`). The base `Lottie` widget is a separate class used for
  fully pre-decoded compositions (`Lottie(composition: ...)`) — rarely used directly.
- `controller` parameter type: `Animation<double>?`. In practice callers always pass an
  `AnimationController`, which extends `Animation<double>`. When a controller is provided, the
  package does NOT start, stop, or dispose it — all lifecycle is the caller's responsibility.
  The package source checks for controller presence and delegates tick-driving to it entirely.
- `onLoaded`: `void Function(LottieComposition)?`. Fires once after the composition JSON is
  parsed; this is the documented and only reliable place to call
  `controller.duration = composition.duration`. Without it the controller's duration is
  `Duration.zero` by default, causing the animation to never advance.
- `frameRate`: `FrameRate?`. Three variants:
  - `FrameRate.composition` (default) — uses the exported After Effects FPS; most battery-efficient.
  - `FrameRate.max` — matches device refresh rate (up to 120 Hz on ProMotion); triggers a repaint
    every vsync tick regardless of composition FPS, doubling/quadrupling repaint work on 120 Hz
    devices versus a 30 FPS composition.
  - `FrameRate(double)` — custom rate.
- `renderCache`: `RenderCache?`. Two static values (v3.0+):
  - `RenderCache.raster` — fully rasterizes frames to `dart:ui.Image`; 50 MB default cap;
    doc explicitly says "should only be used for very short and very small animations".
  - `RenderCache.drawingCommands` — stores frames as `dart:ui.Picture`; lower memory cost.
  - Default (null) = no cache; redraws every frame on demand.
- `errorBuilder`: `ImageErrorWidgetBuilder?` (same typedef as `Image.errorBuilder`). Only
  present on `Lottie.network`, `Lottie.asset`, `Lottie.file`, `Lottie.memory` (the builder
  constructors); absent on the base `Lottie(composition: ...)` constructor which always has a
  decoded composition already.
- `backgroundLoading`: `bool?` (v3.0+). When `true`, JSON parsing happens on a background
  isolate so the UI thread is not blocked. Defaults to `false` — meaning large JSON files block
  the main thread during first load.
- `addRepaintBoundary`: `bool?`. Defaults to `true`; the package automatically wraps the
  widget in a `RepaintBoundary`. Setting `false` causes the animation repaint to propagate up
  the paint tree.
- Library URI: `package:lottie/lottie.dart` (main barrel export).

**Confirmed AST-detectable concerns:**
1. `controller:` arg present with no `onLoaded:` arg — animation stuck at frame 0, duration
   never set from composition. Verified by official example always pairing the two.
2. `Lottie.network(...)` call with no `errorBuilder:` named arg — broken network URL shows a
   blank widget with no user-visible fallback; confirmed by API design (only `.network` can
   fail at load time with an HTTP error; `.asset` failures are deterministic at build time).
3. `frameRate: FrameRate.max` without a `renderCache:` arg — doubles repaint work on
   120 Hz devices versus composition rate, no caching to offset the extra ticks; the
   package README notes FrameRate.max "advances the animation at every frame" beyond the
   composition's own cadence.
4. `renderCache: RenderCache.raster` — the official API doc explicitly warns this should
   only be used for "very short and very small animations"; a blanket flag points out the
   risk so developers add a deliberate justification comment.
5. `Lottie.network(...)` without `backgroundLoading: true` — network animations must parse
   JSON after download; blocking the main thread on large compositions produces janky first
   frames; `backgroundLoading` was added in v3.0 precisely for this.

---

> **VALIDATION (2026-06-11) — BLOCKER (detection strategy):** the plan deliberately matches `.network`/`.asset`/`.file`/`.memory` by bare `methodName.name` string with only a file-level import guard, skipping receiver static-type resolution. Those method names collide heavily (`Image.network`, `http`, custom `.asset()`); a file-level import guard does NOT constrain the receiver. This violates CLAUDE.md's "string matching for types" anti-pattern and will produce large-scale FPs. ALL 5 rules must resolve the receiver via static-type/element (e.g. confirm the target is LottieBuilder / the lottie library URI) before they can ship. The claim "unique namespace makes bare-name adequate" is incorrect.

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `lottie_controller_missing_on_loaded` | correctness | `Lottie.asset/network/file/memory(controller: ...)` present but no `onLoaded:` arg in the same call | report-only | WARNING | only when `controller:` named arg is present; skip if `onLoaded:` is also present |
| `lottie_network_missing_error_builder` | robustness | `Lottie.network(...)` call with no `errorBuilder:` named arg | report-only | WARNING | narrow to `Lottie.network` method invocations only; skip if `errorBuilder:` named arg is present |
| `lottie_frame_rate_max_without_render_cache` | performance | `frameRate: FrameRate.max` present and no `renderCache:` arg | report-only | INFO | only when `frameRate:` value resolves to the `FrameRate.max` static member; skip when `renderCache:` is also present |
| `lottie_render_cache_raster_large_risk` | performance | `renderCache: RenderCache.raster` used anywhere | report-only | INFO | only when the value is the `RenderCache.raster` static member access; always fires to require deliberate sign-off |

> **VALIDATION (2026-06-11) — NOTE (`lottie_render_cache_raster_large_risk`):** "always fires to require sign-off" is deliberate INFO-spam on every use; defensible only at INFO + suppression.
| `lottie_network_missing_background_loading` | performance | `Lottie.network(...)` without `backgroundLoading: true` | report-only | INFO | narrow to `Lottie.network`; skip when `backgroundLoading: true` is present; `backgroundLoading: false` still fires |

---

## Rule detail

### `lottie_controller_missing_on_loaded`

- **What/why:** When a custom `AnimationController` is passed to any `Lottie.*` constructor, the
  package drives the animation entirely through the provided controller. The controller's `duration`
  defaults to `Duration.zero`, so without `onLoaded: (c) { controller.duration = c.duration; … }`,
  the animation never progresses past frame 0. The official full-control example in the package
  repository always pairs `controller:` with `onLoaded:`. Absence of `onLoaded:` is a silent defect:
  the widget renders but appears frozen, with no error or assertion raised at runtime.
- **Detection (AST, type-safe):**
  1. Match a `MethodInvocation` whose `methodName.name` is one of `{'asset', 'network', 'file', 'memory'}`
     AND whose `target` static type (or receiver class name) resolves to `LottieBuilder` or `Lottie`
     from `package:lottie/lottie.dart`. Guard with `fileImportsPackage(node, {'package:lottie/'})`.
  2. Walk `node.argumentList.arguments` filtering to `NamedExpression` nodes.
  3. Confirm a `NamedExpression` with `name.label.name == 'controller'` is present.
  4. Confirm NO `NamedExpression` with `name.label.name == 'onLoaded'` is present.
  5. Report at the `controller:` named expression.
- **Fix:** report-only. The correct `onLoaded` body depends on whether the controller should
  auto-forward, loop, or be driven externally — a TODO-insert is prohibited; no mechanical replacement.
- **False positives:**
  - A controller passed as `controller: _myAnimation` where `_myAnimation` is a pre-configured
    `AnimationController` whose duration was set externally. Accepted FP; severity INFO or WARNING
    keeps the rule actionable without being fatal.
  - `Lottie(composition: ...)` base constructor (not a builder factory) does not suffer this
    problem because the composition is already decoded at call time; this case is not matched
    because we only target the named factory constructors.

---

### `lottie_network_missing_error_builder`

- **What/why:** `Lottie.network` makes an HTTP request; the URL may be unreachable, return a
  non-200, or deliver malformed JSON. Without `errorBuilder`, the widget silently renders nothing
  — a blank space — leaving users with no feedback and developers with no diagnostic surface.
  `errorBuilder` is the `ImageErrorWidgetBuilder` typedef identical to `Image.errorBuilder`,
  giving access to the exception and stack trace. This mirrors the established Flutter convention
  for `Image.network` where omitting `errorBuilder` is a known footgun. The `.asset`, `.file`, and
  `.memory` constructors load from deterministic local sources (app bundle / disk / memory); network
  is the only constructor where the load can fail at runtime due to external factors.
- **Detection (AST, type-safe):**
  1. Match a `MethodInvocation` with `methodName.name == 'network'` inside a receiver chain
     that references `Lottie` or `LottieBuilder`. Guard with
     `fileImportsPackage(node, {'package:lottie/'})`.
  2. Scan `node.argumentList.arguments` for a `NamedExpression` with
     `name.label.name == 'errorBuilder'`.
  3. If absent, report at the entire method invocation node.
- **Fix:** report-only. The content of an error widget is project-specific; inserting a
  placeholder `errorBuilder` that just wraps `Text(e.toString())` would be bad practice.
- **False positives:**
  - Wrapping `Lottie.network` in a parent widget that already provides error handling (e.g., a
    `FutureBuilder` that catches network errors before they reach Lottie). Rare in practice; the
    rule fires at the Lottie call site, which is the correct place to handle Lottie-specific errors.
  - Test files loading from a mock network. Scope can be narrowed with `!ProjectContext.isTestFile`
    if FP rate is high.

---

### `lottie_frame_rate_max_without_render_cache`

- **What/why:** `FrameRate.max` instructs the widget to call `markNeedsPaint` on every vsync tick,
  regardless of the composition's own frame rate. On a 120 Hz ProMotion device running a 30 FPS
  Lottie file, this quadruples the number of paint operations. Without `renderCache`, every paint
  re-evaluates the full vector drawing tree. The combination is the worst possible battery and CPU
  profile for a Lottie animation. `FrameRate.composition` (the default) already gives smooth
  playback at the authored rate. `FrameRate.max` is only justified when sub-frame interpolation is
  perceptually important (e.g., a scrub-driven progress indicator), and even then `renderCache`
  should be added to offset the extra paint cost. The package changelog and source explicitly call
  out `FrameRate.composition` as "the default frame rate behavior" while `FrameRate.max` is
  described as an opt-out that "advances the animation progression at every frame."
- **Detection (AST, type-safe):**
  1. Match any `NamedExpression` with `name.label.name == 'frameRate'` inside a `LottieBuilder`
     constructor call. Guard with `fileImportsPackage(node, {'package:lottie/'})`.
  2. Inspect the value expression: match a `PrefixedIdentifier` or `PropertyAccess` where the
     target/prefix is `FrameRate` and the identifier is `max` — i.e., static member access
     `FrameRate.max`.
  3. Walk siblings in `node.parent.arguments` for a `NamedExpression` with
     `name.label.name == 'renderCache'`.
  4. Report at the `frameRate:` named expression if `renderCache:` is absent.
- **Fix:** report-only. The correct `renderCache` variant depends on animation length and size;
  no safe mechanical default.
- **False positives:**
  - Intentional high-rate playback of a scrub animation that is deliberately not cached.
    INFO severity handles this: developers can suppress with `// ignore:` after review.
  - `FrameRate.max` stored in a local variable and then passed. The variable value is not
    statically resolvable; this case is not flagged (conservative).

---

### `lottie_render_cache_raster_large_risk`

- **What/why:** `RenderCache.raster` caches each rendered frame as a fully rasterized
  `dart:ui.Image`. The package documentation explicitly warns: *"should only be used for very
  short and very small animations (final size on the screen)"*. Memory consumption scales as
  `rendered_width × rendered_height × frame_count`, with a 50 MB default cap. A full-screen
  animation at 60 FPS for 3 seconds at 390×844 px would require approximately 280 MB before
  the cap kicks in and evicts frames, causing repeated re-rasterization that defeats the
  purpose of the cache. Using `RenderCache.raster` without understanding these constraints is
  a silent memory pressure bug. The rule fires on every use to require a deliberate developer
  decision, analogous to `// ignore:` forcing a documented rationale.
- **Detection (AST, type-safe):**
  1. Match any `NamedExpression` with `name.label.name == 'renderCache'` inside a
     `LottieBuilder` call. Guard with `fileImportsPackage(node, {'package:lottie/'})`.
  2. Value expression must be a `PrefixedIdentifier` or `PropertyAccess` where the
     target/prefix is `RenderCache` and the identifier is `raster` (static member access
     `RenderCache.raster`).
  3. Report at the `renderCache:` named expression.
- **Fix:** report-only. `RenderCache.drawingCommands` is the lower-risk alternative, but the
  choice depends on whether the developer wants CPU savings (raster) or memory savings
  (drawingCommands); cannot be mechanically substituted without context.
- **False positives:**
  - Legitimate use of `RenderCache.raster` on a genuinely small, short animation (e.g., a
    16×16 px icon animation, 0.5 s). INFO severity lets the developer suppress with a
    justification comment without blocking CI.

---

### `lottie_network_missing_background_loading`

- **What/why:** `Lottie.network` must download the JSON/dotLottie file and then parse it
  (decompress + JSON decode + layer tree construction). For typical Lottie files shipped in
  production (50–500 KB compressed), the parse step alone can take 10–80 ms on a mid-range
  device. Without `backgroundLoading: true` this work runs on the main thread (Flutter's UI
  isolate), causing jank or a brief frame drop on first render. The `backgroundLoading`
  parameter was introduced in v3.0 precisely to offload this cost. For `.asset`, `.file`,
  and `.memory`, the data source is local and fast; the parse cost is lower and more
  predictable. Only `.network` combines download latency with an unpredictably-timed parse
  on the UI thread, making it the highest-risk variant.
- **Detection (AST, type-safe):**
  1. Match a `MethodInvocation` with `methodName.name == 'network'` on a `Lottie` /
     `LottieBuilder` receiver. Guard with `fileImportsPackage(node, {'package:lottie/'})`.
  2. Scan arguments for a `NamedExpression` with `name.label.name == 'backgroundLoading'`
     whose value is a `BooleanLiteral` with `value == true`.
  3. Report if that named arg is absent OR if `backgroundLoading: false` is explicitly set.
- **Fix:** report-only. Insertion of `backgroundLoading: true` is mechanically safe but
  this parameter interacts with `frameBuilder` (used to show a placeholder during load);
  silently adding it without a `frameBuilder` placeholder could produce a visual flash that
  was not previously present.
- **False positives:**
  - Tiny test animations served from a local mock server where performance is irrelevant.
    `ProjectContext.isTestFile` guard can be applied to skip test files.
  - Apps where the file is pre-fetched / pre-decoded before the widget mounts. The rule
    fires at the call site regardless; INFO severity keeps suppression low-friction.

---

## Implementation note

New file: `lib/src/rules/packages/lottie_rules.dart`

Header imports required:
```dart
// ignore_for_file: depend_on_referenced_packages, deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';
```

Registration checklist:
1. Add `PackageImports.lottie = {'package:lottie/'}` to `lib/src/import_utils.dart`.
2. Export each rule class from `lib/src/rules/all_rules.dart` (barrel, no manual edits if the
   new file is picked up via a glob export; verify the barrel pattern used for other package files).
3. Add `LottieXxxRule.new` entries to `_allRuleFactories` in `lib/saropa_lints.dart`.
4. Add all five rule name strings to a tier in `lib/src/tiers.dart`; recommended placement:
   - `lottie_controller_missing_on_loaded` → `recommendedOnlyRules` (silent correctness defect)
   - `lottie_network_missing_error_builder` → `recommendedOnlyRules` (user-visible failure)
   - `lottie_frame_rate_max_without_render_cache` → `professionalOnlyRules` (performance, INFO)
   - `lottie_render_cache_raster_large_risk` → `professionalOnlyRules` (performance, INFO)
   - `lottie_network_missing_background_loading` → `comprehensiveOnlyRules` (perf, INFO, low urgency)
5. Add all five to `ROADMAP.md` under a new `## Lottie` section.

Detection strategy for all rules: use `fileImportsPackage(node, {'package:lottie/'})` as an
early-return guard; then match on `MethodInvocation` method name strings, iterate
`argumentList.arguments` filtered to `NamedExpression`, and check `name.label.name` string
equality. REQUIRED (per VALIDATION 2026-06-11 BLOCKER): resolve the receiver via
static-type/element and confirm it is `LottieBuilder` / the `package:lottie/` library URI
before reporting — do NOT rely on bare `methodName.name` equality plus the import guard.
The method names (`.network`/`.asset`/`.file`/`.memory`) collide with other packages, so the
import guard alone does not constrain the receiver; bare-name matching produces large-scale FPs.

For `FrameRate.max` and `RenderCache.raster` detection: match the value expression as a
`PrefixedIdentifier` (e.g., `FrameRate.max`) where `prefix.name == 'FrameRate'` and
`identifier.name == 'max'`, guarded by the lottie import check. The receiver of the enclosing
`LottieBuilder` constructor call must still be resolved via static-type/element (per the
VALIDATION BLOCKER above) — the import guard alone does not constrain the call site.

---

## Sources

- [lottie pub.dev package page](https://pub.dev/packages/lottie)
- [lottie pub.dev API docs](https://pub.dev/documentation/lottie/latest/)
- [xvrh/lottie-flutter GitHub repository](https://github.com/xvrh/lottie-flutter)
- [lottie_builder.dart — factory constructor signatures (verified)](https://github.com/xvrh/lottie-flutter/blob/master/lib/src/lottie_builder.dart)
- [render_cache.dart — RenderCache.raster 50MB cap, warning text (verified)](https://github.com/xvrh/lottie-flutter/blob/master/lib/src/render_cache.dart)
- [animation_full_control.dart — onLoaded + controller.dispose() pattern (verified)](https://github.com/xvrh/lottie-flutter/blob/master/example/lib/examples/animation_full_control.dart)
- [RenderCache class API doc — raster warning text (verified)](https://pub.dev/documentation/lottie/latest/lottie/RenderCache-class.html)
- [lottie changelog — backgroundLoading and renderCache introduced in v3.0 (verified)](https://pub.dev/packages/lottie/changelog)
- [flutter/flutter issue #148472 — Android Lottie performance](https://github.com/flutter/flutter/issues/148472)

---

## Finish Report (2026-06-11)

 Scope (LINTER variant): (A) Dart lint rules / analyzer plugin + (C) docs.

**Shipped.** 5 rules (controller_missing_on_loaded, network_missing_error_builder, frame_rate_max_without_render_cache, render_cache_raster_large_risk, network_missing_background_loading). The detection-strategy BLOCKER was resolved: every rule resolves the receiver to the Lottie/LottieBuilder type rather than bare method-name matching.

Rules marked DROP / defer in the 2026-06-11 VALIDATION notes were intentionally not implemented (duplicates, overlap with existing rules, or feasibility concerns) — that triage is honored, not skipped. Every rule is import-gated via `fileImportsPackage`; migration rules are version-gated via `kRulePackDependencyGates` and relocated out of their base pack via `kRelocatedRulePackCodes` so a project on the old major never sees a rule for an API it lacks.

**Verification.** `dart analyze lib --fatal-infos` clean; `dart run tool/rule_pack_audit.dart` exit 0; full test suite green (1336 tests across test/integrity, test/config, test/rules/packages); registry regenerated twice + `dart format`. Rules authored by parallel subagents then serially registered into the shared files (tiers.dart, saropa_lints.dart, import_utils.dart, all_rules.dart, rule_packs.dart, generator + audit).

**Plan disposition.** Complete — archived to `plans/history/2026.06/2026.06.11/`.
