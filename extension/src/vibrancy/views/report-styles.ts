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
        .vibrant .count { color: var(--vscode-testing-iconPassed); }
        .quiet .count { color: var(--vscode-editorInfo-foreground); }
        .legacy .count { color: var(--vscode-editorWarning-foreground); }
        .eol .count { color: var(--vscode-editorError-foreground); }
        table {
            width: 100%; border-collapse: collapse; margin-top: 8px;
        }
        th, td {
            text-align: left; padding: 6px 10px;
            border-bottom: 1px solid var(--vscode-widget-border);
        }
        th {
            cursor: pointer; user-select: none;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        th:hover { background: var(--vscode-list-hoverBackground); }
        tr:hover { background: var(--vscode-list-hoverBackground); }
        .sort-arrow { margin-left: 4px; opacity: 0.6; }
        a {
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }
        .update-major { color: var(--vscode-editorError-foreground); font-weight: bold; }
        .update-minor { color: var(--vscode-editorWarning-foreground); }
        .update-patch { color: var(--vscode-editorInfo-foreground); }
        .updates .count { color: var(--vscode-textLink-foreground); }
        .unused .count { color: var(--vscode-editorWarning-foreground); }
        .badge-unused {
            background: var(--vscode-editorWarning-foreground);
            color: var(--vscode-editor-background);
            padding: 2px 6px; border-radius: 3px; font-size: 0.85em;
        }
        .caveat { font-size: 0.8em; opacity: 0.6; margin-top: 4px; }
    `;
}
