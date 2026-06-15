# Saropa Dashboard & Webview Style Guide

**Status:** Canonical. This is the single source of truth for the visual language of every
Saropa dashboard, webview, report panel, and HTML export across all projects (saropa_lints
extension, Saropa Contacts in-app dashboards, Saropa Log Capture reports, drift advisor /
viewer panels, and any future surface).

**Scope:** Every pixel a user sees in a dashboard-class surface — banners, cards, tables,
charts, toolbars, pills, gauges, empty/loading/error states. It does **not** cover product
marketing pages or the host application chrome that the OS/IDE owns.

**Explicitly exempt: high-density data consoles.** A virtualized log/terminal/stream view (the
Saropa Log Capture viewer, a raw output console, a hex/diff pane) is **not** a dashboard and is
held to a different contract. These surfaces keep their monospace font and host-driven font size
(`--vscode-editor-font-family` / a `--log-font-size`), pack rows far tighter than the §4 density,
and must **not** consume the §3.10 sans type scale. What they **do** share with dashboards: the
token layer for color/border (§3.1–3.4), the semantic status colors (§3.5), the accessibility
gate (§7), and the i18n/copy rules (§8). When a console embeds a dashboard-class panel (a stats
summary, a findings table), that embedded panel follows the full guide; the surrounding stream
does not. If you are about to apply the type scale or row density to a console and it looks
wrong, that is the guide telling you the surface is exempt — not a defect to force.

**Why this exists:** Saropa shipped two dashboards built on two unrelated render stacks with
two independent stylesheets (a Dart-generated HTML report with a fixed brand palette, and a
TypeScript webview bound to host-theme tokens), plus a third orphan stylesheet for a
scanning-progress panel. The result: surfaces that should read as one product look like three.
This guide defines one token system and one component contract so every surface is consistent,
theme-aware, accessible, and on-brand — and so a new surface is assembled from named parts
instead of hand-painted.

---

## 0. The one rule that governs all others

**A dashboard is the host theme wearing a Saropa brand accent — never a fixed skin, never a
raw host surface.**

Two failure modes this rejects:

1. **Fixed skin** (the old Project Map): beautiful hardcoded `#0a0f1c`/`#f97316` palette that
   ignores the user's chosen light/dark/high-contrast theme. Looks great in one theme, fights
   the user in every other, and fails high-contrast accessibility modes outright.
2. **Raw host surface** (the old scan-progress panel): bound to host tokens but with no brand
   layer, no curated spacing, no elevation — technically themed, visually anonymous and cheap.

The unified system is **both**: a theme-aware foundation (surfaces, text, borders, semantic
colors inherit from the host) **plus** a thin Saropa brand overlay (the orange brand accent,
the radius, the elevation, the eyebrow/banner treatment, the type scale). The foundation makes
it correct in every theme; the overlay makes it unmistakably Saropa.

---

## 1. Core principles

1. **Target 10/10, judged holistically.** A surface is done when hierarchy, rhythm, alignment,
   motion, and every state (empty, loading, scanning, error, offline, stale) are right — not
   when the happy-path desktop render works. Beautiful is a requirement, not a bonus.
2. **Tokens, never literals.** Pull color, spacing, radius, elevation, and type from the token
   set below. A raw hex, a magic pixel, or an inline font size at a call site where a token
   exists is a defect. If no token fits, that is a token-set gap to raise — not a license to
   inline a literal.
3. **Theme-aware by default.** Bind to host-theme tokens (`--vscode-*` in VS Code, the app
   `ThemeCommon*` in Flutter). The brand accent layer is the only fixed color, and even it is
   blended toward the host foreground for text legibility.
4. **Consistency beats novelty.** A new element matches the established spacing density, corner
   treatment, motion timing, and iconography of the surrounding surfaces. An element that
   ignores the system reads as broken even when technically correct.
5. **One render path per platform.** Within a project, all dashboard surfaces share one
   stylesheet/token module and one component library. Do not fork a second stylesheet for a
   single panel — extend the shared one.
6. **Accessible is non-negotiable.** WCAG AA contrast minimum, visible focus, full keyboard
   operability, `prefers-reduced-motion` respected, RTL-clean, dyslexia-mode safe.

---

## 2. Architecture: how a surface is built

Every dashboard surface, regardless of platform, is layered the same way:

