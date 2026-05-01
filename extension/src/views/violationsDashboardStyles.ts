/**
 * CSS for the **Findings Dashboard** editor webview (`violationsDashboardHtml.ts`).
 *
 * Aligned to the gold-standard editor-area dashboard patterns documented in
 * `plan/guides/UX_UI_GUIDELINES.md` (§4 layout, §6 charts, §7 tables,
 * §8 affordances, §14 anti-pattern catalog). Key invariants:
 *   - All chrome bound to `var(--vscode-*)` tokens — never a hard-coded hue.
 *   - Three layered surfaces (page → panel → inset card) so structural depth
 *     is visible without heavy borders.
 *   - Three button tiers (primary / secondary / tertiary) so the user's eye
 *     lands on one action per region. See §8.10.
 *   - Hero KPI numbers ~1.8em (§4.2) — KPIs must read as the largest type
 *     after the title, otherwise the dashboard fails its glance test.
 */
export function getViolationsDashboardStyles(): string {
    return `
    :root {
      --surface-1: var(--vscode-editor-background);
      --surface-2: var(--vscode-editorWidget-background);
      --surface-3: var(--vscode-editor-inactiveSelectionBackground);
      --inset: var(--vscode-input-background);
      --border: var(--vscode-widget-border);
      --border-strong: color-mix(in srgb, var(--vscode-focusBorder) 35%, var(--vscode-widget-border));
      --muted: var(--vscode-descriptionForeground);
      --link: var(--vscode-textLink-foreground);
      --accent-error: var(--vscode-editorError-foreground);
      --accent-warning: var(--vscode-editorWarning-foreground);
      --accent-info: var(--vscode-editorInfo-foreground);
      --accent-critical: var(--vscode-editorError-foreground);
      --accent-high: color-mix(in srgb, var(--vscode-editorError-foreground) 60%, var(--vscode-editorWarning-foreground));
      --accent-medium: var(--vscode-editorWarning-foreground);
      --accent-low: var(--vscode-editorInfo-foreground);
      --accent-opinionated: var(--vscode-descriptionForeground);
      --hero-tint: color-mix(in srgb, var(--vscode-textLink-foreground) 14%, transparent);
      --status-good: var(--vscode-testing-iconPassed, var(--vscode-editorInfo-foreground));
      --status-bad: var(--vscode-editorError-foreground);
    }

    * { box-sizing: border-box; }
    /* Content max-width with full-width override (guideline §4). Editor panes can be 4000+px
       wide on ultrawide monitors — long-line text and dense KPI strips become unreadable past
       ~1300px. Body[data-full-width="true"] removes the cap when the user clicks the toggle. */
    body {
      margin: 0 auto;
      padding: 18px 18px 28px;
      max-width: 1280px;
      font-family: var(--vscode-font-family);
      font-size: 13px;
      line-height: 1.45;
      color: var(--vscode-foreground);
      background: var(--surface-1);
    }
    body[data-full-width="true"] { max-width: none; }
    .full-width-toggle {
      flex: 0 0 auto;
      width: 26px; height: 26px;
      display: inline-flex; align-items: center; justify-content: center;
      border: 1px solid var(--border);
      border-radius: 6px;
      background: var(--surface-3);
      color: var(--vscode-foreground);
      font-size: 13px;
      cursor: pointer;
      transition: background 0.12s, border-color 0.12s;
    }
    .full-width-toggle:hover { background: var(--vscode-list-hoverBackground); border-color: var(--border-strong); }
    .full-width-toggle:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
    body[data-full-width="true"] .full-width-toggle {
      background: var(--vscode-list-activeSelectionBackground);
      border-color: var(--vscode-focusBorder);
    }
    .status-line .full-width-toggle { margin-left: auto; }

    /* ============================================================
       HERO — title, status line, hero gauge, version stamp.
       Layered above page background with a subtle tint so it reads
       as the focal element of the page (§4.1).
       ============================================================ */
    .dash-hero {
      position: relative;
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 18px;
      align-items: center;
      padding: 18px 20px;
      margin-bottom: 14px;
      border: 1px solid var(--border-strong);
      border-radius: 12px;
      background:
        radial-gradient(900px 220px at 0% 0%, var(--hero-tint), transparent 60%),
        var(--surface-2);
      animation: hero-in 360ms ease-out;
    }
    .hero-text { min-width: 0; }
    .hero-text h1 {
      margin: 0 0 4px;
      font-size: 1.55em;
      font-weight: 600;
      letter-spacing: .2px;
    }
    .hero-text h1 .stamp {
      margin-left: 10px;
      font-size: .55em;
      font-weight: 400;
      opacity: .55;
      vertical-align: middle;
      letter-spacing: .4px;
    }
    .status-line {
      margin: 0;
      color: var(--muted);
      font-size: .95em;
      display: flex;
      flex-wrap: wrap;
      gap: 4px 10px;
      align-items: center;
    }
    .status-line .dot { opacity: .55; }
    .status-line .pill {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      padding: 1px 8px;
      border-radius: 999px;
      background: var(--surface-3);
      color: var(--vscode-foreground);
      font-size: .92em;
    }
    .status-line .pill.good { color: var(--status-good); }
    .status-line .pill.bad  { color: var(--status-bad); }
    .status-line .pill.warn { color: var(--accent-warning); }

    /* Hero gauge — 0–100 health ring derived from severity mix.
       Driven by --gauge-target / --gauge-arc CSS vars so the keyframe
       animation does not fight the inline stroke-dasharray. */
    .hero-gauge {
      position: relative;
      width: 96px;
      height: 96px;
      flex: 0 0 auto;
    }
    .hero-gauge svg { width: 96px; height: 96px; display: block; }
    .gauge-track { stroke: var(--border); }
    .gauge-fill {
      stroke-dasharray: var(--gauge-target, 0) var(--gauge-arc, 999);
      animation: gauge-fill-in 1100ms ease-out;
    }
    @keyframes gauge-fill-in {
      from { stroke-dasharray: 0 var(--gauge-arc, 999); }
      to   { stroke-dasharray: var(--gauge-target, 0) var(--gauge-arc, 999); }
    }
    .gauge-label {
      position: absolute;
      inset: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 1px;
      pointer-events: none;
    }
    .gauge-label .lg { font-size: 1.55em; font-weight: 700; line-height: 1; }
    .gauge-label .sm { font-size: .7em; opacity: .7; }

    /* ============================================================
       TOOLBAR — bordered band, density tiers, sticky.
       Tier 1 (primary) ≤1, Tier 2 (secondary) ≤4, Tier 3 in overflow.
       ============================================================ */
    .toolbar-band {
      position: sticky;
      top: 0;
      z-index: 10;
      display: flex;
      flex-direction: column;
      gap: 10px;
      padding: 10px 12px;
      margin-bottom: 12px;
      border: 1px solid var(--border);
      border-radius: 10px;
      background: var(--surface-2);
    }
    .toolbar-row {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px 10px;
    }
    .toolbar-row.spread { justify-content: space-between; }
    .toolbar-row label { color: var(--muted); font-size: .92em; display: inline-flex; align-items: center; gap: 6px; }

    .field {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 8px;
      border: 1px solid var(--vscode-input-border, var(--border));
      border-radius: 6px;
      background: var(--vscode-input-background);
    }
    .field:focus-within { border-color: var(--vscode-focusBorder); }
    .field input, .field select {
      border: 0;
      outline: 0;
      background: transparent;
      color: var(--vscode-input-foreground);
      font: inherit;
      min-width: 160px;
    }
    .field input { flex: 1; min-width: 200px; }
    .field .glyph { color: var(--muted); }
    .field .clear-btn {
      border: 0; background: transparent; color: var(--muted);
      cursor: pointer; padding: 0 2px; font: inherit;
    }
    .field .clear-btn:hover { color: var(--vscode-foreground); }

    /* Segmented control — replaces the bare <select> for severity/impact
       so users can multi-toggle in one click without the menu round-trip. */
    .seg {
      display: inline-flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 4px;
      padding: 3px;
      border: 1px solid var(--border);
      border-radius: 999px;
      background: var(--surface-3);
    }
    .seg .seg-label {
      padding: 0 8px;
      color: var(--muted);
      font-size: .9em;
    }
    /* Inverted toggle visual model (guideline §14.15): pressed = quiet (default state),
       unpressed = ghosted (the diverged state). Pressed state never borrows primary-button
       colors — primary-button vocabulary is reserved for tier-1 actions in the same toolbar. */
    .seg .seg-btn {
      border: 1px solid transparent;
      border-radius: 999px;
      padding: 3px 10px;
      font: inherit;
      font-size: .9em;
      color: var(--vscode-foreground);
      background: transparent;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: opacity 0.12s, color 0.12s;
    }
    .seg .seg-btn .swatch {
      width: 9px; height: 9px; border-radius: 50%;
      background: var(--accent-info);
      border: 1px solid color-mix(in srgb, var(--vscode-foreground) 20%, transparent);
      transition: opacity 0.12s, transform 0.12s;
    }
    /* Pressed = INCLUDED — the default, quiet state. Plain text + colored swatch. */
    .seg .seg-btn[aria-pressed="true"] {
      color: var(--vscode-foreground);
      font-weight: 500;
      opacity: 1;
    }
    /* Unpressed = EXCLUDED — the diverged state. Ghosted, strike-through, desaturated swatch.
       This is the loud signal: "you have actively removed this category from the view." */
    .seg .seg-btn[aria-pressed="false"] {
      color: var(--muted);
      opacity: 0.5;
      text-decoration: line-through;
      text-decoration-color: color-mix(in srgb, var(--muted) 60%, transparent);
    }
    .seg .seg-btn[aria-pressed="false"] .swatch {
      opacity: 0.4;
      transform: scale(0.85);
    }
    .seg .seg-btn:hover {
      opacity: 1;
      background: color-mix(in srgb, var(--vscode-list-hoverBackground) 60%, transparent);
    }
    .seg .seg-btn:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 1px; }

    /* Button tiers (§8.10).
       Tier 1: one primary per region. Tier 2: secondary, icon+text.
       Tier 3: tertiary palette commands (hidden inside More actions). */
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      border-radius: 999px;
      border: 1px solid var(--vscode-button-border, transparent);
      background: var(--vscode-button-secondaryBackground);
      color: var(--vscode-button-secondaryForeground);
      cursor: pointer;
      font: inherit;
      font-size: .95em;
      transition: background .12s ease, border-color .12s ease, color .12s ease;
    }
    .btn .glyph { font-size: 1em; line-height: 1; }
    .btn:hover {
      background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
      border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, transparent);
    }
    .btn:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
    .btn.tier-1 {
      background: var(--vscode-button-background);
      color: var(--vscode-button-foreground);
      font-weight: 600;
    }
    .btn.tier-1:hover { background: var(--vscode-button-hoverBackground, var(--vscode-button-background)); }
    .btn.tier-3 {
      padding: 4px 10px;
      font-size: .88em;
      background: var(--surface-3);
      color: var(--vscode-foreground);
      border-color: var(--border);
      border-radius: 6px;
    }
    .btn.tier-3:hover { background: var(--vscode-list-hoverBackground); }
    .btn.danger {
      color: var(--accent-error);
      border-color: color-mix(in srgb, var(--accent-error) 50%, transparent);
    }

    /* Overflow menu — collapses ≥6 tertiary commands behind one trigger
       (§14.4). Implemented with native <details> so it works without JS
       in the host. */
    details.more {
      position: relative;
    }
    details.more > summary {
      list-style: none;
      cursor: pointer;
    }
    details.more > summary::-webkit-details-marker { display: none; }
    details.more[open] > summary .chev { transform: rotate(180deg); }
    details.more > summary .chev { display: inline-block; transition: transform .15s linear; }
    details.more .menu {
      position: absolute;
      top: calc(100% + 6px);
      right: 0;
      min-width: 220px;
      max-width: 320px;
      padding: 6px;
      display: grid;
      gap: 4px;
      background: var(--vscode-editorWidget-background);
      border: 1px solid var(--border);
      border-radius: 8px;
      box-shadow: 0 6px 20px rgba(0,0,0,.18);
      z-index: 20;
      animation: menu-in .14s ease-out;
    }
    details.more .menu .menu-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      padding: 6px 10px;
      border-radius: 5px;
      cursor: pointer;
      background: transparent;
      color: var(--vscode-foreground);
      border: 0;
      font: inherit;
      font-size: .92em;
      text-align: left;
    }
    .menu-item .kbd {
      font-size: .78em;
      color: var(--muted);
      letter-spacing: .3px;
    }
    .menu-item:hover { background: var(--vscode-list-hoverBackground); }
    .menu-item:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: -1px; }

    /* Active filters chip strip (§8.5, §14.10).
       Only renders when filter state diverges from defaults; each chip
       carries the constraint and a [×] to drop just that one. */
    .chip-strip {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 6px;
      padding: 6px 8px;
      border: 1px dashed var(--border-strong);
      border-radius: 8px;
      background: color-mix(in srgb, var(--surface-3) 65%, transparent);
    }
    .chip-strip .lbl { color: var(--muted); font-size: .9em; margin-right: 2px; }
    .chip {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 2px 4px 2px 10px;
      border-radius: 999px;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      font-size: .88em;
      animation: chip-in .14s ease-out;
    }
    .chip .x {
      cursor: pointer;
      border: 0;
      background: transparent;
      color: inherit;
      font: inherit;
      padding: 0 5px;
      border-radius: 999px;
      opacity: .8;
    }
    .chip .x:hover { opacity: 1; background: rgba(0,0,0,.18); }
    .chip-strip .clear-all {
      margin-left: auto;
      color: var(--link);
      background: transparent;
      border: 0;
      cursor: pointer;
      padding: 2px 4px;
      font: inherit;
      font-size: .9em;
    }
    .chip-strip .clear-all:hover { text-decoration: underline; }

    /* ============================================================
       KPI ROW — hero numbers (§4.2).
       Cards act as preset filters (§8.5, §14.8). 1.8em values.
       ============================================================ */
    .kpi-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
      gap: 10px;
      margin-bottom: 14px;
    }
    .kpi-card {
      position: relative;
      padding: 12px 14px;
      border: 1px solid var(--border);
      border-radius: 10px;
      background: var(--surface-2);
      transition: background .15s ease, border-color .15s ease, transform .15s ease;
    }
    .kpi-card.interactive { cursor: pointer; }
    .kpi-card.interactive:hover {
      background: var(--vscode-list-hoverBackground);
      border-color: var(--border-strong);
    }
    .kpi-card.interactive:focus-visible {
      outline: 2px solid var(--vscode-focusBorder);
      outline-offset: 1px;
    }
    .kpi-card.active {
      background: var(--vscode-list-activeSelectionBackground);
      color: var(--vscode-list-activeSelectionForeground);
      border-color: var(--vscode-focusBorder);
    }
    .kpi-k {
      text-transform: uppercase;
      font-size: .7em;
      letter-spacing: .8px;
      color: var(--muted);
    }
    .kpi-v {
      margin-top: 4px;
      font-size: 1.85em;
      font-weight: 700;
      line-height: 1.05;
      font-variant-numeric: tabular-nums;
    }
    .kpi-sub {
      margin-top: 4px;
      font-size: .82em;
      color: var(--muted);
      min-height: 1em;
    }
    .kpi-card.errors .kpi-v   { color: var(--accent-error); }
    .kpi-card.warnings .kpi-v { color: var(--accent-warning); }
    .kpi-card.crit .kpi-v     { color: var(--accent-critical); }
    .kpi-card.high .kpi-v     { color: var(--accent-high); }
    .kpi-card.todos .kpi-v    { color: var(--accent-info); }

    /* ============================================================
       SECTIONS — every major band wrapped in a <section> with <h2>
       (§14.6). Surfaces layered for visible depth.
       ============================================================ */
    .section { margin-bottom: 14px; }
    .section > h2 {
      margin: 0 0 8px;
      font-size: 1.05em;
      font-weight: 600;
      letter-spacing: .2px;
      color: var(--vscode-foreground);
      display: flex;
      align-items: baseline;
      gap: 8px;
    }
    .section > h2 .count {
      font-size: .82em;
      color: var(--muted);
      font-weight: 500;
    }
    .section > h2 .meta {
      font-size: .82em;
      color: var(--muted);
      font-weight: 400;
      margin-left: auto;
    }
    .section .meta-line {
      margin: 0 0 8px;
      color: var(--muted);
      font-size: .92em;
    }
    .section .footer-line {
      margin: 0;
      color: var(--muted);
      font-size: .9em;
      padding: 6px 0;
    }

    /* ============================================================
       CHARTS — bars + donut side by side (§6.1).
       Bars stay rendered with zero-width fills when a slot is empty;
       the whole chart card is omitted only if every slot is zero
       (§8.16 "skeleton vs omit" rule).
       ============================================================ */
    .charts-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 12px;
    }
    .chart-card {
      padding: 12px 14px;
      border: 1px solid var(--border);
      border-radius: 10px;
      background: var(--surface-2);
      animation: card-in 220ms ease-out;
    }
    .chart-card h3 {
      margin: 0 0 10px;
      font-size: .98em;
      font-weight: 600;
      display: flex;
      align-items: baseline;
      gap: 8px;
    }
    .chart-card h3 .count {
      font-size: .82em;
      color: var(--muted);
      font-weight: 500;
    }
    .chart-card .body {
      display: grid;
      grid-template-columns: 1fr 96px;
      gap: 10px;
      align-items: center;
    }
    .bar-row {
      display: grid;
      grid-template-columns: 84px 1fr 36px;
      align-items: center;
      gap: 8px;
      padding: 3px 4px;
      border-radius: 4px;
      cursor: pointer;
      font-size: .92em;
    }
    .bar-row:hover { background: var(--vscode-list-hoverBackground); }
    .bar-row:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: -1px; }
    .bar-row.zero { opacity: .45; cursor: default; }
    .bar-row.zero:hover { background: transparent; }
    .bar-label { text-transform: capitalize; color: var(--vscode-foreground); }
    .bar-track {
      height: 8px;
      border-radius: 999px;
      background: var(--border);
      overflow: hidden;
    }
    .bar-fill {
      height: 100%;
      border-radius: 999px;
      width: var(--bar-width, 0%);
      animation: grow-x 520ms ease-out;
      transform-origin: left center;
    }
    .bar-value { text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); }

    .bar-fill.sev-error      { background: var(--accent-error); }
    .bar-fill.sev-warning    { background: var(--accent-warning); }
    .bar-fill.sev-info       { background: var(--accent-info); }
    .bar-fill.imp-critical   { background: var(--accent-critical); }
    .bar-fill.imp-high       { background: var(--accent-high); }
    .bar-fill.imp-medium     { background: var(--accent-medium); }
    .bar-fill.imp-low        { background: var(--accent-low); }
    .bar-fill.imp-opinionated { background: var(--accent-opinionated); }

    /* Donut — same dataset as the bars; pairs rank with proportion (§6.1). */
    .donut-wrap { width: 96px; height: 96px; position: relative; }
    .donut svg { width: 100%; height: 100%; transform: rotate(-90deg); display: block; }
    .donut .seg { fill: transparent; stroke-width: 16; }
    .donut-legend {
      position: absolute; inset: 0;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      pointer-events: none;
    }
    .donut-legend .total {
      font-size: 1.25em;
      font-weight: 700;
      line-height: 1;
      font-variant-numeric: tabular-nums;
    }
    .donut-legend .lbl { font-size: .68em; color: var(--muted); margin-top: 2px; }

    /* ============================================================
       FINDINGS TABLE — replaces the deeply-nested <details> tree.
       Sortable headers, sticky group rows, expand chevrons (§4.4, §7).
       ============================================================ */
    .findings-wrap {
      border: 1px solid var(--border);
      border-radius: 10px;
      overflow: hidden;
      background: var(--surface-2);
    }
    .findings-toolbar {
      display: flex; align-items: center; gap: 10px;
      padding: 8px 12px;
      border-bottom: 1px solid var(--border);
      background: var(--surface-3);
    }
    .findings-toolbar .actions { margin-left: auto; display: flex; gap: 6px; }
    .findings-toolbar .mini-btn {
      border: 0;
      background: transparent;
      color: var(--link);
      cursor: pointer;
      font: inherit;
      font-size: .9em;
      padding: 2px 4px;
    }
    .findings-toolbar .mini-btn:hover { text-decoration: underline; }

    .findings-table { width: 100%; border-collapse: collapse; font-size: .92em; }
    .findings-table thead th {
      position: sticky; top: 0;
      background: var(--surface-3);
      text-align: left;
      font-weight: 600;
      font-size: .82em;
      letter-spacing: .3px;
      text-transform: uppercase;
      color: var(--muted);
      padding: 6px 10px;
      border-bottom: 1px solid var(--border);
      cursor: pointer;
      user-select: none;
      white-space: nowrap;
    }
    .findings-table thead th .arrow { opacity: .4; margin-left: 4px; }
    .findings-table thead th[aria-sort="ascending"]  .arrow { opacity: 1; }
    .findings-table thead th[aria-sort="descending"] .arrow { opacity: 1; }
    .findings-table tr.group-row td {
      padding: 7px 10px;
      background: var(--surface-3);
      font-weight: 600;
      cursor: pointer;
      border-top: 1px solid var(--border);
    }
    .findings-table tr.group-row .gtitle { display: inline-flex; align-items: center; gap: 6px; }
    .findings-table tr.group-row .chev { display: inline-block; transition: transform .15s linear; }
    .findings-table tr.group-row[aria-expanded="false"] .chev { transform: rotate(-90deg); }
    .findings-table tr.group-row .gcount { color: var(--muted); font-weight: 500; margin-left: 6px; }

    .findings-table tr.frow { border-bottom: 1px solid var(--border); cursor: pointer; }
    .findings-table tr.frow:nth-child(odd of .frow) { background: color-mix(in srgb, var(--surface-3) 35%, transparent); }
    .findings-table tr.frow:hover {
      background: var(--vscode-list-hoverBackground);
      outline: 1px solid var(--border-strong);
      outline-offset: -1px;
    }
    .findings-table tr.frow:focus-visible {
      outline: 2px solid var(--vscode-focusBorder);
      outline-offset: -2px;
    }
    .findings-table td { padding: 6px 10px; vertical-align: top; }
    .findings-table .col-sev   { width: 80px; white-space: nowrap; }
    .findings-table .col-rule  { width: 22%; }
    .findings-table .col-msg   { }
    .findings-table .col-line  { width: 60px; text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); white-space: nowrap; }
    .findings-table .col-actions { width: 56px; text-align: right; }

    .sev-pill {
      display: inline-block;
      padding: 1px 8px;
      border-radius: 999px;
      font-size: .82em;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: .3px;
    }
    .sev-pill.sev-error   { background: color-mix(in srgb, var(--accent-error) 18%, transparent); color: var(--accent-error); }
    .sev-pill.sev-warning { background: color-mix(in srgb, var(--accent-warning) 18%, transparent); color: var(--accent-warning); }
    .sev-pill.sev-info    { background: color-mix(in srgb, var(--accent-info) 18%, transparent); color: var(--accent-info); }
    .sev-pill.sev-note    { background: var(--surface-3); color: var(--muted); }

    .rule-tag {
      font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
      font-size: .92em;
      word-break: break-word;
    }
    .vmsg { white-space: pre-wrap; word-break: break-word; }
    .row-action {
      visibility: hidden;
      border: 0; background: transparent;
      color: var(--link); cursor: pointer;
      font: inherit; font-size: .9em;
      padding: 0 4px;
    }
    .findings-table tr.frow:hover .row-action,
    .findings-table tr.frow:focus-within .row-action { visibility: visible; }

    .overflow-note {
      padding: 8px 12px;
      border-top: 1px solid var(--border);
      font-size: .9em;
      color: var(--muted);
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    /* Empty CTA inside the findings band — primary action is tier-1 (§8.16). */
    .empty-cta {
      padding: 28px 20px;
      text-align: center;
    }
    .empty-cta h3 { margin: 0 0 6px; font-size: 1.05em; }
    .empty-cta p { margin: 0 0 14px; color: var(--muted); }
    .empty-cta .btns { display: inline-flex; gap: 8px; }

    /* ============================================================
       SECONDARY LISTS — TODOs, HACKS, drift issues (§14.7).
       Compact \`note\` row layout: severity pill, location code, snippet,
       line.  When zero & enabled: collapse to a one-line muted footer
       (§14.3).
       ============================================================ */
    .compact-list {
      border: 1px solid var(--border);
      border-radius: 8px;
      background: var(--surface-2);
      overflow: hidden;
    }
    .compact-list .crow {
      display: grid;
      grid-template-columns: 60px minmax(160px, 28%) 1fr 64px;
      gap: 10px;
      align-items: center;
      padding: 6px 12px;
      border-bottom: 1px solid var(--border);
      cursor: pointer;
      font-size: .92em;
    }
    .compact-list .crow:last-child { border-bottom: 0; }
    .compact-list .crow:hover { background: var(--vscode-list-hoverBackground); }
    .compact-list .crow:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: -1px; }
    .compact-list .crow.inert { cursor: default; }
    .compact-list .crow.inert:hover { background: transparent; }
    .compact-list .floc {
      font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
      font-size: .9em;
      color: var(--muted);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .compact-list .fline { text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); }
    .compact-list .fmsg { white-space: pre-wrap; word-break: break-word; }

    /* Suppressions band — single bordered section, kind counts inlined,
       drillable rows for rule + file only. (§14.1, §14.3) */
    .sup-band { padding: 10px 12px; border: 1px solid var(--border); border-radius: 10px; background: var(--surface-2); }
    .sup-row {
      display: grid;
      grid-template-columns: 1fr 56px;
      align-items: center;
      gap: 10px;
      padding: 6px 8px;
      border-radius: 4px;
      font-size: .92em;
      border-bottom: 1px solid var(--border);
    }
    .sup-row:last-child { border-bottom: 0; }
    .sup-row.sup-act { cursor: pointer; }
    .sup-row.sup-act:hover, .sup-row.sup-act:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: 1px solid var(--border-strong);
      outline-offset: -1px;
    }
    .sup-k {
      min-width: 0;
      word-break: break-word;
      font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
      font-size: .9em;
    }
    .sup-k.plain { font-family: var(--vscode-font-family); }
    .sup-n {
      text-align: right;
      font-variant-numeric: tabular-nums;
      color: var(--muted);
    }
    .sup-disclosure { margin: 8px 0 4px; }
    .sup-disclosure > summary {
      cursor: pointer;
      font-size: .9em;
      color: var(--muted);
      padding: 4px 2px;
      list-style: none;
    }
    .sup-disclosure > summary::-webkit-details-marker { display: none; }
    .sup-disclosure > summary::before {
      content: '▸';
      display: inline-block;
      margin-right: 6px;
      transition: transform .12s linear;
    }
    .sup-disclosure[open] > summary::before { transform: rotate(90deg); }

    .sup-ul { margin: 4px 0 8px 18px; padding: 0; font-size: .9em; color: var(--muted); }
    .sup-ul li { margin: 2px 0; }
    .sup-ul code {
      font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
      background: transparent;
    }

    /* ============================================================
       MICRO — links, code, focus rings, motion.
       ============================================================ */
    .link {
      color: var(--link);
      cursor: pointer;
      background: transparent;
      border: 0;
      padding: 0;
      font: inherit;
    }
    .link:hover { text-decoration: underline; }
    code, .mono {
      font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
    }

    @keyframes hero-in   { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes card-in   { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes chip-in   { from { opacity: 0; transform: scale(.92); }      to { opacity: 1; transform: scale(1); } }
    @keyframes menu-in   { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes grow-x    { from { transform: scaleX(0); }                   to { transform: scaleX(1); } }

    @media (prefers-reduced-motion: reduce) {
      .dash-hero, .chart-card, .kpi-card, .chip { animation: none; }
      .bar-fill { animation: none; transform: scaleX(1); }
      .gauge-fill {
        animation: none !important;
        stroke-dasharray: var(--gauge-target, 0) var(--gauge-arc, 999) !important;
      }
    }

    @media (max-width: 720px) {
      body { padding: 12px; }
      .dash-hero { grid-template-columns: 1fr; }
      .hero-gauge { justify-self: start; }
      .findings-table .col-rule { width: auto; }
      .findings-table .col-actions { display: none; }
    }
  `;
}

