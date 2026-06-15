# Dashboard style unification + Project Map generated-file filter

The extension's dashboard surfaces had diverged onto several independent stylesheets: most editor
dashboards shared a chrome stylesheet bound to the host theme, but the Project Map dashboard
rendered a fixed brand palette that ignored the user's light/dark/high-contrast theme, the Code
Health scanning screen used a fourth orphan stylesheet, and the About panel, rule-violations
dashboard, command catalog, and package-details sidebar each carried their own token scales.
Separately, the Project Map size map and hot-spot rankings counted machine-generated and
localization Dart files (`.g.dart`, freezed, drift, `app_localizations_*`), so a single generated
database file or a megabyte of translation tables dominated the rankings and buried the hand-written
code those rankings exist to surface.

## Finish Report (2026-06-14)

### Scope

- **(A) Dart analyzer/CLI:** new `lib/src/cli/generated_dart_files.dart`, `size_scanner.dart`,
  `health_html_template.dart` (comment only), `test/project_health/size_scanner_test.dart`.
- **(B) VS Code extension:** `dashboardChromeStyles.ts`, `aboutView.ts`, `codeHealthScanProgress.ts`,
  `projectMapView.ts`, `projectVibrancyReportStyles.ts`, `consolidated/consolidatedStyles.ts`,
  `commandCatalogWebviewHtml.ts`, `vibrancy/views/detail-view-styles.ts`.
- **(C) docs:** `docs/design/SAROPA_DASHBOARD_STYLE_GUIDE.md` (new canonical guide), `CHANGELOG.md`,
  and the `plans/` consolidation (below).

### What changed

**Project Map generated-file filter.** `isGeneratedDartPath(relPosix)` in the new
`generated_dart_files.dart` is the one predicate the analysis CLIs share for "is this Dart
machine-generated?" — covering the common codegen suffixes (`.g.dart`, `.freezed.dart`, `.drift.dart`,
`.gr.dart`, `.config.dart`, protobuf, mockito, flutter_gen, chopper) plus gen-l10n tables
(`app_localizations*` / `intl_*` under an `l10n/` directory, which also catches wrapper variants like
`remote_app_localizations.dart`). `runSizeScan` in `size_scanner.dart` now skips these in its walk,
so they no longer reach the size map or hot-spot rankings — matching the filter the Code Health scan
(`project_vibrancy`) already applied inline. The knowledge that was duplicated across several scanners
now has a single home.

**Dashboard style system.** A canonical design-system document defines one token set, component
contract, accessibility gate, and per-platform adoption for every Saropa dashboard surface. The
shared chrome stylesheet (`dashboardChromeStyles.ts`) was extended from a color-only token set to the
full scale (spacing, radius, type, elevation, motion, z-index, plus brand and an A–F grade ramp
derived from the semantic tokens), additively so the already-conforming surfaces are unchanged, and
exposes `getDashboardTokens()` for surfaces that keep bespoke components. The six non-conforming
surfaces adopted it:

- **About panel** — inline stylesheet replaced with the shared chrome + hero.
- **Code Health scan screen** — orphan stylesheet replaced; hero now matches the finished report (no
  title jump on completion); stepper/counters/bar re-tokened. The inline client script and every
  id/class it (and its unit test) references were kept unchanged.
- **Project Map** — the Dart template keeps the curated fallback palette for the standalone HTML
  export, and `projectMapView.ts` injects a token override binding those same token names to
  `--vscode-*` for the in-editor webview, so it tracks the host theme. The ECharts charts already
  flip via `prefers-color-scheme`.
- **Rule-violations dashboard, command catalog, package-details sidebar** — private token scales
  (`--s-/--t-/--r-/--sev-`) aliased to the canonical tokens; the score gauge, command tiles, and
  package badges kept, only their values converged.

**Style-guide hardening adoption.** Three rules added to the guide from a separate rollout were
applied to the code: secondary buttons in the chrome gained a fallback fill and a guaranteed border
(host themes that leave `--vscode-button-secondaryBackground` undefined no longer render buttons as
bare text); letter grades across the Code Health report and scan screen drive off the shared A–F
ramp; the tinted-badge `color-mix` rule had no offenders.

**Plan consolidation.** The two overlapping consolidated-dashboard plans were merged: the
design-inventory plan (`CENTRAL_DASHBOARD_CONSOLIDATION.md`) absorbed the diagnostics-residuals plan's
status and one open verification item, and the residuals plan was archived to history with its
2026-06-12 finish report intact.

### Verification

- `dart analyze` on the four touched Dart files: no issues.
- `dart test test/project_health/size_scanner_test.dart`: 6 passing, including a new case asserting
  generated and gen-l10n files (incl. a `remote_app_localizations.dart` wrapper) are skipped while
  hand-written files survive.
- Extension `npx tsc -p tsconfig.json` and `tsconfig.test.json`: clean.
- Extension view + vibrancy-view test sweep: 429 passing. Two failures (`commandCatalogRegistry`
  missing two command ids from the catalog; `languagePick` locale badge) are pre-existing on the
  release commit and tied to files untouched here — confirmed unrelated.
- The Project Map webview theme override and the standalone HTML export render are structurally
  verified but not screenshot-verified; that needs a human F5 launch (see What to test).

### Notes for the reviewer

- The generated-file predicate is centralized but only `size_scanner.dart` consumes it so far;
  `project_vibrancy` and the `cross_file` analyzers still carry their own inline copies and could be
  converged onto it as a follow-up (not done here to avoid touching the vibrancy determinism tests).
- The style guide explicitly exempts high-density log/terminal consoles and documents the VS Code
  reconciliations (no `--surface-0` in a webview, 13px type base, primary text via
  `var(--vscode-foreground)`).
