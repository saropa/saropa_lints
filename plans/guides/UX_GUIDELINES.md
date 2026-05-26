# UX Guidelines — Dashboard compliance & remaining work

Single plan for editor-area dashboards aligned with [`plans/guides/UX_UI_GUIDELINES.md`](guides/UX_UI_GUIDELINES.md) (last reviewed 2026-05-02).

## Part A — Compliance punch list

## Status snapshot

- **Document role:** compliance/status record (structural work largely complete).
- **Open category:** deferred/manual verification items only.
- **Remaining backlog:** See **Part B** below (tiers A–D).

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
- [x] **Keyboard-shortcut overlay component** (§15.2) — `2abb3bcd`. `keyboard-shortcuts.ts` ships builder + script + styles. Wired into Findings, Code Health, and Known Issues with `/`, `Esc`, `Enter`/`Space`, and `?` bindings (quick-win pass after the structural compliance work). Other surfaces adopt opportunistically.

---

## Phase 2 — Cross-cutting sweeps (do once across all surfaces)

Greppable patterns that need consistent treatment. After Phase 1, these are mechanical sweeps — easy to delegate per file or run as a batch.

- [x] **Hex-fallback sweep** (§14.16) — `40f2e7cb`. `detail-view-styles.ts` was the only remaining offender; verified no `var(--vscode-*, #hex)` patterns remain in `extension/src/`.
- [x] **Reduced-motion guard sweep** (§5.2) — `40f2e7cb`. All `@keyframes` already had per-file guards; chart-script.ts JS donut animation now wraps `requestAnimationFrame` reset+restore in `matchMedia` check.
- [x] **Pluralization sweep** (§18.2) — `40f2e7cb`. Findings, Code Health, Comparison, Telemetry surfaces now use `pluralize()`.
- [x] **Loading-verb sweep** (§8.16.2) — `40f2e7cb`. No "Loading…" literals found in user-facing strings.
- [x] **Logical-property sweep** (§23.1) — quick-win pass after structural compliance: every `margin-left` / `margin-right` / `padding-left` / `padding-right` / `border-left:` / `border-right:` in `extension/src/**/*.ts` migrated to the `*-inline-start` / `*-inline-end` equivalents. Inline-style strings inside HTML builders included. Position-based `left:` / `right:` (absolute/fixed positioning) intentionally left for the dedicated RTL-readiness pass — those need per-call review of whether the offset should mirror or stay anchored.
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
- [x] §15.6 search input explicit `<label>` — sweep covered: every webview search input now carries a `<label>` (visually hidden via `.sr-only` where needed). Inputs touched: `known-issues-html` `#search-input`, `report-html` `#search-input`, `package-detail-html` `.gap-search`. Inputs that already carried `<label>` (`pvSearch`, `pack-search`, `disabled-rules-search`) or an `aria-label` (`#textFilter`, `#search`) verified.
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

### Suggested execution order (compliance phases)

1. **Phase 1.1–1.4 in parallel** (chrome refactor + helpers + snapshot infra). Independent modules; can be split across contributors.
2. **Phase 2 sweeps after Phase 1.4 lands** (helpers exist for the pluralization sweep, etc.). All sweeps are file-rewrites and can run in parallel.
3. **Phase 3 per-dashboard sweeps** — assign one dashboard per session. Each surface's a11y + perf measurement is ~1–2 hours of focused work.
4. **Phase 4** — opportunistic, when product needs surface (e.g. user complaint about column widths triggers §7.6).

### Tracking conventions (Part A)

- Update **Part A** checkboxes as items land. Linked PR or commit SHA next to each `[x]`.
- New compliance items discovered during execution get added to the appropriate phase, not silently fixed.
- When a dashboard reaches full Phase 3 compliance, mark it in the Status table below.

### Status table

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

---

## Part B — Remaining work plan

Earned-scope backlog (Tiers A–D) against the expanded [`plans/guides/UX_UI_GUIDELINES.md`](guides/UX_UI_GUIDELINES.md). **Part A** above is the structural compliance record; this part expands deferred items with triggers and sketches.

## Execution snapshot

### Next 3 (ordered quick wins)