```
┌─────────────────────────────────────────────┐
│  Brand overlay   (eyebrow, top strip, ring,   │  ← fixed Saropa tokens
│                   primary-action accent)      │
├─────────────────────────────────────────────┤
│  Component layer (cards, tables, chips, …)    │  ← shared component contracts
├─────────────────────────────────────────────┤
│  Token layer     (surfaces, text, borders,    │  ← theme-bound tokens
│                   spacing, radius, type)      │
├─────────────────────────────────────────────┤
│  Host theme      (VS Code / Flutter / OS)     │  ← inherited, never overridden
└─────────────────────────────────────────────┘
```

**Token-binding modes.** The same token names resolve differently per host:

| Host | Surfaces/text/border bind to | Brand accent |
|------|------------------------------|--------------|
| VS Code webview | `var(--vscode-*)` editor tokens | fixed Saropa orange |
| Standalone HTML export (no host theme) | the **fallback palette** (§3.6) | fixed Saropa orange |
| Flutter app | `ThemeCommon*` / `Theme.of(context)` | brand color from the app theme |

A standalone HTML report (emailed, opened in a browser, attached to a CI artifact) has no host
theme to inherit, so it ships the fallback palette baked in. A webview inherits the IDE theme.
**Same token names, same components, two resolution tables** — this is what lets one component
library serve both.

---

## 3. Design tokens

These are the canonical token names. Use these names everywhere; only the *resolution* changes
per host. Values shown are the standalone-fallback resolutions (the brand palette); the
VS Code binding column shows the host token each maps to.

> **Reference implementation (VS Code):** `extension/src/views/dashboardChromeStyles.ts`
> (`chromeTokens()`) is the live `:root` for every webview. It is the source of truth for these
> tokens in VS Code; this section is the spec it implements. A few host-specific reconciliations
> hold there and any adopter must follow them:
> - **Primary text** is `var(--vscode-foreground)` directly. `--text` is the standalone-export
>   alias for the same role; in a webview, use `var(--vscode-foreground)`.
> - **`--surface-0`** is standalone-only (a subtle page tint distinct from cards). In VS Code the
>   page background is `--surface-1` (`--vscode-editor-background`); cards are `--surface-1` plus a
>   `--border`. Do not reference `--surface-0` in a webview.
> - **Type base is 13px** in VS Code (host density), not the 14px standalone base — the
>   `--text-*` tokens in the chrome carry the 13px-anchored values; the ratio (~1.2) is identical.

### 3.1 Surfaces (elevation by depth, not by shadow alone)

| Token | Role | Fallback (light) | Fallback (dark) | VS Code binding |
|-------|------|------------------|-----------------|-----------------|
| `--surface-0` | Page background (standalone-only — see note) | `#fafaf9` | `#0a0f1c` | _(use `--surface-1`)_ |
| `--surface-1` | Card / panel | `#ffffff` | `#0f172a` | `--vscode-editor-background` |
| `--surface-2` | Raised / banner / header | `#f5f5f4` | `#1e293b` | `--vscode-editorWidget-background` |
| `--surface-3` | Inset chips / toolbar band | `#eeeeec` | `#243044` | `--vscode-editor-inactiveSelectionBackground` |
| `--inset` | Input / field interior | `#ffffff` | `#0b1220` | `--vscode-input-background` |

Rule: surfaces step **lighter in dark mode and darker in light mode** as they rise. Never use a
drop shadow as the *only* signal of elevation — pair surface step + shadow.

**Host caveat — VS Code collapses the bottom of the ramp.** The editor exposes no four-level
surface ramp, so `--surface-0` does not exist in a webview (it is standalone-only per the
reference note above): the page background **and** cards are both `--surface-1`
(`--vscode-editor-background`), separated by a `--border`, not by a tone change. The raised steps
map to `--vscode-editorWidget-background` / `--vscode-editor-inactiveSelectionBackground`, which
in some themes render close to the editor background. In webviews, lean on the **widget border**
(`--border`) plus the available step to separate stacked surfaces; do not assume the surface
token alone produces a visible elevation change. The full four-step ramp only materializes in the
standalone fallback palette (§3.6) and in Flutter, where the app theme defines distinct container
tones.

### 3.2 Text

| Token | Role | Fallback (light) | Fallback (dark) | VS Code binding |
|-------|------|------------------|-----------------|-----------------|
| `--text` | Primary body / headings | `#0f172a` | `#f1f5f9` | `--vscode-foreground` |
| `--muted` | Secondary / captions / labels | `#64748b` | `#94a3b8` | `--vscode-descriptionForeground` |
| `--link` | Hyperlinks | `#ea580c` | `#fb923c` | `--vscode-textLink-foreground` |

