/**
 * Findings-dashboard-specific CSS fragments, split out of violationsDashboardStyles.ts so the
 * (still substantial) CSS string is not one function.
 *
 * Migrated onto the canonical dashboard chrome (`views/dashboardChromeStyles.ts`) per design
 * principle 5 ("one design system", plans/PLAN_extension_ui_redesign.md §1.5). The chrome's class
 * names (.dash-hero, .kpi-row/.kpi-card, .toolbar-band/.field/.seg/.btn, .chip-strip/.chip,
 * .chart-card/.bar-row/.donut, details.more) were originally MODELED on this dashboard's own
 * markup (see dashboardChromeStyles.ts's header comment), so this dashboard's HTML already used
 * the same selectors before this migration — no markup or client-script changes were needed here,
 * only deleting the ~700 lines of byte-identical duplicate declarations these functions used to
 * carry and keeping only what the canonical chrome does not provide:
 *   - Behavioral bespoke rules that must survive verbatim: the deliberately-uncancelled gauge
 *     entrance animation (a live-rebuild flicker bugfix), the dropdown `<select>`/`<option>`
 *     contrast fix, and the fixed (not responsive) bar-row/donut sizing this dashboard's tighter
 *     card grid needs.
 *   - Structural bespoke content the chrome has no equivalent for: the findings table, the top
 *     rules triage table, the secondary compact-list/suppressions bands, the recent-filters
 *     popover, and the analysis-progress strip.
 * Purely cosmetic differences from the chrome defaults (segment-label styling, swatch tint,
 * full-width-toggle size) were NOT preserved as overrides — letting them converge on the
 * canonical look is the intended effect of "one design system", not a regression.
 */

/** Hero extras: freshness/toggle status pills, the gauge's pending state, and the override that
 *  cancels the chrome's inherited entrance animation on the health gauge. */
export function vdsHeroExtras(): string {
  return `
    /* Freshness pill doubles as a refresh button (role="button" + tabindex="0"). */
    .status-line .pill.freshness {
      cursor: pointer;
      user-select: none;
      transition: background .15s;
    }
    .status-line .pill.freshness:hover {
      background: var(--vscode-toolbar-hoverBackground, var(--surface-3));
    }
    .status-line .pill.freshness:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    /* Toggle pills (#224) — clickable status-line affordances for the supplementary-counts
       feature. Promo state telegraphs "available but inactive" via dashed border + reduced
       opacity; ON state inherits the neutral pill look so it doesn't compete with severity pills. */
    .status-line .pill.toggle {
      cursor: pointer;
      user-select: none;
      transition: opacity .15s, background .15s;
    }
    .status-line .pill.toggle:hover {
      background: var(--vscode-toolbar-hoverBackground, var(--surface-3));
    }
    .status-line .pill.toggle.promo {
      opacity: .65;
      border: 1px dashed var(--border, currentColor);
      background: transparent;
    }
    .status-line .pill.toggle.promo:hover { opacity: 1; }
    .status-line .pill.toggle:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    /* The chrome's .gauge-fill plays a 1.1s entrance animation on first paint (gauge-fill-in) —
       correct for a dashboard that renders once, but WRONG here: this panel rebuilds its whole
       HTML on every diagnostics tick, and a keyframe restarts from frame 0 on each rebuild, so
       when ticks arrive faster than the animation duration the ring is forever caught near-empty
       (reads as a lone round-cap dot). Cancel the inherited animation and keep only the
       pending-state opacity fade, which is the ONLY transition this gauge should ever play. */
    .gauge-fill { animation: none !important; transition: opacity 160ms ease-out; }
    .gauge-label .lg { font-size: 1.55em; font-weight: 700; line-height: 1; }
    .gauge-label .sm { font-size: .7em; opacity: .7; }

    /* Pending state (analysis streaming results in) — not in the chrome at all: dim the ring,
       hide the grade, and show a compact "computing" glyph so a not-yet-settled score never
       flashes a misleading grade. Toggled via data-pending in the script. */
    .gauge-pending {
      position: absolute;
      inset: 0;
      display: none;
      align-items: center;
      justify-content: center;
      font-size: 1.6em;
      font-weight: 700;
      letter-spacing: 1px;
      color: var(--muted);
      pointer-events: none;
    }
    .hero-gauge[data-pending="true"] .gauge-fill { opacity: .2; }
    .hero-gauge[data-pending="true"] .gauge-label { display: none; }
    .hero-gauge[data-pending="true"] .gauge-pending { display: flex; }
`;
}