/** Empty-state document when `violations.json` is missing (matches dashboard tokens). */
export function getFindingsEmptyStateStyles(): string {
    return `
    body { margin: 0; padding: 24px; font-family: var(--vscode-font-family); font-size: 13px;
      color: var(--vscode-foreground); background: var(--vscode-editor-background); line-height: 1.5; }
    .empty-hero {
      max-width: 640px;
      margin: 8vh auto 0;
      padding: 28px 32px;
      border: 1px solid var(--vscode-widget-border);
      border-radius: 12px;
      background: var(--vscode-editorWidget-background);
      text-align: center;
    }
    h1 { margin: 0 0 10px; font-size: 1.45em; font-weight: 600; }
    p { margin: 0 0 14px; color: var(--vscode-descriptionForeground); }
    .btns { display: flex; flex-wrap: wrap; gap: 10px; justify-content: center; }
    button {
      padding: 8px 16px; cursor: pointer; border-radius: 999px;
      border: 1px solid var(--vscode-button-border, transparent);
      background: var(--vscode-button-secondaryBackground);
      color: var(--vscode-button-secondaryForeground);
      font: inherit; font-size: .95em;
      transition: background .12s ease, border-color .12s ease;
    }
    button:hover {
      background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
      border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, transparent);
    }
    button:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
    button.primary { background: var(--vscode-button-background); color: var(--vscode-button-foreground); font-weight: 600; }
    button.primary:hover { background: var(--vscode-button-hoverBackground, var(--vscode-button-background)); }
    `;
}