`--muted` must still clear **AA (4.5:1)** against the surface it sits on. On busy tinted bands
(segmented controls, status pills) lift muted toward foreground:
`color-mix(in srgb, var(--text) 72%, var(--muted))`.

### 3.3 Borders

| Token | Role | Fallback | VS Code binding |
|-------|------|----------|-----------------|
| `--border` | Default hairline | `#e5e7eb` (light) / `rgba(148,163,184,.18)` (dark) | `--vscode-widget-border` |
| `--border-strong` | Focus-adjacent / hover edge | `color-mix(in srgb, var(--brand) 35%, var(--border))` | `color-mix(in srgb, var(--vscode-focusBorder) 35%, var(--vscode-widget-border))` |

### 3.4 Brand (the only fixed colors)

| Token | Value | Use |
|-------|-------|-----|
| `--brand` | `#f97316` | Eyebrow text, top strip start, primary-action fill, focus ring, active accent |
| `--brand-2` | `#ea580c` | Top strip mid, gradient partner, link in fallback |
| `--brand-glow` | `rgba(249,115,22,.20)` (`.28` in standalone dark) | Soft tint behind brand chips/badges |
| `--ring` | `0 0 0 3px rgba(249,115,22,.32)` | Focus ring (decorative; pair with a real outline for AA) |

Brand orange is **accent only** — never a large fill behind body text (it cannot hold AA for
small text). Use it for the 3px banner strip, eyebrow label, the single primary action, the
focus ring, and active-state edges. Everything else is theme-bound.

### 3.5 Semantic / status (severity, health, pass/fail)

Bind to the host's diagnostic colors so severity reads identically to the editor's own
squiggles. Never invent a green/red.

| Token | Role | Fallback | VS Code binding |
|-------|------|----------|-----------------|
| `--status-good` | Pass / healthy | `#16a34a` | `--vscode-testing-iconPassed, --vscode-editorInfo-foreground` |
| `--status-bad` | Fail / critical | `#dc2626` | `--vscode-editorError-foreground` |
| `--accent-critical` | Severity: critical | `#dc2626` | `--vscode-editorError-foreground` |
| `--accent-high` | Severity: high | `#ea580c` | `color-mix(error 60%, warning)` |
| `--accent-medium` / `--accent-warning` | Severity: medium | `#d97706` | `--vscode-editorWarning-foreground` |
| `--accent-low` / `--accent-info` | Severity: low / info | `#2563eb` | `--vscode-editorInfo-foreground` |
| `--accent-opinionated` | Stylistic / opt-in | `#64748b` | `--vscode-descriptionForeground` |

When a status color carries **text** (a pill label), blend it toward foreground so it stays
legible on its own tinted background:
`color-mix(in srgb, var(--status-bad) 44%, var(--text))`.

### 3.6 Standalone fallback palette (copy-paste)

For HTML exports with no host theme. This IS the curated brand palette; ship it in the report's
`<style>` and override only surfaces/text in the dark media query.

```css
:root {
  color-scheme: light dark;
  --brand: #f97316;  --brand-2: #ea580c;  --brand-glow: rgba(249,115,22,.20);
  --surface-0: #fafaf9;  --surface-1: #ffffff;  --surface-2: #f5f5f4;  --surface-3: #eeeeec;
  --inset: #ffffff;
  --text: #0f172a;  --muted: #64748b;  --link: #ea580c;
  --border: #e5e7eb;  --border-strong: color-mix(in srgb, var(--brand) 35%, var(--border));
  --status-good: #16a34a;  --status-bad: #dc2626;
  --accent-critical: #dc2626;  --accent-high: #ea580c;  --accent-medium: #d97706;
  --accent-low: #2563eb;  --accent-opinionated: #64748b;
}
@media (prefers-color-scheme: dark) {
  :root {
    --surface-0: #0a0f1c;  --surface-1: #0f172a;  --surface-2: #1e293b;  --surface-3: #243044;
    --inset: #0b1220;
    --text: #f1f5f9;  --muted: #94a3b8;  --link: #fb923c;
    --border: rgba(148,163,184,.18);  --brand-glow: rgba(249,115,22,.28);
  }
}
```

### 3.7 Spacing scale (4px base)

All margins, padding, and gaps land on this scale. No arbitrary pixel values.

