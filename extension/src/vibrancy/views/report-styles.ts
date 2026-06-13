/**
 * CSS string for the **package vibrancy report** webview. Uses `var(--vscode-*)` tokens so the
 * HTML panel tracks the active theme (light/dark/high-contrast) without bundling a static palette.
 *
 * **Layout:** header with radial gauge, filter cards, dependency table, charts, and footnotes.
 * **Gauge:** SVG stroke animation relies on CSS vars set inline on the circle so the arc can
 * animate from zero to the target without fighting attribute specificity.
 * **Tables:** zebra rows, sticky headers where supported, and responsive wrapping for long package names.
 */
// Token-only palette: every color resolves through `var(--vscode-*)` so HC themes stay correct.
// Layout: max-width body with `data-full-width` escape hatch (ultrawide readability trade-off).
// Animation: gauge stroke uses inline CSS vars from TS/HTML so the arc can tween predictably.
/** CSS for the vibrancy report webview, using VS Code theme variables. */
export function getReportStyles(): string {
    return `
        /* Content max-width with full-width override (guideline §4). Editor panes can be 4000+px
           wide on ultrawide monitors — long-line text and dense tables become unreadable past
           ~1300px. Body[data-full-width="true"] removes the cap when the user clicks the toggle. */
        body {
            font-family: var(--vscode-font-family);
            color: var(--vscode-foreground);
            background: var(--vscode-editor-background);
            padding: 16px;
            margin: 0 auto;
            max-width: 1280px;
        }
        body[data-full-width="true"] { max-width: none; }
        h1 { font-size: 1.4em; margin-bottom: 8px; }

        /* ---- Report header with floating gauge ----
           Matches the Findings dashboard hero (the gold standard): gradient tint, rounded
           panel surface, padding, mount-in animation. The CSS vars used here mirror the
           chrome's tokens so the hero reads identically across the three editor surfaces
           (Findings, Code Health, Lints Config) and the vibrancy panels. */
        .report-header {
            position: relative;
            display: grid;
            grid-template-columns: 1fr auto;
            gap: 18px;
            align-items: center;
            padding: 18px 20px;
            margin-bottom: 14px;
            border: 1px solid color-mix(in srgb, var(--vscode-focusBorder) 35%, var(--vscode-widget-border));
            border-radius: 12px;
            background:
                radial-gradient(900px 220px at 0% 0%,
                    color-mix(in srgb, var(--vscode-textLink-foreground) 14%, transparent),
                    transparent 60%),
                var(--vscode-editorWidget-background);
            animation: hero-in 360ms ease-out;
        }
        .report-header .hero-text { flex: 1; min-width: 0; }
        .report-header h1 {
            margin: 0 0 4px;
            font-size: 1.55em;
            font-weight: 600;
            letter-spacing: 0.2px;
        }
        .header-version {
            font-size: 0.55em; font-weight: normal;
            opacity: 0.5; margin-inline-start: 10px;
            vertical-align: middle;
            letter-spacing: 0.4px;
        }
        @keyframes hero-in {
            from { opacity: 0; transform: translateY(-4px); }
            to   { opacity: 1; transform: translateY(0); }
        }
        @media (prefers-reduced-motion: reduce) {
            .report-header { animation: none; }
        }
        /* Status line (guideline §4.1) — muted facts row under the title. */
        .status-line {
            margin: 0 0 12px;
            color: var(--vscode-descriptionForeground);
            font-size: 0.92em;
            display: flex; flex-wrap: wrap; gap: 4px 10px;
            align-items: center;
        }
        .status-line .dot { opacity: 0.55; }
        .status-line .pill {
            display: inline-flex; align-items: center; gap: 5px;
            padding: 1px 8px;
            border-radius: 999px;
            background: var(--vscode-editor-inactiveSelectionBackground);
            color: var(--vscode-foreground);
            font-size: 0.95em;
        }
        .status-line .pill.good { color: var(--vscode-testing-iconPassed); }
        .status-line .pill.bad  { color: var(--vscode-editorError-foreground); }
        .status-line .pill.warn { color: var(--vscode-editorWarning-foreground); }
        /* Full-width toggle (guideline §4) — flips body[data-full-width]. */
        .full-width-toggle {
            flex: 0 0 auto;
            width: 26px; height: 26px;
            display: inline-flex; align-items: center; justify-content: center;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editor-inactiveSelectionBackground);
            color: var(--vscode-foreground);
            font-size: 13px;
            cursor: pointer;
            margin-inline-start: auto;
            transition: background 0.12s, border-color 0.12s;
        }
        .full-width-toggle:hover { background: var(--vscode-list-hoverBackground); }
        .full-width-toggle:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
        body[data-full-width="true"] .full-width-toggle {
            background: var(--vscode-list-activeSelectionBackground);
            border-color: var(--vscode-focusBorder);
        }

        /* ---- Radial gauge ---- */
        .radial-gauge {
            position: relative; width: 72px; height: 72px;
            flex-shrink: 0;
        }
        .gauge-svg { width: 72px; height: 72px; }
        /* Arc fill: stroke-dasharray is set as a direct SVG presentation
           attribute on the <circle class="gauge-fill"> (see buildRadialGauge
           in report-html.ts) and the load animation is driven by a SMIL
           <animate> child. Both survive the strict CSP — an earlier CSS-vars
           approach using inline style="..." attributes collapsed under CSP3
           and left the gauge as a single dot. Do NOT reintroduce a
           stroke-dasharray rule here: it would override the attribute. */
        .gauge-label {
            position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, -55%);
            font-size: 1.3em; font-weight: bold;
        }
        .gauge-sub {
            position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, 40%);
            font-size: 0.65em; opacity: 0.5;
        }
        /* Gauge doubles as the trigger for the "Why this grade?" breakdown
           panel (see buildGradeBreakdown). Visual affordance: cursor change +
           subtle focus ring; the SVG itself is unchanged so the animation
           reads the same. */
        .radial-gauge[role="button"] { cursor: pointer; }
        .radial-gauge[role="button"]:hover { filter: brightness(1.08); }
        .radial-gauge[role="button"]:focus-visible {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: 4px;
            border-radius: 50%;
        }

        /* ---- "Why this grade?" breakdown panel ---- */
        .grade-breakdown {
            margin: 0 0 14px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 10px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        .grade-breakdown-summary {
            cursor: pointer;
            padding: 10px 14px;
            list-style: none;
            display: flex; align-items: center; justify-content: space-between;
            gap: 12px;
            font-size: 0.95em;
        }
        /* Override the default disclosure-triangle marker so the chevron sits
           where we expect across Chromium and WebKit. */
        .grade-breakdown-summary::-webkit-details-marker { display: none; }
        .grade-breakdown-summary::marker { content: ''; }
        .grade-breakdown-summary::before {
            content: '\\25B8'; /* right-pointing triangle, rotates on open */
            display: inline-block;
            margin-inline-end: 8px;
            transition: transform 0.15s ease-out;
            opacity: 0.6;
        }
        .grade-breakdown[open] > .grade-breakdown-summary::before {
            transform: rotate(90deg);
        }
        .grade-breakdown-title { font-weight: 600; flex: 1; min-width: 0; }
        .grade-breakdown-hint {
            font-size: 0.85em;
            color: var(--vscode-descriptionForeground);
            opacity: 0.7;
        }
        .grade-breakdown[open] > .grade-breakdown-summary .grade-breakdown-hint {
            visibility: hidden;
        }
        .grade-breakdown-body {
            padding: 0 14px 14px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            border-top: 1px solid var(--vscode-widget-border);
            padding-top: 12px;
        }
        .grade-breakdown-body h3 {
            margin: 0 0 6px;
            font-size: 0.82em;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--vscode-descriptionForeground);
        }
        .grade-breakdown-body ul,
        .grade-breakdown-body ol {
            list-style: none;
            margin: 0; padding: 0;
        }
        .breakdown-section li {
            display: flex; align-items: center; gap: 8px;
            padding: 3px 0;
            font-size: 0.92em;
        }
        .breakdown-dist-row,
        .breakdown-bottom-row {
            justify-content: space-between;
        }
        .breakdown-dist-count,
        .breakdown-pkg-score {
            font-variant-numeric: tabular-nums;
            color: var(--vscode-foreground);
        }
        .breakdown-dist-pct {
            font-variant-numeric: tabular-nums;
            color: var(--vscode-descriptionForeground);
            opacity: 0.7;
            min-width: 38px;
            text-align: end;
        }
        /* Filter / jump buttons inside the breakdown panel — visually plain
           so the panel reads as a report, not a toolbar; styled like links
           with a hover affordance to confirm they're actionable. */
        .breakdown-filter-btn,
        .breakdown-jump-btn {
            background: none; border: none; cursor: pointer; padding: 0;
            color: var(--vscode-foreground);
            font: inherit;
            display: inline-flex; align-items: center; gap: 6px;
            flex: 1; min-width: 0;
            text-align: start;
        }
        .breakdown-filter-btn:hover,
        .breakdown-jump-btn:hover {
            color: var(--vscode-textLink-foreground);
            text-decoration: underline;
        }
        .breakdown-filter-btn:focus-visible,
        .breakdown-jump-btn:focus-visible {
            outline: 1px solid var(--vscode-focusBorder);
            outline-offset: 2px;
            border-radius: 3px;
        }
        .breakdown-filter-btn[disabled] {
            cursor: default;
            opacity: 0.45;
            text-decoration: none;
        }
        .breakdown-filter-btn[disabled]:hover {
            color: var(--vscode-foreground);
            text-decoration: none;
        }
        .breakdown-pkg-name {
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .breakdown-thresholds li { font-size: 0.88em; }

        /* ---- Letter grade badges ---- */
        .grade-badge {
            display: inline-block;
            width: 20px; height: 20px; line-height: 20px;
            text-align: center; border-radius: 4px;
            font-size: 0.75em; font-weight: bold;
            margin-inline-end: 4px; vertical-align: middle;
        }
        .grade-A { background: var(--vscode-testing-iconPassed); color: var(--vscode-editor-background); }
        .grade-B { background: var(--vscode-editorInfo-foreground); color: var(--vscode-editor-background); }
        .grade-C { background: var(--vscode-editorWarning-foreground); color: var(--vscode-editor-background); }
        .grade-D { background: var(--vscode-editorWarning-foreground); color: var(--vscode-editor-background); opacity: 0.8; }
        .grade-E { background: var(--vscode-editorWarning-foreground); color: var(--vscode-editor-background); }
        .grade-F { background: var(--vscode-editorError-foreground); color: var(--vscode-editor-background); }
        .category-cell {
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .sparkline {
            opacity: 0.9;
        }

        /* ---- Row expansion ---- */
        .col-expand { width: 24px; padding: 6px 2px; }
        .expand-cell { text-align: center; padding: 6px 2px; width: 24px; cursor: pointer; }
        .expand-chevron {
            display: inline-block; font-size: 0.7em;
            transition: transform 0.2s;
            opacity: 0.5; user-select: none;
        }
        .expand-cell:hover .expand-chevron { opacity: 1; }
        .pkg-row.expanded .expand-chevron { transform: rotate(90deg); opacity: 1; }
        .detail-row td { padding: 0; border-bottom: none; }
        .detail-card {
            background: var(--vscode-editor-inactiveSelectionBackground);
            border-radius: 6px; padding: 12px 16px;
            margin: 4px 8px 8px;
            display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 12px;
        }
        /* Detail-card content was at 0.85em with opacity 0.6 on labels — too small
         * and too dim to read in many themes (the value-side numbers stayed full
         * opacity, so the label/value contrast inside the same row was harsh).
         * Now: 0.95em body for readability, descriptionForeground token for muted
         * labels (theme-aware, WCAG-correct), and h4 at full opacity since opacity
         * stacks against the card background instead of pairing cleanly. */
        .detail-section h4 {
            margin: 0 0 6px; font-size: 0.95em; font-weight: 600;
            color: var(--vscode-foreground);
            border-bottom: 1px solid var(--vscode-widget-border);
            padding-bottom: 4px;
        }
        .detail-grid {
            display: grid; grid-template-columns: auto 1fr;
            gap: 4px 14px; font-size: 0.95em;
        }
        .detail-label { color: var(--vscode-descriptionForeground); }
        .vuln-row { font-size: 0.95em; margin: 2px 0; }
        .file-row {
            font-size: 0.9em; font-family: var(--vscode-editor-font-family, monospace);
            color: var(--vscode-descriptionForeground);
        }
        .detail-links .link-list { font-size: 0.95em; }
        .detail-search-link { cursor: pointer; font-size: 0.95em; }

        /* ---- Deps column ---- */
        .deps-icon { font-size: 0.85em; margin-inline-end: 2px; }
        .badge-shared {
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            padding: 1px 4px; border-radius: 3px;
            font-size: 0.7em; margin-inline-start: 4px;
            vertical-align: middle;
        }
        .badge-shared-sm {
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            padding: 0 3px; border-radius: 2px;
            font-size: 0.65em; margin-inline-start: 3px;
        }
        .dep-cloud { font-size: 0.8em; line-height: 1.8; }
        .dep-cloud span { margin-inline-end: 6px; }
        .dep-shared { font-weight: bold; color: var(--vscode-editorInfo-foreground); }

        /* ---- Summary cards ---- */
        .summary {
            display: flex; gap: 16px; margin-bottom: 16px;
            flex-wrap: wrap;
        }
        .summary-card {
            background: var(--vscode-editor-inactiveSelectionBackground);
            border-radius: 6px; padding: 12px 16px;
            min-width: 100px; text-align: center;
        }
        .summary-card .count { font-size: 1.8em; font-weight: bold; }
        /* Summary-card label: was 0.85em + opacity 0.8 — small and washed-out.
         * descriptionForeground gives proper muted contrast in any theme. */
        .summary-card .label { font-size: 0.9em; color: var(--vscode-descriptionForeground); min-height: 18px; }
        .summary-card[data-filter],
        .summary-card[data-breakdown-trigger] {
            cursor: pointer; transition: box-shadow 0.2s, background 0.2s;
        }
        .summary-card[data-filter]:hover,
        .summary-card[data-breakdown-trigger]:hover {
            box-shadow: 0 0 0 2px var(--vscode-focusBorder);
        }
        .summary-card[data-filter]:focus-visible,
        .summary-card[data-breakdown-trigger]:focus-visible {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: 2px;
        }
        .summary-card.card-active {
            box-shadow: 0 0 0 2px var(--vscode-focusBorder);
            background: var(--vscode-list-activeSelectionBackground);
        }
        .vibrant .count { color: var(--vscode-testing-iconPassed); }
        .stable .count { color: var(--vscode-editorInfo-foreground); }
        .outdated .count { color: var(--vscode-editorWarning-foreground); }
        .abandoned .count { color: var(--vscode-editorWarning-foreground); }
        .eol .count { color: var(--vscode-editorError-foreground); }
        .updates .count { color: var(--vscode-textLink-foreground); }
        .unused .count { color: var(--vscode-editorWarning-foreground); }
        .vulns .count { color: var(--vscode-editorError-foreground); }
        .overrides .count { color: var(--vscode-descriptionForeground); }

        /* ---- Toolbar (search + pubspec button) ---- */
        .table-toolbar {
            display: flex; gap: 12px; align-items: center;
            margin: 12px 0 8px;
            flex-wrap: wrap;
            padding: 8px 10px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        /* Accessibility helper — visually hide the search label but keep
           it readable to screen readers. The class is in the HTML, but
           without this rule the label paints over the toolbar (redundant
           with the input placeholder). dashboardChromeStyles defines the
           same rule for other webviews; the vibrancy report doesn't load
           that stylesheet, so we duplicate it here. */
        .sr-only {
            position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
            overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
        }
        /* Relative wrapper anchors the absolutely-positioned clear (X)
           button inside the search field. inline-flex keeps the wrapper
           sized to the input so the toolbar layout is unchanged. */
        .search-wrapper {
            position: relative;
            display: inline-flex;
            align-items: center;
        }
        .search-input {
            padding: 4px 24px 4px 8px; /* right padding leaves room for clear (X) */
            border: 1px solid var(--vscode-input-border);
            background: var(--vscode-input-background);
            color: var(--vscode-input-foreground);
            border-radius: 3px;
            font-size: 0.9em;
            min-width: 200px;
        }
        .search-input:focus {
            outline: none;
            border-color: var(--vscode-focusBorder);
        }
        /* Clear (X) button lives inside the input via absolute positioning.
           Hidden by default via [hidden]; report-script.ts toggles it when
           the input value is non-empty after trim. */
        .search-clear {
            position: absolute;
            /* §23.1 — clear-X anchors to the trailing edge of the input so
               it stays at end-of-line whether the writing direction is LTR
               or RTL. */
            inset-inline-end: 4px;
            top: 50%;
            transform: translateY(-50%);
            width: 16px;
            height: 16px;
            padding: 0;
            line-height: 14px;
            font-size: 14px;
            border: none;
            background: transparent;
            color: var(--vscode-input-foreground);
            opacity: 0.6;
            cursor: pointer;
            border-radius: 2px;
        }
        .search-clear:hover {
            opacity: 1;
            background: var(--vscode-toolbar-hoverBackground);
        }
        /* Rounded-rect toolbar buttons. Tokens stay on the secondary-button
         * pair. Two notes on the shape and border:
         *   - border-radius 6px: a full-pill 999px read as "too round" next
         *     to the rectangular search input and Preset select; 6px matches
         *     the table-toolbar container radius and reads as one family.
         *   - border fallback: --vscode-button-border is undefined in most
         *     themes (only Dark+ and a few HC themes set it), so the prior
         *     transparent fallback rendered as no border at all. Falling
         *     back to --vscode-widget-border keeps a visible edge in every
         *     theme without competing with focusBorder. */
        .toolbar-btn {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
            border: 1px solid var(--vscode-button-border, var(--vscode-widget-border));
            padding: 6px 12px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.85em;
            transition: background 0.12s ease, border-color 0.12s ease;
        }
        .toolbar-btn:hover {
            background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
            border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, var(--vscode-button-border, var(--vscode-widget-border)));
        }
        .toolbar-btn:focus-visible {
            outline: 1px solid var(--vscode-focusBorder);
            outline-offset: 2px;
        }
        .toolbar-btn:disabled {
            opacity: 0.65;
            cursor: not-allowed;
        }
        #pkg-nav-back { min-width: 82px; }
        /* Age slider sits immediately before the Preset dropdown. Without
           a strong visual break, the slider's max-value label ("All")
           reads as the value of the adjacent "Preset" field. We use a
           wider trailing margin AND a higher-contrast divider built from
           focusBorder + widget-border so it survives both light and dark
           themes — widget-border on its own is too subtle. */
        .age-filter {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 0.8em;
            padding-inline-end: 14px;
            margin-inline-end: 6px;
            border-inline-end: 1px solid
                color-mix(in srgb, var(--vscode-focusBorder) 30%, var(--vscode-widget-border));
        }
        .age-filter input[type="range"] { width: 120px; }
        /* The slider's max-value readout sits at the end of the age group,
           directly before the divider. A muted chip-style background and
           a min-width keep "All" from blending into the neighboring
           "Preset" label. */
        #age-max-label {
            display: inline-block;
            min-width: 32px;
            padding: 1px 6px;
            border-radius: 4px;
            background: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
            text-align: center;
            font-size: 0.95em;
        }
        .preset-filter {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 0.82em;
        }
        .preset-filter select {
            border: 1px solid var(--vscode-input-border);
            background: var(--vscode-input-background);
            color: var(--vscode-input-foreground);
            border-radius: 3px;
            padding: 2px 6px;
            font-size: 0.95em;
        }
        .dev-toggle {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 0.85em;
            white-space: nowrap;
        }
        .active-filters {
            display: flex;
            align-items: center;
            gap: 8px;
            margin: 6px 0 2px;
            padding: 6px 10px;
            border: 1px dashed var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        /* The HTML5 [hidden] attribute is set by JS when chips.length === 0; without
           this rule the .active-filters display:flex above wins and the strip
           re-appears empty (label + Clear all with no chips). */
        .active-filters[hidden] {
            display: none !important;
        }
        .active-filters-label {
            font-size: 0.82em;
            opacity: 0.8;
            white-space: nowrap;
        }
        .active-filters-list {
            display: flex;
            align-items: center;
            gap: 6px;
            flex-wrap: wrap;
            flex: 1;
        }
        .active-filter-chip {
            background: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
            border: 1px solid var(--vscode-widget-border);
            border-radius: 999px;
            padding: 2px 8px;
            font-size: 0.78em;
            cursor: pointer;
        }
        .active-filter-chip:hover {
            filter: brightness(1.08);
        }

        /* ---- Footprint mode toggle (radio-style segmented control) ----
           Three buttons that swap the Size column between own / +unique / +all transitive
           footprint. Per guideline §14.15 the active button does NOT borrow primary-button
           colors — primary-button vocabulary is reserved for tier-1 actions (Rescan, Run).
           For a radio toggle (exactly one active), the active option gets an inactive-selection
           backdrop tint; inactive options stay transparent. The user picks out the active
           option by its subtle tinted backdrop, not by a shouting blue pill. */
        /* Segmented control sits beside the rounded-rect toolbar buttons,
           so its radius is matched (6px container + 4px segments) instead
           of the prior full-pill 999px. */
        .footprint-toggle {
            display: inline-flex; align-items: center; gap: 2px;
            padding: 2px 4px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        .footprint-toggle .toggle-label {
            font-size: 0.75em; opacity: 0.7;
            margin-inline-end: 4px;
            padding-inline-start: 4px;
            text-transform: uppercase;
            letter-spacing: 0.4px;
        }
        .toggle-btn {
            background: transparent;
            color: var(--vscode-foreground);
            border: 1px solid transparent;
            padding: 2px 10px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.85em;
            white-space: nowrap;
            opacity: 0.6;
            transition: opacity 0.12s, background 0.12s;
        }
        .toggle-btn:hover { opacity: 1; }
        .toggle-btn:focus-visible {
            outline: 1px solid var(--vscode-focusBorder);
            outline-offset: 1px;
            opacity: 1;
        }
        .toggle-btn.active {
            background: var(--vscode-list-activeSelectionBackground);
            color: var(--vscode-list-activeSelectionForeground);
            opacity: 1;
        }

        /* Size column: only the span matching the active footprint mode
           is visible. Default class is set in JS on table load. */
        .size-cell .size-own,
        .size-cell .size-unique,
        .size-cell .size-total { display: none; }
        table.fp-own .size-cell .size-own { display: inline; }
        table.fp-unique .size-cell .size-unique { display: inline; }
        table.fp-total .size-cell .size-total { display: inline; }

        /* ---- Table ---- */
        /* §4 — the wide multi-column tables cannot fit a narrow (docked) webview;
         * a scroll wrapper lets the table scroll horizontally inside its own
         * bounds instead of pushing the whole page sideways. At wide widths the
         * table fits so no scrollbar appears. These tables have no sticky thead,
         * so the overflow container does not regress a pinned header. */
        .table-scroll { max-width: 100%; overflow-x: auto; }

        /* §7 master-detail: the packages table (left, flex-grow) sits beside the
         * docked detail pane (right, fixed). The pane is hidden until a row is
         * selected, so the default view is the full-width table. min-width:0 on
         * the table column lets .table-scroll shrink inside the flex row instead
         * of forcing overflow. On a narrow webview the pane stacks below. */
        .dash-split { display: flex; gap: 16px; align-items: flex-start; }
        .dash-split > details,
        .dash-split > .packages-section { flex: 1 1 auto; min-width: 0; }
        .detail-pane {
            box-sizing: border-box;
            flex: 0 0 380px; max-width: 380px;
            position: sticky; top: 8px;
            max-height: calc(100vh - 24px); overflow: auto;
            border: 1px solid var(--vscode-widget-border); border-radius: 8px;
            padding: 12px 14px;
            background: var(--vscode-editorWidget-background);
        }
        .detail-pane[hidden] { display: none; }
        /* The row whose detail is open in the pane stays highlighted so the
         * master-detail relationship is visible while scrolling the table. */
        .pkg-row.row-selected > td {
            background: var(--vscode-list-inactiveSelectionBackground, var(--vscode-list-hoverBackground));
        }
        .detail-pane-head {
            display: flex; align-items: center; justify-content: space-between;
            margin-bottom: 10px;
        }
        .detail-pane-kicker {
            font-size: 0.72em; text-transform: uppercase; letter-spacing: 0.08em;
            color: var(--vscode-descriptionForeground);
        }
        .detail-pane-close {
            background: none; border: none; cursor: pointer; font-size: 1.2em;
            line-height: 1; color: var(--vscode-descriptionForeground);
            padding: 2px 6px; border-radius: 4px;
        }
        .detail-pane-close:hover {
            color: var(--vscode-foreground);
            background: var(--vscode-list-hoverBackground);
        }
        .detail-pane-close:focus-visible {
            outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px;
        }
        .detail-pane .pane-header {
            display: flex; gap: 12px; align-items: flex-start; margin-bottom: 12px;
        }
        .detail-pane .pane-logo {
            width: 40px; height: 40px; border-radius: 6px; object-fit: contain;
            flex-shrink: 0;
        }
        .detail-pane .pane-title { font-size: 1.15em; font-weight: 600; margin-bottom: 4px; }
        @media (max-width: 900px) {
            /* Stack on narrow webviews. align-items:stretch (not flex-start) so
             * the table column fills the viewport width and .table-scroll keeps
             * the wide table contained — flex-start would let it take its
             * content width and overflow the page. */
            .dash-split { flex-direction: column; align-items: stretch; }
            .dash-split > details,
            .dash-split > .packages-section { width: 100%; }
            .detail-pane {
                flex-basis: auto; max-width: 100%; width: 100%;
                position: static; max-height: none;
            }
        }
        table {
            width: 100%; border-collapse: collapse; margin-top: 8px;
        }
        th, td {
            text-align: left; padding: 4px 6px;
            border-bottom: 1px solid var(--vscode-widget-border);
        }
        th {
            background: var(--vscode-editor-inactiveSelectionBackground);
            /* Prevent header text wrapping when many columns are visible.
               Long labels like "Transitives" / "References" / "Published"
               otherwise stack to two lines and inflate row height. */
            white-space: nowrap;
        }
        /* Only sortable headers (with data-col) get pointer cursor. */
        th[data-col] {
            cursor: pointer; user-select: none;
        }
        th[data-col]:hover { background: var(--vscode-list-hoverBackground); }
        tr:hover { background: var(--vscode-list-hoverBackground); }
        .row-focused {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: -2px;
        }
        .sort-arrow { margin-inline-start: 4px; opacity: 0.6; }
        a {
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }

        /* ---- Right-aligned numeric cells ---- */
        /* nowrap so size/count values stay on one line in narrow viewports. */
        .cell-right { text-align: right; white-space: nowrap; }
        .deps-cell, .transitives-cell, .refs-cell { text-align: right; }

        /* ---- File usage count styling ---- */
        .file-single { color: var(--vscode-descriptionForeground); }
        .file-deep { font-weight: bold; }
        /* Tiny badge next to the References count when at least one usage
           is a re-export. Subtle — the cell is already crowded and the
           tooltip carries the explanation. */
        .ref-reexport-badge {
            color: var(--vscode-editorInfo-foreground);
            font-weight: bold;
            margin-inline-start: 2px;
        }

        /* ---- Version age suffix ---- */
        .version-age {
            color: var(--vscode-descriptionForeground);
            font-size: 0.85em;
            margin-inline-start: 2px;
        }

        /* ---- Update status colors ---- */
        .update-major { color: var(--vscode-editorError-foreground); font-weight: bold; }
        .update-minor { color: var(--vscode-editorWarning-foreground); }
        .update-patch { color: var(--vscode-editorInfo-foreground); }

        /* ---- Badges ---- */
        .badge-unused {
            background: var(--vscode-editorWarning-foreground);
            color: var(--vscode-editor-background);
            padding: 2px 6px; border-radius: 3px; font-size: 0.85em;
        }
        .badge-dev {
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            padding: 1px 5px; border-radius: 3px; font-size: 0.75em;
            margin-inline-start: 6px; vertical-align: middle;
        }
        .badge-transitive {
            background: var(--vscode-descriptionForeground);
            color: var(--vscode-editor-background);
            padding: 1px 5px; border-radius: 3px; font-size: 0.75em;
            margin-inline-start: 6px; vertical-align: middle;
        }

        /* ---- Dimmed placeholder text (dashes, hyphens) ---- */
        .dimmed { opacity: 0.35; }

        /* ---- Description text column ---- */
        .desc-text {
            max-width: 300px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            font-size: 0.85em;
            color: var(--vscode-descriptionForeground);
        }

        /* ---- Clickable package name (links to pubspec.yaml entry) ---- */
        .pkg-name-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .pkg-name-link:hover { text-decoration: underline; }

        /* ---- Clickable reference count (links to import search) ---- */
        .ref-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .ref-link:hover { text-decoration: underline; }
        .size-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .size-link:hover { text-decoration: underline; }
        .file-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .file-link:hover { text-decoration: underline; }
        .dep-list-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .dep-list-link:hover { text-decoration: underline; }
        .pkg-row.pkg-nav-focus {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: -2px;
        }
        .dep-popover {
            position: fixed;
            z-index: 1000;
            min-width: 220px;
            max-width: 420px;
            max-height: 280px;
            overflow: auto;
            padding: 8px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editorWidget-background);
            box-shadow: 0 2px 10px rgba(0,0,0,0.35);
        }
        .dep-popover-title {
            font-size: 0.8em;
            opacity: 0.75;
            margin-bottom: 6px;
            position: sticky;
            top: 0;
            background: var(--vscode-editorWidget-background);
            padding-bottom: 4px;
        }
        .dep-popover .dep-nav-link {
            display: block;
            margin: 2px 0;
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        .dep-popover .dep-nav-link:hover { text-decoration: underline; }
        .dep-popover .ref-nav-link {
            display: block;
            margin: 2px 0;
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
            font-family: monospace;
            font-size: 0.9em;
        }
        .dep-popover .ref-nav-link:hover { text-decoration: underline; }
        .network-wrap {
            margin-top: 10px;
            margin-bottom: 6px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            padding: 6px 10px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        .network-wrap summary {
            cursor: pointer;
            font-weight: 600;
        }
        /* Collapsible dashboard sections — used by Size Distribution,
           Filters, and the Packages table. <details>/<summary> primitive
           gives the disclosure triangle and toggle behavior for free; we
           only style the summary affordance and ensure the inner <h2>
           sits inline with the marker. Marker stays default-colored so
           it tracks the active theme. */
        .dashboard-collapsible {
            margin: 16px 0;
        }
        .dashboard-collapsible > summary {
            cursor: pointer;
            user-select: none;
            list-style: revert;
            padding: 4px 0;
        }
        .dashboard-collapsible > summary > h2 {
            display: inline-block;
            margin: 0;
            font-size: 1.1em;
            opacity: 0.9;
            vertical-align: middle;
        }
        .dashboard-collapsible[open] > summary {
            margin-bottom: 8px;
        }
        .network-canvas {
            /* Both axes scroll: the SVG uses natural pixel dimensions so
             * labels never get squashed by a narrow container (which is
             * what produced the previous overlapping-text corruption when
             * the panel was rendered with width: 100% + height: auto). */
            margin-top: 8px;
            overflow: auto;
            max-height: 420px;
            border-top: 1px solid var(--vscode-widget-border);
            padding-top: 8px;
        }
        .network-svg { display: block; }
        .network-edge {
            stroke: var(--vscode-widget-border);
            stroke-width: 1;
            opacity: 0.6;
            fill: none;
        }
        .network-edge-link { cursor: pointer; }
        .network-node {
            fill: var(--vscode-foreground);
            /* 12px (was 10px): the panel sat in a scrollable container at
             * natural size, so tiny labels were unnecessary — readability
             * matters more than fitting more in the viewport. */
            font-size: 12px;
            font-family: var(--vscode-font-family);
        }
        .network-node-link {
            cursor: pointer;
        }
        .network-node-link:hover,
        .network-node-link:focus {
            fill: var(--vscode-textLink-foreground);
            text-decoration: underline;
            outline: none;
        }
        .network-node-link.network-selected,
        .network-edge-link.network-selected {
            stroke: var(--vscode-textLink-foreground);
            fill: var(--vscode-textLink-foreground);
            opacity: 1;
            stroke-width: 1.6;
        }
        .network-node.direct { font-weight: 700; }
        .network-node.transitive { opacity: 0.85; }

        /* ---- Copy-row button ---- */
        .col-copy { width: 28px; padding: 6px 4px; }
        .copy-cell { text-align: center; padding: 6px 4px; width: 28px; }
        .copy-btn {
            cursor: pointer; opacity: 0; font-size: 0.9em;
            transition: opacity 0.15s;
            user-select: none;
        }
        tr:hover .copy-btn { opacity: 0.5; }
        .copy-btn:hover { opacity: 1; }
        .copy-btn.copied { color: var(--vscode-testing-iconPassed); opacity: 1; }

        /* ---- Chart filter indicator ---- */
        .chart-filter-indicator {
            padding: 4px 12px;
            background: var(--vscode-editor-inactiveSelectionBackground);
            border-radius: 4px;
            font-size: 0.85em;
            display: flex; align-items: center; gap: 8px;
            margin-top: 8px;
        }
        .clear-filter-btn {
            background: none; border: none; cursor: pointer;
            color: var(--vscode-textLink-foreground);
            font-size: 0.85em;
        }
        .clear-filter-btn:hover { text-decoration: underline; }

        @media (prefers-reduced-motion: reduce) {
            /* gauge-fill SMIL <animate> is removed at runtime by
               report-script.ts when this query matches — CSS can't disable
               SMIL, so the JS path is the only reliable kill-switch. */
            .expand-chevron { transition: none; }
            .copy-btn { transition: none; }
            .summary-card[data-filter] { transition: none; }
            .active-filter-chip { transition: none; }
            .bar-row { transition: none; }
            .search-clear { transition: none; }
            .footprint-toggle .toggle-btn { transition: none; }
        }
    `;
}
