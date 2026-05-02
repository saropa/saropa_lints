# UX / UI guidelines — editor-area data dashboards

> **Last reviewed:** 2026-05-02
> **Owner:** Most recent contributor to `extension/src/vibrancy/views/report-*.ts` (the gold-standard Package Dashboard).
> **Open issues / proposals:** Discussion thread in the project tracker; tag with `ux-guidelines`.

This document describes the **gold-standard** interaction and visual language used by the full-width **package dependency dashboard** webview (editor tab): rich tables, summary metrics, charts, and deep drill-down. Wording is **generic** so the same patterns can be reused for other dashboards, reports, and embedded HTML surfaces inside a desktop IDE or similar host.

**Vocabulary:** [Section 0](#0-vocabulary) carries the canonical definitions for tier-1, preset filter, segmented control, inset card, chip strip, and the rest of the recurring terms in this document. Read it once before §1.

**Code map:** [Section 13](#13-implementation-map-package-dashboard) lists the Saropa extension files that implement this dashboard so maintainers can jump from guideline to implementation.

**UI catalog:** [Section 8](#8-affordance-catalog) spells out titles, links, counts, sorting, filtering, tooltips, icons, expanders, sections, buttons, and related patterns in one place.

**Coverage requirements:** [Section 15](#15-accessibility-a11y) (a11y), [Section 16](#16-performance-budgets) (perf), [Section 17](#17-state-persistence-and-session-memory) (state), [Section 19](#19-theme-verification-process) (theme verification) apply to **every** new dashboard — there is no opt-out.

<!-- cspell:disable -->

## Changelog

- **2026-05-02** — §0 Vocabulary, §15 Accessibility, §16 Performance budgets, §17 State persistence and session memory, §18 Internationalization / pluralization / formatting, §19 Theme verification process, §20 CSS architecture conventions, §21 Webview ↔ host messaging contract, §22 Print / export / onboarding, §23 RTL support, §24 Document governance. §5 motion enriched with easing-curves library and reduced-motion implementation pattern; §7 grew §7.3 multi-select, §7.4 multi-column sort, §7.5 virtualization, §7.6 column resize/reorder; §8.5 grew §8.5.1 debounce/throttle table and §8.5.2 search behavior; §8.16 split into eight subsections (empty / loading / partial / error / offline / stale / retry-backoff / error-boundary). §14 anti-pattern catalog grew with §14.16 hex fallbacks mask theme-token gaps, §14.17 doubled freshness indicators, §14.18 action-emphasis tint bleeding into content tiles.
- **2026-04-XX** — Initial publication of §1–§14 with the gold-standard Package Dashboard as the reference implementation.

---

## 0. Vocabulary

Canonical definitions for the terms this document uses. If a future contributor coins a synonym, replace it with the term below — every other section relies on these names. Plain language, one row per term, with a canonical example so the definition is unambiguous.

| Term | Definition | Canonical example |
|------|------------|-------------------|
| **Tier-1 / primary action** | The single emphasized action per region — at most one per toolbar, banner, or empty state. Uses the host primary-button background. | *Run analysis* in the Findings toolbar. |
| **Tier-2 / secondary action** | Always-visible companion actions tied to the current data. Multiple allowed (≤4). Uses host secondary-button tokens. | *Refresh*, *Copy JSON*, *Save report*. |
| **Tier-3 / overflow action** | Lower-emphasis actions hidden behind a *More actions ▾* trigger. No visible-row cap because they are collapsed by default. | Palette-style command shortcuts in the More menu. |
| **Preset filter** | A clickable summary card or chip that applies a saved filter combination on click. Active state shows a focus-ring + active-selection background ([§8.5](#85-filtering)). | KPI card *Errors* setting `severity = error`. |
| **Segmented control** | A row of mutually-related buttons inside a single bordered band (`.seg`) that read as one control. Used for multi-select inclusion (severity), radio (footprint mode), or additive (*Show enabled*). Visual model: [§14.15](#1415-toggle-visual-model-inverted-by-default). | The severity / impact filter row in the Findings Dashboard. |
| **Multi-select toggle** | A segmented control where any subset of options can be active. Default state is *all on*; the news is what the user *excluded*. | Severity filter (Errors / Warnings / Info). |
| **Radio toggle** | A segmented control where exactly one option is active at a time. Active option shows the inactive-selection backdrop tint, never primary-button colors. | Footprint mode (own / unique / total). |
| **Additive filter** | A toggle row where *no* button pressed = no constraint; pressing one adds a filter. Default state shows zero pressed. | *Show detected*, *Show enabled*. |
| **Inset card** | A rounded surface with a secondary background tone, sitting visually inside another section. Used for detail rows, sub-sections in single-rule panels, and multi-panel grids ([§7.2](#72-detail-row-expander)). | The expander row body in the package table. |
| **Chip strip** | A bordered row of removable filter chips that appears whenever filter state diverges from defaults ([§8.5](#85-filtering)). Each chip carries the constraint name + value + `[×]`; trailing *Clear all* link. | The active-filter band that appears below the toolbar when the user types a search. |
| **KPI card** | A summary card with a hero number, short label, and optional sublabel; doubles as a preset filter when interactive ([§4.2](#42-summary-cards), [§14.8](#148-inert-kpi-cards)). | The five Severity / Impact cards above the Findings table. |
| **Status line** | A muted one-line strip under the page `<h1>` carrying freshness + the highest-signal facts ([§4.1](#41-header-region), [§14.9](#149-status-line-absence)). | *Last run 2m ago · 0 violations · 4 TODOs · Drift offline*. |
| **Hero band** | The header region: title, optional version stamp, status line, and (when present) a focal visual like a radial gauge or logo. Always rounded with a stronger accent than the body. | The top band of the Findings or Code Health dashboard. |
| **Toolbar band** | A bordered, rounded strip behind search + buttons + selectors so the controls read as one unit ([§4.3](#43-toolbar)). Multiple flat rows of controls bleeding into the page do not count. | The sticky band above the findings table. |
| **Expander / disclosure** | A row or section that toggles a hidden child. Implemented as either a table row + sibling detail row, or a native `<details><summary>` ([§4.5](#45-collapsible-sections), [§8.8](#88-expanders-rows-and-disclosures)). | Per-row file-usage detail in the package table. |
| **Popover** | A fixed-position overlay anchored to a trigger, with high z-index, scrollable body, and dismissal on outside-click or Escape ([§8.12](#812-popovers-and-overlays)). | The "shared dependencies" list expanded from a count cell. |
| **Focus ring** | Outline applied via `var(--vscode-focusBorder)` with `outline-offset` so it sits inside the row bounds and does not clip. Distinct from hover-state hue shift. | Keyboard focus on a sortable header. |
| **Swatch** | A small colored square paired with a label inside a multi-select toggle to encode severity / impact / category in addition to text ([§14.15](#1415-toggle-visual-model-inverted-by-default)). | The red square next to *Errors* in the severity filter. |
| **Affordance** | A visual cue that something is interactive — pointer cursor, link color, focus ring, hover background, button shape. The contract: *if it looks interactive, it must behave interactively* ([§14.1](#141-bait-and-switch-interactives-rows-chips-badges-cards)). | The chevron rotation on an expanded row. |

---

## 1. Design principles

1. **Host-native theming** — The surface must follow the user’s active theme (light, dark, high contrast). Do not ship a fixed brand palette for chrome, text, or controls; bind to the host’s design tokens so contrast and accessibility stay correct when the user switches themes.

2. **Information density without clutter** — Primary workflows are scanning and comparing many rows. Use compact typography, tight vertical rhythm, and optional columns that auto-hide when empty so the table does not advertise noise.

3. **Progressive disclosure** — Show summaries and aggregates first; reveal per-row detail (breakdowns, file lists, dependency clouds) only when the user expands a row or opens a focused panel.

4. **Actionable data** — Numbers and labels that can drive the next step (open manifest, search codebase, open remote docs, rescan) should be visibly interactive and backed by clear affordances (pointer, underline on hover, focus rings).

5. **Honest semantics** — Use color to encode severity or health state consistently (e.g. success, informational, caution, error). Reserve decorative color for charts where a distinct hue per segment is required; even then, prefer hues that remain distinguishable in grayscale-adjacent themes.

---

## 2. Color system

### 2.1 Chrome and content (theme-bound)

| Role | Guideline |
|------|------------|
| Page background | Host editor background token |
| Body text | Host foreground token |
| Secondary / helper text | Host description-foreground token (lower emphasis) |
| Borders and dividers | Host widget-border or panel-border token |
| Subtle panels (cards, toolbars, table headers) | Host inactive-selection or list-hover style backgrounds |
| Primary actions | Host button background / foreground |
| Secondary actions | Host secondary button tokens with hover state |
| Inputs | Host input background, border, and foreground; focus border uses focus token |
| Links | Host text-link token; underline on hover |
| Focus | Host focus-border token (outline or ring, not only color) |
| Badges (counts, tags) | Host badge background / foreground |

### 2.2 Semantic accents (still theme-aware where possible)

Map **grades**, **status**, and **severity** to host tokens when available (e.g. testing passed, info, warning, error foregrounds) so badges stay on-system. For **ordered grades** (A through F), reuse the same accent ladder: best = success-like, mid = info/warning, worst = error.

### 2.3 Data-specific color (charts and gauges)

- **Ordinal / spectrum indicators** (e.g. a single composite score on a continuous scale) may use **computed HSL** along a red → amber → green path so the hue itself carries meaning independent of a named token.
- **Categorical charts** (many segments) use a **fixed hue sequence** defined as CSS variables on a container (e.g. ten distinct hues plus reserved slots for aggregate buckets such as “other”, “unique indirect”, “shared indirect”). One slot can map to description-foreground for “other” style consolidation.
- **Shared vs unique** indirect dependencies: give **unique** segments a cooler, more saturated accent; give **shared** segments a **muted, desaturated** tone to signal “cost already amortized elsewhere.”

Always pair chart color with **non-color cues** (labels, order, legend, tooltips) for accessibility.

---

## 3. Typography

- **Font stack**: Host UI font family (same as the rest of the IDE).
- **Scale**: Slightly smaller than default body for tables and metadata (e.g. ~0.8–0.9em); titles ~1.1–1.4em; hero numbers in summary cards larger (e.g. ~1.8em) with short labels underneath.
- **Weight**: Bold for primary metrics and grade letters; normal for supporting copy.
- **Case**: Uppercase or small-caps only for short column hints / micro-labels, with increased letter-spacing or opacity so they read as labels, not shouting.
- **Monospace**: File paths, IDs, and technical snippets in the host’s monospace preference where density matters.

---

## 4. Spacing, shape, and layout

- **Page padding**: Comfortable outer margin (e.g. 16px) so content does not touch the panel edge.
- **Content max-width with full-width override**: Editor-area dashboards must constrain primary content to a readable max-width (~1100–1300px) centered in the pane. Tables, KPI rows, charts, and prose all inherit the same wrapper — the editor pane can be 4000+px wide on ultrawide monitors, and a 90-character paragraph stretched to 4000px is unreadable. Pair the constraint with a **Full width** toggle (off by default, persisted per-pane) for users who genuinely want the panel to fill the editor — large tables, side-by-side comparisons, and chart-heavy reports can all benefit from the override. Without the toggle, max-width feels like a cage; without max-width, the constraint feels like an oversight.
- **Radius**: Small consistent rounding (roughly 3–8px) on cards, inputs, buttons, and popovers; slightly larger on inset “detail cards.”
- **Vertical rhythm**: Clear separation between **header**, **summary strip**, **chart block**, **toolbar**, **filter chips row**, and **table** using margin rather than heavy divider lines except where grouping needs a bordered band.

### 4.1 Header region

- **Left**: Title and optional **version or build stamp** (smaller, muted, inline with title).
- **Right**: A **hero visual** (e.g. radial score gauge) aligned to the top; the gauge is a focal point, not a replacement for the summary cards.
- **Status line** below the title: one muted sentence summarizing freshness and the highest-signal facts the page knows — for example *"Last run 2m ago · 0 violations · 4 TODOs · Drift offline"*. This tells the user **whether the data is current** and **whether anything needs attention** without scanning the rest of the page. Always present when the data has a generation timestamp; never replace it with marketing copy. Pair every value with a unit or qualifier so the line is self-explanatory in isolation.

### 4.2 Summary cards

- Horizontal **flex row** with wrap; each card: min-width, centered count, label below.
- **Hero number sizing**: ~1.8em weight 700; short label (one line) underneath at body size or smaller. KPI numbers must read as the largest typographic element on the page after the title — if they read like body text, the dashboard fails its first job (give the user a number to scan in a glance).
- **Interactive cards** (filters): pointer cursor, short transition on background and focus ring; **active** state uses list-active-selection background and a 2px focus-colored ring (not only a hue shift).
- **No three-card redundancy**: do not render three cards displaying the same value when filters are at defaults. Either collapse to one card and only fan out when the values diverge, or pick KPIs that always carry distinct information (e.g. *Errors* / *Critical+High* / *Files affected* — not three flavors of total).

### 4.3 Toolbar

- Bordered, rounded **band** behind search, sliders, dropdowns, toggles, and icon buttons so controls read as one unit. Multiple flat rows of controls bleeding into the page background do not count as a toolbar — the band is what makes them read as a control surface instead of decorative chrome.
- **Density tiers** for actions:
  - **Tier 1 — Primary** (≤1 button): the single action most users want next (e.g. *Run analysis*, *Save report*). Uses primary button tokens. Should be the only highlighted control in the toolbar.
  - **Tier 2 — Secondary** (≤4 buttons): the always-visible companion actions tied to the current data (e.g. *Refresh*, *Copy JSON*, *Reset view*). Uses secondary button tokens with icons.
  - **Tier 3 — Overflow** (everything else): collapsed behind a single *More actions ▾* trigger. Anything that is not a frequent action — palette navigation links, settings shortcuts, infrequent toggles — belongs here. Never render more than ~6 buttons in the visible toolbar; the moment a row exceeds that, it stops being a toolbar and starts being a feature index.
- **Sticky** while the user scrolls long content: the toolbar must remain reachable without scrolling back up.
- **Search**: Inline clear control when non-empty; focus removes default outline in favor of border-color using focus token.
- **Auto-apply on change** (debounced): typed-text and checkbox changes should reflect in the table without an explicit *Apply* click. An explicit Apply button is acceptable only when applying the filter is expensive enough to need batching, and even then the affordance should be a *save view* / *run* control, not a *commit my checkboxes*.

### 4.4 Table

- Full width, collapsed borders, subtle row separators.
- **Header row**: Distinct background; **no wrap** on header labels when many columns exist so row height stays stable.
- **Sticky header** where supported for long scrolls.
- **Row hover**: List-hover background.
- **Focused row** (keyboard or cross-highlight from chart): outline using focus token with negative offset so it sits inside the row bounds.

### 4.5 Collapsible sections

- Use native **disclosure** patterns for heavy optional views (e.g. dependency graph): summary line is bold and clickable; body scrolls within a max height with inner padding.

---

## 5. Motion and animation

| Pattern | Duration / easing | Notes |
|--------|-------------------|--------|
| Radial gauge arc fill | ~1.2s ease-out | Animate stroke dash from empty to target; drive with CSS variables so initial keyframe does not fight inline geometry |
| Bar chart grow | ~0.6s ease-out | Width from 0 to target via CSS variable (host webview is Chromium-safe for this pattern) |
| Chevron / expander | ~0.2s linear | Rotate 90° when expanded; full opacity on row hover |
| Copy button fade-in | ~0.15s | Hidden until row hover; full opacity when hovered or “copied” success |
| Summary card / chip hover | ~0.2s | Background and box-shadow transitions |
| Chart row highlight | ~0.15s | Background transition when linked to table filter |

**Principles:** Motion explains **state change** or **orientation** (what opened, what is selected), not decoration. Respect **reduced motion** preferences if the host exposes them (degrade to instant or near-instant updates).

### 5.1 Easing curves library

Pick from this small set; do not invent new curves per surface. Consistency across dashboards lets users predict how long a transition will take, which makes the surface feel responsive instead of laggy.

| Token | `cubic-bezier()` | When to use |
|-------|------------------|-------------|
| `ease-out-default` | `cubic-bezier(0.0, 0.0, 0.2, 1)` | Element entering view (gauge fill, bar grow, expander opening). Decelerates into rest position. |
| `ease-in-default` | `cubic-bezier(0.4, 0.0, 1, 1)` | Element leaving view or being dismissed (rare; prefer instant for dismissal). |
| `ease-in-out-default` | `cubic-bezier(0.4, 0.0, 0.2, 1)` | Two-state transitions where neither side dominates (segmented toggle press, sort-arrow rotation). |
| `linear` | `linear` | Mechanical state flips — chevron rotation, opacity dissolve. Avoid for size/position changes. |

**Duration scale** — `0.15s` (micro: opacity fade-in, hover background), `0.2s` (small: chevron rotation, summary card hover), `0.6s` (medium: bar chart grow), `1.2s` (large: hero gauge arc fill, animation that explains a calculation). Anything longer than `1.2s` is decoration; cut it.

### 5.2 Reduced-motion implementation pattern

Wrap every animation that exceeds `0.2s` in a `prefers-reduced-motion` media query. Do not assume the cascade alone is enough — JavaScript-driven animations bypass CSS, so guard those with `matchMedia`:

```css
@keyframes hero-gauge-fill {
  from { stroke-dasharray: 0 100; }
  to   { stroke-dasharray: var(--gauge-target) 100; }
}
.hero-gauge .gauge-fill {
  animation: hero-gauge-fill 1.2s cubic-bezier(0.0, 0.0, 0.2, 1) forwards;
}
@media (prefers-reduced-motion: reduce) {
  .hero-gauge .gauge-fill {
    animation: none;
    stroke-dasharray: var(--gauge-target) 100;
  }
}
```

```js
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
function applyChartGrow(el, target) {
  if (prefersReducedMotion) {
    el.style.width = `${target}%`;
    return;
  }
  el.animate([{ width: '0%' }, { width: `${target}%` }], { duration: 600, easing: 'cubic-bezier(0.0, 0.0, 0.2, 1)', fill: 'forwards' });
}
```

The contract: when reduced-motion is on, the animation's *end state* must still apply. Skipping the animation entirely AND leaving the element at its start state is a regression — the user with reduced-motion sees a broken empty bar where animated users see a filled one.

---

## 6. Charts and large visuals

### 6.1 Composition

- **Section title** + optional **toggle** (e.g. exclude shared indirect cost) in one header row.
- **Side-by-side layout**: dominant **horizontal bar chart** (labels right-aligned, track flex-grow, values right column) beside a **donut** for the same dataset so users can scan rank and proportion.

### 6.2 Interaction

- **Clickable segments / bars** apply a table filter and show a **filter indicator strip** below the chart with text plus “clear” control.
- **Hover** on bars: background highlight; optional tooltip for exact byte values and percentages.
- **Dimming**: Non-selected segments may reduce opacity when filtering to show what is active.

### 6.3 Radial gauge (header)

- Partial arc (e.g. three quarters of a circle), thick stroke, rounded caps.
- Track uses neutral border color; fill uses **score-derived HSL** or semantic stroke.
- Centered **letter grade** and optional sublabel (muted).

### 6.4 Network / graph (optional block)

- SVG inside a scrollable, max-height region.
- Edges: subtle stroke; **selected** node or edge uses link color and slightly thicker stroke.
- **Direct** vs **indirect** nodes: weight or opacity distinction; clickable text matches link styling.

---

## 7. Tables: columns, sorting, and expansion

- **Sortable** headers: pointer, no text selection, hover background; show sort direction with a small arrow or glyph with muted opacity.
- **Data attributes** on rows for client-side sort/filter (numeric sort for metrics, empty string for missing → stable fallback).
- **Expand column**: Narrow; chevron only; entire cell clickable.
- **Per-row actions**: e.g. copy structured payload — icon visible on row hover, success state uses success accent.
- **Right-align** numeric columns; **nowrap** on counts and sizes to avoid broken layout in narrow panels.
- **Optional columns** omitted from DOM when globally empty (or hidden) to reduce cognitive load.

### 7.1 Cell semantics

- **Missing data**: Em dash or hyphen in **dimmed** style (low opacity), with `title` tooltip explaining why empty.
- **Update severity**: Distinct classes for major / minor / patch (error / warning / info mapping).
- **Embedded badges**: Small pill for dev-only, transitive-only, unused, shared-count, etc., using semantic backgrounds.
- **Consistent inline tags within a list**: when rendering a list of rows that share a column (e.g. a label column listing rule names, file paths, or kind tokens), use **the same HTML element** across every row. Do not mix `<code>` for some rows and `<span>` for others — `<code>` carries default monospace + (in many themes) a subtle background tint, which makes those rows look pre-highlighted and visually distinct from `<span>` rows. The user reads that as "these rows are different / selected" when no such state exists. Pick one element and apply a CSS class for monospace where needed.
- **Don't repeat the column header as cell content.** A column titled *Rules* whose every cell renders the literal text "Rules" (as a link or button) wastes a column header and reads as a mistake — every row appears to repeat the header. Cells in an action column should carry the **verb of the action**, not the noun of the column (*View*, *Open*, *Show*, `▸`), or a small icon with `title`. The header above can still be the noun (*Rules*), but cell text must not be a copy of it. Same rule for *Details*, *Files*, *Errors* — the cell carries the action, the header carries the category.
- **One signal, one column.** If a row attribute can be expressed as a single boolean or category (e.g. *"is this pack applicable to my workspace?"*), render it in **exactly one place** on the row. Splitting the same answer across a status column, a badge, AND a methodology footnote ("flutter >=3.10.0 (pubspec environment) sdk breaking" *plus* a *Yes/No* *In pubspec* cell *plus* a risk badge) forces the user to triangulate three encodings of the same fact. Pick the clearest single column; demote the methodology to a `title` tooltip on that cell so it's reachable but not competing.

### 7.2 Detail row (expander)

- Full-width **inset card**: multi-column CSS grid of sections.
- Section titles: small heading, bottom border, slight opacity.
- **Definition lists** inside sections: label / value grid with muted labels.

### 7.3 Multi-select and bulk actions

When a table grows to the point where a user wants to act on N rows at once (suppress all, copy all, hide all, export selected), introduce row selection — but only when there is a real bulk action. Adding a checkbox column to a read-only table is dead weight.

| Pattern | Guideline |
|---------|-----------|
| **Checkbox column** | Leftmost narrow column. Header carries the *select-all-visible* checkbox (intermediate state when partial). Visible-rows-only — never select rows hidden by filter. |
| **Range select** | `Shift` + click extends from the last clicked row through the current row; respects the visible-row order at the moment of click. |
| **Toggle select** | `Ctrl` / `Cmd` + click toggles a single row without affecting others. |
| **Bulk-action toolbar** | Slides in (or replaces the toolbar contents) when selection ≥ 1. Carries the selection count + applicable bulk verbs (e.g. *Suppress 3 rules*, *Copy 12 findings*, *Clear*). |
| **Selection count display** | `1 selected / 47 in view / 3,200 total` in the toolbar — three numbers because *visible* and *post-filter total* and *grand total* often diverge. Match the disambiguation rule from [§14.11](#1411-identical-twin-kpi-cards). |
| **Selection survival** | Selection clears on filter change unless the row is still visible after the filter applies. State this contract explicitly so the user is never surprised. |
| **Keyboard** | `Space` toggles row at focus; `Shift+Space` extends; `Esc` clears selection. |
| **Empty-state CTA** | Bulk-action toolbars appearing on a 1-row selection still show the count (*1 selected*) — do not hide the toolbar at low counts unless the action is genuinely meaningless under threshold. |

**When NOT to add multi-select.** Single-action tables (one *View* per row) do not need it. If the only bulk action is *Copy as JSON*, *Copy filtered as JSON* in the toolbar already covers the case without per-row selection.

### 7.4 Multi-column sort

Single-column sort is the default. Multi-column sort earns its complexity only when users actually have stable secondary criteria (e.g. *severity desc, then file asc*).

- **Activation**: `Shift` + click on a second sortable header adds it as a tiebreaker. Plain click on any header collapses back to single-column sort by that column.
- **Indicator**: Numbered badges on each active sort column header (`1`, `2`, `3`) plus the direction arrow. No badges in single-sort mode.
- **Default direction per column type** — pick once and codify so users do not have to think:

| Column type | Default | Reasoning |
|-------------|---------|-----------|
| Numeric (count, score, size) | descending | Largest is usually the most interesting. |
| Severity / impact / status (enum) | descending by enum order | Critical / Error first, Info / Note last. |
| Date | descending | Newest first; most projects care about recent. |
| Text / name | ascending | Alphabetical, predictable. |
| Boolean | true first | The "yes" bucket is usually the actionable one. |

- **Stable sort fallback**: when two rows tie on every active column, preserve insertion order. Never let the visible order shuffle on each re-render.
- **Missing values**: `null` / empty string sorts *last* in both directions (defaulting them to "smallest" or "largest" creates surprising clusters when half the data is missing).

### 7.5 Virtualization and pagination

Editor-area tables can render 5,000+ rows on a real project. The `<tbody>` becomes the bottleneck before the data does. Pin thresholds so a future contributor doesn't ship a slow surface.

| Threshold | Strategy |
|-----------|----------|
| **≤ 300 rows** | Render every row in the DOM. No virtualization needed; sort/filter is in-memory; the browser's compositor keeps up. |
| **300 – 2,000 rows** | Render all rows in DOM, but apply `content-visibility: auto` per row (skips off-screen layout/paint cost). Still no virtualization. |
| **> 2,000 rows** | Virtualize (windowing) — render only ~50 rows around the viewport, recycle DOM nodes on scroll. Carry a fixed-height row contract so the windowing math stays cheap. |
| **> 10,000 rows** | Add server-side or worker-side filtering before render. The webview shouldn't see all the rows; the host bridge should pre-filter and stream pages. |

**Pagination vs infinite scroll** — prefer infinite scroll (with a fixed-height window) for read-mostly dashboards because it preserves keyboard navigation and `Find in page`. Use pagination only when the dataset has natural page boundaries (e.g. *one page per project version*).

**"Showing N of M" disclosure** — every virtualized or filtered table renders an explicit count strip near the table foot: *Showing 200 of 4,712 (filtered from 5,000)*. The strip carries the filter context so the user is never confused about whether they are seeing the real total.

### 7.6 Column resize and reorder

Optional. Add only when the surface has wide variation in column-content width across projects (e.g. file paths in monorepos). When you do add it:

- **Resize**: Drag the column-header right edge; double-click to auto-fit. Persist widths to `workspaceState` per surface.
- **Reorder**: Drag the column-header label (not the resize handle); ghost preview during drag. Persist the order alongside the widths.
- **Reset**: A *Reset columns* control in the More menu wipes the persistence so users can recover from broken layouts.

Skip both if the table already fits comfortably with `auto`-sized columns. Resize/reorder is one of the most-shipped features that nobody actually uses — do not add it as defensive scope.

---

## 8. Affordance catalog

One-page reference for the concrete UI elements the gold-standard dashboard uses. **Color** is summarized here but detailed in [Section 2](#2-color-system).

### 8.1 Titles and subtitles

| Element | Guideline |
|--------|------------|
| **Page title** (`h1`) | Single primary name for the report; largest type scale in the document (e.g. ~1.4em). |
| **Product prefix** (editor only) | Editor-area dashboard `<h1>` **and** the document `<title>` are prefixed with `Saropa ` (e.g. *Saropa Findings Dashboard*, *Saropa Code Health*, *Saropa Package Comparison*). The prefix earns the editor pane the user opened from the host command palette. Sidebar webviews, tree views, and quick-open palettes are **not** prefixed — they live inside the host's own activity-bar container which already supplies the product context, and prefixing them would just repeat the parent container's name in every row. Treat the prefix as a contract: any new editor-area panel must adopt it before merging. |
| **Build / version stamp** | Inline next to title, smaller (e.g. ~0.55em of title size), normal weight, **muted opacity** (~0.5)—reads as metadata, not a second headline. |
| **Band subtitles** (`h2`) | Use for major blocks (e.g. chart section); slightly above body size (~1.1em), optional opacity (~0.9) so they sit below the page title hierarchy. |
| **Card / panel micro-titles** | Uppercase or small label style with reduced opacity for “Packages”, “Updates”, etc.; pair with a **large numeric** primary. |
| **Expander detail headings** (`h4`) | Small section titles inside inset cards; bottom border or divider to separate from body; used for “Health”, “Vulnerabilities”, “Links”, etc. |

Avoid stacking multiple `h1`s; keep a **clear depth**: title → optional subtitle line → summary → charts → controls → table.

### 8.2 Links

| Pattern | Guideline |
|--------|------------|
| **External** (registry, changelog, repo) | Real `href`; host opens in external browser; **no underline** by default, **underline on hover**; link color token. |
| **In-panel actions** (open manifest line, search imports, open local folder) | Styled like links (`cursor`, link color, hover underline) but implemented as **script + postMessage** to the host—no `href` to arbitrary schemes. |
| **Long link lists** | Separate with bullets or middots; keep one line where possible with overflow strategy (ellipsis + full string in `title` if needed). |

Escape all dynamic URL segments and query text in HTML builders.

### 8.3 Counts and numeric displays

| Pattern | Guideline |
|--------|------------|
| **Hero counts** (summary cards) | Large bold number; short **label** below (one line); optional `title` with a longer breakdown (e.g. grade distribution). |
| **Wide integers** (downloads, stars) | **Compact display** in the cell (e.g. `1.2M`, `840k`); put **full locale-formatted value** in `title` for precision on hover. |
| **Alignment** | Right-align counts, sizes, and other scalars in tables; **nowrap** so narrow layouts do not wrap mid-number. |
| **Missing / N/A** | Em dash or en dash in **dimmed** class; tooltip explains *why* missing (no registry data, no repo URL, etc.). |
| **Severity or risk beside a count** | Optional emoji or label + count; color-class the cell for worst-case severity so color is not the only cue. |

### 8.4 Sorting

| Pattern | Guideline |
|--------|------------|
| **Sortable headers** | Only columns that sort get `cursor: pointer` and `user-select: none`; hover uses list-hover background. |
| **Direction indicator** | Small arrow / chevron in header with **muted opacity** (~0.6); update when sort changes. |
| **Sort model** | Stable sort; **missing numeric** sorts should not scramble order—use a documented fallback (e.g. empty sorts as NaN / last). |
| **Data for sort** | Prefer **data attributes** on rows (`data-size`, `data-score`, …) so sort logic does not scrape visible text (which may be compacted or localized). |

### 8.5 Filtering

| Layer | Guideline |
|-------|------------|
| **Summary cards** | Act as **preset filters** (click toggles membership in filter set); **active** card gets focus ring + active selection background. |
| **Toolbar** | Text search (with **clear** control), **range** (e.g. max age), **preset dropdown**, **checkboxes** (e.g. include dev deps), **segmented control** (e.g. footprint mode). |
| **Active filter strip** | Dashed border, muted background; label “Active filters:”; **removable chips**; **Clear all** as text button (link-colored, underline on hover). |
| **Chart-driven filter** | Clicking a bar/segment applies the same filter model as cards; show a **chart filter indicator** with explicit copy + clear. |
| **Combine rules** | Document how AND/OR works (typically all active constraints **AND**); edge cases (e.g. “single-use” definition) belong in tooltips or footnotes. |

**Active filter strip is mandatory whenever the filter state diverges from defaults.** This is not optional polish — it is the only way the user can tell *what* is filtering the table without re-reading every checkbox, slider, and search field. Each chip carries the constraint name, the value, and a `[×]` to remove just that constraint; a *Clear all* link sits at the end. Without this strip, the user is left to reconstruct filter state from scattered control values, which they will get wrong.

#### 8.5.1 Debounce / throttle table

Filter inputs that require parsing or DOM updates need rate-limiting so the UI stays smooth during fast typing. Pin numbers so contributors don't re-pick every time:

| Input | Rate | Reasoning |
|-------|------|-----------|
| **Free-text search** | `150ms` debounce | Long enough to coalesce a typing burst, short enough that the table feels live. Anything ≥ `300ms` reads as laggy. |
| **Numeric range slider** | `100ms` throttle | Continuous gesture; throttle (not debounce) so the table updates *during* the drag, not after release. |
| **Checkbox / segmented toggle** | `0ms` (instant) | Discrete state change; the user just committed; no need to wait. |
| **`<select>` preset dropdown** | `0ms` | Same as checkbox. |
| **Sort-header click** | `0ms` | Discrete. |
| **Resize / reorder column** | `100ms` throttle on visual update; `300ms` debounce on persistence write | Visual must feel live; the persistence write to `workspaceState` can lag the gesture. |

**Apply implicitly, never via *Apply* button** — typed-text and checkbox changes auto-apply per the rates above. An explicit *Apply* button is acceptable only when applying the filter is genuinely expensive (e.g. re-runs a CLI scan), and even then the affordance should read *Run scan* / *Save view*, not *Apply*.

#### 8.5.2 Search behavior

| Pattern | Guideline |
|---------|-----------|
| **Default scope** | Search across visible-cell text plus key data-attributes (rule name, file path, message). Document the scope in the input's `placeholder` or `title` (*"Filter by file, rule, or message…"*). |
| **Match style** | **Substring, case-insensitive** by default. Prefix-only or full-word match needs an opt-in toggle. Fuzzy match (Levenshtein) is overkill for editor-area dashboards; reserve for command palettes. |
| **Tokenization** | Spaces in the query are treated as multiple AND-tokens (e.g. *"run analysis"* matches rows with both *run* and *analysis* anywhere). Quoted phrases match literally. |
| **Result highlighting** | Matched substrings get a `<mark>` wrap with a host-token background. Highlight only in the column the match came from to avoid noise. |
| **Recent searches** | After ≥ 5 distinct queries, show a *Recent ▾* affordance below the search input that lists the last 5 (most recent first). Persist to `workspaceState`. Skip until the heuristic count fires — pre-emptive history is clutter. |
| **No-results state** | When the search yields zero rows, the empty-state CTA names the search query in the message ("No findings match *foo bar*") and offers *Clear search* as the tier-1 button. |

### 8.6 Tooltips

| Topic | Guideline |
|-------|------------|
| **Mechanism** | Prefer native **`title`** for portability in embedded webviews unless you invest in a custom tooltip layer (positioning, delay, keyboard). |
| **Content** | Plain language; **multi-line** OK with newlines in `title`; include **units**, **thresholds**, and **definitions** when the UI encodes policy. |
| **Escaping** | Escape quotes and HTML in tooltip strings built from user or registry data. |
| **Redundancy** | Do not duplicate the entire visible cell in the tooltip unless the cell is abbreviated (compact counts, ellipsized description). |
| **Grade / score cells** | Tooltip carries the **factor breakdown**; visible cell stays a compact badge (and optional sparkline). |

### 8.7 Icons

| Topic | Guideline |
|-------|------------|
| **Toolbar / row actions** | Small **Unicode symbols** (file, copy, save, refresh) are acceptable in a host webview; pair every icon button with a **`title`** (and `aria-label` where you add ARIA). |
| **Chevrons** | Row expander: compact triangle; **rotate** when expanded; opacity increases on row hover. |
| **Inline markers** | Single-character or narrow badges for “re-export”, “shared”, etc.—must not be the **only** explanation; tooltip or column legend carries meaning. |
| **Charts** | Prefer shapes and color over icon fonts inside SVGs; keep chart legend text readable without relying on emoji. |

### 8.8 Expanders (rows and disclosures)

| Pattern | Guideline |
|--------|------------|
| **Table row expand** | Dedicated narrow column; whole **expand cell** is clickable; sibling **detail row** spans all columns with one **inset card**. |
| **`<details>` / `<summary>`** | For large optional blocks (dependency **network**, long graphs): summary is the section title; body scrolls with **max-height** and padding. |
| **Animation** | Short CSS transition on chevron; optional max-height transition on detail body if performance allows. |

**Same row visual = same row contract.** If three sibling lists in a section render rows with the same shape, padding, and border, the user has every reason to expect the same interaction on all three. If one of those lists is read-only data (no click target available), the rows must visually demote to a **definition-list** style — no border-bottom row separator, no hover background, no `role="button"`, no pointer cursor. Better still: lift read-only stats out of the row layout entirely and inline them in the section's meta paragraph (e.g. *"3 ignore-for-file, 1 ignore, 1 baseline"*) so the user never sees an inert button-shaped row in the first place. The bait-and-switch — rows that look like buttons but do nothing — is one of the most expensive UX bugs because the user only learns it after clicking and waiting for nothing to happen.

### 8.9 Sections and grouping

| Pattern | Guideline |
|--------|------------|
| **`<section>`** | Wrap self-contained bands (e.g. charts) with an accessible heading. |
| **Toolbar band** | Bordered, filled strip that visually groups all controls that affect the table below. |
| **Inset detail card** | Rounded, secondary background; internal **CSS grid** for multiple sub-panels; consistent gap. |
| **Footnotes** | Below summary or chart, smaller type, muted—material caveats (methodology, data source limits). |

### 8.10 Buttons

| Style | Use |
|-------|-----|
| **Primary** | The single most-likely-next action (e.g. *Run analysis*). One per toolbar at most. Uses primary button tokens. |
| **Secondary** (`toolbar-btn`) | Default for “Open manifest”, “Copy”, “Save”, “Rescan”, “Reset”—host secondary button tokens; hover darkens slightly. |
| **Tertiary / palette** | Lower-emphasis actions that should not compete with the primary: smaller padding, lighter background (e.g. `--vscode-editor-inactiveSelectionBackground`), 1px border. Reserved for navigation-style commands or settings shortcuts. |
| **Toggle (segmented control)** | Mode and filter toggles use a **segmented track** (`.seg` band, [§14.15](#1415-toggle-visual-model-inverted-by-default)), not a `.btn`. Toggles **never** borrow primary-button colors for their pressed state — the primary button vocabulary is reserved for actual actions ("Run analysis", "Save report"). A pressed-state pill that looks identical to a tier-1 action button is the most common source of "buttons I clicked did nothing" complaints. See [§14.15](#1415-toggle-visual-model-inverted-by-default) for the visual model. |
| **Disabled** | Reduced opacity + `cursor: not-allowed`; still explain why in `title` if the reason is non-obvious. **Buttons whose action targets an empty set MUST render disabled with a `title` explaining why.** A button labeled *Enable applicable SDK packs* that fires on click despite zero applicable packs is a silent-failure trap — the user clicks, nothing perceivable happens, trust drops. The disabled state is not a polish concern; it is the only honest signal that this row of buttons cannot help right now. |
| **Destructive** | Rare in read-only dashboards; if present, use error/warning token—not the same as secondary gray. |
| **Icon + text** | Prefer short label text with icon for infrequent actions; icon-only allowed only with strong `title` / `aria-label`. |

**Visible-button budget**: any single toolbar (or visible action row) should expose **no more than ~6 buttons** by default. Anything beyond that goes behind a *More actions ▾* control or into a settings menu. Eighteen pill-shaped buttons in a row is a navigation menu in disguise — the user cannot scan it, and uniform shape destroys the visual hierarchy that makes a primary action discoverable.

**One emphasized button per region.** If every button looks primary, none of them are. The user's eye should land on exactly one button per major region (toolbar, empty-state, drift section, …) without having to read labels.

### 8.11 Inputs and controls

| Control | Guideline |
|---------|------------|
| **Text search** | Host input tokens; **focus** ring via border-color; **clear** (×) inside field when non-empty. |
| **Range** | Labeled min/max semantics; live label updates (“All”, “≤ 12 mo”); consider `title` on thumb for precision. |
| **`<select>` preset** | Input tokens for border/background; options are named scenarios (modernization, risk, cleanup, …). |
| **Checkbox** | `accent-color` or host focus token; label text explains scope (e.g. “Include dev”). |

### 8.12 Popovers and overlays

- **Dependency / reference lists** that would clutter the table: **fixed** position popover, high `z-index`, **max width/height**, scroll, **border + shadow** using widget/editor-widget tokens.
- **Sticky title** inside popover so context stays visible while scrolling.
- **Dismiss** on outside click or Escape if script supports it; otherwise document click-outside behavior.

### 8.13 Focus, keyboard, and selection

- Sortable headers and interactive cells should be **keyboard reachable** if you add `tabindex` and key handlers; at minimum, do not trap focus inside the webview.
- **Row focus outline** when synced from chart or keyboard navigation: use focus-border token, **outline-offset** so it does not clip.
- **Network graph**: focus styles on clickable SVG text match link hover/focus treatment.

### 8.14 Copy, save, and feedback

- **Per-row copy**: control fades in on row hover; **success** state (e.g. check or green accent) briefly after copy.
- **Copy all / save**: secondary buttons; save path and filename convention documented in host message handler; toast or status message on success/failure.

### 8.15 Badges and status pills

- **Letter grades** in small squares: background from semantic tokens; **foreground** often editor background for contrast.
- **Dev / transitive / unused** pills: distinct hue; keep font size small; do not exceed **three** concurrent badges on a single cell if possible.

### 8.16 Empty, loading, and error states

Six distinct conditions, all surfaced through the same chrome but with different messaging contracts. Treat them as separate states — collapsing two of them into one banner is the most common source of misleading UI.

#### 8.16.1 Empty (no data ever)

- **Empty chart**: Omit the section entirely if there is no size data — do not show a broken chart frame. *"No findings."* in a card frame is worse than no card at all: it advertises the absence of data instead of using the space for something useful.
- **Empty optional sections**: Sections that have no data **and** carry no current configuration (e.g. *"Issues view hides — none"*, *"Drift Advisor — integration off"*) collapse to a single muted footer line at most, or are omitted entirely. Never render full-height bordered bands whose only content is "nothing is happening here". Render them at full size only when they have data the user can act on.
- **Skeleton vs omit**: For chart axes that need to keep their slots even at zero (e.g. all severity buckets so the user sees the categories that exist), render zero-width bars rather than omit individual rows. The rule is: **omit the whole card when no data exists; keep the skeleton when partial data exists.**
- **One empty state per emptiness**: Do not render a top-level *"No violations"* banner *and* a child *"No violations match the current filters"* banner for the same condition. Pick one location — the highest one in the hierarchy where the message still has all the context it needs — and suppress the duplicates.
- **Empty-state CTA**: Every empty state names the next action (*Run analysis*, *Reset filters*, *Enable integration*) and renders it as a tier-1 button. Empty banners with no CTA are dead UI.

#### 8.16.2 Loading (in flight)

- **Prefer host progress** for long-running scans — the VS Code notification or status-bar progress is more discoverable than an in-webview spinner and survives panel hide/show.
- **In-webview skeleton** is acceptable for short hops (< 1s) where the host channel would feel laggy. Skeleton rows mirror the real row shape so the layout doesn't reflow when data arrives.
- **Verb on the spinner label**: *Thinking…*, *Preparing…*, *Checking…*, *Fetching…*, *Working…*. Never *Loading…* (banned filler — the user already knows it's loading).
- **Cancel affordance**: any loading state expected to exceed 5 seconds renders a *Cancel* button alongside the spinner. The host bridge must honor it (kill the dart process, abort the fetch).

#### 8.16.3 Partial (some data, some failed)

When a multi-source scan succeeds for some sources and fails for others, the page must render the successful data fully *and* surface the failures inline.

- **Banner above the table**: *"5 of 7 packages loaded. 2 failed: foo, bar."* with a *Retry failed* tier-2 button.
- **Per-row markers**: rows whose data is missing because of the partial failure render with a `⚠` glyph in the affected cells and a `title` explaining ("pub.dev fetch failed; retry to load").
- **Never silently drop the failed rows.** If the row exists in the source list, it must render even if its data is incomplete; otherwise the user thinks the project shrank.

#### 8.16.4 Error (load failed)

- **Banner styling**: input-validation error tokens (border-left accent, background, foreground). Lives at the top of the body, above the toolbar.
- **Message**: name the error class in plain language (*Could not reach pub.dev*, *Workspace has no pubspec.yaml*) — never just *Error*. Include the proximate cause if useful (*HTTP 503*, *file not found*) on a second line.
- **Actionable next step**: tier-1 button driving the obvious recovery (*Retry*, *Open settings*, *Pick workspace*). If no recovery exists, the button reads *Reload* (full webview re-render) — never an inert banner.
- **Stack traces stay out** of user-facing surfaces. Log to host output channel; surface a *Copy details* tier-3 button if developers need to reach them.

#### 8.16.5 Offline (no network)

- **Distinct from generic error.** "Offline" earns its own banner because the recovery is the user's network, not the user's settings.
- **Cached-data fallback**: if a previous scan's data is on disk, render it with a *Stale: last successful run …* badge ([§8.16.6](#8166-stale-cached-data)) plus an *Offline — reconnect to refresh* footer line. Don't blank the page just because the network dropped.
- **Auto-retry policy**: poll the network on a 30s exponential backoff (capped at 5 min) and update the banner state without user action. The user should see *Online again — refresh available* when the network returns, not silent re-success.

#### 8.16.6 Stale (cached data)

When the page is rendering data from a previous run because a refresh failed or hasn't fired yet, the user must know.

- **Status-line warning** ([§4.1](#41-header-region)): replace *Last run 2m ago* with *Last successful run 2h ago — refresh failed* in a `warn` tone pill.
- **Per-cell freshness** is overkill for editor dashboards; one banner covers the page.
- **Refresh button always reachable** even when stale — never lock the user into the cached view.

#### 8.16.7 Retry / backoff pattern

For any recoverable error, follow this contract:

| Attempt | Delay before retry | UI feedback |
|---------|-------------------|-------------|
| 1 (manual) | 0 — fires when user clicks *Retry* | Spinner replaces the button |
| 2 | 1 s after attempt 1 fails | "Retrying…" |
| 3 | 4 s after attempt 2 fails | "Retrying…" |
| 4+ | doubling, capped at 60 s | "Retrying in Ns" with countdown |
| stop | after 6 attempts | "Could not reach … — try again later" + *Retry* button |

Exponential backoff with the cap; never hammer a failing host endpoint at 100ms intervals.

#### 8.16.8 Error boundary fallback (sub-component)

If one section of the page throws while rendering (a chart fails, a sub-table errors), the rest of the page must keep rendering. Wrap each top-level section in a try/catch that:

1. Logs the underlying error to the host output channel.
2. Renders an inline `.error-fallback` band in the section's slot: *"This section couldn't render. Reload the panel."* + tier-2 *Reload* button.
3. Does NOT throw further up — the rest of the page is still useful and the user shouldn't lose unrelated context.

The contract: **a single sub-component failure must not turn the whole dashboard into a blank page.**

---

## 9. Features and behaviors (reference checklist)

Use this as a parity checklist when building similar dashboards:

- [ ] Rescan / refresh without leaving the panel (host command bridge).
- [ ] Open project manifest from toolbar; jump to dependency line from package name.
- [ ] Open another workspace or project via host file picker, then run analysis there.
- [ ] Full **reset view**: filters, sort, persisted UI state.
- [ ] **Export**: copy all rows as structured data; save to workspace reports folder with dated filename.
- [ ] **Search** with clear control; **age** slider; **preset** filter dropdown; **include/exclude** optional dependency class.
- [ ] **Footprint mode** toggle changing how a size column is interpreted (own vs marginal vs total), implemented by CSS visibility classes on precomputed values to avoid jitter.
- [ ] **Active filters** row: pill chips that click to remove; “clear all” as text button.
- [ ] **Sparklines** in a category column when time series exist (mini SVG polyline, theme-colored stroke).
- [ ] **Popover** for long dependency lists: fixed positioning, z-index above table, scrollable, sticky title, link color for navigation targets.
- [ ] **Chart ↔ table** linkage: filtering one updates the other; indicator explains active chart constraint.

---

## 10. Content and trust patterns

- **Footnotes / caveats** below summary metrics (e.g. “sizes are pre-tree-shake estimates”) in small, muted text — never hide material limitations only in tooltips.
- **Tooltips** on dense cells: multi-line, plain language, include thresholds when the UI encodes policy (e.g. stale after N days).
- **External links** open in the host browser; internal paths post back to open editors at a line.

---

## 11. Security and embedding constraints

- Assume a strict **Content Security Policy**: inline styles are often allowed; scripts may require nonces or host-approved patterns.
- Do not rely on **local storage** for sensitive state unless the host explicitly permits it; prefer ephemeral state or host configuration.
- **Escape** all interpolated text in HTML to prevent injection from data files or scan output.

---

## 12. Summary

The gold-standard dashboard treats the **host theme as the single source of truth** for chrome and semantic color, adds **motion only where it explains data**, combines **summary → visualization → controls → dense table → optional graph**, and wires **every repeated user task** (refresh, export, navigate to source, search usage) to one or two obvious controls. New surfaces should match this hierarchy and token usage before introducing new visual languages. The [affordance catalog](#8-affordance-catalog) is the quickest way to align new UI with existing patterns for titles, links, counts, filters, tooltips, icons, and controls.

---

## 13. Implementation map (Package Dashboard)

The **Package Dashboard** is the editor-area webview titled *Package Dashboard*. It is assembled from HTML builders, CSS strings, and client scripts under `extension/src/vibrancy/views/`, with the VS Code panel wrapper in the same area.

### 13.1 Entry and document assembly

| Concern | File | Notes |
|--------|------|--------|
| Singleton `WebviewPanel`, `retainContextWhenHidden`, message routing (pubspec, search, rescan, open file, save JSON) | [`extension/src/vibrancy/views/report-webview.ts`](../../extension/src/vibrancy/views/report-webview.ts) | `VibrancyReportPanel` forwards user actions to commands and workspace APIs. |
| Full HTML document: CSP, style/script injection order, section sequence | [`extension/src/vibrancy/views/report-html.ts`](../../extension/src/vibrancy/views/report-html.ts) | Calls `getReportStyles()`, `getChartStyles()`, `buildChartSection()`, `buildReportTable()`, embeds `getReportScript()` and `getChartScript()`. |
| HTML escaping for untrusted strings | [`extension/src/vibrancy/views/html-utils.ts`](../../extension/src/vibrancy/views/html-utils.ts) | `escapeHtml` and related helpers used across builders. |

### 13.2 Layout and chrome (Sections 4–5, 7–8)

| Concern | File | Notes |
|--------|------|--------|
| All `var(--vscode-*)` layout, table, toolbar, summary cards, popover, network block, grade badges, footprint toggles | [`extension/src/vibrancy/views/report-styles.ts`](../../extension/src/vibrancy/views/report-styles.ts) | Large single CSS string from `getReportStyles()`; documents gauge animation vars in file header comment. |
| Radial gauge SVG, summary cards, toolbar, dependency network `<details>`, table/row/detail markup | [`extension/src/vibrancy/views/report-html.ts`](../../extension/src/vibrancy/views/report-html.ts) | `buildRadialGauge` uses HSL interpolation for arc stroke; `buildReportSummary`, `buildToolbar`, `buildNetworkSection`, `buildReportTable`, `buildDetailCard`, etc. |
| Sorting, filtering, row expand, chart sync, postMessage to host | [`extension/src/vibrancy/views/report-script.ts`](../../extension/src/vibrancy/views/report-script.ts) | Client behavior for the dashboard table and controls. |
| [§8 Affordance catalog](#8-affordance-catalog): titles, links, counts, filters, tooltips, icons, expanders, buttons, inputs, popovers | [`report-html.ts`](../../extension/src/vibrancy/views/report-html.ts) (markup, `title`s, table headers), [`report-styles.ts`](../../extension/src/vibrancy/views/report-styles.ts) (visual states), [`report-script.ts`](../../extension/src/vibrancy/views/report-script.ts) (interactions) | Chart-specific affordances also in [`chart-html.ts`](../../extension/src/vibrancy/views/chart-html.ts) / [`chart-styles.ts`](../../extension/src/vibrancy/views/chart-styles.ts) / [`chart-script.ts`](../../extension/src/vibrancy/views/chart-script.ts). |

### 13.3 Charts (Section 6)

| Concern | File | Notes |
|--------|------|--------|
| Bar + donut markup, “Size Distribution”, exclude-shared toggle, segment prep | [`extension/src/vibrancy/views/chart-html.ts`](../../extension/src/vibrancy/views/chart-html.ts) | `buildChartSection`, `prepareChartData`, consolidation rules. |
| Chart CSS variables (hue slots), bar grow keyframes, donut segments, tooltips | [`extension/src/vibrancy/views/chart-styles.ts`](../../extension/src/vibrancy/views/chart-styles.ts) | `getChartStyles()`. |
| Chart interactivity (filter indicator, clicks, dimming) | [`extension/src/vibrancy/views/chart-script.ts`](../../extension/src/vibrancy/views/chart-script.ts) | `getChartScript()`. |

### 13.4 Related vibrancy webviews (same product family, not the main dashboard)

These follow similar token-driven patterns but serve different entry points; reuse styling ideas, not necessarily full parity. **Editor-area panels only** in this section — sidebar webviews are intentionally excluded from the gold-standard scope (they have their own constraints around width and tree-view density).

| Surface | Files |
|--------|--------|
| Single-package detail panel (editor tab) | [`package-detail-panel.ts`](../../extension/src/vibrancy/views/package-detail-panel.ts), [`package-detail-html.ts`](../../extension/src/vibrancy/views/package-detail-html.ts), [`package-detail-styles.ts`](../../extension/src/vibrancy/views/package-detail-styles.ts), [`package-detail-script.ts`](../../extension/src/vibrancy/views/package-detail-script.ts) |
| Package comparison panel (editor tab) | [`comparison-webview.ts`](../../extension/src/vibrancy/views/comparison-webview.ts), [`comparison-html.ts`](../../extension/src/vibrancy/views/comparison-html.ts) |
| Known Issues Library panel (editor tab) | [`known-issues-webview.ts`](../../extension/src/vibrancy/views/known-issues-webview.ts), [`known-issues-html.ts`](../../extension/src/vibrancy/views/known-issues-html.ts), [`known-issues-script.ts`](../../extension/src/vibrancy/views/known-issues-script.ts) — re-uses [`getReportStyles()`](../../extension/src/vibrancy/views/report-styles.ts) so its summary cards / toolbar / table inherit the gold-standard look. |
| Shared row action helper | [`view-actions.ts`](../../extension/src/vibrancy/views/view-actions.ts) — `openFileAtLine` for postMessage navigation; reuse from new dashboards rather than re-implementing. |

> Sidebar webview `detail-view-provider.ts` (and its `detail-view-{html,styles,script}.ts`) is **out of scope** for these guidelines.

### 13.5 Other editor dashboards (non-vibrancy)

Editor-area panels under `extension/src/views/` that are **not** part of the vibrancy product family but still target the gold-standard hierarchy (summary → controls → table). When adding a new surface, prefer the package dashboard's **split files** pattern (`*-html.ts`, `*-styles.ts`, `*-script.ts`) and bind to `var(--vscode-*)` tokens rather than growing a monolithic `buildHtml` string with hard-coded color.

| Surface | Files | Notes |
|--------|-------|-------|
| Findings Dashboard | [`violationsWideReportView.ts`](../../extension/src/views/violationsWideReportView.ts), [`violationsDashboardHtml.ts`](../../extension/src/views/violationsDashboardHtml.ts), [`violationsDashboardStyles.ts`](../../extension/src/views/violationsDashboardStyles.ts) | Grouped findings, severity/impact filters, search, export — closest non-vibrancy peer to the gold standard. |
| Project Vibrancy report | [`projectVibrancyReportView.ts`](../../extension/src/views/projectVibrancyReportView.ts), [`projectVibrancyReportStyles.ts`](../../extension/src/views/projectVibrancyReportStyles.ts) | Function-level scan results rendered after CLI run. |
| Rule triage block | [`triageDashboardHtml.ts`](../../extension/src/views/triageDashboardHtml.ts) | Embedded inside the lint config dashboard — same groups as the optional Triage sidebar tree. |
| Rule Explain panel | [`ruleExplainView.ts`](../../extension/src/views/ruleExplainView.ts), [`ruleExplainPanelStyles.ts`](../../extension/src/views/ruleExplainPanelStyles.ts) | Single-rule deep-dive opened from issues / palette. |
| Command Catalog panel | [`commandCatalogView.ts`](../../extension/src/views/commandCatalogView.ts), [`commandCatalogWebviewHtml.ts`](../../extension/src/views/commandCatalogWebviewHtml.ts) | Searchable, categorized command browser with recent-runs replay. |
| About panel | [`aboutView.ts`](../../extension/src/views/aboutView.ts) | Version + product info; lightest webview but still must follow theme tokens. |
| Related Rule Telemetry panel | [`relatedRuleTelemetryView.ts`](../../extension/src/views/relatedRuleTelemetryView.ts) | Telemetry counter table with refresh / copy / reset actions. |

CSP escaping should always go through [`createWebviewCspNonce`](../../extension/src/vibrancy/views/html-utils.ts) and [`escapeHtml`](../../extension/src/vibrancy/views/html-utils.ts) rather than per-file copies, so untrusted scan output cannot break out of HTML attributes.

---

## 14. Anti-pattern catalog and density-first ordering

Concrete patterns that have caused dashboards to feel "bland" or "broken" even when each part technically works. Every entry below is something a reviewer caught after the surface shipped — they belong here so the next surface catches them at design time.

### 14.1 Bait-and-switch interactives (rows, chips, badges, cards)

Two patterns generalize from the same root cause:

1. **Sibling rows with mixed contracts** — three sibling sub-sections render row-shaped lists with identical padding, border, and shape. Two are `role="button"` with click handlers; the third is `inert` with no action. The user has no way to know in advance which is which.

2. **Interactive-looking chips, badges, or cards that do nothing** — a tier "segmented control" rendered as `<span class="chip active">` with hover-style and an active state, but no click handler. KPI cards with focus-ring-shaped borders that aren't focusable. Risk badges that look like filter chips but aren't clickable. Each one teaches the user that *visual affordances on this page are unreliable* — the cost compounds across the surface.

**Failure mode:** the user clicks (or hovers, or tabs to) something that looked interactive, gets no feedback, and assumes the dashboard is broken. After two or three of these, they stop trusting any click affordance on the page.

**Fix — pick one of two paths for every interactive-looking element:**

- **Make it real.** If the element makes sense as a control (tier chips → segmented radio control, KPI card → preset filter), wire it up: real `<button>` / `role="radio"`, keyboard handlers, postMessage, and remove the redundant separate "Set tier" / "Apply filter" toolbar button.
- **Demote it visually.** If it cannot be wired up, strip the affordance: no border, no active-state hue shift, no hover background, no pointer cursor. Render it as inline meta text, a definition list, or a comma-separated stat. Better still: lift the data into the parent section's description so the user never sees a button-shaped element again.

The contract: *if it looks like a button, it must behave like a button.* See [§8.8](#88-expanders-rows-and-disclosures) for the same-visual = same-contract rule applied to row layouts specifically.

### 14.2 Doubled empty states

The page renders a top-level *"No items found"* banner *and* an inner *"No items match the current filters"* banner for the same emptiness condition. The user reads the second banner as a different statement and tries to find the difference; there is none.

**Fix:** decide which level owns the empty state — usually the highest level that still has the context to say something useful — and suppress the duplicates. The other levels render nothing (no card, no banner, no border).

### 14.3 Placeholder-as-content

A section's only content is a paragraph stating the section is empty: *"No findings."*, *"Nothing hidden."*, *"No server."*. Each one is bordered, full-width, and visually weighted the same as a section that *does* have data. The page ends up advertising five flavors of nothing.

**Fix:** sections with no current data and no current configuration **collapse to a one-line muted footer** at most, or are omitted entirely. A bordered band is earned by having data in it. This is the converse of the *empty-chart* rule in [§8.16](#816-empty-loading-and-error-states).

### 14.4 Flat-toolbar overflow

The toolbar contains 14+ pill-shaped buttons in one or two flat rows: refresh, run, copy, help, group-by, text-filter, severity, hide-rules, metadata, clear-filters, clear-suppressions, clear-focus, match-editor, copy-tree, package, code-health, lints-config. Every button has the same shape, same color, same priority. None is discoverable by scanning.

**Fix:** apply the **density tiers** from [§4.3](#43-toolbar) (one tier-1 primary, ≤4 tier-2 secondary, everything else behind a *More actions ▾* trigger). The toolbar's job is to let a user reach the next likely action in one glance — not to expose every command the surface can execute.

### 14.5 Buried high-value sections

The page renders sections in implementation order: title → filters → buttons → KPI → charts → suppressions → hides → empty findings → TODOs → HACKS → Drift. The single most useful section on screen (4 TODOs the user can act on) sits below five sections of empty placeholders. The user has to scroll past noise to reach signal.

**Fix:** reorder by **signal density per visit**, not by code module. See [§14.7](#147-density-first-content-ordering).

### 14.6 Decorative weight without depth

Every card on the page uses the same border (`1px solid widget-border`), same radius, same surface tone. Hero, KPIs, charts, sections, and footers all read at the same visual weight. The page has no zoning — eye has nowhere to land first.

**Fix:** layer surfaces. Use at least three tones: page background, panel surface, inset detail card. Reserve a stronger accent (gradient, brighter border, subtle shadow) for the hero. Section titles should be `<h2>` so structural depth is real, not just stylistic.

### 14.7 Density-first content ordering

When laying out the page, sort sections by **expected useful information per visit**, not by feature module:

1. **Hero** — title, status line, freshness, top-line counts.
2. **Actionable summary** — KPIs that summarize the most recent run; chips showing currently-active filters.
3. **Primary table** — the findings list itself. If empty, the empty-state banner with a tier-1 CTA; suppress all child empty states.
4. **Secondary actionable lists** — TODOs, HACKS, drift issues, anything the user can click into and fix. Order within this band by current count, descending: lists with content render fully, lists at zero collapse to a one-line footer.
5. **Charts** — only when they have data; otherwise omit ([§8.16](#816-empty-loading-and-error-states)).
6. **Diagnostics / metadata** — suppressions, hides, integration health, server status. Bottom of the page; collapsed when inactive.

The principle is: **the user's attention is the scarcest resource on the page**. A section's vertical position is a direct claim on that attention. Empty placeholder sections pushing actionable content below the fold is the most common density failure.

### 14.8 Inert KPI cards

KPI cards render numbers and nothing else: no hover, no click, no link. They are static text with a border. The user cannot use them to drive the table.

**Fix:** every KPI card is a **preset filter** ([§8.5](#85-filtering)). Clicking *Errors* sets the severity filter to `error`. Clicking *Critical+High* sets the impact filter to `critical,high`. Clicking *Files affected* opens a popover listing them. The card is the shortest path to the next likely query.

### 14.9 Status-line absence

The page renders a title and a marketing subtitle (*"Grouped lint findings with fast filtering, impact focus, and export."*) and gives no indication of when the data was generated, how many items the page contains, or whether anything needs attention. The user has to scan the entire page to answer "is this fresh?".

**Fix:** every dashboard with a generation timestamp must show a **status line** under `<h1>` ([§4.1](#41-header-region)) — one muted sentence with the freshness and the highest-signal facts. *"Last run 2m ago · 0 violations · 4 TODOs · Drift offline."* The marketing subtitle, if kept, goes elsewhere (footer, About panel) — not in the place where the user's eye looks for "what does this page know right now".

### 14.10 Filter state without a chip strip

Severity, impact, contains, and group-by are set across multiple controls, possibly different rows. The user cannot tell at a glance which filters are active without re-reading every control.

**Fix:** render an **active filters chip strip** ([§8.5](#85-filtering)) whenever the filter state diverges from defaults. Each constraint is one chip with a `[×]` to remove. *Clear all* sits at the end. The strip is a contract with the user: "this list is shaped by these things, here is how to undo any of them."

### 14.11 Identical-twin KPI cards

Three KPI cards render the same number when filters are at defaults: *Visible findings 0 / Post-disable total 0 / Export payload 0*. Three boxes with one number is not three pieces of information.

**Fix:** collapse to one card when values match; expand only when they diverge (and explain *why* they diverge — *"12 visible / 47 post-disable / 47 in export — 35 hidden by view filters"*). Or pick KPIs that always carry independent information — see [§4.2](#42-summary-cards).

### 14.12 One signal, multiple encodings

A row attribute that answers a single question — *"is this pack applicable to my workspace?"*, *"is this rule enabled?"*, *"does this file have errors?"* — gets rendered three places at once: a status column (*Yes/No*), an inline badge on the row name, and a methodology footnote ("flutter >=3.10.0 (pubspec environment) sdk breaking"). Now the user has to triangulate: which of the three is authoritative? Do they ever disagree? What does each one mean?

**Failure mode:** every cell triples the cognitive cost of scanning a row. The user reads three encodings, decides nothing was different, and learns to ignore two of them — at which point one of the three is just noise on the page.

**Fix:** pick **one column** that carries the signal. Demote the other two: methodology becomes a `title` tooltip on the chosen cell; the inline badge moves into a dedicated category column or is dropped. Three places to look becomes one place to look plus one tooltip for the curious.

### 14.13 Schema-duplicate tables

Two side-by-side tables with **identical columns** split by a single category — *SDK migration packs* (Pack / In pubspec / Enabled / Rules / View) and *Package rule packs* (Pack / In pubspec / Enabled / Rules / View). The category split looks tidy in implementation order but doubles the column-header repetition, prevents single-glance comparison ("which packs across all types are detected?"), and forces the user to mentally union two filtered views every time they want a workspace-wide count.

**Failure mode:** the user cannot answer *"what's enabled across the whole workspace?"* or *"sort all packs by rule count"* without scrolling between two tables. Filters and search must be implemented twice. Empty states ship twice ([§14.2](#142-doubled-empty-states)).

**Fix:** **one table, one schema, with a Type column and a Type filter chip.** The table grows by one column (cheap) and loses an entire duplicate header row plus an entire duplicate footnote (expensive savings). If the categories carry meaningfully different sub-actions (e.g. SDK packs have a *Rollout* button), keep the per-row action column; the categorization stays as a filter, not as a structural split.

### 14.14 Reference content above the fold

Documentation links, target-platform tables, methodology footnotes, and "About this dashboard" copy live at the top of the page in implementation order — first because they were the first thing the developer wrote, last in the user's actual scan order. The user's eye lands on three external doc links before reaching a single row of the data they came for.

**Failure mode:** the page advertises *what it is* before showing *what it knows*. First-time users may need the docs, but every-day users — the dominant traffic — pay the scroll cost on every visit.

**Fix:** reference content goes into a **bottom band** (after the primary table) or behind a single help-icon affordance in the header. Marketing subtitles, link lists to external docs, and pure-Dart-vs-Flutter platform tables belong below the data, not above it. The status line under `<h1>` carries the only above-the-fold meta the dashboard owes the user ([§4.1](#41-header-region)).

### 14.15 Toggle visual model (inverted by default)

A multi-select toggle whose default state is "all on" — severity filter, impact filter, include-dev-deps — should look **quietest** in its default state and louder only when the user has diverged from defaults. The naive implementation does the opposite: every toggle in the on-state renders as a filled primary-button pill, so a dashboard with all filters at defaults greets the user with a **wall of blue pills**. Every pill looks like a primary action; none of them are actions. The eye has nowhere to land, and the pressed-state vocabulary collides with the actual action buttons in the same toolbar.

**Failure mode:** users learn that on this surface, "looks like a primary button" is unreliable. Trust drops on every click affordance — including the real ones.

**Fix — invert the visual model:**

- **Pressed (included)**: plain text label + the semantic swatch (severity color, impact color, etc.) + slight bold weight or `✓` glyph. **No primary-button background.** This is the resting state, so it must be quiet.
- **Unpressed (excluded)**: ghosted — reduced opacity (~0.5), strike-through *or* a dashed outline + muted swatch. The exclusion is the news; the chrome should advertise it.
- **Track band** (`.seg`): subtle inactive-selection background with a 1px border so the user can see toggle membership at a glance. The track is the toggle's container; the buttons inside it inherit shape from the track, not from the action-button vocabulary.

**Concrete vocabulary separation:**

| Element | Default state | Active/changed state | Background |
|--------|---|---|---|
| **Action button** (`.btn.tier-1`) | always emphasized | n/a (button has no toggle state) | `var(--vscode-button-background)` |
| **Action button** (`.btn`, secondary) | always visible | hover only | `var(--vscode-button-secondaryBackground)` |
| **Toggle in segmented control** (`.seg .seg-btn`) | quiet (text + swatch) | quiet (text + swatch + ✓) — diverged toggles are the exception | transparent inside the `.seg` track |
| **Excluded toggle** | ghosted (opacity 0.5, strike-through) | n/a | transparent |

The contract: **the primary-button color is reserved for "click me to do something." It does not mean "this filter includes this value."** Filter inclusion is the resting state — a quiet UI is doing its job.

This rule covers severity/impact filters, dev-deps inclusion checkboxes, group-by selectors that render as button rows, and any other multi-select affordance that the user toggles to shape the table or chart below.

**Radio toggles are different.** A toggle where exactly one option is active at a time — footprint mode (own / unique / total), tier selection (Essential / Recommended / …), preset chooser — must NOT use the inverted strike-through model, because two of the three options would always read as ghosted, which is louder than the active one. Radio toggles use a softer pattern: the active option gets an **inactive-selection backdrop tint** (`--vscode-list-activeSelectionBackground`); inactive options stay transparent text at slightly reduced opacity (~0.6). The user picks out the active option by its subtle tinted backdrop, not by a shouting blue pill. The track band still groups the options visually, and the primary-button color is still off-limits.

| Toggle kind | Default | Active state | Inactive state |
|---|---|---|---|
| Multi-select inclusion (severity, impact, dev-deps) | all pressed = all included | text + colored swatch, opacity 1 | strike-through, opacity 0.5, desaturated swatch |
| Radio (footprint, tier, preset) | one selected | text + inactive-selection backdrop | transparent, opacity 0.6 |
| Additive filter (`Show detected`, `Show enabled`) | none pressed = no constraint | text + inactive-selection backdrop, weight 600 | plain text, opacity 0.85 |

**Diverged state is the loud one — but loud never means primary-button colors.** All three patterns share the rule that the pressed state must NOT use `--vscode-button-background`. The active vocabulary for radio + additive is the inactive-selection backdrop tint; the active vocabulary for multi-select is "stay quiet, let the strike-through on the unpressed siblings do the talking." Primary-button colors are reserved for tier-1 actions in the same toolbar.

### 14.16 Hex fallbacks in `var(--vscode-*, #hex)` mask theme-token gaps

The defensive form `var(--vscode-widget-border, #333)` looks careful but is the worst of both worlds: a missing host token now silently falls back to a *dark-only* hex (`#333` is invisible on a light theme background), so the surface looks fine in the developer's Dark+ theme and breaks the moment any user switches to Light+ or High Contrast. The fallback hides the bug — the developer never sees the broken state, the bug ships.

**Failure mode:** the hex was picked once for the dark theme during initial development. Months later, a contributor running Light+ files an issue: "section borders disappear on light theme". Diagnosis takes hours because the dev's own VS Code (Dark+) renders correctly.

**Fix:** drop the hex fallback. Trust the host to define `--vscode-*` tokens (it always does, across every supported VS Code version). If a token genuinely might be undefined in some context, fall back to **another theme-bound token**, never a literal hex:

```css
/* Wrong */
border: 1px solid var(--vscode-widget-border, #333);
background: var(--vscode-input-background, #1e1e1e);

/* Right */
border: 1px solid var(--vscode-widget-border);
background: var(--vscode-input-background);

/* Acceptable when the primary token may be missing in older VS Code versions: */
background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
```

The rule: **every fallback in a `var()` expression must itself be theme-bound** (another `var(--vscode-*)` token). Hex literals belong only in pre-defined chrome tokens (`--surface-1`, `--accent-error`, etc.) where the dev consciously chose the value as intentional non-theme-bound color.

### 14.17 Doubled freshness indicators

The status line under `<h1>` carries *Last run 2m ago*. The chart tooltip on the worst-package bar also says *(Scanned 2 minutes ago)*. The toolbar's *Refresh* button has a tooltip *Reload — last refreshed 2m ago*. Three reports of the same fact.

**Failure mode:** the user sees the time three times, can't tell whether the three numbers are tracking different events ("scan time" vs "fetch time" vs "render time"), and starts triangulating. They are all the same number. The redundancy taught them to distrust each one.

**Fix:** the status line is the single source of truth for freshness. Remove the chart-tooltip timestamp and the refresh-button timestamp. If a chart bar genuinely has its own freshness (e.g. the network call that populated *that one bar* is older than the rest of the page), surface it as a per-cell warning glyph with a `title`, not as a duplicate of the page-level timestamp.

### 14.18 Action-emphasis tint bleeding into content tiles

The toolbar's tier-1 *Run analysis* button uses `--vscode-button-background`. A row of *Frequent* tiles below the toolbar uses `color-mix(in srgb, var(--vscode-button-background) 12%, var(--vscode-editor-background))` — a 12% tint of the same primary color. The tiles read as "almost actions". The user's eye lands on them with the same weight as the actual button, and the tier-1 emphasis dilutes.

This is the same root cause as [§14.15](#1415-toggle-visual-model-inverted-by-default) — primary-button color leaking into content vocabulary — but with content cards / KPI tiles / category badges instead of toggles.

**Failure mode:** every "softer" use of the primary color erodes the contract that primary = "click me to do something." After a few of these, the user no longer knows which pixels are actions and which are decoration.

**Fix:** the primary-button color belongs to one place only — the tier-1 button. Content surfaces (tiles, KPI cards, badges, category counts) use:

- `var(--vscode-editor-inactiveSelectionBackground)` for default tile backgrounds
- `var(--vscode-list-activeSelectionBackground)` for *selected* / *active filter* state
- `var(--vscode-badge-background)` for count badges
- `var(--surface-2)` / `--surface-3` for layered card depth

If a tile genuinely needs a slight color treatment to feel interactive, add a `:hover` outline using `--vscode-focusBorder` — never a tint of `--vscode-button-background`. The action-color vocabulary stays reserved.

---

## 15. Accessibility (a11y)

Treat accessibility as a coverage requirement on every dashboard, not a polish pass at the end. VS Code is used by developers who rely on screen readers, keyboard-only navigation, high-contrast themes, and reduced-motion preferences. Every section below applies to **every** dashboard — there is no "internal tool, skip a11y" exception.

### 15.1 Contrast targets

Bind to host theme tokens ([§2](#2-color-system)) and the host enforces contrast for chrome. For decorative or computed colors (chart hues, score gauges, semantic accents), pin explicit ratios:

| Use | Minimum contrast (WCAG) | When |
|-----|-------------------------|------|
| **Body text on background** | 4.5:1 (AA) | All copy. AAA (7:1) preferred for long-form prose. |
| **Large text** (≥18pt or ≥14pt bold) | 3:1 (AA) | Section headings, KPI numbers. |
| **Active UI components** (buttons, focus rings, form borders) | 3:1 against adjacent | Required for non-text cues. |
| **Decorative graphics** | No requirement | Chart segments paired with non-color cues per [§2.3](#23-data-specific-color-charts-and-gauges). |
| **Disabled state** | No requirement | But never less readable than 3:1 if the disabled label still carries meaning the user must read. |

**Verify in all four default themes** — Dark+, Light+, High Contrast Dark, High Contrast Light — for every new surface ([§19](#19-theme-verification-process)). Computed colors (HSL gauges, chart hues) need explicit verification because no host token guards them.

### 15.2 Keyboard navigation

Every interactive element must be reachable, operable, and visible from the keyboard alone.

| Pattern | Rule |
|---------|------|
| **Tab order** | Follows visual reading order: hero → status line → KPI cards → toolbar → table headers → table body → footer. Never use `tabindex` > 0 to reorder; use DOM order instead. |
| **Skip links** | Long pages (chart-heavy or table-dense) include a hidden *"Skip to table"* link as the first focusable element. Visible only on focus. |
| **Focus visible** | Every interactive element shows the host focus ring (`outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px`). Never `outline: none` without an immediate replacement. |
| **Focus traps** | Popovers, dialogs, and overlays trap focus inside while open; `Esc` releases the trap and returns focus to the trigger. |
| **Activation keys** | `Enter` and `Space` activate buttons, role="button" cards, and chevron expanders. `Arrow` keys navigate inside segmented controls and grid cells. |
| **Range selection** | `Shift + Arrow` extends selection in tables that support multi-select ([§7.3](#73-multi-select-and-bulk-actions)). |
| **Escape contract** | `Esc` consistently means: close popover → clear search → blur input → cancel selection. Document the order so users learn it. |
| **Discoverable shortcuts** | A *Keyboard shortcuts* link in the help-icon overlay or footer lists every page-level shortcut. The user shouldn't have to read source to find them. |

### 15.3 Screen reader patterns

| Pattern | Rule |
|---------|------|
| **Heading hierarchy** | Strict `h1` → `h2` → `h3` → `h4` with no skips. Section depth must match the visual depth ([§8.1](#81-titles-and-subtitles)). One `h1` per page. |
| **Landmark regions** | Wrap major bands in semantic elements: `<header>` for hero, `<nav>` for toolbar (when it carries navigation links), `<main>` for the primary table, `<footer>` for metadata. Only one `<main>` per page. |
| **`aria-label` / `aria-labelledby`** | Every region without a visible heading carries `aria-label`. Icon-only buttons always carry `aria-label`. |
| **`aria-describedby`** | Pair input fields and complex controls with their helper text via `aria-describedby` so the screen reader reads both label and hint. |
| **`aria-live` regions** | Filter / sort changes that update visible row counts announce via a single `aria-live="polite"` region (`#announcer`) — *"47 of 200 rows visible"*. Pre-emptively announcing every keystroke is noise; debounce to ≥ 300ms. |
| **`aria-busy`** | Long-running region updates (≥ 1s) toggle `aria-busy="true"` so screen readers know to wait. |
| **`role="status"`** | Empty-state, error, and partial-state banners get `role="status"` so they announce on first render. |
| **`role="alert"`** | Reserve for genuinely critical errors that interrupt the user's flow. Overuse trains the reader to ignore alerts. |
| **Hidden text for context** | Add `<span class="sr-only">` text to icon-only cells when the icon's meaning isn't obvious from the column header. |

### 15.4 Touch targets and pointer affordances

Even though desktop is the primary form factor, follow touch-target sizing because (a) VS Code runs on touch laptops and tablets, (b) accessibility guidance applies regardless of input method.

- **Minimum 44 × 44 CSS pixels** for any pointer / touch target. Smaller affordances (e.g. row chevrons) compensate by enlarging the *click region* via padding, even when the visual glyph is small.
- **Hit-area padding** never visually extends beyond the surrounding row — extend the target via transparent padding inside the cell.
- **Hover states** must not depend on hover alone for meaning — hover-only affordances are invisible to touch and keyboard users. Pair every hover state with a focus state.

### 15.5 Reduced motion

Already covered in [§5.2](#52-reduced-motion-implementation-pattern). Restated here for completeness because it's an a11y requirement, not a polish concern: every animation longer than `0.2s` must respect `prefers-reduced-motion: reduce` and degrade to instant *while preserving the end state*.

### 15.6 Forms and inputs

| Pattern | Rule |
|---------|------|
| **Label association** | Every input has a `<label for="...">` (or `aria-label` if visually hidden). Placeholder text is NOT a substitute for a label — placeholder vanishes on focus and is invisible to autofill. |
| **Required fields** | Mark with both visual cue (`*`) and `aria-required="true"`. The `*` alone is invisible to screen readers; the attribute alone is invisible to sighted users. |
| **Validation feedback** | Errors render inline below the field, with `aria-describedby` linking field to error message and `aria-invalid="true"` set. Toast-only validation is inaccessible — sighted users without focus on the toast miss it; screen readers announce only on the next role change. |
| **Error summary** | At the top of a form with multiple errors, render a summary list with anchor links to each erroneous field. Allows keyboard users to jump to fixes without re-tabbing. |

### 15.7 Color independence

Never encode meaning by color alone ([§2.3](#23-data-specific-color-charts-and-gauges) restated):

- **Severity badges** carry both color AND text (*Error* / *Warning* / *Info*). Never just color.
- **Chart segments** carry color AND order AND label in tooltip / legend. Never just color.
- **Win / loss columns** carry color AND glyph (*✓ winner* / *— loser*). Never just color.
- **Status pills** carry color AND tone-appropriate language (*passing* / *failing*). Never just color.

Run every new chart through a grayscale screenshot test ([§19](#19-theme-verification-process)). If the meaning survives in grayscale, you're done; if it collapses, add the missing non-color cue.

---

## 16. Performance budgets

Editor-area dashboards are not "free" rendering surfaces — webview HTML lives in a Chromium process that competes with VS Code's main thread. Pin numeric targets so the surface stays fast as feature scope grows.

### 16.1 Time budgets

| Stage | Target | Hard cap |
|-------|--------|----------|
| **Time to first paint** (panel reveal → first pixel rendered) | ≤ 100 ms | ≤ 300 ms |
| **Time to interactive** (panel reveal → toolbar buttons clickable) | ≤ 300 ms | ≤ 1 s |
| **Filter input → table updated** | ≤ 50 ms (after the [§8.5.1](#851-debounce--throttle-table) debounce settles) | ≤ 200 ms |
| **Sort header click → table reordered** | ≤ 50 ms | ≤ 200 ms |
| **Initial scan kickoff** (CLI / dart process) | Run async via host bridge; show *Run analysis* tier-1 button or in-flight status. Never block panel render on scan completion. |

Target = "expected good case"; hard cap = "investigate as a perf bug".

### 16.2 DOM budget

| Element | Target | Hard cap |
|---------|--------|----------|
| **Total DOM nodes per panel** | ≤ 5,000 | ≤ 20,000 |
| **Table rows in DOM** | ≤ 300 (full render) | ≤ 2,000 (with `content-visibility: auto`); ≥ 2,000 must virtualize ([§7.5](#75-virtualization-and-pagination)) |
| **Inline `<style>` block size** | ≤ 30 KB after gzip | ≤ 100 KB — split into composed stylesheets if exceeded |
| **Inline `<script>` block size** | ≤ 20 KB after gzip | Beyond this, move to a webview asset (`extension.uri`) |

### 16.3 Network and CPU

- **No synchronous fetches.** All network I/O happens on the host side; the webview receives data via `postMessage`. Webviews must never `fetch()` directly except for static assets the host has whitelisted in CSP.
- **Worker offload threshold**: any computation taking ≥ 50ms per call (sort, filter, transform) on a 300-row table moves to a worker. Above that, the main thread visibly stutters.
- **Animation budget**: ≤ 60 FPS for sustained motion. Use `transform` / `opacity` properties (compositor-only); avoid animating `width` / `height` / `top` / `left` (force layout).
- **Lazy-load images and SVGs**: any image > 10 KB uses `loading="lazy"`. Network graphs, README image galleries, and package logos all qualify.

### 16.4 Webview lifecycle

| Setting | Default | When to override |
|---------|---------|------------------|
| `retainContextWhenHidden` | `false` (default) | Set `true` only when reconstruction cost exceeds memory cost — large analytical dashboards with expensive client state. The panel keeps DOM + script alive across hide/show. |
| `enableScripts` | `true` for interactive dashboards | Set `false` for pure read-only panels (About) — eliminates a CSP attack surface. |
| `localResourceRoots` | Restrict to `media/`, `dist/` | Never grant the entire workspace; CSP and resource-roots enforce the boundary. |

Document the choice in the panel constructor with a one-line `// retainContextWhenHidden: true — DOM rebuild costs ~600ms on large projects` so future readers know the tradeoff.

### 16.5 Measurement gate

Every new dashboard surface ships with a one-time measurement against the budget above:

1. Open the panel against a representative project (or a synthetic 5,000-row fixture).
2. Use `performance.mark` / `performance.measure` to capture *time to first paint*, *time to interactive*, *filter latency on a 300-row table*.
3. Record the numbers in the surface's PR description.
4. If any number exceeds the *target*, document why; if it exceeds the *hard cap*, do not merge.

---

## 17. State persistence and session memory

Users move between dashboards constantly. Consistent, predictable state persistence is what makes the surface feel like a tool instead of a series of one-shot views.

### 17.1 Persistence policy table

| State | Survives | Where it lives |
|-------|----------|----------------|
| **Filter state** (severity, impact, search query) | Across panel close → reopen within session | `vscode.setState()` (ephemeral webview state) |
| **Sort column / direction** | Across panel close → reopen within session | `vscode.setState()` |
| **Expanded rows** | Across panel hide → show; reset on panel close | In-memory only (set on `<tr>` data attribute) |
| **Full-width toggle** | Across panel close → reopen, per-panel | `vscode.setState()` keyed by panel type |
| **Search query** | Within session only — clears on panel close | `vscode.setState()` (intentionally not persisted across reload) |
| **Column resize / reorder** | Across sessions, per-workspace | `workspaceState` keyed by `<panelType>.columns` |
| **Saved view / preset** | Across sessions, per-workspace | `workspaceState` keyed by `<panelType>.views` |
| **Recent searches** | Across sessions, per-workspace | `workspaceState` ([§8.5.2](#852-search-behavior)) |
| **Theme override / density preference** | Across sessions, per-machine | `globalState` |
| **Telemetry opt-in** | Across sessions, per-machine | `globalState` |
| **Selection (multi-select)** | Within session, clears on filter change ([§7.3](#73-multi-select-and-bulk-actions)) | In-memory only |
| **Scroll position** | Across panel hide → show only with `retainContextWhenHidden: true`; else resets | Browser state |

### 17.2 Reset semantics

A *Reset view* control exists in every dashboard's More menu and clears:

- Filter state, sort, search query, expanded rows.
- Does NOT clear: column widths, saved presets, telemetry settings, theme overrides.

The user expects *Reset view* to give them the panel-as-shipped (default filters, sort, layout). It must not nuke their saved presets or column widths — those are deliberate customizations.

### 17.3 Session memory rules

- **Never persist sensitive data** to `globalState` / `workspaceState`. PII, credentials, project file paths that include user names — none of this belongs in persisted state. The webview can hold them in-memory but must not write them to disk via the persistence APIs.
- **Schema versioning**: every persisted state object carries a `version` field. On read, if the version is older than expected, migrate or discard — never attempt to merge mismatched schemas blindly.
- **Quota awareness**: `workspaceState` and `globalState` are not infinite. Cap recent-search histories at 25, saved presets at 50, etc. Document the cap inline.

---

## 18. Internationalization, pluralization, and formatting

Even though Saropa Lints is English-first, strings, numbers, and dates need consistent treatment so a future i18n pass — or even just a copy edit — doesn't have to refactor 14 surfaces.

### 18.1 String externalization

Every user-facing string in the webview HTML / CSS / script gets routed through a single localization helper rather than inlined. Centralize the helper now even if every key currently maps to English; the externalization point is what makes a future translation tractable.

```ts
// webview-l10n.ts (host side, embedded into the webview as a JSON blob via postMessage)
export const STRINGS = {
  toolbar: {
    runAnalysis: 'Run analysis',
    refresh: 'Refresh',
  },
  empty: {
    noFindings: 'No findings.',
    resetFilters: 'Reset filters',
  },
  // …
} as const;
```

Banned: `${count} finding${count === 1 ? '' : 's'}` inline. Use a plural-aware helper ([§18.2](#182-pluralization-rules)).

### 18.2 Pluralization rules

JavaScript's `Intl.PluralRules` handles plural forms across languages including those with more than two forms (Arabic, Russian, Polish):

```ts
const pr = new Intl.PluralRules('en-US');
function pluralize(count: number, forms: { one: string; other: string }): string {
  return forms[pr.select(count)] ?? forms.other;
}
// Usage:
pluralize(count, { one: '{count} finding', other: '{count} findings' })
  .replace('{count}', count.toLocaleString());
```

Even for English, route every count through this helper so future locale support is one PR away. Inline ternaries (`count === 1 ? '' : 's'`) are banned because they force a refactor when the helper arrives.

### 18.3 Number formatting

| Pattern | Rule |
|---------|------|
| **Integers in tables** | `value.toLocaleString()` — adds locale-correct thousands separators (`1,234,567` in en-US, `1.234.567` in de-DE). |
| **Compact display** | `Intl.NumberFormat(locale, { notation: 'compact' }).format(n)` for cells where space is tight (download counts, stars). Render the full value in `title`. |
| **Percentages** | `Intl.NumberFormat(locale, { style: 'percent', maximumFractionDigits: 1 }).format(0.123)` → `12.3%`. Never `${n * 100}%` — locale gets the decimal separator wrong. |
| **File sizes** | Use IEC units (KiB / MiB / GiB) for technical contexts (archive sizes, bundle sizes); SI units (KB / MB / GB) for download speeds. Be consistent within a column. |
| **Decimals** | Pin a max-fraction-digits per column (e.g. score = 1, percentage = 1, money = 2). Drift causes columns to misalign. |

### 18.4 Date and time formatting

| Pattern | Rule |
|---------|------|
| **Relative time** | *2m ago*, *3h ago*, *4d ago*, *2w ago*. Use a single helper (`formatRelativeTimestamp`) so the breakpoints are consistent. |
| **Absolute time** | ISO 8601 (`2026-04-12T14:23:00Z`) in tooltips and exports. `Intl.DateTimeFormat` for display: `2026-04-12 14:23` in tables. |
| **Pair them** | Visible cell shows relative ("2m ago"); `title` tooltip shows absolute ("2026-04-12 14:23 UTC"). The user gets quick context plus precision on hover. |
| **Time zones** | Store and transmit UTC. Display in the user's local zone (per `Intl.DateTimeFormat`'s default behavior). Never display server-time without a TZ suffix. |
| **"Just now"** | < 45 seconds. Above that, switch to *Ns ago* / *Nm ago*. Below that, "just now" reads as fresh. |

---

## 19. Theme verification process

VS Code ships four default themes; the host supports thousands more from the marketplace. Every new dashboard must verify against the four defaults at minimum.

### 19.1 The four required themes

| Theme | Background tone | Notable token differences |
|-------|----------------|---------------------------|
| **Dark+ (default dark)** | Near-black | The dev's likely default — if the surface only works here, it ships broken. |
| **Light+ (default light)** | Near-white | Catches `color: #fff` errors and dark-only hex fallbacks ([§14.16](#1416-hex-fallbacks-in-var--vscode---hex-mask-theme-token-gaps)). |
| **High Contrast Dark** | Pure black | Catches missing focus rings, insufficient contrast on accent colors, transparent borders. |
| **High Contrast Light** | Pure white | Catches the same as HC Dark, in the opposite direction. |

Verify in this order: Dark+ → Light+ → HC Dark → HC Light. If a surface breaks in HC, it almost certainly has at least one un-tokenized color, and fixing HC fixes the other three.

### 19.2 Verification checklist

For every new dashboard, run through this list once before merge and on every PR that touches CSS:

- [ ] Hero title legible (contrast ≥ 4.5:1)
- [ ] Status line pills legible at all four tones (good / warn / bad / neutral)
- [ ] KPI card numbers legible
- [ ] KPI card *active* state visibly distinct from default
- [ ] Toolbar tier-1 button distinguishable from tier-2
- [ ] Search input border visible on focus
- [ ] Sortable header hover background visible
- [ ] Sortable header *active sort* arrow visible
- [ ] Table row hover background visible
- [ ] Table row focus outline visible
- [ ] Expander chevron visible in collapsed AND expanded states
- [ ] Empty-state banner border + button distinguishable
- [ ] Error banner left-border accent visible
- [ ] Chart segments distinguishable in grayscale (color-independence per [§15.7](#157-color-independence))
- [ ] Disabled buttons readable but clearly distinct from enabled
- [ ] Links visible, underline visible on hover
- [ ] Focus ring visible on all interactive elements

### 19.3 Visual snapshot tests

For each surface, capture one representative screenshot per theme (4 screenshots) and commit them under `extension/test/visual-snapshots/<surface>-<theme>.png`. CI compares snapshots against the stored baseline; a diff > 1% fails the build. Update baselines deliberately when an intentional visual change ships.

The screenshots themselves are reference artifacts — do not pixel-perfect them, do not gate on tiny anti-aliasing differences. The 1% threshold catches structural regressions (a missing border, a swapped color) without false-positiving on font-rendering noise.

### 19.4 Token coverage matrix

Maintain a per-surface matrix tracking which `--vscode-*` tokens the surface uses. When a surface adds a new token, add a row. When VS Code deprecates a token, the matrix tells you which surfaces need migration:

| Token | Findings | Code Health | Rule Explain | … |
|-------|----------|-------------|--------------|---|
| `--vscode-button-background` | ✓ | ✓ | ✓ | |
| `--vscode-list-activeSelectionBackground` | ✓ | ✓ | — | |
| `--vscode-editorWidget-background` | — | ✓ | ✓ | |

Generated from a static-analysis pass over the styles files — keep automated rather than hand-maintained.

---

## 20. CSS architecture conventions

Every dashboard imports the shared chrome (`getDashboardChromeStyles()`) and adds surface-specific rules on top. The chrome owns visual primitives shared across surfaces; per-surface stylesheets own surface-specific layout. Drift between the two is the most common source of "the new dashboard doesn't quite look like the old ones".

### 20.1 What lives in the chrome

| Pattern | In chrome? |
|---------|------------|
| Body padding, max-width, full-width override | Yes |
| Hero band visual (title size, status-line styling, gauge layout) | Yes |
| KPI card primitives (`.kpi-row`, `.kpi-card`, `.kpi-k`, `.kpi-v`) | Yes |
| Toolbar band, segmented control track | Yes |
| `.btn` / `.btn.tier-1` / `.btn.tier-3` / `.btn.danger` | Yes |
| Chip strip (`.chip-strip`, `.chip`) | Yes |
| Sortable table base (`.dash-table`, `.sortable`, sticky headers) | Yes |
| Surface-specific column widths and row layout | No — per-surface |
| Surface-specific badge colors (e.g. severity pills) | No — per-surface |
| Empty-state CTA card (`.empty-cta`) | **Should be** chrome — currently duplicated across 3+ surfaces; lift on next refactor |

### 20.2 Naming conventions

- **Class prefix `.dash-*`** for chrome-owned regions (`.dash-hero`, `.dash-table`). Signals "this lives in chrome; do not redefine locally."
- **No prefix** for primitive utilities (`.btn`, `.seg`, `.chip`, `.muted`, `.sr-only`). These are short by design.
- **Surface-specific classes** use a surface-specific prefix when there's any naming-collision risk: `.ki-chip-strip` (Known Issues), `.pv-empty` (Project Vibrancy). Avoids stomping the chrome's generic class.
- **IDs are unique per panel**. Within a single webview, an `id` is a hard handle — never reuse. Across panels, IDs may repeat (different webviews are isolated).

### 20.3 Specificity discipline

- **Never use `!important`** in production CSS. If a rule needs to override the chrome, increase specificity by qualifying the selector (e.g. `.findings-dash .btn` instead of `.btn !important`). `!important` masks the cascade and turns future tweaks into a war.
- **Single-class selectors preferred** over deeply nested chains. Three classes is the practical ceiling — beyond that, refactor the markup.
- **Avoid element-tag selectors** for components (`.kpi-card` not `button.kpi-card`). The component should work whether rendered as `<button>` or `<div>`; locking it to a tag forces refactoring when semantics change.

### 20.4 CSS variable conventions

- **Chrome defines tokens once** in `:root` (`--surface-1`, `--accent-error`, etc.). Per-surface stylesheets consume them; per-surface stylesheets do NOT redefine them.
- **Component-scoped variables** for runtime values: `style="--gauge-target: 75"` on the SVG, then `stroke-dasharray: var(--gauge-target) 100` in the rule. Drives animation from CSS variables instead of inline `style` attributes whenever possible.
- **Inline `style="color: …"` is banned** for theme-bound color. The cascade can't reach inline styles, so a theme switch leaves the inline color stale. Use a class + token instead.

### 20.5 File structure

The Package Dashboard's split-file pattern is the contract for new surfaces:

```
extension/src/views/<surface>/
  <surface>-html.ts       — HTML builder (markup)
  <surface>-styles.ts     — CSS (returns a string)
  <surface>-script.ts     — Webview script (postMessage bridge)
  <surface>-panel.ts      — VS Code WebviewPanel wrapper, message routing
```

Avoid monolithic `buildHtml.ts` files that intermix HTML, CSS, and script. The split is what makes per-section review (and per-section testing) tractable.

---

## 21. Webview ↔ host messaging contract

Every interactive dashboard sends messages from the webview to the host (and sometimes back). Drift in message-shape conventions across surfaces is the most common cause of "I added a button and it dispatched the wrong handler."

### 21.1 Message-type naming

- **camelCase verbs** for action types: `runAnalysis`, `copyFilteredJson`, `openFile`, `openUrl`, `resetFilters`, `paletteCommand`.
- **Domain prefixes** when a surface has many distinct messages: `kpi.click`, `kpi.reset`, `findings.suppress`. Use only if the un-prefixed type would collide.
- **No verbs as nouns**: `runAnalysis` (verb) not `analysisRun` (gerund). The type names what the user wants to happen.

### 21.2 Dispatch patterns

| Pattern | When to use |
|---------|-------------|
| **Per-button `id` + `bindClick`** | Single, unique action that takes no parameters. Three of these in a script is fine; ten is a smell. |
| **`data-cmd="<commandId>"` on the element + delegated listener** | Generic palette command dispatch. The host registered the command; the webview just names it. Reusable across any button. |
| **`data-action="<verb>" data-<key>="<value>"`** | Action that takes parameters from the row (file, line, package name). The handler reads the dataset and posts a message. |
| **`message.type` switch in host** | Explicit typed handlers in the panel's `onDidReceiveMessage`. Prefer over a generic dispatcher when the verbs are few and stable. |

Prefer `data-cmd` and `data-action` over per-button `id` for new surfaces — they scale to N buttons without proportional script growth.

### 21.3 Schema versioning

- **Every message carries an implicit schema version** through its `type` string. To evolve a message shape, ship a new type (`copyFilteredJson` → `copyFilteredJsonV2`); never silently change the payload of an existing type.
- **The host treats unknown message types as warnings**, not errors. A webview from a previous extension version may still be running in a hidden panel; killing the host on unknown types breaks reload.
- **Backward compatibility window**: keep the old type handler for one full release cycle after introducing a replacement. Document the deprecation in the panel's source comments.

### 21.4 Payload conventions

- **Strings are escaped at the host boundary**, not the webview. The webview sends raw values; the host's `escapeHtml` / `JSON.stringify` is the trust boundary. Reverse direction: the webview never trusts host-supplied HTML — always escape via `html-utils.ts` before injecting.
- **Prefer flat payloads** over deep objects. `{ type: 'openFile', path: 'lib/foo.dart', line: 42 }` is easier to debug than `{ type: 'fileNav', target: { uri: { fsPath: …, line: … } } }`.
- **Validate at the host**. Every `onDidReceiveMessage` handler validates `message.type` and `message.<field>` shape before acting. Untrusted webviews (theoretically) could send malformed messages; the host shouldn't crash on them.

---

## 22. Print, export, and onboarding

### 22.1 Print and PDF export

Editor-area dashboards are occasionally printed or exported as PDF for share-out. A surface need not be print-perfect, but it should not actively break:

- **Print stylesheet** (`@media print`) hides the toolbar, full-width toggle, hover affordances, and any sticky headers (sticky printing leaves a duplicate band on each page). Renders the table with `border-collapse: collapse` and a `1px solid` border so cells are visible on plain paper.
- **Page break hints**: `tr { break-inside: avoid; }` so a single row doesn't split across pages.
- **Background colors**: respect `print-color-adjust: exact` on KPI cards and severity pills so the user's intent (a colored severity badge) survives the print engine's default of stripping background colors.
- **Long text**: rely on `word-wrap: break-word` for file paths and rule names. Print handles overflow poorly.

### 22.2 CSV / JSON export

Every dashboard's *Save report* action exports the underlying dataset, not the rendered HTML.

| Pattern | Rule |
|---------|------|
| **CSV header row** | One row, column names match the visible table headers exactly. |
| **CSV escaping** | Quote any value containing `,`, `"`, newline. Escape embedded `"` as `""`. Use `\r\n` line endings for Windows compatibility. |
| **JSON shape** | One object per row keyed by column name; preserve null vs empty-string distinction; numbers stay numbers (don't stringify). |
| **Filename convention** | `<surface>-<YYYYMMDD>-<HHMM>.csv` saved to `<workspace>/reports/.saropa_lints/`. Date-stamped so consecutive exports don't overwrite each other. |
| **Encoding** | UTF-8 with no BOM for JSON; UTF-8 with BOM for CSV (Excel needs the BOM to detect UTF-8 correctly). |

### 22.3 First-run / onboarding

- **No-project state**: when the user opens a dashboard with no Dart workspace open, render a dedicated empty state (different from "no findings"). Message: *"Open a Flutter or Dart project to see findings."* + tier-1 *Open folder* button that triggers `vscode.openFolder`. Never render a blank table on no-project.
- **No-data state** (project open, scan never run): tier-1 *Run analysis* button and a one-line muted explainer.
- **What-is-this disclosure**: a small `?` icon in the hero (next to the version stamp) toggles a short popover describing the surface's purpose. Helpful for first-timers, invisible to everyone else. Use sparingly — most dashboards earn discoverability through their content, not through tour overlays.

---

## 23. Right-to-left (RTL) support

Even though the source language is English, write CSS so an RTL-locale flip works without reflow surgery. The ROI is high (one-time discipline) and the cost of retrofitting later is high (every flex direction, every margin, every chevron).

### 23.1 Logical properties over physical

| Use | Don't use |
|-----|-----------|
| `margin-inline-start` | `margin-left` |
| `margin-inline-end` | `margin-right` |
| `padding-inline` | `padding-left` / `padding-right` |
| `border-inline-start` | `border-left` |
| `inset-inline-start` | `left` |
| `text-align: start` | `text-align: left` |

Logical properties auto-flip in `dir="rtl"` containers. Physical properties don't.

### 23.2 Direction-aware glyphs

- **Chevrons**: row expanders use a triangle (`▸` / `▾`) that's already directionally neutral on the vertical axis. Horizontal chevrons (back arrow `‹`, forward `›`) flip with `transform: scaleX(-1)` inside RTL containers — never hard-code `‹` for "back".
- **Sort arrows**: `▲` / `▼` (vertical) stay the same in RTL. Avoid `→` / `←`.

### 23.3 Charts

- **Horizontal bar charts** flip in RTL: bars grow from right to left, labels right-align. Use `direction: rtl` on the chart container and let the flex direction handle it.
- **Donut charts** rotate counterclockwise in RTL; this is usually fine because order doesn't carry meaning, but verify that legend matching still reads correctly.

### 23.4 Numbers in RTL

Numbers themselves stay LTR even in RTL contexts. Use `<bdo dir="ltr">1,234</bdo>` for any number that might display next to RTL text and risk reordering.

Don't ship full RTL support yet — but write CSS as if you are, so the eventual locale switch is a config change and not a refactor.

---

## 24. Document governance

A guidelines document that nobody owns becomes a museum. Keep this one alive.

### 24.1 Header metadata

The top of this document carries:

- **Last reviewed**: YYYY-MM-DD — when a maintainer last walked the doc end-to-end.
- **Owner**: handle of the person responsible for keeping it current. Default to the most recent contributor to the gold-standard surface (Package Dashboard).
- **Open issues**: link to a tracking ticket where guideline-evolution discussions live.

Update *Last reviewed* every time you read the doc cover-to-cover and find nothing to fix; that itself is a signal.

### 24.2 Changelog

Add a brief changelog at the top of the doc:

```markdown
## Changelog

- **2026-05-02** — §0 Vocabulary, §15 Accessibility, §16 Performance budgets,
  §17 State persistence, §18 i18n, §19 Theme verification, §20 CSS architecture,
  §21 Webview messaging, §22 Print/export/onboarding, §23 RTL, §24 Governance.
  §5 motion enriched with easing curves; §7 with multi-select / multi-column sort
  / virtualization; §8.5 with debounce numbers; §8.16 split into 8 sub-states.
  §14 anti-pattern catalog grew with hex-fallback / doubled-freshness / action-tint
  entries.
- **2026-04-XX** — Initial publication of §1–§14.
```

Never silently rewrite history. If a guideline reverses, add an entry explaining why; do not edit the original section to read as if it always said the new thing.

### 24.3 Review cadence

- **Quarterly**: walk the full doc, update *Last reviewed*, prune anti-patterns the codebase no longer commits.
- **On every audit**: surface findings into §14's anti-pattern catalog so the lesson outlives the dashboard that prompted it.
- **On every chrome change**: update §13 (implementation map) and §20 (CSS architecture) so the codebase and the doc don't drift.

### 24.4 Contributing

A new contributor adding a guideline:

1. Picks the lowest-numbered section that already covers the topic; appends a new sub-section (`§N.M`) rather than creating a top-level entry.
2. New top-level entries are reserved for genuinely new categories (a new device class, a new accessibility regulation, a new chrome capability).
3. Every new guideline carries: the **rule**, a one-line **why** (the failure mode it prevents), a one-line **how to apply** (when the rule kicks in). Anti-pattern entries additionally carry the **fix**.
4. Cross-link with `§N.M` references — the doc's value compounds when sections reach back and forth.
