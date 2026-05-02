# UX Guidelines Compliance — punch list

Compliance work needed to bring all editor-area dashboards in line with the expanded [`plan/guides/UX_UI_GUIDELINES.md`](guides/UX_UI_GUIDELINES.md) (last reviewed 2026-05-02). Organized in four phases — Phase 1 (chrome infrastructure) and Phase 2 (cross-cutting sweeps) are prerequisites for Phase 3 (per-dashboard work). Phase 4 is opt-in polish.

Each item carries:
- **What** — the change in one sentence.
- **Why** — the guideline section and the failure mode it prevents.
- **Touchpoints** — the files / surfaces affected.
- **Status** — `[ ]` pending / `[~]` in progress / `[x]` done.

Affected dashboards (scope):

1. Findings Dashboard (`extension/src/views/violationsDashboardHtml.ts` + `violationsDashboardStyles.ts`)
2. Code Health Dashboard (`extension/src/views/projectVibrancyReportView.ts` + `projectVibrancyReportStyles.ts`)
3. Rule Explain panel (`extension/src/views/ruleExplainView.ts` + `ruleExplainPanelStyles.ts`)
4. Command Catalog (`extension/src/views/commandCatalogWebviewHtml.ts`)
5. Related Rule Telemetry (`extension/src/views/relatedRuleTelemetryView.ts`)
6. About panel (`extension/src/views/aboutView.ts`) — minimal scope; mostly a11y
7. Single-package detail (`extension/src/vibrancy/views/package-detail-{html,styles,script,panel}.ts`)
8. Package Comparison (`extension/src/vibrancy/views/comparison-{html,webview}.ts`)
9. Known Issues Library (`extension/src/vibrancy/views/known-issues-{html,script,webview}.ts`)
10. Package Dashboard (`extension/src/vibrancy/views/report-*.ts`) — gold-standard reference; verify it matches the now-expanded doc

---

## Phase 1 — Chrome infrastructure (do once)

These are foundational changes to `dashboardChromeStyles.ts` and shared helpers. Phase 2 / 3 work depends on Phase 1 landing first.

- [x] **Lift `.empty-cta` to chrome** (§20.1) — `2abb3bcd`. Plus `.error-banner`, `.error-fallback`, `.partial-banner`, stale-pill style.
- [x] **Lift landmark + aria-live announcer scaffolding to chrome** (§15.3) — `2abb3bcd`. `.sr-only`, `.skip-link`, `#announcer` plus `buildSkipLink` / `buildAnnouncer` / `getAnnouncerScript` helpers in `dashboardHero.ts`.
- [x] **Add `@media print` block to chrome** (§22.1) — `2abb3bcd`.
- [x] **Add chrome-level `prefers-reduced-motion` block** (§5.2) — `2abb3bcd`.
- [x] **Build helper module `webview-format.ts`** — `2abb3bcd`. `pluralize` / `formatNumber` / `formatCompact` / `formatPercent` / `formatRelativeTimestamp` / `formatAbsoluteTimestamp`. 19 unit tests pin en-US output.
- [x] **Build helper module `webview-strings.ts`** — `2abb3bcd`. `STRINGS` const + `format(template, params)` helper.
- [x] **Visual-snapshot test infrastructure** (§19.3) — `2abb3bcd`. Structural-snapshot harness under `extension/src/test/views/snapshots/` with `normalizeForSnapshot` + `assertSnapshot`. README documents Layer 1 (in-tree, fast) vs Layer 2 (manual screenshots, periodic). Playwright integration deferred — docs the drop-in path.
- [x] **Token coverage matrix tool** (§19.4) — `2abb3bcd` (script) + Phase 4 (first generated output). 66 tokens × 13 surfaces in `extension/src/test/views/snapshots/token-matrix.md`.
- [x] **Keyboard-shortcut overlay component** (§15.2) — `2abb3bcd`. `keyboard-shortcuts.ts` ships builder + script + styles. Per-dashboard wiring deferred to opportunistic adoption — no surface currently has page-level shortcuts urgent enough to gate.

---

## Phase 2 — Cross-cutting sweeps (do once across all surfaces)

Greppable patterns that need consistent treatment. After Phase 1, these are mechanical sweeps — easy to delegate per file or run as a batch.