- [x] **UX-B08 (P1)** Cross-session recent-search persistence via `workspaceState`. (Done 2026-05-08: Findings + Known Issues + Command Catalog search histories hydrate from `workspaceState` + host `postMessage` saves.)
- [x] **UX-B09 (P1)** Full RTL slider behavior for config dashboard toggle knob. (Done 2026-05-08: logical inset + mirrored translate for `[dir="rtl"]`.)
- [ ] **UX-C07 (P2)** RTL structural snapshot regression test harness.

### Promotion rule

Tier B/C items are only pulled into active implementation when their explicit "Earn it when" trigger fires.

### Delivered backlog notes (2026-05-08 UX batch)

Shipped pragmatic slices of Tier B backlog items rather than gated full-scope builds:

- **B1 Multi-column sort:** Findings table supports stacked sort (Shift+secondary column) with numbered header hints; Known Issues/Code Health dashboards unchanged in this slice.
- **B2 Bulk actions:** Findings exposes checkbox selection plus **copy selected violations as JSON** (no destructive bulk hide/disable bundle — those remain Top Rules workflows).
- **B3 Large tables:** Rows use **`content-visibility: auto`** with an intrinsic-height hint rather than viewport virtualization library integration.

### UX-B08 implementation slice (active when triggered)

- [x] Add host-side recent-search storage service keyed by surface + workspace.
- [x] Add webview init/set message contract for recent-search sync.
- [ ] Add one persistence test per surface (Known Issues, Findings, Command Catalog). *(still open — exercised manually; follow-up tracked with extension test debt.)*

Each item below carries:

- **Why** — the failure mode the guideline prevents.
- **Scope** — which surfaces / files would change.
- **Sketch** — concrete implementation steps (not exhaustive specs).
- **Risk** — what can go wrong, and how to mitigate.
- **Earn it when** — the trigger that promotes the item from "deferred" to "do next." Without a trigger, the item stays in the backlog.

The order below is **roughly priority-descending within each tier**, but every tier is gated by a real trigger — there is no inherent deadline on this work.

---

## Tier A — Polish that ships with the next non-trivial UI change

**Status as of [Unreleased]:** Tier A is **complete**. Every item below shows what landed and where to find the implementation. Nothing in this section is open work — it stays here as a record so future readers can see how the patterns were applied.

### A1. Surface keyboard-shortcut overlay rollout to remaining dashboards (§15.2) — DONE

- **Landed.** Wired into Command Catalog, Rule Explain, Telemetry, Comparison, Single-package detail, and Package Dashboard, alongside the three from the prior release (Findings, Code Health, Known Issues). Every editor-area dashboard now has the same `?` affordance.
- **Implementation.** `dashboardHero.ts` exposes an `extraToggleHtml` slot that surfaces use to inject `buildKeyboardShortcutsButton()` alongside the full-width toggle. Each dashboard advertises only the shortcuts it actually binds; the Package Dashboard documents its existing arrow-key / `j` / `k` / `Enter` / `Space` / `Alt + ←` row navigation, Command Catalog adds `/` to refocus search.
- **Test coverage.** `extension/src/test/views/violationsDashboardHtml.test.ts`, `extension/src/test/vibrancy/views/known-issues-html.test.ts`, and `extension/src/test/vibrancy/views/package-detail-html.test.ts` each pin the trigger + dialog markup so a regression that drops the overlay would fail in CI.

### A2. Search highlighting in Command Catalog and Known Issues (§8.5.2) — DONE

- **Landed.** Both surfaces wrap matched substrings in `<mark class="search-hit">` after filtering. Known Issues highlights against the full query; Command Catalog highlights every space-separated token (matching how the search blob is tokenized for filtering). The mark is bound to `var(--vscode-editor-findMatchHighlightBackground)` so it survives every default theme.
- **Risk note that informed implementation.** The original sketch warned about HTML mangling. The shipped code walks `TreeWalker` text nodes only and never touches `innerHTML` of the matched cell — wrapping happens via `document.createElement('mark')` and `parent.insertBefore`, so existing `<a>` and other markup stay intact. `clearSearchHighlights()` runs at the start of every `applyFilters` / `applySearch` pass and `parent.normalize()`s after, so re-applying a different query never doubles up `<mark>` tags or fragments text nodes.

### A3. Recent-searches dropdown for Known Issues + Findings + Command Catalog (§8.5.2) — DONE (in-session persistence)