/** Toolbar extras: the dropdown contrast fix (not in the chrome — canonical .field only resets
 *  <select> chrome, not its open-menu palette) and the grouped-menu structure the chrome's plain
 *  details.more menu doesn't have (section headings + separators for Export/Filter/Open/System). */
export function vdsToolbarExtras(): string {
  return `
    /* The chrome's .toolbar-row label uses plain --muted, which the Phase-7 UX-harness sweep
       would have measured as an AA failure here too (4.06:1 in the dark theme) -- this
       dashboard already carried the color-mix-toward-foreground fix from an earlier a11y pass,
       so keep it as an override rather than regressing back to the chrome's unfixed default. */
    .toolbar-row label { color: color-mix(in srgb, var(--vscode-foreground) 72%, var(--muted)); }

    /* The native <select> popup previously inherited a transparent background, so the open
       option list fell back to the browser default — a low-contrast bright highlight on the
       active row (the reported contrast bug). Pin the control and its <option>s to the VS Code
       dropdown tokens, and the active/hovered option to the list-selection tokens. */
    .field select {
      background: var(--vscode-dropdown-background, var(--vscode-input-background));
      color: var(--vscode-dropdown-foreground, var(--vscode-input-foreground));
    }
    .field select option {
      background: var(--vscode-dropdown-background, var(--surface-2));
      color: var(--vscode-dropdown-foreground, var(--vscode-foreground));
    }
    .field select option:checked,
    .field select option:hover {
      background: var(--vscode-list-activeSelectionBackground, var(--surface-3));
      color: var(--vscode-list-activeSelectionForeground, var(--vscode-foreground));
    }

    .menu-item .kbd {
      font-size: .78em;
      color: var(--muted);
      letter-spacing: .3px;
    }
    /* Uniform icon column so labels align across every menu item regardless of glyph advance
       width. .menu-item-label wraps glyph+label so they shrink together rather than breaking
       the kbd column. */
    .menu-item-label {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-width: 0;
    }
    .menu-item-label > .glyph {
      display: inline-block;
      width: 1.2em;
      flex: 0 0 1.2em;
      text-align: center;
      color: var(--muted);
      font-size: 1.05em;
      line-height: 1;
    }
    /* Section separator + heading inside the More menu (Export / Filter / Open / System groups).
       The first heading has no separator above it — a line immediately under the menu's top
       edge would look like a rendering glitch, not a group boundary. */
    .menu-sep {
      border: 0;
      border-top: 1px solid var(--vscode-input-border, var(--surface-3, rgba(128,128,128,.25)));
      margin: 6px 4px;
      height: 0;
    }
    .menu-section-title {
      padding: 6px 10px 2px;
      font-size: .72em;
      font-weight: 600;
      letter-spacing: .6px;
      text-transform: uppercase;
      color: var(--muted);
      pointer-events: none;
      user-select: none;
    }
`;
}

/** KPI/chart extras: the impact-tinted 5th KPI variant the chrome doesn't define, the chart
 *  card's entrance animation, and the fixed (not chrome-responsive) bar-row/donut sizing this
 *  dashboard's tighter `.charts-grid` cards need to avoid overflow. */
