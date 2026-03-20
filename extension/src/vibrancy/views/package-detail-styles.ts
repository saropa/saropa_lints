/** CSS styles for the package detail webview panel. */
export function getPackageDetailStyles(): string {
    return `
        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: var(--vscode-editor-font-family, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif);
            font-size: var(--vscode-editor-font-size, 13px);
            color: var(--vscode-foreground);
            background: var(--vscode-editor-background);
            padding: 16px 24px;
            line-height: 1.5;
        }

        a {
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }

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
            border-bottom: 1px solid var(--vscode-widget-border, #333);
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

        .badge-vibrant { background: var(--vscode-testing-iconPassed, #388e3c); color: #fff; }
        .badge-quiet { background: var(--vscode-editorInfo-foreground, #1976d2); color: #fff; }
        .badge-legacy { background: var(--vscode-editorWarning-foreground, #f9a825); color: #000; }
        .badge-stale { background: var(--vscode-editorWarning-foreground, #e65100); color: #fff; }
        .badge-eol { background: var(--vscode-editorError-foreground, #d32f2f); color: #fff; }

        .section {
            margin-bottom: 16px;
            border: 1px solid var(--vscode-widget-border, #333);
            border-radius: 4px;
            overflow: hidden;
        }

        .section-header {
            background: var(--vscode-sideBarSectionHeader-background, #252526);
            padding: 8px 12px;
            font-weight: 600;
            font-size: 0.95em;
            cursor: pointer;
            user-select: none;
        }
        .section-header:hover {
            background: var(--vscode-list-hoverBackground, #2a2d2e);
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
            border-bottom: 1px solid var(--vscode-widget-border, #333);
        }
        .metrics-table td:first-child {
            color: var(--vscode-descriptionForeground);
            width: 40%;
            white-space: nowrap;
        }

        .action-btn {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 4px;
            border: none;
            cursor: pointer;
            font-size: 0.9em;
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground, #fff);
            margin-right: 8px;
            margin-top: 6px;
        }
        .action-btn:hover {
            background: var(--vscode-button-hoverBackground);
        }
        .action-btn.secondary {
            background: var(--vscode-button-secondaryBackground, #3a3d41);
            color: var(--vscode-button-secondaryForeground, #ccc);
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
            background: var(--vscode-sideBarSectionHeader-background, #252526);
            text-align: center;
        }
        .gap-card .count {
            font-size: 1.5em;
            font-weight: 700;
        }
        .gap-card .label {
            font-size: 0.8em;
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
            border: 1px solid var(--vscode-widget-border, #333);
            border-radius: 4px;
            background: var(--vscode-input-background, #1e1e1e);
            color: var(--vscode-input-foreground, #ccc);
            font-size: 0.9em;
        }
        .gap-toolbar input:focus {
            outline: none;
            border-color: var(--vscode-focusBorder, #007acc);
        }
        .gap-toolbar .filter-btn {
            padding: 3px 10px;
            border: 1px solid var(--vscode-widget-border, #333);
            border-radius: 4px;
            background: transparent;
            color: var(--vscode-foreground);
            cursor: pointer;
            font-size: 0.85em;
        }
        .gap-toolbar .filter-btn.active {
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground, #fff);
            border-color: var(--vscode-button-background);
        }

        .gap-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9em;
        }
        .gap-table th {
            text-align: left;
            padding: 6px 8px;
            border-bottom: 2px solid var(--vscode-widget-border, #333);
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
            border-bottom: 1px solid var(--vscode-widget-border, #333);
            vertical-align: top;
        }
        .gap-table tr:hover {
            background: var(--vscode-list-hoverBackground, #2a2d2e);
        }

        .type-pr { color: var(--vscode-testing-iconPassed, #388e3c); }
        .type-issue { color: var(--vscode-editorInfo-foreground, #1976d2); }

        .review-select {
            padding: 2px 4px;
            border: 1px solid var(--vscode-widget-border, #333);
            border-radius: 3px;
            background: var(--vscode-input-background, #1e1e1e);
            color: var(--vscode-input-foreground, #ccc);
            font-size: 0.85em;
        }

        .review-applicable { color: var(--vscode-testing-iconPassed, #388e3c); font-weight: 600; }
        .review-not-applicable { color: var(--vscode-descriptionForeground); }
        .review-reviewed { color: var(--vscode-editorInfo-foreground, #1976d2); }

        .notes-input {
            width: 100%;
            padding: 3px 6px;
            border: 1px solid var(--vscode-widget-border, #333);
            border-radius: 3px;
            background: var(--vscode-input-background, #1e1e1e);
            color: var(--vscode-input-foreground, #ccc);
            font-size: 0.85em;
            margin-top: 4px;
        }
        .notes-input:focus {
            outline: none;
            border-color: var(--vscode-focusBorder, #007acc);
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
            border-top: 1px solid var(--vscode-widget-border, #333);
        }

        .alert-item {
            padding: 6px 8px;
            margin-bottom: 6px;
            border-radius: 4px;
            border-left: 3px solid var(--vscode-editorWarning-foreground, #e65100);
        }
        .alert-item.critical {
            border-left-color: var(--vscode-editorError-foreground, #d32f2f);
        }
        .alert-item.info {
            border-left-color: var(--vscode-editorInfo-foreground, #1976d2);
        }

        .vuln-severity-critical { color: var(--vscode-editorError-foreground, #d32f2f); font-weight: 700; }
        .vuln-severity-high { color: var(--vscode-editorError-foreground, #e65100); font-weight: 600; }
        .vuln-severity-medium { color: var(--vscode-editorWarning-foreground, #f9a825); }
        .vuln-severity-low { color: var(--vscode-descriptionForeground); }
    `;
}
