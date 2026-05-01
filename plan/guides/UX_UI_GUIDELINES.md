# UX / UI guidelines — editor-area data dashboards

This document describes the **gold-standard** interaction and visual language used by the full-width **package dependency dashboard** webview (editor tab): rich tables, summary metrics, charts, and deep drill-down. Wording is **generic** so the same patterns can be reused for other dashboards, reports, and embedded HTML surfaces inside a desktop IDE or similar host.

**Code map:** [Section 13](#13-implementation-map-package-dashboard) lists the Saropa extension files that implement this dashboard so maintainers can jump from guideline to implementation.

**UI catalog:** [Section 8](#8-affordance-catalog) spells out titles, links, counts, sorting, filtering, tooltips, icons, expanders, sections, buttons, and related patterns in one place.

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

- **Empty chart**: Omit the section entirely if there is no size data—do not show a broken chart frame. *"No findings."* in a card frame is worse than no card at all: it advertises the absence of data instead of using the space for something useful.
- **Empty optional sections**: Sections that have no data **and** carry no current configuration (e.g. *"Issues view hides — none"*, *"Drift Advisor — integration off"*) collapse to a single muted footer line at most, or are omitted entirely. Never render full-height bordered bands whose only content is "nothing is happening here". Render them at full size only when they have data the user can act on.
- **Skeleton vs omit**: For chart axes that need to keep their slots even at zero (e.g. all severity buckets so the user sees the categories that exist), render zero-width bars rather than omit individual rows. The rule is: **omit the whole card when no data exists; keep the skeleton when partial data exists.**
- **One empty state per emptiness**: Do not render a top-level *"No violations"* banner *and* a child *"No violations match the current filters"* banner for the same condition. Pick one location — the highest one in the hierarchy where the message still has all the context it needs — and suppress the duplicates.
- **Empty-state CTA**: Every empty state names the next action (*Run analysis*, *Reset filters*, *Enable integration*) and renders it as a tier-1 button. Empty banners with no CTA are dead UI.
- **Loading**: Prefer host progress (notification / status bar) while generating HTML; webview can show a static “Run scan first” if opened with no data.
- **Errors**: Banner using input-validation error tokens (border-left accent, background, foreground); actionable next step (open settings, rescan).

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
