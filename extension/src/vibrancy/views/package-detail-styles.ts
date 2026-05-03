/**
 * CSS for the **single-package detail** webview (version gap, trust, license, links, review notes).
 * Typography mirrors the editor; spacing is tuned for narrow sidebar widths as well as full editor columns.
 *
 * **Components:** action links (command bridge), section headers, tables for transitive issues,
 * and muted helper text for empty states. Hover/focus states use theme link colors for accessibility.
 */
/** CSS styles for the package detail webview panel. */
export function getPackageDetailStyles(): string {
    return `
        * { box-sizing: border-box; margin: 0; padding: 0; }

        /* §4 — page padding + max-width matched to the chrome's gold-standard
           (~1280px). The full-width toggle in the hero (§4) flips
           body[data-full-width="true"] which the chrome already styles to
           drop the cap; this rule sets the cap that toggle reverses. */
        body {
            font-family: var(--vscode-font-family);
            font-size: var(--vscode-font-size, var(--vscode-editor-font-size, 13px));
            color: var(--vscode-foreground);
            background: var(--vscode-editor-background);
            padding: 16px 24px;
            margin: 0 auto;
            max-width: 1280px;
            line-height: 1.5;
        }
        body[data-full-width="true"] { max-width: none; }

        a {
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }

        /* §8.2 — distinguish external URLs from in-panel file-open actions.
           External links (data-action="openUrl") follow the gold-standard
           "no underline default, underline on hover" pattern. In-panel
           file-open links (data-action="openFile") keep the underline
           always so they read clearly as navigation targets inside the
           same surface. */
        .action-link {
            cursor: pointer;
        }
        a[data-action="openUrl"] { text-decoration: none; }
        a[data-action="openUrl"]:hover {
            color: var(--vscode-textLink-activeForeground);
            text-decoration: underline;
        }
        a[data-action="openFile"] { text-decoration: underline; }
        a[data-action="openFile"]:hover {
            color: var(--vscode-textLink-activeForeground);
        }

        h1 {
            font-size: 1.4em;
            margin-bottom: 4px;
            font-weight: 600;
        }

        .header {
            display: flex;
            align-items: baseline;
            gap: 12px;
            flex-wrap: wrap;
            margin-bottom: 16px;
            padding-bottom: 12px;
            border-bottom: 1px solid var(--vscode-widget-border);
        }

        .header-meta {
            display: flex;
            gap: 8px;
            align-items: center;
            font-size: 0.9em;
            color: var(--vscode-descriptionForeground);
        }

        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: 600;
        }

        .badge-vibrant { background: var(--vscode-testing-iconPassed); color: #fff; }
        .badge-quiet { background: var(--vscode-editorInfo-foreground); color: #fff; }
        .badge-legacy { background: var(--vscode-editorWarning-foreground); color: #000; }
        .badge-stale { background: var(--vscode-editorWarning-foreground); color: #fff; }
        .badge-eol { background: var(--vscode-editorError-foreground); color: #fff; }

        /* §7.2 / §14.6 — sections render as inset detail cards with a
           secondary background tone so the page reads as layered surfaces
           (page → card → header) rather than a flat sequence of text bands
           sharing the page background. */
        .section {
            margin-bottom: 16px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            overflow: hidden;
            background: var(--vscode-editorWidget-background);
        }

        .section-header {
            background: var(--vscode-sideBarSectionHeader-background);
            padding: 8px 12px;
            font-weight: 600;
            font-size: 0.95em;
            cursor: pointer;
            user-select: none;
        }
        .section-header:hover {
            background: var(--vscode-list-hoverBackground);
        }

        .section-body {
            padding: 10px 12px;
        }

        .section.collapsed .section-body { display: none; }

        .metrics-table {
            width: 100%;
            border-collapse: collapse;
        }
        .metrics-table td {
            padding: 4px 8px;
            border-bottom: 1px solid var(--vscode-widget-border);
        }
        .metrics-table td:first-child {
            color: var(--vscode-descriptionForeground);
            width: 40%;
            white-space: nowrap;
        }

        /* Pill shape (border-radius 999px) shared with the canonical
         * .saropa-pill-button helper in pill-button-styles.ts. Removed the
         * hard-coded dark-only fallbacks (#fff, #ccc, #3a3d41) — those broke
         * in light + high-contrast themes. The button-{,secondary} token pairs
         * are spec-guaranteed to contrast in any theme; the dark hex defaults
         * were paper over a problem that does not exist with proper tokens. */
        .action-btn {
            display: inline-flex;
            align-items: center;
            padding: 6px 12px;
            border-radius: 999px;
            border: 1px solid var(--vscode-button-border, transparent);
            cursor: pointer;
            font-size: 0.9em;
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
            margin-inline-end: 8px;
            margin-top: 6px;
            transition: background 0.12s ease, border-color 0.12s ease;
        }
        .action-btn:hover {
            background: var(--vscode-button-hoverBackground, var(--vscode-button-background));
        }
        .action-btn:focus-visible {
            outline: 1px solid var(--vscode-focusBorder);
            outline-offset: 2px;
        }
        .action-btn.secondary {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
        }
        .action-btn.secondary:hover {
            background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
        }

        /* Version-gap section */
        .gap-summary {
            display: flex;
            gap: 16px;
            margin-bottom: 12px;
            flex-wrap: wrap;
        }
        .gap-card {
            padding: 8px 16px;
            border-radius: 4px;
            background: var(--vscode-sideBarSectionHeader-background);
            text-align: center;
        }
        /* §4.2 — hero numbers are the largest typographic element after the
           page title; bump from 1.5em to 1.8em so the count reads as a KPI,
           not body text. */
        .gap-card .count {
            font-size: 1.8em;
            font-weight: 700;
        }
        .gap-card .label {
            font-size: 0.9em;
            color: var(--vscode-descriptionForeground);
        }

        .gap-toolbar {
            display: flex;
            gap: 12px;
            align-items: center;
            margin-bottom: 10px;
            flex-wrap: wrap;
        }
        .gap-toolbar input[type="text"] {
            flex: 1;
            max-width: 300px;
            padding: 4px 8px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 4px;
            background: var(--vscode-input-background);
            color: var(--vscode-input-foreground);
            font-size: 0.9em;
        }
        .gap-toolbar input:focus {
            outline: none;
            border-color: var(--vscode-focusBorder);
        }
        /* §4.3 — radio-style segmented control band. The .seg wrapper groups
           the four filter buttons so they read as a single control surface,
           matching the chrome's segmented pattern used elsewhere. */
        .gap-toolbar .seg {
            display: inline-flex;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            overflow: hidden;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        .gap-toolbar .filter-btn {
            padding: 4px 12px;
            border: 0;
            background: transparent;
            color: var(--vscode-foreground);
            cursor: pointer;
            font-size: 0.85em;
            opacity: 0.7;
        }
        .gap-toolbar .filter-btn:hover { opacity: 1; }
        /* §14.15 — radio active state uses inactive-selection backdrop, NOT
           the primary-button color. Primary-button vocabulary is reserved
           for tier-1 actions (*Upgrade*); a filter selection is the resting
           state, so it must read quietly. */
        .gap-toolbar .filter-btn.active {
            background: var(--vscode-list-activeSelectionBackground);
            color: var(--vscode-list-activeSelectionForeground);
            opacity: 1;
            font-weight: 600;
        }

        .gap-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9em;
        }
        .gap-table th {
            text-align: left;
            padding: 6px 8px;
            border-bottom: 2px solid var(--vscode-widget-border);
            color: var(--vscode-descriptionForeground);
            font-weight: 600;
            cursor: pointer;
            user-select: none;
            white-space: nowrap;
        }
        .gap-table th:hover {
            color: var(--vscode-foreground);
        }
        .gap-table td {
            padding: 6px 8px;
            border-bottom: 1px solid var(--vscode-widget-border);
            vertical-align: top;
        }
        .gap-table tr:hover {
            background: var(--vscode-list-hoverBackground);
        }

        .type-pr { color: var(--vscode-testing-iconPassed); }
        .type-issue { color: var(--vscode-editorInfo-foreground); }

        .review-select {
            padding: 2px 4px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 3px;
            background: var(--vscode-input-background);
            color: var(--vscode-input-foreground);
            font-size: 0.85em;
        }

        .review-applicable { color: var(--vscode-testing-iconPassed); font-weight: 600; }
        .review-not-applicable { color: var(--vscode-descriptionForeground); }
        .review-reviewed { color: var(--vscode-editorInfo-foreground); }

        .notes-input {
            width: 100%;
            padding: 3px 6px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 3px;
            background: var(--vscode-input-background);
            color: var(--vscode-input-foreground);
            font-size: 0.85em;
            margin-top: 4px;
        }
        .notes-input:focus {
            outline: none;
            border-color: var(--vscode-focusBorder);
        }

        .gap-footer {
            margin-top: 10px;
            padding: 6px 0;
            font-size: 0.85em;
            color: var(--vscode-descriptionForeground);
        }

        .loading-spinner {
            text-align: center;
            padding: 24px;
            color: var(--vscode-descriptionForeground);
        }

        .links-row {
            display: flex;
            gap: 12px;
            margin-top: 16px;
            padding-top: 12px;
            border-top: 1px solid var(--vscode-widget-border);
        }

        .alert-item {
            padding: 6px 8px;
            margin-bottom: 6px;
            border-radius: 4px;
            border-inline-start: 3px solid var(--vscode-editorWarning-foreground);
        }
        .alert-item.critical {
            border-inline-start-color: var(--vscode-editorError-foreground);
        }
        .alert-item.info {
            border-inline-start-color: var(--vscode-editorInfo-foreground);
        }

        .vuln-severity-critical { color: var(--vscode-editorError-foreground); font-weight: 700; }
        .vuln-severity-high { color: var(--vscode-editorError-foreground); font-weight: 600; }
        .vuln-severity-medium { color: var(--vscode-editorWarning-foreground); }
        .vuln-severity-low { color: var(--vscode-descriptionForeground); }

        /* ---- File usages section ---- */
        .file-usage-item {
            padding: 3px 8px;
            font-family: var(--vscode-editor-font-family, monospace);
            font-size: 0.9em;
        }
        .file-usage-item.commented {
            color: var(--vscode-descriptionForeground);
            font-style: italic;
        }
        .file-usage-commented {
            padding: 6px 8px 2px;
            font-size: 0.92em;
            color: var(--vscode-descriptionForeground);
        }
        /* Re-export badge — small inline pill to flag public-API surface
           usages without overwhelming the file path link visually. */
        .file-usage-reexport {
            display: inline-block;
            padding: 0 4px;
            margin-inline-start: 6px;
            border-radius: 2px;
            font-size: 0.75em;
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            vertical-align: middle;
        }
        .reexport-note {
            font-size: 0.9em;
            color: var(--vscode-descriptionForeground);
            font-weight: normal;
        }

        /* ---- Description section ---- */
        .description-text {
            padding: 8px 12px;
            font-size: 0.95em;
            color: var(--vscode-foreground);
            line-height: 1.6;
        }

        /* ---- Topics section ---- */
        .topics-row {
            padding: 8px 12px;
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
        }
        .topic-badge {
            display: inline-block;
            padding: 2px 10px;
            border-radius: 12px;
            background: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
            font-size: 0.8em;
            text-decoration: none;
            cursor: pointer;
        }
        .topic-badge:hover {
            opacity: 0.85;
            text-decoration: none;
        }

        /* ---- Dependencies section ---- */
        .dep-list {
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
        }
        .dep-chip {
            display: inline-block;
            padding: 2px 10px;
            border-radius: 12px;
            border: 1px solid var(--vscode-widget-border);
            background: var(--vscode-sideBarSectionHeader-background);
            color: var(--vscode-foreground);
            font-size: 0.8em;
            text-decoration: none;
            cursor: pointer;
        }
        .dep-chip:hover {
            background: var(--vscode-list-hoverBackground);
            text-decoration: none;
        }

        /* ---- Package logo in header ---- */
        .package-logo {
            width: 48px;
            height: 48px;
            object-fit: contain;
            border-radius: 6px;
            margin-inline-end: 12px;
            vertical-align: middle;
        }

        /* ---- README image gallery ---- */
        .image-gallery {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
        }
        .image-gallery img {
            max-width: 200px;
            max-height: 150px;
            object-fit: contain;
            border-radius: 4px;
            border: 1px solid var(--vscode-widget-border);
            cursor: pointer;
        }
        .image-gallery img:hover {
            border-color: var(--vscode-focusBorder);
        }
    `;
}