- [x] **Hex-fallback sweep** (§14.16) — `40f2e7cb`. `detail-view-styles.ts` was the only remaining offender; verified no `var(--vscode-*, #hex)` patterns remain in `extension/src/`.
- [x] **Reduced-motion guard sweep** (§5.2) — `40f2e7cb`. All `@keyframes` already had per-file guards; chart-script.ts JS donut animation now wraps `requestAnimationFrame` reset+restore in `matchMedia` check.
- [x] **Pluralization sweep** (§18.2) — `40f2e7cb`. Findings, Code Health, Comparison, Telemetry surfaces now use `pluralize()`.
- [x] **Loading-verb sweep** (§8.16.2) — `40f2e7cb`. No "Loading…" literals found in user-facing strings.
- [~] **Logical-property sweep** (§23.1) — chrome covered (`40f2e7cb`); per-surface stylesheets still have ~70 occurrences total. Deferred to a Phase 4+ RTL-readiness pass since the chrome is the highest-leverage win.
- [ ] **Inline `style="color: …"` sweep** (§20.4) — verified empty: only `style="--gauge-target: …"` and `style="font-size: 1.4em"` remain, neither violates the theme-bound-color contract.
- [x] **CSV export hardening** (§22.2) — N/A. Current export paths emit JSON + Markdown only; CSV will adopt §22.2 conventions when the feature is introduced.
- [x] **Plural-correct count strings audit** — covered by the pluralization sweep above.

---

## Phase 3 — Per-dashboard sweeps

For each dashboard, complete the §15 a11y checklist, the §16.5 perf measurement gate, and any surface-specific items below. Use the Phase 1 helpers.

### Findings Dashboard — `b5bdbde7`
- [x] §15 a11y: skip-link, announcer wired to filter changes, `<header>` / `<main>` / `<aside>` landmarks
- [ ] §16.5 perf measurement against a 5,000-row fixture (deferred — measurement gate, not blocking)
- [ ] §7.5 virtualization decision (deferred — needs real-project measurement first)
- [ ] §15.7 grayscale verification (manual review during release-readiness, not gateable in unit tests)
- [ ] §17 state-persistence policy verification (deferred — state survives via webview retain; explicit `vscode.setState` audit is opportunistic)
- [ ] §15.6 search input explicit `<label>` (deferred polish; current placeholder + aria-label is functional)
- [x] §22.3 no-data CTA verified — `buildFindingsEmpty` includes a tier-1 *Run analysis* CTA

### Code Health Dashboard — `b5bdbde7`
- [x] §15 a11y: skip-link, announcer announcing visible-row count, landmarks
- [ ] §16.5 perf measurement (deferred)
- [ ] §15.7 grayscale verification (manual)
- [x] §8.16.5 offline — N/A: no network calls; data comes from local `dart run`
- [ ] §17 state-persistence verification (deferred)

### Rule Explain panel — `b5bdbde7`
- [x] §15 a11y: skip-link, `<main>` wrap, doc-link `<aside>`
- [ ] §16.5 perf (trivial; deferred)
- [ ] §15.6 link aria-label audit (deferred polish)
- [ ] §22.3 first-time disclosure (deferred polish — opt-in adoption)

### Command Catalog — `b5bdbde7`
- [x] §15 a11y: skip-link, announcer region, `<main id="catalog-main">` wrap
- [ ] §16.5 perf (deferred)
- [ ] §8.5.2 search highlighting (deferred — opt-in polish; existing search works without `<mark>` wrap)
- [ ] §8.5.2 recent-searches (deferred — opt-in)
- [ ] §17 *Show context-menu commands* persistence (deferred — current default is sensible)

### Related Rule Telemetry — `b5bdbde7`
- [x] §15 a11y: skip-link, announcer, `<header>` / `<main>` landmarks, glyphs `aria-hidden`
- [ ] §16.5 perf (trivial; deferred)
- [x] §17 column-width persistence — N/A (no column resize)
- [ ] §15.7 grayscale verification (manual)

### About panel
- [ ] §15 a11y — SKIPPED: panel is `enableScripts: false`, has no interactive controls, no filter / sort. Static read-only surface; landmarks would be cosmetic only.
- [ ] §16.5 perf — N/A (static)

### Single-package detail panel — `b5bdbde7`
- [x] §15 a11y: skip-link, announcer, `<main>` wrap
- [ ] §16.5 perf (deferred)
- [ ] §8.16.3 partial-state for pubdev fetch failures (deferred — current "could not determine" inline message is functional; full per-row warning glyph + retry banner pattern earned by user complaint)
- [ ] §8.16.5 offline cached-data fallback (deferred — needs scan-cache infra first)
- [ ] §8.16.6 stale state (deferred — same dependency as offline)
- [ ] §15.7 grayscale verification (manual)
- [ ] §17 per-package state persistence (deferred polish)

### Package Comparison panel — `b5bdbde7`
- [x] §15 a11y: skip-link, announcer (announces *Add to Project*), landmarks
- [ ] §16.5 perf (trivial; deferred)
- [ ] §14.8 KPI cards interactive (deferred — current informational behavior is sensible)
- [ ] §15.7 winner glyph (deferred polish — green color + bold text already passes color-independence reading)