export function vdsKpiAndChartExtras(): string {
  return `
    /* Impact-based KPI coloring — the chrome only ships error/warning/crit/todos variants. */
    .kpi-card.high .kpi-v { color: var(--accent-high); }

    /* Entrance animation for chart cards — a Findings-only touch; the chrome's own chart-card
       has no animation of its own. */
    .chart-card { animation: card-in 220ms ease-out; }
    @media (prefers-reduced-motion: reduce) {
      .chart-card { animation: none; }
    }

    /* Fixed sizing (vs. the chrome's responsive minmax(120px,30%) / 48px columns): this
       dashboard's charts sit inside a tighter auto-fit grid (.charts-grid, min 300px per card)
       than the chrome's general-purpose layout, so the wider responsive columns can overflow a
       narrow card. Keeping the narrower fixed columns here avoids that without touching the
       chrome (which other, wider-card consumers still rely on). */
    .bar-row { grid-template-columns: 84px 1fr 36px; padding: 3px 4px; }
    .donut-wrap { width: 96px; height: 96px; }
`;
}

/** Section extras: the two meta-line/footer-line variants the chrome's `.section` doesn't define. */
export function vdsSectionExtras(): string {
  return `
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
`;
}

/** The findings table, the top-rules triage table, and their shared toolbar/empty/progress
 *  chrome — none of this has a canonical equivalent; the chrome only provides the generic
 *  `.dash-table` base, and this dashboard's grouped/expandable/bulk-select table predates and
 *  exceeds that base, so it stays fully bespoke rather than a partial, riskier re-basing. */