| Token | px | Typical use |
|-------|----|-------------|
| `--space-1` | 4 | Icon-to-label gap, pill padding-y |
| `--space-2` | 8 | Chip padding, tight stacks |
| `--space-3` | 12 | Card inner padding-y, control gap |
| `--space-4` | 16 | Card inner padding, default block gap |
| `--space-5` | 24 | Page horizontal padding, section gap |
| `--space-6` | 32 | Major section separation, page bottom |
| `--space-8` | 48 | Hero / empty-state vertical breathing |

### 3.8 Radius

| Token | px | Use |
|-------|----|-----|
| `--radius-sm` | 3 | Pills, focus outlines, tiny affordances |
| `--radius` | 8 | Buttons, chips, inputs |
| `--radius-lg` | 12 | Cards, panels, banners |
| `--radius-pill` | 999 | Status pills, filter chips |

### 3.9 Elevation (surface step + shadow, paired)

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `--shadow` | `0 1px 2px rgba(15,23,42,.04), 0 1px 3px rgba(15,23,42,.06)` | `0 1px 3px rgba(0,0,0,.4)` | Cards, sticky banner |
| `--shadow-lg` | `0 4px 12px rgba(15,23,42,.08), 0 10px 30px -8px rgba(15,23,42,.16)` | `0 8px 24px rgba(0,0,0,.45), 0 20px 50px -12px rgba(0,0,0,.6)` | Popovers, modals, drill-down |

