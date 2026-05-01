/**
 * CSS string for the **package vibrancy report** webview. Uses `var(--vscode-*)` tokens so the
 * HTML panel tracks the active theme (light/dark/high-contrast) without bundling a static palette.
 *
 * **Layout:** header with radial gauge, filter cards, dependency table, charts, and footnotes.
 * **Gauge:** SVG stroke animation relies on CSS vars set inline on the circle so the arc can
 * animate from zero to the target without fighting attribute specificity.
 * **Tables:** zebra rows, sticky headers where supported, and responsive wrapping for long package names.
 */
/** CSS for the vibrancy report webview, using VS Code theme variables. */
export function getReportStyles(): string {
    return `
        body {
            font-family: var(--vscode-font-family);
            color: var(--vscode-foreground);
            background: var(--vscode-editor-background);
            padding: 16px;
            margin: 0;
        }
        h1 { font-size: 1.4em; margin-bottom: 8px; }

        /* ---- Report header with floating gauge ---- */
        .report-header {
            display: flex; align-items: flex-start;
            justify-content: space-between;
        }
        .header-version {
            font-size: 0.55em; font-weight: normal;
            opacity: 0.5; margin-left: 8px;
            vertical-align: middle;
        }

        /* ---- Radial gauge ---- */
        .radial-gauge {
            position: relative; width: 72px; height: 72px;
            flex-shrink: 0;
        }
        .gauge-svg { width: 72px; height: 72px; }
        /* Animate the arc fill on load: start at 0, fill to target.
           The resting value uses inline CSS vars set on the <circle>
           (--gauge-target = filled length, --gauge-arc = full arc).
           Without referencing the vars here, the static rule would
           override the SVG attribute and the gauge would always read 0. */
        .gauge-fill {
            stroke-dasharray: var(--gauge-target, 0) var(--gauge-arc, 999);
            animation: gauge-fill-in 1.2s ease-out;
        }
        @keyframes gauge-fill-in {
            from { stroke-dasharray: 0 var(--gauge-arc, 999); }
            to   { stroke-dasharray: var(--gauge-target, 0) var(--gauge-arc, 999); }
        }
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

        /* ---- Letter grade badges ---- */
        .grade-badge {
            display: inline-block;
            width: 20px; height: 20px; line-height: 20px;
            text-align: center; border-radius: 4px;
            font-size: 0.75em; font-weight: bold;
            margin-right: 4px; vertical-align: middle;
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
        .detail-section h4 {
            margin: 0 0 6px; font-size: 0.85em;
            opacity: 0.8; border-bottom: 1px solid var(--vscode-widget-border);
            padding-bottom: 4px;
        }
        .detail-grid {
            display: grid; grid-template-columns: auto 1fr;
            gap: 2px 12px; font-size: 0.85em;
        }
        .detail-label { opacity: 0.6; }
        .vuln-row { font-size: 0.85em; margin: 2px 0; }
        .file-row { font-size: 0.8em; opacity: 0.8; font-family: monospace; }
        .detail-links .link-list { font-size: 0.85em; }
        .detail-search-link { cursor: pointer; font-size: 0.85em; }

        /* ---- Deps column ---- */
        .deps-icon { font-size: 0.85em; margin-right: 2px; }
        .badge-shared {
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            padding: 1px 4px; border-radius: 3px;
            font-size: 0.7em; margin-left: 4px;
            vertical-align: middle;
        }
        .badge-shared-sm {
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            padding: 0 3px; border-radius: 2px;
            font-size: 0.65em; margin-left: 3px;
        }
        .dep-cloud { font-size: 0.8em; line-height: 1.8; }
        .dep-cloud span { margin-right: 6px; }
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
        .summary-card .label { font-size: 0.85em; opacity: 0.8; min-height: 18px; }
        .summary-card[data-filter] {
            cursor: pointer; transition: box-shadow 0.2s, background 0.2s;
        }
        .summary-card[data-filter]:hover {
            box-shadow: 0 0 0 2px var(--vscode-focusBorder);
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
        .caveat { font-size: 0.8em; opacity: 0.6; margin-top: 4px; }

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
            right: 4px;
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
        /* Pill shape (border-radius 999px) shared with the canonical
         * .saropa-pill-button helper in pill-button-styles.ts. Tokens are
         * already secondary-button pair; the shape change makes this
         * panel's toolbar visually consistent with every other Saropa
         * dashboard. New primary CTAs should use the explicit
         * .saropa-pill-button + .saropa-pill-button-icon markup for the
         * chip-with-icon-circle look. */
        .toolbar-btn {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
            border: 1px solid var(--vscode-button-border, transparent);
            padding: 6px 12px;
            border-radius: 999px;
            cursor: pointer;
            font-size: 0.85em;
            transition: background 0.12s ease, border-color 0.12s ease;
        }
        .toolbar-btn:hover {
            background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
            border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, var(--vscode-button-border, transparent));
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
        .age-filter {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 0.8em;
            padding-right: 6px;
            border-right: 1px solid var(--vscode-widget-border);
        }
        .age-filter input[type="range"] { width: 120px; }
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

        /* ---- Footprint mode toggle ---- */
        /* Three buttons that swap the Size column between own / +unique /
           +all transitive footprint. Active button gets a brighter bg. */
        .footprint-toggle {
            display: inline-flex; align-items: center; gap: 4px;
            padding: 2px 6px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 3px;
        }
        .footprint-toggle .toggle-label {
            font-size: 0.75em; opacity: 0.7;
            margin-right: 2px;
        }
        .toggle-btn {
            background: transparent;
            color: var(--vscode-foreground);
            border: 1px solid transparent;
            padding: 2px 8px;
            border-radius: 2px;
            cursor: pointer;
            font-size: 0.8em;
            white-space: nowrap;
        }
        .toggle-btn:hover {
            background: var(--vscode-list-hoverBackground);
        }
        .toggle-btn.active {
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
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
        .sort-arrow { margin-left: 4px; opacity: 0.6; }
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
            margin-left: 2px;
        }

        /* ---- Version age suffix ---- */
        .version-age {
            color: var(--vscode-descriptionForeground);
            font-size: 0.85em;
            margin-left: 2px;
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
            margin-left: 6px; vertical-align: middle;
        }
        .badge-transitive {
            background: var(--vscode-descriptionForeground);
            color: var(--vscode-editor-background);
            padding: 1px 5px; border-radius: 3px; font-size: 0.75em;
            margin-left: 6px; vertical-align: middle;
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
        .network-canvas {
            margin-top: 8px;
            overflow: auto;
            max-height: 320px;
            border-top: 1px solid var(--vscode-widget-border);
            padding-top: 8px;
        }
        .network-svg { width: 100%; height: auto; }
        .network-edge {
            stroke: var(--vscode-widget-border);
            stroke-width: 1;
            opacity: 0.8;
        }
        .network-edge-link { cursor: pointer; }
        .network-node {
            fill: var(--vscode-foreground);
            font-size: 10px;
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
            .gauge-fill { animation: none !important;
                stroke-dasharray: var(--gauge-target, 0) var(--gauge-arc, 999) !important; }
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
