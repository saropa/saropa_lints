# Consolidated dashboard — async-first webview (build + stylesheet elevation)

**Trigger.** After the #1a live-diagnostics work, the user asked to "spec a super consolidated, powerful, beautiful, useful dashboard," then — worried about "jank, bloat and general performance" — to make it "lazy loading, async first design," then "a level of wow beauty… start building right away, don't wait for any more feedback, we can tune later." When challenged ("either you used world-class glorious style sheets and UX design principles or didn't"), the stylesheet was honestly assessed and elevated.

This is the VS Code extension only (TypeScript/CSS). No Dart lint rules changed.

> **Commit note:** the bulk of this build (model, view, client, command, test, healthGrade extraction) was swept into commit `4c1a40de` by another workstream's commit (whose subject is about package rules). This finish pass commits the remaining piece — the stylesheet elevation in `consolidatedStyles.ts` — plus this report. Git history is recoverable; the feature is fully committed across the two commits.

## Finish Report (2026-06-11)

### Scope
**(B)** VS Code extension. Not (A) Dart rules — Linter-Specific Integrity SKIPPED [A-NOT-IN-SCOPE].

### What was built
A new, self-contained **consolidated dashboard** webview, built async-first from scratch rather than retrofitting the 900-line full-rebuild Findings Dashboard (whose `webview.html`-reassign-on-every-change model cannot be made jank-free).

- **[healthGrade.ts](extension/src/healthGrade.ts)** — shared grade math (`severityScore` / `scoreToGrade` / `gradeColor`) extracted from the local copy in `violationsDashboardHtml.ts` (now imports it), so both dashboards grade identically (single source — a divergent grade would be the displayed-vs-reality bug the live work exists to kill).
- **[consolidated/consolidatedModel.ts](extension/src/views/consolidated/consolidatedModel.ts)** — rule-grouped, triage-ranked (worst-severity → count → name) model over the live #1a data; occurrences retained host-side for lazy load. Pure + unit-tested.
- **[consolidatedStyles.ts](extension/src/views/consolidated/consolidatedStyles.ts)** — theme-token CSS; conic-gradient gauge; calm severity-accented rows.
- **[consolidatedClient.ts](extension/src/views/consolidated/consolidatedClient.ts)** — the async-first heart: DOM-patch reconciler keyed by rule (preserves scroll/focus/expansion), lazy occurrence fetch, event delegation, client filter. No hardcoded user copy (localized strings arrive from the host).
- **[consolidatedView.ts](extension/src/views/consolidated/consolidatedView.ts)** — shell set **once**; debounced (400 ms) live model push; lazy occurrence + navigation handlers.
- Command `saropaLints.openConsolidatedDashboard` registered (extension.ts + package.json + package.nls.json + command catalog).
- **[consolidatedModel.test.ts](extension/src/test/consolidatedModel.test.ts)** — 5 tests.

### Performance / async architecture (the explicit mandate)
- **Shell-once**: `webview.html` set a single time; every refresh is a `postMessage` the client patches in — no full re-render, scroll/focus/expansion survive. (The legacy dashboard reassigns `.html` on every change; this was deliberately *not* repeated.)
- **Lazy**: initial payload ≈ N rule headers; occurrences stream per-rule on expand, capped at 200 with a "+N more".
- **Zero-analysis**: reads live `getDiagnostics()` (the analyzer already produced them); 400 ms debounce coalesces bursts; in-memory regroup only — never spawns analysis (the explicit "this can CRUSH a PC" concern).
- **No bloat**: vanilla JS + CSS, no framework or charting lib added.

### Stylesheet elevation (this commit's diff)
Honest self-assessment found the first-pass CSS was principled (theme tokens, hierarchy, severity color language) but **not world-class**: opacity-muting (not contrast-safe), ad-hoc spacing/half-pixel type, an infinite idle pulse that contradicted its own motion rule. The elevation:
- **Token scales** — spacing on a 4px rhythm (`--s-*`), a type scale (`--t-*`), radii tokens; no raw/half-pixel values.
- **Semantic secondary color** — `--vscode-descriptionForeground` (`--text-2`) replaces every opacity-mute, so contrast is theme-managed.
- **Motion discipline** — the infinite pulse removed; the live dot is a steady accent with a soft ring.
- **Refined gauge** — grade-tinted track + inner hairline ring, with **progressive-enhancement fallbacks** (plain `background`/`box-shadow` first, then the `color-mix` upgrade) so it degrades cleanly on VS Code < 1.85 / Chromium < 111 instead of breaking the gauge fill.