export function vdsFindingsAndTopRulesTables(): string {
  return `
    /* ============================================================
       FINDINGS TABLE — replaces the deeply-nested <details> tree.
       Sortable headers, sticky group rows, expand chevrons.
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
    .findings-toolbar .actions { margin-inline-start: auto; display: flex; gap: 6px; }
    /* Raw --link on --surface-3 measured 3.91:1 in the harness's first populated-fixture run
       (below the 4.5:1 AA floor) -- this dashboard's toolbar previously had no test fixture with
       real findings to render against, so the bug went undetected. Same color-mix-toward-
       foreground fix used elsewhere in this file. */
    .findings-toolbar .mini-btn {
      border: 0;
      background: transparent;
      color: color-mix(in srgb, var(--link) 75%, var(--vscode-foreground));
      cursor: pointer;
      font: inherit;
      font-size: .9em;
      padding: 2px 4px;
    }
    .findings-toolbar .mini-btn:hover { text-decoration: underline; }

    .findings-bulk-bar {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 6px 12px 8px 12px;
      border-bottom: 1px solid var(--border);
      background: color-mix(in srgb, var(--surface-3) 92%, transparent);
    }
    .findings-bulk-bar[hidden] { display: none !important; }
    .findings-bulk-label {
      font-size: .88em;
      color: var(--muted);
    }
    .findings-table thead th .sort-idx {
      margin-inline-start: 4px;
      font-size: .78em;
      color: var(--muted);
      user-select: none;
    }
    .findings-table tbody tr.frow,
    .findings-table tbody tr.crow {
      content-visibility: auto;
      contain-intrinsic-size: 40px auto;
    }
    .findings-table .col-sel-bulk {
      width: 28px;
      text-align: center;
      vertical-align: middle;
    }

    .findings-table { width: 100%; border-collapse: collapse; font-size: .92em; }
    .findings-table thead th {
      position: sticky; top: 0;
      background: var(--surface-3);
      text-align: left;
      font-weight: 600;
      font-size: .82em;
      letter-spacing: .3px;
      text-transform: uppercase;
      /* Same bug the Phase 7 UX-harness sweep already fixed in the chrome's own .dash-table
         thead th (--muted on --surface-3 measured 4.02:1, under AA) -- this table predates that
         fix and carries its own copy of the same color, only now surfaced because this pass
         added the dashboard's first populated fixture. --vscode-foreground clears AA in every
         shipped theme against editor-family surfaces without a per-theme tuned value. */
      color: var(--vscode-foreground);
      padding: 6px 10px;
      border-bottom: 1px solid var(--border);
      cursor: pointer;
      user-select: none;
      white-space: nowrap;
    }
    .findings-table thead th .arrow { opacity: .4; margin-inline-start: 4px; }
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
    .findings-table tr.group-row .gcount { color: var(--muted); font-weight: 500; margin-inline-start: 6px; }

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
    /* Finding-row file path (rendered via the .kpi-sub class, visual reuse): default LTR
       truncation eats the END of the path — the filename, the part the user most needs. Flip
       the truncation via RTL + plaintext bidi so the FRONT of the path clips instead and the
       filename stays visible; the title attribute still carries the full path for hover.
       Scoped via .col-msg so KPI-card subtitles (also .kpi-sub) keep their default layout. */
    .findings-table .col-msg .kpi-sub {
      direction: rtl;
      text-align: left;
      unicode-bidi: plaintext;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .row-action {
      visibility: hidden;
      border: 0; background: transparent;
      color: var(--link); cursor: pointer;
      font: inherit; font-size: .9em;
      padding: 0 4px;
    }
    .findings-table tr.frow:hover .row-action,
    .findings-table tr.frow:focus-within .row-action { visibility: visible; }

    /* Top Rules triage table — same chrome as the findings table but the Hide button is
       always-visible (primary affordance, not hover-only). */
    .top-rules-table { width: 100%; border-collapse: collapse; font-size: .92em; }
    .top-rules-table thead th {
      background: var(--surface-3);
      text-align: left;
      font-weight: 600;
      font-size: .82em;
      letter-spacing: .3px;
      text-transform: uppercase;
      /* Same fix as .findings-table thead th above -- same original color, same bug class. */
      color: var(--vscode-foreground);
      padding: 6px 10px;
      border-bottom: 1px solid var(--border);
      user-select: none;
      white-space: nowrap;
    }
    .top-rules-table tr.trow { border-bottom: 1px solid var(--border); }
    /* No :nth-child zebra striping: expander detail rows interleave with main rows (and stay in
       the DOM while collapsed), so position parity no longer maps to visible-row parity. */
    .top-rules-table tr.trow:hover { background: var(--vscode-list-hoverBackground); }
    .top-rules-table td { padding: 6px 10px; vertical-align: middle; }
    .top-rules-table .col-rank   { width: 36px; color: var(--muted); font-variant-numeric: tabular-nums; text-align: right; }
    .top-rules-table .col-rule   { }
    .top-rules-table .col-count  { width: 80px; text-align: right; font-variant-numeric: tabular-nums; font-weight: 600; }
    .top-rules-table .col-sev    { width: 100px; white-space: nowrap; }
    .top-rules-table .col-actions { width: 152px; text-align: right; white-space: nowrap; }
    /* Two always-visible action buttons per row, diverging on hover so the commitment
       difference (workspace Hide vs. project-wide Disable) reads at scan distance. */
    .top-rules-table .row-action {
      visibility: visible;
      border: 1px solid var(--border);
      border-radius: 4px;
      padding: 2px 10px;
      margin-inline-start: 4px;
      color: var(--vscode-foreground);
      background: var(--surface-3);
      font: inherit;
      font-size: .9em;
      cursor: pointer;
    }
    .top-rules-table .row-action.neutral:hover {
      background: color-mix(in srgb, var(--link) 14%, transparent);
      color: var(--link);
      border-color: var(--link);
    }
    .top-rules-table .row-action.danger:hover {
      background: color-mix(in srgb, var(--accent-error) 18%, transparent);
      color: var(--accent-error);
      border-color: var(--accent-error);
    }
    .top-rules-table .row-action:focus-visible {
      outline: 2px solid var(--vscode-focusBorder);
      outline-offset: 1px;
    }

    /* Sortable headers (Rule / Count / Severity). Rank is intentionally not sortable. */
    .top-rules-table thead th[data-sort] { cursor: pointer; }
    .top-rules-table thead th[data-sort] .arrow { opacity: .4; margin-inline-start: 4px; }
    .top-rules-table thead th[aria-sort="ascending"] .arrow,
    .top-rules-table thead th[aria-sort="descending"] .arrow { opacity: 1; }
    .top-rules-table thead th[data-sort]:hover { color: var(--vscode-foreground); }

    /* Expander affordance: a chevron in the rule cell; the whole row toggles. */
    .top-rules-table tr.trow[data-expandable="true"] { cursor: pointer; }
    .top-rules-table .trow-chev {
      display: inline-block;
      width: 1em;
      margin-inline-end: 4px;
      color: var(--muted);
    }
    .top-rules-table .trow-chev.placeholder { visibility: hidden; }
    .top-rules-table tr.trow[aria-expanded="true"] { background: var(--vscode-list-hoverBackground); }

    /* Detail (expanded) row — full rule message + affected-file breakdown. Indented to align
       under the rule name, past the rank + chevron gutter. */
    .top-rules-table tr.trow-detail > td { padding: 0; border-bottom: 1px solid var(--border); }
    .top-rules-table tr.trow-detail .trd-body {
      padding: 8px 12px 12px 50px;
      background: color-mix(in srgb, var(--surface-3) 50%, transparent);
    }
    .top-rules-table .trd-msg { margin: 0 0 8px; color: var(--vscode-foreground); line-height: 1.45; }
    .top-rules-table .trd-files-head {
      font-size: .82em;
      letter-spacing: .3px;
      text-transform: uppercase;
      color: var(--muted);
      margin-bottom: 4px;
    }
    .top-rules-table .trd-files {
      list-style: none; margin: 0; padding: 0;
      display: flex; flex-direction: column; gap: 2px;
    }
    .top-rules-table .trd-file {
      display: flex; align-items: center; justify-content: space-between;
      gap: 12px; padding: 3px 8px; border-radius: 4px;
      cursor: pointer; color: var(--link);
    }
    .top-rules-table .trd-file:hover { background: var(--vscode-list-hoverBackground); }
    /* RTL + plaintext bidi anchors the path to the right so the filename stays visible when the
       row narrows (same trick as the findings table). */
    .top-rules-table .trd-file-path {
      overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
      direction: rtl; text-align: left; unicode-bidi: plaintext;
    }
    .top-rules-table .trd-file-count { color: var(--muted); font-variant-numeric: tabular-nums; flex: 0 0 auto; }
    .top-rules-table .trd-file:focus-visible {
      outline: 2px solid var(--vscode-focusBorder);
      outline-offset: 1px;
    }

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

    /* This dashboard's own .empty-cta (h2/p/.btns children, center-aligned block) predates and
       differs structurally from the chrome's .empty-cta (icon+.empty-title+.empty-msg column);
       since this markup never uses the chrome's child classes, only this rule's own child
       selectors apply — no collision, kept as-is rather than restructuring working markup. */
    .empty-cta {
      padding: 28px 20px;
      text-align: center;
    }
    .empty-cta h2 { margin: 0 0 6px; font-size: 1.05em; }
    .empty-cta p { margin: 0 0 14px; color: var(--muted); }
    .empty-cta .btns { display: inline-flex; gap: 8px; }

    /* Analysis progress strip — shown while Run analysis is in flight. */
    .analysis-progress {
      margin: 10px 0 14px;
      padding: 10px 12px;
      border: 1px solid var(--border);
      border-radius: 10px;
      background: color-mix(in srgb, var(--surface-2) 86%, var(--vscode-editorInfo-foreground) 14%);
    }
    .analysis-progress-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 8px;
      font-size: .92em;
    }
    .analysis-progress-head strong { font-weight: 600; }
    .analysis-progress-head span { color: var(--muted); }
    .analysis-progress-track {
      position: relative;
      height: 6px;
      border-radius: 999px;
      overflow: hidden;
      background: color-mix(in srgb, var(--surface-3) 80%, transparent);
    }
    .analysis-progress-bar {
      position: absolute;
      inset-block: 0;
      inline-size: 42%;
      border-radius: inherit;
      background: var(--vscode-progressBar-background);
      animation: analysis-indeterminate 1.15s ease-in-out infinite;
    }
    @keyframes analysis-indeterminate {
      0% { transform: translateX(-120%); }
      50% { transform: translateX(40%); }
      100% { transform: translateX(260%); }
    }
`;
}