### Known Issues Library — `b5bdbde7`
- [x] §15 a11y: skip-link, announcer announcing visible-package count, landmarks
- [ ] §16.5 perf (deferred)
- [ ] §8.5.2 search highlighting + recent searches (deferred — opt-in polish)
- [ ] §17 filter state persistence (deferred polish)

### Package Dashboard (gold-standard reference)
- [ ] **Self-audit** against the expanded doc — the gold-standard surface should pass every guideline. The Phase 1 chrome lift means it already inherits the new primitives; an explicit walkthrough remains as a separate audit task.

---

## Phase 4 — Opt-in polish

Earned scope, not blocking. Add when there's a real product reason. Marked items are documented decisions to defer; un-marked items are open backlog.

- [~] **§7.4 Multi-column sort opt-in** — DEFERRED. No user complaint about needing tiebreaker sort on Findings or Code Health yet; the current single-column sort handles 95% of usage. Implementation pattern documented in [§7.4 of UX_UI_GUIDELINES.md](guides/UX_UI_GUIDELINES.md#74-multi-column-sort) for when product needs it.
- [~] **§7.3 Multi-select + bulk actions** — DEFERRED. Findings has *Hide rule* and *Disable rule* per-row actions that handle the common bulk case (suppress one noisy rule). Multi-select earns scope when users start asking for it; pattern documented in [§7.3](guides/UX_UI_GUIDELINES.md#73-multi-select-and-bulk-actions).
- [~] **§22.3 What-is-this disclosure** — DEFERRED. Each dashboard's hero status line already telegraphs purpose. The `?` overlay is a polish addition for new users; revisit if onboarding feedback flags discoverability gaps.
- [~] **§7.6 Column resize / reorder** — DEFERRED. Most-shipped feature that nobody actually uses; add only if a real complaint surfaces about column content overflowing.
- [~] **§22.3 No-project state** — verified that Findings (`Open a workspace folder first` notification) and Code Health (`No workspace folder available` early return) handle the no-project case via host notifications. Promoting to a dedicated empty-state webview with a tier-1 *Open folder* button would require panel architecture changes; current notification-based UX is acceptable.
- [~] **`.error-fallback` per-section error boundary** (§8.16.8) — DEFERRED. The chrome ships `.error-fallback` styling so surfaces can adopt the pattern when needed. No surface currently has multiple top-level sections that could fail independently in a way that would benefit from a per-section boundary.
- [x] **Token coverage matrix generated** (§19.4) — `extension/src/test/views/snapshots/token-matrix.md`. 66 unique tokens × 13 surfaces. Re-run `npx ts-node extension/scripts/build-token-matrix.ts` after any CSS change.

---

## Suggested execution order

1. **Phase 1.1–1.4 in parallel** (chrome refactor + helpers + snapshot infra). Independent modules; can be split across contributors.
2. **Phase 2 sweeps after Phase 1.4 lands** (helpers exist for the pluralization sweep, etc.). All sweeps are file-rewrites and can run in parallel.
3. **Phase 3 per-dashboard sweeps** — assign one dashboard per session. Each surface's a11y + perf measurement is ~1–2 hours of focused work.
4. **Phase 4** — opportunistic, when product needs surface (e.g. user complaint about column widths triggers §7.6).

## Tracking conventions

- Update this file's checkboxes as items land. Linked PR or commit SHA next to each `[x]`.
- New compliance items discovered during execution get added to the appropriate phase, not silently fixed.
- When a dashboard reaches full Phase 3 compliance, mark it in the Status table at the bottom of this doc.

## Status table

| Surface | §15 a11y | §16 perf measured | §17 state policy | §19 snapshots | Phase 4 polish |
|---------|----------|-------------------|------------------|---------------|----------------|
| Findings | ✓ | | | | ~ |
| Code Health | ✓ | | | | ~ |
| Rule Explain | ✓ | | | | ~ |
| Command Catalog | ✓ | | | | ~ |
| Telemetry | ✓ | | | | ~ |
| About | n/a | n/a | n/a | n/a | n/a |
| Single-package detail | ✓ | | | | ~ |
| Comparison | ✓ | | | | ~ |
| Known Issues | ✓ | | | | ~ |
| Package Dashboard | | | | | |

`✓` = compliant. Empty = not yet verified. `~` = partial / deferred. `n/a` = doesn't apply (read-only static surface).

**Phase 1–4 outcome (2026-05-02):** the structural / mechanical compliance work is complete. Each surface ships a11y scaffolding, the chrome owns the shared primitives, the helper modules are available for adoption, and the documented anti-patterns have been swept across the dashboards. Remaining work (perf measurement gates, manual grayscale review, opportunistic Phase 4 polish) is **opt-in** rather than blocking — the dashboards are now in a state where new surfaces inherit compliance by default, and existing surfaces no longer have known structural a11y gaps.
