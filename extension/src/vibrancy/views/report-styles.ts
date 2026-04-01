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
        .summary-card .label { font-size: 0.85em; opacity: 0.8; }
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
        .quiet .count { color: var(--vscode-editorInfo-foreground); }
        .legacy .count { color: var(--vscode-editorWarning-foreground); }
        .stale .count { color: var(--vscode-editorWarning-foreground); }
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
        }
        .search-input {
            padding: 4px 8px;
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
        .toolbar-btn {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
            border: none;
            padding: 4px 10px;
            border-radius: 3px;
            cursor: pointer;
            font-size: 0.85em;
        }
        .toolbar-btn:hover {
            background: var(--vscode-button-secondaryHoverBackground);
        }

        /* ---- Table ---- */
        table {
            width: 100%; border-collapse: collapse; margin-top: 8px;
        }
        th, td {
            text-align: left; padding: 6px 10px;
            border-bottom: 1px solid var(--vscode-widget-border);
        }
        th {
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        /* Only sortable headers (with data-col) get pointer cursor. */
        th[data-col] {
            cursor: pointer; user-select: none;
        }
        th[data-col]:hover { background: var(--vscode-list-hoverBackground); }
        tr:hover { background: var(--vscode-list-hoverBackground); }
        .sort-arrow { margin-left: 4px; opacity: 0.6; }
        a {
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }

        /* ---- Right-aligned numeric cells ---- */
        .cell-right { text-align: right; }

        /* ---- File usage count styling ---- */
        .file-single { color: var(--vscode-descriptionForeground); }
        .file-deep { font-weight: bold; }

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

        /* ---- Description + info icons ---- */
        .col-icon { width: 28px; text-align: center; padding: 6px 4px; }
        .desc-icon { cursor: help; opacity: 0.6; }
        .desc-icon:hover { opacity: 1; }
        .info-icon {
            cursor: help; opacity: 0.5; font-size: 0.85em; margin-left: 4px;
        }
        .info-icon:hover { opacity: 1; }

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
    `;
}