In VS Code webviews, prefer the host's own widget border + `--surface` step over heavy shadows
(VS Code's flat language); reserve `--shadow-lg` for true overlays.

### 3.10 Type scale (modular, ratio ~1.2)

Sizes follow a 1.2 minor-third step. The table below is the **14px standalone base** (HTML
exports). **VS Code anchors at 13px** for host density (see the reference note in §3): the chrome
carries `--text-eyebrow:11 --text-caption:11 --text-body:13 --text-label:13 --text-h3:15
--text-h2:18 --text-h1:22 --text-kpi:28 --text-kpi-xl:40`, same ratio. Pair every size with a
deliberate line-height. Never eyeball a font size.

| Token | px / line-height | Weight | Role |
|-------|------------------|--------|------|
| `--text-eyebrow` | 11 / 1.2 | 700, `letter-spacing:.14em`, uppercase | Brand eyebrow above title |
| `--text-caption` | 12 / 1.4 | 500 | Captions, table sub-labels, pill text |
| `--text-body` | 14 / 1.45 | 400 | Default body, table cells |
| `--text-label` | 14 / 1.4 | 600 | Field labels, KPI labels |
| `--text-h3` | 17 / 1.35 | 600 | Panel/section heading |
| `--text-h2` | 20 / 1.3 | 600 | Sub-page title |
| `--text-h1` | 28 / 1.2 | 700 | Dashboard title |
| `--text-kpi` | 34 / 1.1 | 700 | Stat-card big number |
| `--text-kpi-xl` | 44 / 1.05 | 700 | Hero metric (single headline number) |

Font family: inherit the host (`var(--vscode-font-family)`; in standalone HTML use the system
stack `-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, "Helvetica Neue", Arial,
sans-serif`). Numeric columns use `font-variant-numeric: tabular-nums` so digits align.

### 3.11 Motion

| Token | Value | Use |
|-------|-------|-----|
| `--ease` | `cubic-bezier(.2,.6,.2,1)` | Default easing |
| `--dur-fast` | 80ms | Hover, chevron rotate, pill toggle |
| `--dur` | 160ms | Card hover lift, panel expand |
| `--dur-slow` | 300ms | Gauge fill, progress sweep, view swap |

Wrap all non-essential motion in `@media (prefers-reduced-motion: reduce)` and collapse to
instant. Never animate `width`/`height`/`top`/`left` for anything large — use `transform` and
`opacity`.

### 3.12 Z-index layers

| Token | Value | Layer |
|-------|-------|-------|
| `--z-base` | 0 | Content |
| `--z-sticky` | 50 | Sticky banner / sticky table header |
| `--z-overlay` | 100 | Drill-down, popover |
| `--z-modal` | 200 | Blocking dialog |
| `--z-toast` | 300 | Transient notifications |

### 3.13 Layout constants

| Token | Value | Role |
|-------|-------|------|
| `--page-max` | 1400px | Max content width, centered |
| `--page-pad-x` | 24px (`--space-5`) | Page horizontal padding |
| `--col-gap` | 16px (`--space-4`) | Grid/card gap |

---

## 4. Layout

- **Page shell:** `max-width: var(--page-max); margin: 0 auto; padding: 0 var(--page-pad-x)
  var(--space-6);` on `--surface-0`.
- **Vertical rhythm:** sections separated by `--space-6`; cards within a grid by `--space-4`.
- **Banner is sticky** (`position: sticky; top: 0; z-index: var(--z-sticky)`) with a backdrop
  blur so scrolled content stays legible underneath.
- **Density:** comfortable, not cramped. Table rows ~32–36px tall; card padding `--space-4`.
  Match the host's density — VS Code is denser than a standalone report; honor the host.
- **Responsive:** cards reflow from a multi-column grid to single column under ~720px. Tables
  gain horizontal scroll rather than truncating columns. Verify at narrow + wide.

---

## 5. Component contracts

Each component has a fixed structure and class contract. Build from these — do not reinvent.

### 5.1 Banner + eyebrow + brand strip

The signature Saropa header. Sticky, blurred, with a 3px brand gradient strip on top.

```html
<header class="banner">
  <div class="eyebrow">SAROPA · PROJECT MAP</div>
  <h1 class="title">Project health</h1>
  <p class="subtitle muted">Where size, churn, and complexity concentrate.</p>
</header>
```

- `.banner::before` paints the 3px strip: `linear-gradient(90deg, var(--brand), var(--brand-2)
  55%, var(--text) 100%)`.
- Eyebrow is the **only** uppercase, brand-colored, letter-spaced text on the page.
- Exactly one `h1.title` per surface.

### 5.2 KPI / stat cards

The big-number summary row (files, functions, problems, elapsed — as in the scan dashboard).

```html
<div class="kpi-grid">
  <div class="kpi-card">
    <div class="kpi-v">3,724</div>
    <div class="kpi-l">Files</div>
  </div>
  <div class="kpi-card crit"><div class="kpi-v">0</div><div class="kpi-l">Problems</div></div>
</div>
```

- `.kpi-v` uses `--text-kpi` + `tabular-nums`; `.kpi-l` uses `--text-caption muted` uppercase.
- Severity modifier classes color **only the number**: `.kpi-card.crit .kpi-v { color:
  var(--accent-critical) }`, `.warnings`, `.errors`, `.info`. A zero-problem count stays
  `--status-good`, not red.
- Card: `--surface-1`, `1px solid --border`, `--radius-lg`, padding `--space-4`, `--shadow`.

### 5.3 Toolbar band

Holds search, segmented filters, and actions. A single `--surface-3` inset band under the
banner.

- Left: search field. Center: segmented control / chips. Right: button cluster.
- Wraps gracefully; never let the toolbar push content below the fold on narrow widths.

### 5.4 Buttons (three tiers)

| Tier | Class | Fill | Use |
|------|-------|------|-----|
| Primary | `.btn.primary` | `--brand` fill, white text | The single most likely action (Rescan, Export) |
| Secondary | `.btn` | `--surface-3`, `1px solid --border` | Common actions |
| Ghost | `.btn.ghost` | transparent, text only | Tertiary / inline |

- Exactly **one** primary per surface (or per toolbar group). More than one primary = no
  primary.
- All tiers: `--radius`, padding `--space-2 --space-3`, `--text-label`, `--dur-fast` hover.
- Focus: `outline: 2px solid var(--vscode-focusBorder, var(--brand)); outline-offset: 2px;`.
- **A secondary button MUST declare a fallback fill _and_ a border.** Bind the fill to the host
  token but fall back to a token surface — `background: var(--vscode-button-secondaryBackground,
  var(--surface-3))` — and always give it a `1px solid var(--border)` edge. Several host themes
  leave `--vscode-button-secondaryBackground` undefined or set it nearly equal to the surface
  behind it; without both the fallback and the border the button renders as bare text and reads
  as a link, not a control. This is the single most common "the buttons don't look like buttons"
  defect.

### 5.5 Segmented control

Mutually-exclusive view/filter switch (e.g. tier selector, severity filter).

- Container `--surface-3`, inner buttons share the band; active button gets
  `--surface-1` + `--border-strong` + `--text` (inactive stays `--muted` lifted to AA).
- Keyboard: arrow keys move selection; `aria-pressed` on each segment.

### 5.6 Chips / filter strip

Removable filters and quick toggles.

- `--radius-pill`, `--surface-3`, `--text-caption`. Active chip: `--brand-glow` background +
  `--brand-2` text. Remove affordance is a `×` button with its own `aria-label`.

### 5.7 Data table (sortable, filterable)

The workhorse — hot spots, function lists, findings. One table contract everywhere.

```html
<table class="dash-table" aria-label="Hot spots">
  <thead><tr>
    <th class="sortable" aria-sort="descending">Fire</th>
    <th class="sortable">File</th>
  </tr></thead>
  <tbody>
    <tr><td class="num">🔥🔥🔥</td><td class="path">lib/foo/bar.dart</td></tr>
  </tbody>
</table>
```

- **Sticky header** (`--z-sticky`) on `--surface-2`; header text `--text-caption muted`
  uppercase.
- **Zebra** rows via `--zebra` (`rgba(text, .025)`); **hover** via `--hover`
  (`rgba(text, .05)`), never both fighting.
- **Sort affordance:** header is a button; show a ▲/▼ glyph; reflect `aria-sort`. "Click a
  column to sort" hint lives in the panel summary, not per cell.
- **Numeric columns** right-aligned, `tabular-nums`. **Path columns** left-aligned, ellipsis
  in the middle (keep the filename visible), full path in `title`.
- **Row click** opens the target (drill-down) — the whole row is the affordance; show a pointer
  cursor and a hover row tint.
- **Filter:** a single search field above the table filters by file or reason; show the
  filtered/total count.

### 5.8 Pills & badges

| Variant | Use | Style |
|---------|-----|-------|
| `.grade-badge` | Letter grade A–F | Pill; A→`--status-good`, F→`--status-bad`, graded blend between |
| `.flag-pill` | A finding flag (unused, uncovered, long) | Small `--surface-3` pill, `--text-caption` |
| `.status-pill.good/.warn/.bad` | Pass/warn/fail | Tinted bg + blended-toward-fg text (§3.2) |

Grade and status colors come from the semantic tokens — never a bespoke green.

**Tinted badge background** (a status pill whose fill is a wash of its own status color): use
`color-mix(in srgb, var(--status-bad) 20%, transparent)` for the background paired with
`var(--status-bad)` text — never an `#rrggbbaa` alpha-suffixed hex, which bakes in a fixed color
that ignores the theme and fails in high-contrast mode.

**Grade ramp**, derived from the semantic tokens so each grade reads the same hue as the matching
severity (A=good, F=bad, C=warning at the midpoint, B/D blended) — no bespoke grade greens/reds:

```css
--grade-a: var(--status-good);
--grade-b: color-mix(in srgb, var(--status-good) 55%, var(--accent-warning));
--grade-c: var(--accent-warning);
--grade-d: var(--accent-high);
--grade-e: color-mix(in srgb, var(--accent-high) 50%, var(--status-bad)); /* only where data carries an E grade */
--grade-f: var(--status-bad);
```

### 5.9 Gauge / radial progress

For a single 0–100 score (health, coverage, gravity).

- SVG ring: track `--border`, fill `--gauge-color` (defaults to
  `--vscode-progressBar-background` / brand). Animate `stroke-dasharray` over `--dur-slow`,
  disabled under reduced-motion.
- Center label: the number at `--text-kpi`, caption below at `--text-caption muted`.

### 5.10 Charts (ECharts)

Treemaps, scatter, bar. Charts must read the **same tokens**, not a separate chart palette.

- Read CSS vars at render time and pass into the ECharts theme: text → `--text`, axis/split →
  `--border`, series ramp anchored on `--brand`/`--accent-*`.
- Background **transparent** so the card surface shows through.
- Vendored ECharts only (offline webviews have no network). Provide a no-JS fallback (a table)
  for the data the chart visualizes.
- Tooltip uses `--surface-2` + `--shadow-lg` + `--text`.

### 5.11 States (the part most surfaces skip)

Every data surface specifies all of these — not just the happy path.

| State | Treatment |
|-------|-----------|
| **Loading** | Skeleton rows/cards in `--surface-2`, subtle shimmer (reduced-motion: static). Never a bare spinner on a blank page. |
| **Scanning / progress** | Phase stepper + progress bar + current item + live counters + streamed preview. Uses the **same** banner/card/token system — this was the orphan panel; it must look like the rest. Pause/Resume/Restart/Cancel are buttons in the standard tiers. |
| **Empty** | Centered, `--space-8` vertical padding: an icon, a one-line "nothing here" in `--text`, a one-line why in `--muted`, and a primary action if one exists ("Run a scan"). |
| **Error** | Inline banner on `--surface-2` with `--accent-critical` left edge, the human-readable cause, and a retry action. Never dump a stack trace as the primary message. |
| **Offline** | A `--accent-warning` status pill in the banner; cached data stays visible and is labeled stale. |
| **Stale** | A "data from {time}" caption near the title in `--muted`; offer a one-tap refresh. |

The scanning state in particular is held to the same 10/10 bar as the finished report — it is
the first thing the user sees, and on large projects it is on screen the longest.

---

## 6. Iconography & emoji

- **Semantic icons** come from the host icon set (VS Code Codicons in webviews; the app icon
  system in Flutter). Every action/entity carries its matching icon.
- **Emoji ratings are intentional and bounded.** The 🔥 hot-spot rating is a deliberate
  ordinal glyph (1–3 flames). When using emoji as data: keep the set tiny and ordinal, give
  the cell a text `aria-label` ("severity 3 of 3"), and never rely on emoji color alone to
  carry meaning (accessibility + cross-platform rendering).
- No decorative emoji in headings, labels, or buttons. Emoji is data or it is absent.

---

## 7. Accessibility (ship gate, not a nicety)

1. **Contrast:** body and `--muted` clear **AA 4.5:1** on their surface; large text (≥18.66px
   bold / ≥24px) clears **3:1**. Verify in light, dark, and high-contrast.
2. **Focus:** every interactive element has a visible `:focus-visible` outline (2px
   `--vscode-focusBorder`/`--brand`, offset 2px). The decorative `--ring` is additive, not a
   substitute.
3. **Keyboard:** full operability — tables sortable via Enter/Space on header buttons,
   segmented controls arrow-navigable, drill-down rows reachable and activatable, no mouse-only
   affordance.
4. **Semantics:** real `<table>`/`<th scope>`/`aria-sort` for tables; `aria-label` on
   icon-only buttons, search fields, charts; `role`/`aria-pressed` on toggles.
5. **Reduced motion:** `@media (prefers-reduced-motion: reduce)` collapses gauge fills,
   shimmer, sweeps, and view-swap transitions to instant.
6. **RTL:** logical properties (`margin-inline`, `padding-inline`, `inset-inline`) so the
   layout mirrors. The 3px banner strip and chevrons flip. Verify with `dir="rtl"`.
7. **Color independence:** severity is never color-only — pair with an icon, a label, or a
   glyph (a red pill also says "Critical").
8. **Dyslexia mode:** where the app offers it, the type scale and spacing must survive the
   font swap without overflow or collision.

---

## 8. Copy & voice (inside dashboards)

Dashboard copy follows the Saropa user-copy rules:

- **Externalize every user-facing string** through the project's i18n catalog (`l10n('key')`
  in the extension → `extension/src/i18n/locales/en.json`; ARB getters in Contacts; NLS in Log
  Capture). Never hardcode display text. Exempt: dev/debug/log strings, CSS, identifiers, URLs.