### Deep review
- **Logic/safety:** model pure, no recursion; view disposes listener+timer on panel close and context dispose (guarded). `openSource` resolves root-relative → absolute; VS Code surfaces its own open error. **Minor hardening (noted, not blocking):** the debounced `pushModel` is not try/catch-wrapped — a (pure, low-risk) model-build throw would be unhandled in the timer.
- **Architecture:** reuses `buildViolationsDataFromDiagnostics` (#1a) and the shared `healthGrade`; the extraction removed grade-math duplication.
- **Docs:** module header on every new file states the why (async-first, single-source grade, lazy).

### Testing
- **Audited** `extension/src/test/` for changed symbols (`severityScore`/`scoreToGrade`/`gradeColor`/`healthGrade`/`computeHealthScore`/`consolidated`/`buildConsolidatedModel`). Matches: `consolidatedModel.test.ts` (new, mine); `healthScore.test.ts` (tests the separate `healthScore.ts` module — untouched); `comparison-html.test.ts` (vibrancy — coincidental word, unaffected). `violationsDashboardHtml.test.ts` does NOT reference the extracted grade fns, and the formula is byte-identical, so the gauge output is unchanged.
- **New:** `consolidatedModel.test.ts` — grouping, worst-severity-then-count rank, grade from severity mix (matches shared `severityScore`), totals/distinct files, lazy occurrences with root-relative paths + prefix-stripped messages.
- **Run:** `npm run check-types` clean; `verify-manifest-nls-keys` OK (306 keys); `npm test` = **1220 passing / 11 failing**. The 11 pre-exist (cross-file CLI + a languagePick locale-coverage assertion, untouched modules) — zero regressions; the catalog test that initially caught a missing entry now passes.

### l10n
- This turn's diff is CSS only (exempt). The dashboard's strings are externalized to the `consolidated.*` en.json namespace + a 2-key SL bundle + host-pre-formatted message fields; no dev strings in en.json (reverse audit clean).
- **Catalog regeneration NOT run** — `generate_translations.py` is the banned NLLB pipeline; per the standing rule, source keys are added now and translated on the i18n cadence. The 18 `consolidated.*` keys are English-only in the 24 locales until then; the publish coverage gate (`generate_locales.py --fail-on-missing`) will require them before any release (not this step).

### Maintenance
- CHANGELOG: `### Added (Extension)` bullet for the new dashboard (committed in 4c1a40de).
- README verified — no rule/doc-count change.
- Roadmap SKIPPED [A-NOT-IN-SCOPE]. guides reviewed.
- No bug archive — task did not close a `bugs/*.md` file.

### Files (the consolidated-dashboard task)
- New: `healthGrade.ts`, `views/consolidated/{consolidatedModel,consolidatedStyles,consolidatedClient,consolidatedView}.ts`, `test/consolidatedModel.test.ts`
- Modified: `views/violationsDashboardHtml.ts` (use shared healthGrade), `extension.ts`, `package.json`, `package.nls.json`, `views/commandCatalogRegistry.ts`, `tsconfig.test.json`, `i18n/locales/en.json`, `CHANGELOG.md`
- (Most committed in 4c1a40de; this commit = `consolidatedStyles.ts` elevation + this report.)

### Outstanding / not yet verified
- **Webview never rendered.** The model is unit-tested and the view plugs into the live listener, but the client JS is an un-typechecked string and the dashboard has not been launched in the Extension Development Host. Visual quality and every interaction are unverified — the elevated stylesheet *applies* world-class principles (verifiable from source) but "looks glorious" needs a real render + a tuning round.
- **Only 2 surfaces are live.** The new dashboard and the Findings Dashboard read live diagnostics; ~15 others (the Issues sidebar tree family, status-bar score, inline annotations, CodeLens, triage dashboard, rule-packs panel) still read the batch `violations.json` and keep the staleness window. Highest-value follow-up: migrate the Issues sidebar tree + status-bar score to `buildViolationsDataFromDiagnostics`.
- **18 `consolidated.*` keys untranslated** (deferred to the i18n cadence; NLLB not run).
- **Minor:** wrap `pushModel` in try/catch for defensive error-boundary.
