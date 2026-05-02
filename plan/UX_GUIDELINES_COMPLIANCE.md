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

- [ ] **Lift `.empty-cta` to chrome** (§20.1). Currently duplicated in `violationsDashboardStyles.ts`, `projectVibrancyReportStyles.ts`, `relatedRuleTelemetryView.ts`, `known-issues-html.ts`. Move the rule into `dashboardChromeStyles.ts` and remove the per-surface copies.
- [ ] **Lift landmark + aria-live announcer scaffolding to chrome** (§15.3). Add a `<header>` / `<main>` / `<footer>` wrapper builder, plus a hidden `<div id="announcer" role="status" aria-live="polite" class="sr-only">` that surfaces inject filter/sort messages into.
- [ ] **Add `@media print` block to chrome** (§22.1). Hide toolbars, sticky headers, hover affordances; add `tr { break-inside: avoid }`; preserve KPI / pill backgrounds via `print-color-adjust: exact`.
- [ ] **Add chrome-level `prefers-reduced-motion` block** with `animation: none` overrides for every named keyframe in the chrome (§5.2).
- [ ] **Build helper module `extension/src/views/webview-format.ts`** carrying:
  - `pluralize(count, { one, other })` using `Intl.PluralRules('en-US')` (§18.2)
  - `formatNumber(n)` and `formatCompact(n)` (§18.3)
  - `formatRelativeTimestamp(iso)` (already exists in `dashboardHero.ts` — consolidate)
  - `formatAbsoluteTimestamp(iso)` for tooltip pairs (§18.4)