- **No first-person.** The dashboard speaks to the user ("Run a scan", "No problems found") or
  about the product ("Saropa Lints scanned 3,724 files") — never "we" / "our" / "me" / "my".
- **Be specific.** Name the thing and show the value: "0 problems in 3,724 files", not
  "Scan complete". A confirmation the user cannot tie to a concrete item is noise.
- **Interpolate, never concatenate.** `l10n('scan.filesDone', { count })` with value
  `"{count} files scanned"`, not `count + ' files scanned'`.
- **Empty/error copy states the next action**, not just the condition.

---

## 9. Anti-patterns (banned)

- A **second stylesheet** for one panel instead of extending the shared one (this is the
  original sin that produced three style islands).
- **Fixed hex** for surfaces/text/borders in a host-themed surface — breaks every non-default
  theme and high-contrast mode.
- **Brand orange as a large text background** — fails AA for small text.
- A **bare spinner** on a blank page as the loading state.
- **Two primary buttons** in one group.
- **Drop shadow as the only elevation signal** with no surface step.
- A **separate chart palette** that ignores the design tokens.
- **Emoji as decoration** in headings/labels/buttons.
- **String concatenation** to build user-facing copy; **hardcoded** display strings.
- Animating layout-affecting properties (`width`/`top`) on large elements.
- A **scanning/progress state** that looks unlike the finished report.