/** Secondary lists — TODOs, HACKs, drift issues, and analyzer suppressions. No chrome equivalent. */
export function vdsSecondaryLists(): string {
  return `
    /* ============================================================
       SECONDARY LISTS — TODOs, HACKS, drift issues.
       Compact \`note\` row layout: severity pill, location code, snippet, line.
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

    /* Suppressions band — single bordered section, kind counts inlined, drillable rows for
       rule + file only. */
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
      margin-inline-end: 6px;
      transition: transform .12s linear;
    }
    .sup-disclosure[open] > summary::before { transform: rotate(90deg); }

    .sup-ul { margin: 4px 0 8px 18px; padding: 0; font-size: .9em; color: var(--muted); }
    .sup-ul li { margin: 2px 0; }
    .sup-ul code {
      font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
      background: transparent;
    }
`;
}

/** Micro extras: the recent-filters popover, the live-rebuild anti-flicker hook, and the
 *  narrow-viewport overrides — none of which the chrome defines. */
export function vdsMicroExtras(): string {
  return `
    /* §8.5.2 — recent-filters popover anchored under the textFilter input. */
    .text-filter-field { position: relative; }
    .findings-recent {
      position: absolute;
      top: calc(100% + 4px);
      inset-inline-start: 0;
      inset-inline-end: 0;
      z-index: 50;
      max-height: 220px;
      overflow-y: auto;
      background: var(--surface-2);
      border: 1px solid var(--border);
      border-radius: 4px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    }
    .findings-recent-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 4px 8px;
      border-bottom: 1px solid var(--border);
    }
    .findings-recent-title {
      font-size: 0.8em;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.4px;
    }
    .findings-recent-clear {
      background: none;
      border: 0;
      padding: 0;
      cursor: pointer;
      color: var(--link);
      font-size: 0.85em;
    }
    .findings-recent-clear:hover { text-decoration: underline; }
    .findings-recent-list {
      list-style: none;
      margin: 0;
      padding: 4px 0;
    }
    .findings-recent-list li {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 0;
    }
    .findings-recent-list .recent-pick {
      flex: 1;
      text-align: start;
      background: none;
      border: 0;
      padding: 4px 10px;
      color: var(--vscode-foreground);
      cursor: pointer;
      font: inherit;
    }
    .findings-recent-list .recent-pick:hover,
    .findings-recent-list .recent-pick:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: none;
    }
    .findings-recent-list .recent-remove {
      width: 22px;
      height: 22px;
      margin-inline-end: 6px;
      border: 0;
      background: transparent;
      color: var(--muted);
      cursor: pointer;
      opacity: 0.6;
      border-radius: 2px;
      font-size: 14px;
    }
    .findings-recent-list .recent-remove:hover,
    .findings-recent-list .recent-remove:focus-visible {
      opacity: 1;
      background: var(--vscode-toolbar-hoverBackground, var(--vscode-list-hoverBackground));
    }

    /* Live rebuilds set body[data-no-hero-anim] so the hero entrance animation plays only on the
       first paint of a freshly-opened panel. Without this, every webview.html reassignment (one
       per analyzer diagnostic republish) reloads the document and replays the fade/slide — the
       constant header flicker. The end-state (opacity 1, no offset) is the element's default, so
       suppressing the animation leaves the header correctly rendered. */
    body[data-no-hero-anim] .dash-hero { animation: none; }

    /* Narrow-viewport collapse — the chrome has no such breakpoint at all (its own .dash-hero
       stays a fixed 2-column grid regardless of width), but this dashboard is also embedded in
       narrower panes than the chrome's other consumers, so it keeps its own override to avoid
       the hero's auto-width gauge column forcing horizontal overflow. */
    @media (max-width: 720px) {
      body { padding: 12px; }
      .dash-hero { grid-template-columns: 1fr; }
      .hero-gauge { justify-self: start; }
      .findings-table .col-rule { width: auto; }
      .findings-table .col-actions { display: none; }
    }
`;
}