- [ ] **Build helper module `extension/src/views/webview-strings.ts`** with a `STRINGS` const carrying every user-facing label currently inlined across surfaces (§18.1). Even if every key maps to an English string today, the externalization point unlocks a future i18n pass.
- [ ] **Visual-snapshot test infrastructure** (§19.3). Add a Playwright or Puppeteer-based test runner that opens each dashboard against four theme stubs and writes baselines under `extension/test/visual-snapshots/<surface>-<theme>.png`. CI compares with a 1% diff threshold.
- [ ] **Per-dashboard token coverage matrix tool** (§19.4). Static-analysis script that walks every `*-styles.ts`, extracts `var(--vscode-*)` references, and emits a markdown table mapping tokens × surfaces. Run on each PR to flag drift.
- [ ] **Keyboard-shortcut overlay component** (§15.2). One reusable component (?-key opens a popover listing the page's shortcuts). Each surface registers its own list.

---

## Phase 2 — Cross-cutting sweeps (do once across all surfaces)

Greppable patterns that need consistent treatment. After Phase 1, these are mechanical sweeps — easy to delegate per file or run as a batch.

- [ ] **Hex-fallback sweep** (§14.16). Grep `var\(--vscode-[^,]+,\s*#[0-9a-fA-F]` across `extension/src/`. Replace with token-only or token-only fallback chain (`var(--vscode-foo, var(--vscode-bar))`). Already done for `package-detail-styles.ts`; remaining surfaces likely have at least a few.
- [ ] **Reduced-motion guard sweep** (§5.2). Grep `@keyframes` and JS `animate()` calls; ensure each is wrapped in `@media (prefers-reduced-motion: reduce) { animation: none; }` (CSS) or guarded by `matchMedia('(prefers-reduced-motion: reduce)').matches` (JS). End-state must still apply.
- [ ] **Pluralization sweep** (§18.2). Grep `\?\s*''\s*:\s*'s'` and `count === 1 \? '' :` patterns. Replace with `pluralize()` from the Phase 1 helper.
- [ ] **Loading-verb sweep** (§8.16.2). Grep `Loading…|Loading\.\.\.|>\s*Loading` and replace with action verbs (*Thinking*, *Preparing*, *Checking*, *Fetching*, *Working*).
- [ ] **Logical-property sweep** (§23.1). Grep `margin-left|margin-right|padding-left|padding-right|text-align:\s*(left|right)|border-left|border-right|left:|right:` in all `*-styles.ts`. Convert physical to logical (`margin-inline-start`, `padding-inline`, `text-align: start`, `border-inline-start`, `inset-inline-start`). Document the few intentional physical-property uses.
- [ ] **Inline `style="color: …"` sweep** (§20.4). Grep `style="[^"]*color:` in HTML builders; replace with class + token. Inline colors don't survive theme switches.
- [ ] **CSV export hardening** (§22.2). Audit every `saveFilteredJson` / `copyAsJson` path. Verify CSV variants (if any) emit BOM, escape `"`, `,`, newlines per RFC 4180, use `\r\n` line endings, save under `<workspace>/reports/.saropa_lints/`, and stamp the filename `YYYYMMDD-HHMM`.
- [ ] **Plural-correct count strings audit** — look for `${n} item${n === 1 ? '' : 's'}`, `${count} thing${count === 1 ? '' : 's'}` variants and route through the helper. Also check for `${n}%` (locale-incorrect; use `Intl.NumberFormat`) and `${n.toFixed(1)}` (works but consider locale).

---

## Phase 3 — Per-dashboard sweeps

For each dashboard, complete the §15 a11y checklist, the §16.5 perf measurement gate, and any surface-specific items below. Use the Phase 1 helpers.

### Findings Dashboard
- [ ] §15 a11y: keyboard tab order, focus-visible on all interactive, landmark elements, aria-live announcer wired to filter/sort changes
- [ ] §16.5 perf measurement against a 5,000-row fixture; record TTFP / TTI / filter latency in PR description
- [ ] §7.5 virtualization decision — likely needed (Findings can render 5k+ rows on real projects); use `content-visibility: auto` at 300–2000 rows, virtualize beyond
- [ ] §15.7 verify severity badges + chart legend survive grayscale screenshot test
- [ ] §17 verify state-persistence policy: filters + sort survive panel close, search query resets, full-width toggle persists per-panel
- [ ] §15.6 search input has explicit `<label>` (currently uses placeholder only)
- [ ] §22.3 no-data state when `violations.json` doesn't exist yet — already covered by `buildFindingsEmpty`; verify it has a tier-1 CTA

### Code Health Dashboard
- [ ] §15 a11y full pass
- [ ] §16.5 perf measurement (representative project = ~2,000 functions)
- [ ] §15.7 grade gauge + flag pills must read in grayscale (paired with grade letter, not just hue)
- [ ] §8.16.5 offline state when network calls fail (does this dashboard fetch anything? — verify)
- [ ] §17 state-persistence verification

### Rule Explain panel
- [ ] §15 a11y full pass
- [ ] §16.5 perf — should be trivial (small panel) but record numbers
- [ ] §15.6 verify links have proper `aria-label` for icon-only or terse anchors
- [ ] §22.3 first-time disclosure — small `?` in hero that explains "what this panel shows"

### Command Catalog
- [ ] §15 a11y full pass; the category jump-flash needs `aria-live` notification
- [ ] §16.5 perf — large catalog, watch for DOM count
- [ ] §8.5.2 search highlighting in matched rows (`<mark>` wrap)
- [ ] §8.5.2 recent-searches affordance after 5 distinct queries
- [ ] §17 persist *Show context-menu commands* checkbox to `workspaceState`

### Related Rule Telemetry
- [ ] §15 a11y full pass
- [ ] §16.5 perf
- [ ] §17 column-width persistence (only if column resize lands)
- [ ] §15.7 grayscale verification — currently no chart, but verify table data reads without color

### About panel
- [ ] §15 a11y verification (read-only panel — should be trivial)
- [ ] §15.6 link label association — every external link has `aria-label` describing the target
- [ ] §16.5 perf — trivial; record anyway for the matrix

### Single-package detail panel
- [ ] §15 a11y full pass
- [ ] §16.5 perf — large surfaces (PR/issue tables can be hundreds of rows); use `content-visibility: auto`
- [ ] §8.16.3 partial-state pattern for pubdev fetch failures (per-row warning glyph + retry banner)
- [ ] §8.16.5 offline state with cached-data fallback
- [ ] §8.16.6 stale state with refresh-failed status-line warning
- [ ] §15.7 grayscale verification of badge-vibrant / quiet / legacy / stale / eol pills
- [ ] §17 persist filter + sort to `workspaceState` per package (so re-opening the same package restores the view)

### Package Comparison panel
- [ ] §15 a11y full pass
- [ ] §16.5 perf
- [ ] §14.8 KPI cards currently informational — consider making them interactive (clicking *Leading* could highlight the leader column)
- [ ] §15.7 winner / loser column class survives grayscale (currently green-only; add a glyph)

### Known Issues Library
- [ ] §15 a11y full pass; the chip strip needs `aria-live` to announce on filter divergence
- [ ] §16.5 perf
- [ ] §8.5.2 search highlighting + recent searches
- [ ] §17 persist filter state to `workspaceState`

### Package Dashboard (gold-standard reference)
- [ ] **Self-audit** against the expanded doc — the gold-standard surface should pass every guideline. If anything fails, either fix it OR document it as a known divergence in `extension/src/vibrancy/views/report-html.ts` header comment.

---

## Phase 4 — Opt-in polish

Earned scope, not blocking. Add when there's a real product reason.

- [ ] **§7.4 Multi-column sort opt-in** for Findings + Code Health where users have stable secondary criteria (e.g. severity desc, then file asc). Add `Shift+click` extension and numbered-badge indicators.
- [ ] **§7.3 Multi-select + bulk actions** for Findings (suppress N rules, copy N findings) and Known Issues (mark N as reviewed). Adds checkbox column, range select, bulk-action toolbar, selection survival rules.
- [ ] **§22.3 What-is-this disclosure** — small `?` icon in each hero that opens a one-paragraph popover explaining the surface. Cheap discoverability for first-time users.
- [ ] **§7.6 Column resize / reorder** — only for surfaces with wide variation in column-content widths (Findings file paths in monorepos). Persist to `workspaceState`. Add only when there's a real complaint; usually unused.
- [ ] **§22.3 No-project state** — every dashboard should render a *"Open a Flutter or Dart project"* tier-1 CTA when no workspace is open. Audit each surface; many may already inherit a host-level guard.
- [ ] **`.error-fallback` per-section error boundary** (§8.16.8) — wrap every top-level section in a try/catch that renders a small *Reload* fallback band on per-section failure. Prevents one broken sub-component from blanking the whole page.

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
| Findings | | | | | |
| Code Health | | | | | |
| Rule Explain | | | | | |
| Command Catalog | | | | | |
| Telemetry | | | | | |
| About | | | | | |
| Single-package detail | | | | | |
| Comparison | | | | | |
| Known Issues | | | | | |
| Package Dashboard | | | | | |

`✓` = compliant. Empty = not yet verified. `~` = partial.