---

## 10. Adoption per platform

### VS Code webviews (saropa_lints extension, drift advisor/viewer, Log Capture dashboard panels)
- Import the shared chrome stylesheet (in saropa_lints, `extension/src/views/dashboardChromeStyles.ts`;
  in Log Capture, the prepended `:root` token module in `src/ui/viewer-styles/`) for the token
  `:root` + component base. Per-surface CSS adds **only** that surface's specifics. Each project
  names its own shared module — the *token names* are shared, the file is per-project.
- **Prefer injecting the token `:root` once at the webview choke point over a per-panel import.**
  If every panel already passes through one shared security wrapper before display (e.g. a
  `secureWebviewHtml` that stamps the CSP `<meta>` into `<head>`), inject `<style>` + the token
  `:root` in that same wrapper. Every surface then resolves `var(--status-bad)` etc. with zero
  per-panel imports, and one edit re-themes them all — no risk of a new panel shipping without the
  tokens. `style-src 'unsafe-inline'` already permits the injected `<style>`, so it needs no nonce.
  (Validated in drift advisor, 2026-06.)
- **Log Capture is in scope on two fronts, not one:** its standalone HTML reports (see below) AND
  its dashboard-class webview panels (SQL query history, Crashlytics, Performance, Signal report,
  error-rate, recurring, project-state). Those panels follow this guide. Its log-viewer console is
  exempt per the Scope carve-out at the top.
