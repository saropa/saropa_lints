# Internalize `ren` feature-gravity into saropa_lints (rules + dashboard)

**Trigger:** The user asked to review the external project `https://github.com/gearscrafter/ren`
(a Flutter "feature gravity" performance analyzer), then said: *"need to internalize the
feature into the appropriate lint rules and screens. obviously apply all the corrections
needed and you write the code."* The user chose (via AskUserQuestion) to **extend the existing
Project Health dashboard** rather than build a new one.

`ren`'s real insight is **compound** performance detection — a widget is expensive because of
its parent (e.g. `Opacity` inside `AnimatedBuilder`). Its flaws (which "apply all corrections"
required fixing): presence-only over-reporting, and a feature-gravity score that **divided by
file count** so adding harmless files lowered the score (demonstrated: ren dropped a single
catastrophic pattern from 29%/MEDIUM to 6%/LOW after 4 empty files were added).

## Finish Report (2026-06-09)

### Scope
(A) Dart lint rules + analyzer plugin, plus the `project_health` CLI / dashboard rendering, plus
one TypeScript line in the extension (a CLI flag).

### What shipped

**Part 1 — six compound performance lint rules (context-gated, never presence-only)**
- `avoid_opacity_in_animated_builder`, `avoid_opacity_in_scrollable`,
  `avoid_backdrop_filter_in_scrollable`, `avoid_shader_mask_in_scrollable`,
  `avoid_image_filter_in_scrollable`, `avoid_clip_path_in_animated_builder`.
- Each fires ONLY when the costly widget sits inside the problematic parent — a bare widget used
  on its own is never flagged. Implemented via a shared `_CompoundPerformanceRule` base.
- Deviation from the originally-proposed list: dropped `avoid_save_layer_in_scrollable` (a
  `canvas.saveLayer()` call lives in a separate `CustomPainter`, structurally detached from the
  widget tree, so it cannot be an AST-detectable compound — only presence-only, the flaw being
  corrected) and added `avoid_opacity_in_scrollable` instead.
- Registered in `saropa_lints.dart` factories, `tiers.dart` (Recommended), `all_rules.dart`
  barrel. Fixtures + unit test added.

**Part 2 — per-feature performance gravity in the Project Health (Project Map) dashboard**
- `--performance` flag on `project_health`; a "Performance gravity" panel ranks each feature
  0–100 by the compound patterns its files contain. Hidden when nothing is found.
- **Corrected scoring:** `gravityScore(w) = round(100·(1 − e^(−w/100)))` — saturating, monotonic,
  and INDEPENDENT of file count. Proven: the same `BackdropFilter`-in-`ListView` holds at 63%/HIGH
  whether its feature has 1 file or 5.

### Single source of truth
`lib/src/rules/core/compound_performance_patterns.dart` holds the canonical weighted pattern
table + the AST helpers (`widgetConstructionName`, `enclosingWidgetOfType`, `kScrollableWidgets`,
`kAnimatedRebuilders`). BOTH the lint rules and the dashboard scanner import it — the
widget/parent knowledge is defined once. Detection registers on BOTH
`addInstanceCreationExpression` AND `addMethodInvocation` because unresolved parses
(`parseString`, used by the scan + health CLIs) produce target-less `MethodInvocation` for widget
constructors while resolved trees produce `InstanceCreationExpression`.

### Files changed
- New: `lib/src/rules/core/compound_performance_patterns.dart`
- New: `lib/src/rules/core/compound_performance_rules.dart`
- New: `lib/src/cli/project_health/perf_gravity.dart`
- New fixtures: `example/lib/performance/avoid_{opacity_in_animated_builder,opacity_in_scrollable,backdrop_filter_in_scrollable,shader_mask_in_scrollable,image_filter_in_scrollable,clip_path_in_animated_builder}_fixture.dart`
- New tests: `test/rules/core/compound_performance_rules_test.dart`, `test/project_health/perf_gravity_test.dart`
- Edited: `lib/saropa_lints.dart` (factories), `lib/src/tiers.dart` (Recommended set), `lib/src/rules/all_rules.dart` (export)
- Edited: `lib/src/cli/project_health/{health_model,size_scanner,health_html_reporter,health_html_template}.dart`, `bin/project_health.dart`
- Edited: `extension/src/views/projectMapView.ts` (adds `--performance` to the CLI args)
- Edited: `CHANGELOG.md` (Unreleased → Added)

### Verification
- All 6 lint rules fire under the scan CLI with exact BAD-case counts; GOOD cases stay clean.
- Dilution fix proven (63%/HIGH at 1 file == 5 files) and pinned by `perf_gravity_test.dart`.
- `dart analyze` clean on every changed/new file. All 137 `test/project_health/` tests pass
  (additive changes broke no pins) + new rule test (12) + new gravity test (11) + tier↔plugin
  integrity test. Default `project_health` (no `--performance`) emits valid JSON with no
  `featureGravity` — no regression. `dart format` applied.

### Outstanding / not verified
- The TypeScript extension build (`npm`/`tsc`) was NOT run. The `projectMapView.ts` change is a
  single string added to an args array (syntactically safe) but the extension was not compiled.