- **Landed.** Dropdown anchored under the search input on each surface. Hidden until the input is focused empty AND there is at least one stored entry; click an entry to re-apply, click the per-row × to remove a single entry, click *Clear* to drop everything. Caps at 10, dedupes (case-insensitive, LRU), and commits the typed query after a debounce of ~800ms so transient keystrokes don't pollute the list.
- **Persistence.** Uses `sessionStorage` keyed per surface (`saropa.knownIssues.recentSearches`, `saropa.findings.recentFilters`, `saropa.commandCatalog.recentSearches`). The list survives within a panel session and resets on panel close, which is good enough to remove the typing friction the original sketch targeted.
- **Cross-session persistence (per-workspace) deferred.** Per [§17.1](guides/UX_UI_GUIDELINES.md#171-persistence-policy-table) recent searches "should" live in `workspaceState` so they survive across workspace reopens. That requires a host-side service plus a typed `postMessage` round-trip per surface — non-trivial coupling. Promoted to **Tier B** (see new B8 below) so it has a sketch and an *Earn it when* trigger.

### A4. RTL-readiness pass on positional `left:` / `right:` (§23.1) — DONE (per-call review complete)

- **Landed.** Every `position: absolute` / `position: fixed` offset in `extension/src/**/*.ts` reviewed individually:
  - **Migrated to `inset-inline-start` / `inset-inline-end`:** the `details.more .menu` popover (chrome + Findings dashboard duplicate), the `.skip-link` keyboard-only affordance, the `.search-clear` X inside Known Issues + Package Dashboard search inputs.
  - **Kept physical `left:`** with an inline rationale comment: the Lints Config slider knob (`.slider:before { left: 2px; }`). Its on-state animation uses `transform: translateX(14px)` which is direction-agnostic; flipping `left` to `inset-inline-start` without flipping the translate sign would break LTR. Full RTL support for the slider is a focused follow-up tracked here as **Tier B (B9)**.
  - **`text-align: right`** on numeric table columns is intentionally untouched — numbers right-align in both LTR and RTL by design, so the physical alignment is correct in both directions.
- **Test gap acknowledged.** The original sketch suggested adding a `dir="rtl"` structural snapshot regression test. Not added in this pass — a meaningful test would need to exercise every dashboard at multiple breakpoints. Tracked as **Tier C (C7)**.

### A5. Per-row pubdev fetch warning glyph in single-package detail (§8.16.3) — DONE (banner-level, not per-row)

- **Landed.** The Single-package detail panel now tracks per-fetch error state for the three lazy fetches (README, version-gap PRs and issues, reverse dependency count) and renders a `.partial-banner` at the top of the page when any of them fails. The banner names the failed sections in user-facing language (e.g. *"Some sections couldn't load: README and logo, and reverse dependency count."*) and exposes a single tier-2 **Retry** button. Retry posts `{ type: 'retryFetches' }` to the host, which clears the error state and re-runs all three lazy fetches; clicks within 2 s of the previous retry are ignored so the user can't spam pubdev or GitHub.
- **Per-row glyph deferred.** The original sketch proposed an inline `⚠` glyph next to each affected row PLUS the partial banner. The banner alone covers the headline failure mode (silent missing sections) cleanly without doubling up; per-row glyphs would require knowing which specific row corresponds to which fetch, which the data model doesn't currently expose. Promoted to **Tier B (B10)** with a concrete sketch.

---

## Tier B — Earned-scope work that needs a real product reason

Bigger lifts. Don't pre-empt them; wait for the product signal. Build the entry path and exit criteria into the plan now so the work is one decision away rather than a scoping exercise from scratch.

### B1. Multi-column sort in Findings + Code Health + Known Issues (§7.4)

- **Why.** Single-column sort handles ~95% of usage. Multi-column emerges when users want a tiebreaker (e.g. sort by severity, then by file) — common in triage workflows once the issue list grows past a few hundred.
- **Scope.** `views/violationsDashboardHtml.ts` (the table sort logic in the inline script), `views/projectVibrancyReportView.ts` (likewise), `vibrancy/views/known-issues-script.ts`.
- **Sketch.**
  1. Replace `sortKey: string, sortAsc: boolean` state with `sortKeys: { col: string, asc: boolean }[]`.
  2. Shift+click on a column header **adds** to the sort stack; plain click **resets** to single-column.
  3. Render small numeric badges (`①` `②`) on each column header showing its position in the stack.
  4. Persist via `vscode.setState({ sortKeys })` ([§17](guides/UX_UI_GUIDELINES.md#17-state-persistence-and-session-memory)).
- **Risk.** UX confusion — users not familiar with shift-click need a discoverability cue. Keyboard-shortcut overlay (already wired) is the right place to advertise it.
- **Earn it when.** A user complaint about tiebreaker sort, OR consistent feedback in user research that "I want to sort by X then by Y."

### B2. Multi-select + bulk actions in Findings (§7.3)

- **Why.** Findings has *Hide rule* / *Disable rule* per-row actions today — handles the common bulk case (suppress one noisy rule). Multi-select earns scope when users want to act on **specific subsets** (e.g. "hide these 8 specific findings" rather than "hide all of rule X").
- **Scope.** `views/violationsDashboardHtml.ts` (table rows + toolbar), `views/violationsDashboardStyles.ts` (selection styling).
- **Sketch.**
  1. Add a checkbox column on the left of the findings table (`<input type="checkbox" data-finding-id="...">`).
  2. Header checkbox toggles all visible rows. Shift+click on a row checkbox extends selection from the last clicked.
  3. Selection state is in-memory only; clears on filter change ([§17.1](guides/UX_UI_GUIDELINES.md#171-persistence-policy-table)).
  4. Bulk-action bar appears above the table when selection > 0: *Hide selected*, *Disable rules for selected*, *Copy selected as JSON*.
  5. Wire `aria-checked`, `role="checkbox"`, range-select keyboard binding (Shift+Arrow extends, Esc clears).
- **Risk.** Selection state desync with filter changes — clear-on-filter is the only sane policy. Multi-select also expands the test surface significantly.
- **Earn it when.** Users explicitly request bulk operations beyond per-rule hide.

### B3. Table virtualization for ≥ 2,000 rows (§7.5)

- **Why.** [§16.2](guides/UX_UI_GUIDELINES.md#162-dom-budget) caps DOM rows at 300 (full render) / 2,000 (with `content-visibility: auto`). Beyond that, virtualization is **required**, not optional. Enterprise projects with 10k+ findings will trip this.
- **Scope.** Findings table primarily; Code Health table secondarily (capped to top 200 already, but the 200 cap is itself a workaround).
- **Sketch.**
  1. **Step 1**: profile a real 5k-finding fixture. Confirm whether `content-visibility: auto` + `contain-intrinsic-size` is enough. (Often is — the budget says ≤ 2,000 with this technique.)
  2. **Step 2**: if not enough, integrate a windowing library (or hand-roll one — virtualizing a flat table is ~150 lines). Render only visible rows + a buffer; dispatch on scroll.
  3. **Step 3**: keyboard navigation must still work — focus into a virtualized row that doesn't exist yet has to materialize it. This is the hard part.
- **Risk.** Sort stability — a virtualized table with sort + filter + virtualization is a state-machine quagmire. Ship measurement-driven (Step 1 first) before committing to Step 2/3.
- **Earn it when.** A real project measurement shows the panel becomes janky (frame drops > 5/sec on filter input), OR a user reports the dashboard freezing on a very large project.

### B4. Column resize + reorder + saved column-set presets (§7.6)

- **Why.** "I want to widen the rule column" is the most-shipped feature that nobody actually uses. Add only when a real complaint surfaces.
- **Scope.** Findings + Code Health + Known Issues + Telemetry tables.
- **Sketch.**
  1. Wrap each `<th>` in a resize handle (`<div class="col-resize">`), drag = adjust column width.
  2. Persist per-workspace via `workspaceState['<panelType>.columns']` ([§17.1](guides/UX_UI_GUIDELINES.md#171-persistence-policy-table)).
  3. Reorder via drag-on-header.
  4. *Reset columns* in the More menu.
- **Risk.** Drag-and-drop in webviews is surprisingly stateful; a botched implementation produces "the column won't release" bugs. The worst case is users avoid the column-resize affordance once they encounter the bug — pulling the feature back is harder than not shipping it.
- **Earn it when.** A user requests it and it's clear which columns they want resizable.

### B5. Offline / stale state + scan-cache fallback (§8.16.5, §8.16.6)

- **Why.** Currently `dart run` returns errors → user sees a generic banner. With a scan cache, the panel can fall back to the last successful result and tag it *Stale* with a freshness pill.
- **Scope.** Host-side: scan cache infra (`extension/src/services/scanCache.ts` — new module). Webview-side: stale pill in the hero status line, *Refresh* CTA in a partial banner. Multiple panels (Findings, Code Health, single-package detail).
- **Sketch.**
  1. Host-side: persist successful scan output to `workspaceState['scanCache.<scanType>']` keyed by panel type. Trim old entries.
  2. On scan failure, post the cached payload to the webview tagged with `{ stale: true, cachedAt: ISO8601 }`.
  3. Webview: when payload is stale, replace the hero freshness pill with `⚠ Cached · 2h ago — Refresh` (clickable; tier-2 button).
  4. Stale styling already exists in chrome (`stale-pill` was lifted in Phase 1).
- **Risk.** Cached data drifting from reality misleads users. Cap cache age at 24h; never serve cache older than that.
- **Earn it when.** A user reports the panel becomes useless during a flaky network / dart-run failure.

### B6. Performance measurement gate in CI (§16.5)

- **Why.** [§16.5](guides/UX_UI_GUIDELINES.md#165-measurement-gate) requires every new dashboard to record TTFP / TTI / filter-latency in its PR description. Today this is honor-system; CI doesn't enforce.
- **Scope.** New module `extension/scripts/measure-perf.ts` + a CI step.
- **Sketch.**
  1. Use Playwright or a headless webview (the snapshot harness has the pieces) to render each dashboard against a synthetic 5,000-row fixture.
  2. Capture `performance.measure` marks: `ttfp`, `tti`, `filter-300`.
  3. Compare against the budgets in [§16.1](guides/UX_UI_GUIDELINES.md#161-time-budgets); fail CI if any exceeds the **hard cap**.
  4. Log target-cap exceedances as warnings (don't fail).
- **Risk.** Flaky CI from machine variance — pin to the same runner image, take median of 5 runs, set generous threshold envelopes (target × 2 = warning, hard cap × 2 = failure).
- **Earn it when.** The test infrastructure for headless webview rendering exists — the snapshot harness gets us most of the way; the perf-mark capture is what's missing.

### B7. State persistence audit (§17)

- **Why.** Every dashboard claims to persist filter / sort state across panel close → reopen via `vscode.setState`. The compliance plan deferred verification ("state survives via webview retain; explicit `vscode.setState` audit is opportunistic"). The audit is the work.
- **Scope.** Every dashboard's client script.
- **Sketch.**
  1. For each dashboard, walk the inline script for `acquireVsCodeApi()` and look for `setState` / `getState` calls.
  2. Check against the persistence policy table ([§17.1](guides/UX_UI_GUIDELINES.md#171-persistence-policy-table)). Filter state, sort, full-width toggle, expanded rows must persist; search query must clear on close (intentionally not persisted across reload — a stale search greeting the user is worse than a fresh one).
  3. Write a single test that mounts each dashboard, sets state, dispatches a hide → show event, and asserts state survived.
  4. Schema-version every persisted object: `{ v: 1, ...state }`. Migrate or discard on read.
- **Risk.** Adding migrations to existing state objects can lose user state if migration is wrong. Pin a migration test per schema version.
- **Earn it when.** A user reports their filter state vanishing across panel reopens (likely already true for several dashboards), OR before a major version bump where breaking the persistence schema becomes a known risk.

### B8. Cross-session persistence for recent searches (§17.1, follow-up to A3)

- **Why.** A3 shipped recent-searches with `sessionStorage` (in-session only). The guideline puts recent searches in `workspaceState` so the list survives panel close → reopen. Users searching the same terms across days get less benefit until this lands.
- **Scope.** `extension/src/views/recentSearches.ts` (new module) + host-side message handler in each surface's panel/webview class + the existing client-side logic in `known-issues-script.ts`, `violationsDashboardHtml.ts` (script), and `commandCatalogWebviewHtml.ts` (script).
- **Sketch.**
  1. Host-side service stores `Record<surfaceKey, string[]>` keyed off `vscode.ExtensionContext.workspaceState`.
  2. Each panel posts its persisted list to the webview on first render via `postMessage({ type: 'recentSearchesInit', list })`.
  3. The client-side helper, on every record/remove/clearAll, posts `{ type: 'recentSearchesSet', list }` to the host.
  4. Cap stays at 10 per surface; total quota cap of 50 entries across all surfaces.
- **Risk.** Migration when a surfaceKey changes: unknown keys in `workspaceState` should be discarded silently rather than throwing.
- **Earn it when.** Two or more reports of "I lost my recent searches when I reopened the panel," OR the in-session implementation surfaces a clear gap during dogfooding.

### B9. Lints Config slider knob full RTL support (§23.1, follow-up to A4)

- **Why.** A4 left the slider knob with physical `left: 2px` because its on-state `transform: translateX(14px)` is direction-agnostic. Full RTL support would flip the knob's animation direction so the off→on visual reads naturally in RTL.
- **Scope.** `extension/src/rulePacks/configDashboardStyles.ts` — the `.slider:before` block plus the `input:checked + .slider:before` translate.
- **Sketch.**
  1. Use a CSS variable for the on-state translate distance, default `14px`.
  2. Add a `[dir="rtl"]` override that sets the variable to `-14px` so the knob slides in the opposite direction.
  3. Convert `left: 2px` → `inset-inline-start: 2px` once the translate is direction-aware.
  4. Verify both directions visually before shipping — a wrong sign produces a visibly broken switch.
- **Risk.** Animation regressions. Manual verification in both directions before merge.
- **Earn it when.** Tier A4's RTL pass surfaces an actual user complaint, OR a localization pass formally adds RTL coverage to the QA matrix.

### B10. Per-row pubdev fetch glyphs in Single-package detail (§8.16.3, follow-up to A5)

- **Why.** A5 shipped a banner-level partial-fetch indicator with one Retry button. Per-row glyphs would attribute the failure to the specific row affected (e.g. a single PR row that couldn't load its review status) and offer a row-scoped retry.
- **Scope.** `vibrancy/views/package-detail-html.ts` (row builders), `vibrancy/views/package-detail-script.ts` (per-row click handler), `vibrancy/views/package-detail-panel.ts` (per-row retry handler), and the data model for tracking which row the error attaches to.
- **Sketch.**
  1. Extend the lazy-fetch error model from `{ readme, gap, reverseDeps }` to a per-row map keyed by some stable id (e.g. PR number for version-gap rows).
  2. Render an inline `⚠` glyph in the affected row with `title` carrying the error reason; click posts `{ type: 'retryFetchRow', rowId }`.
  3. Banner stays as the at-a-glance summary; per-row glyphs are the granular affordance.
- **Risk.** UI clutter when many rows fail. Cap visible glyphs at 3 (with "+N more" overflow) so the panel doesn't degrade into a wall of warnings.
- **Earn it when.** A user reports they can't tell which specific PR/issue row is missing data, OR pubdev rate-limit errors become routine enough that batched failures matter.

---

## Tier C — Background / governance work

Not user-visible, but the guideline says to do it.

### C1. Theme verification automation (§19)

- **Why.** [§19.2](guides/UX_UI_GUIDELINES.md#192-verification-checklist) lists 17 checkboxes that should be ticked in all four default themes (Dark+, Light+, HC Dark, HC Light). Today it's manual.
- **Scope.** `extension/scripts/theme-verify.ts` + `extension/test/visual-snapshots/` baselines.
- **Sketch.**
  1. Render each dashboard against a fixture in each of the four themes.
  2. Capture full-page screenshot per theme. Commit baselines.
  3. CI compares against baselines; > 1% diff fails.
  4. Augment with axe-core or manual contrast checks against [§15.1](guides/UX_UI_GUIDELINES.md#151-contrast-targets).
- **Risk.** Screenshot tests are flaky in CI without a pinned runner image. Tolerate small diffs (~1% per pixel) but catch structural regressions (missing border, swapped color).
- **Earn it when.** A theme-related regression slips through code review (a `color: #fff` that breaks Light+, a fallback hex that loses HC contrast).

### C2. Token coverage matrix automation (§19.4)

- **Already done** as a one-time generation (committed under `extension/src/test/views/snapshots/token-matrix.md`). The matrix needs a CI step that **fails** when a surface adds a token that isn't documented anywhere — a forcing function for the deprecation playbook.
- **Sketch.** Run `npx ts-node extension/scripts/build-token-matrix.ts` in CI; diff vs the committed file; fail on diff with a "regenerate the matrix" message.
- **Earn it when.** The Phase 4 / governance work begins in earnest, OR a token deprecation slips by because the matrix wasn't checked.

### C3. Webview ↔ host messaging contract (§21)

- **Why.** Each dashboard's `postMessage` payload shape is ad-hoc and undocumented. The guideline calls for a typed message protocol.
- **Scope.** Every dashboard's host-side message handler + webview-side `postMessage` calls.
- **Sketch.**
  1. Define message types in a shared `extension/src/views/webview-messages.ts`: `type ToHost = { type: 'runAnalysis' } | { type: 'refresh' } | …;` plus `type ToWebview = …`.
  2. Replace string-keyed dispatches with discriminated-union switches.
  3. Generate a JSON schema or Zod parser at the boundary so malformed messages from the webview side fail loudly.
- **Risk.** Refactoring messages risks breaking webview state restoration on reload. Land per-dashboard, not in one PR.
- **Earn it when.** A bug traces back to a malformed message and ends up costing more debug time than the refactor would.

### C4. Full string externalization (§18.1)

- **Why.** `webview-strings.ts` exists as the helper but most surfaces still inline copy. Centralized strings make a future translation pass tractable and unblock copy-edit-only PRs that don't have to touch every TS file.
- **Scope.** Every dashboard's HTML builder.
- **Sketch.**
  1. For each dashboard, extract every user-facing literal into `webview-strings.ts` under a category (`empty.noFindings`, `toolbar.runAnalysis`, etc.).
  2. Replace inline literals with `STRINGS.empty.noFindings`.
  3. Add a CI lint that bans bare English literals in `*-html.ts` builders (allow exceptions via `// l10n-skip` for technical strings like file paths).
- **Risk.** Big rewrite touching every surface. Land per-dashboard so the diff stays reviewable.
- **Earn it when.** A real localization pass starts, OR a copy-edit PR keeps having to touch 14 files.

### C5. CSV export hardening (§22.2)

- **Why.** Listed in the compliance plan as N/A because no CSV export exists yet. When one is introduced (likely on Findings or Code Health), it must follow [§22.2](guides/UX_UI_GUIDELINES.md#222-export-format-conventions): UTF-8 BOM, RFC 4180 quoting, never-trust-the-user formula prefix sanitization (`=`, `+`, `-`, `@` at start of cell get quoted with a leading apostrophe to prevent CSV-injection in Excel).
- **Earn it when.** A CSV export feature is requested.

### C6. Print / onboarding polish (§22.1, §22.3)

- **Why.** [§22.1](guides/UX_UI_GUIDELINES.md#221-print-styles) print styles are in chrome (Phase 1). Per-surface print verification (does the layout actually print sensibly?) is unfinished. [§22.3](guides/UX_UI_GUIDELINES.md#223-onboarding-and-no-data-states) onboarding for new users (e.g. *What is this?* overlay) is deferred polish.
- **Earn it when.** Either: a user reports a printed report renders garbled, OR onboarding feedback flags discoverability gaps.

### C7. RTL structural snapshot regression test (§23, follow-up to A4)

- **Why.** A4's per-call review of `left:` / `right:` was correct in principle, but only manual verification confirms each surface still renders cleanly under `dir="rtl"`. A structural snapshot test would catch regressions where future CSS additions silently re-introduce physical offsets in places that should flip.
- **Scope.** New test under `extension/src/test/views/snapshots/` that renders each dashboard with `<body dir="rtl">` injected, normalizes the HTML, and diffs against a stored `.rtl.snap` baseline.
- **Sketch.**
  1. Extend the existing `snapshot-harness.ts` with an `rtl: true` option that wraps the rendered HTML in a `<body dir="rtl">` shell before normalizing.
  2. Generate baselines once per surface; commit under `extension/src/test/views/snapshots/*.rtl.snap`.
  3. CI fails on diff so adding a new physical `left:` / `right:` requires either updating the baseline (intentional) or fixing the CSS (regression).
- **Risk.** Snapshot files multiply quickly and review fatigue makes intentional changes hard to spot. Mitigated by keeping the diff small (only inline-positioned elements show up) and by using normalization to strip irrelevant attributes.
- **Earn it when.** A physical-position regression slips into a release, OR the team commits to RTL coverage in QA.

---

## Tier D — Out-of-scope / N/A items captured for future reference

Decisions documented so future contributors don't relitigate them.

### D1. Dedicated no-project webview (§22.3)

- **Decision.** DEFERRED. Findings shows a notification (`Open a workspace folder first`); Code Health does an early return. Both are acceptable host-pattern UX. A dedicated empty-state webview with a tier-1 *Open folder* button would require panel architecture changes (the webview would need to mount before any project data exists).
- **Earn it when.** A user reports the no-project state confuses them, AND host-side refactoring of the panel-mount pipeline is in scope for another reason.

### D2. Per-section error boundary (§8.16.8)

- **Decision.** DEFERRED. Chrome ships `.error-fallback` styling (Phase 1). No surface today has multiple top-level sections that fail independently in a way that benefits from a per-section boundary.
- **Earn it when.** A surface ships with two or more independently-loaded sections (e.g. Code Health gauge fails while function table renders fine).

### D3. KPI cards interactive on Comparison panel (§14.8)

- **Decision.** DEFERRED. Cards are informational; making them clickable presets ([§14.8](guides/UX_UI_GUIDELINES.md#148-inert-kpi-cards) calls inert KPI cards an anti-pattern in the **general** case but the comparison panel's cards summarize a side-by-side and don't have a sensible filter target).
- **Earn it when.** The comparison panel grows a filterable sub-panel where the KPI cards naturally drive the filter.

### D4. About panel a11y scaffolding

- **Decision.** SKIPPED. Panel is `enableScripts: false`, has no interactive controls, no filter / sort. Static read-only surface; landmarks would be cosmetic.
- **Earn it when.** Never, unless the About panel grows interactive content.

---

### Suggested execution order (backlog tiers)

1. ~~**Tier A first**, opportunistically.~~ **Complete as of [Unreleased].** Each item shipped with implementation notes recorded above.
2. **Tier B** items are gated by real triggers (user reports, telemetry, project signals). Do not pull them forward without a trigger; the per-item *Earn it when* lines are the criteria. New items B8 / B9 / B10 were spun out of the Tier A landings (cross-session recent-searches, slider RTL, per-row fetch glyphs) — these are concrete follow-ups with sketches, not loose backlog.
3. **Tier C** items are background work that should ride on a quiet sprint or a release-readiness pass. None are blocking. New item C7 was spun out of A4 (RTL snapshot regression test).
4. **Tier D** items are documented decisions to defer; revisit on the trigger only.

### Tracking conventions (Part B)

- When a Tier A or Tier B item lands, update **Part A** (checkboxes / status table above) with the commit SHA and trim duplicate narrative from **Part B** if the item is fully done.
- When a trigger fires for a Tier B item, escalate it to *next-up* in the team's sprint board — do not silently start the work without acknowledging the trigger.
- New earned-scope backlog items belong under **Part B** in the appropriate tier — not as silent one-off fixes in **Part A** without updating this plan.

---

**Status as of 2026-05-02:** Phase 1–4 of the compliance plan are landed. Quick wins (label sweep, kbd-shortcut wiring on three priority dashboards, full logical-property sweep) are landed alongside this plan. Everything in **Part B** is **earned-scope** work — no blocking deadlines, but each item has a clear trigger and a clear sketch when the time comes.

**Status update [Unreleased]:** Tier A is **complete**. A1 (kbd overlay rollout to 6 more dashboards), A2 (search highlighting in Known Issues + Command Catalog), A3 (recent-searches dropdown in Known Issues + Findings + Command Catalog, in-session persistence), A4 (RTL review of `left:` / `right:`), and A5 (partial-fetch banner with Retry on Single-package detail) all landed with tests. Three follow-ups identified during the work were captured as concrete Tier B / C items (B8 cross-session recent-searches, B9 slider RTL, B10 per-row fetch glyphs, C7 RTL snapshot test) — each has a sketch and an *Earn it when* trigger so they don't drift into vague backlog.