- Bind to `--vscode-*` per §3. CSP: allow vendored scripts + inline style/data only.
- **Migrate the outliers:** (1) move Project Map's Dart-generated HTML onto these tokens (or render
  it through the same TS chrome), (2) bring the scan-progress panel under the shared chrome so all
  three surfaces match, and (3) migrate Log Capture's existing hand-painted dashboard panels off
  raw hex onto the token names, console excepted.

### Standalone HTML exports (project_health report, Log Capture reports)
- Ship the §3.6 fallback palette in the report `<style>`. Same component classes as the
  webview. Vendor any chart library.

### Flutter app (Saropa Contacts in-app dashboards)
- Map tokens to `ThemeCommon*` / `Theme.of(context)`: surfaces → `ThemeCommonColors`, spacing
  → `ThemeCommonSpace`, radius → `ThemeCommonRadius`, type → the app text theme. Brand orange
  comes from the app brand color. Same component anatomy (banner/eyebrow, KPI cards, tables,
  pills, states), expressed in widgets. Never inline a hex/px where a theme token exists.

---

## 11. Ship checklist (verify, do not hope)

Before a dashboard surface ships:

- [ ] Every color/space/radius/type value resolves from a token — zero literals at call sites.
- [ ] Renders correctly in **light, dark, and high-contrast** themes.
- [ ] **AA contrast** verified for body, muted, and every status/pill text.
- [ ] **Focus visible** on every interactive element; full **keyboard** operability.
- [ ] **All states** implemented: loading, scanning, empty, error, offline, stale.
- [ ] **RTL** mirrors cleanly; **reduced-motion** collapses animation.
- [ ] **Responsive** at narrow (~360–720px) and wide (≥1400px) — no overflow, no truncation.
- [ ] Charts read the design tokens and have a no-JS data fallback.
- [ ] Every user-facing string is in the i18n catalog; none hardcoded; none concatenated.
- [ ] One primary action; one `h1`; one eyebrow.
- [ ] The scanning/progress state looks like the finished report, not a different app.

---

_This guide is portable. Copy it into any Saropa project and bind the token table (§3) to that
project's host theme; the components (§5), accessibility gate (§7), and checklist (§11) are
platform-independent._

---

## 12. Changelog

Newest first. Each entry records what changed in the guide and the project work that proved it.

- **Buttons, badges, and adoption hardened from the drift advisor rollout.** Added the
  secondary-button fallback-and-border rule to §5.4 (the concrete cause of "buttons that don't
  look like buttons"); added the `color-mix` tinted-badge background recipe and the explicit
  A–F grade-ramp derivation to §5.8 (replacing `#rrggbbaa` alpha hexes and bespoke grade colors);
  added the "inject the token `:root` once at the webview choke point" adoption pattern to §10.
  All three were validated migrating the drift advisor extension's panels onto the token system.
- **Initial canonical guide.** One token system (§3), component contracts (§5), accessibility
  ship gate (§7), and per-platform adoption (§10) unifying the formerly-divergent Saropa dashboard
  surfaces.
