/** CSS styles for the package detail view. */
export function getDetailStyles(): string {
    return `
:root {
    --vscode-font-family: var(--vscode-editor-font-family, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif);
    --vscode-font-size: var(--vscode-editor-font-size, 13px);
}

* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: var(--vscode-font-family);
    font-size: var(--vscode-font-size);
    color: var(--vscode-foreground);
    background: var(--vscode-sideBar-background);
    padding: 12px;
    line-height: 1.5;
}

body.placeholder {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 200px;
}

.empty-state {
    text-align: center;
    color: var(--vscode-descriptionForeground);
}

.empty-state .icon {
    font-size: 32px;
    margin-bottom: 8px;
    opacity: 0.7;
}

header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 8px;
}

h1 {
    font-size: 16px;
    font-weight: 600;
    color: var(--vscode-foreground);
    word-break: break-word;
    flex: 1;
    margin-right: 8px;
}

.score {
    font-size: 18px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 4px;
    white-space: nowrap;
}

.score.vibrant { background: var(--vscode-testing-iconPassed); color: #fff; }
.score.quiet { background: var(--vscode-editorInfo-foreground); color: #fff; }
.score.legacy-locked { background: var(--vscode-editorWarning-foreground); color: #000; }
.score.end-of-life { background: var(--vscode-editorError-foreground); color: #fff; }

.category-badge {
    display: inline-block;
    font-size: 11px;
    padding: 2px 6px;
    border-radius: 3px;
    margin-bottom: 12px;
    text-transform: uppercase;
    font-weight: 500;
}

.category-badge.vibrant { background: rgba(40, 167, 69, 0.2); color: var(--vscode-testing-iconPassed); }
.category-badge.quiet { background: rgba(23, 162, 184, 0.2); color: var(--vscode-editorInfo-foreground); }
.category-badge.legacy-locked { background: rgba(255, 193, 7, 0.2); color: var(--vscode-editorWarning-foreground); }
.category-badge.end-of-life { background: rgba(220, 53, 69, 0.2); color: var(--vscode-editorError-foreground); }

section {
    margin-bottom: 16px;
    border: 1px solid var(--vscode-widget-border, var(--vscode-editorWidget-border, #333));
    border-radius: 4px;
    overflow: hidden;
}

.section-header {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    padding: 6px 10px;
    background: var(--vscode-sideBarSectionHeader-background);
    color: var(--vscode-sideBarSectionHeader-foreground);
    cursor: pointer;
    user-select: none;
}

.section-header:hover {
    background: var(--vscode-list-hoverBackground);
}

.section-content {
    padding: 8px 10px;
    max-height: 500px;
    overflow: hidden;
    transition: max-height 0.2s ease-out, padding 0.2s ease-out;
}

section[data-expanded="false"] .section-content {
    max-height: 0;
    padding-top: 0;
    padding-bottom: 0;
}

.detail-row {
    margin-bottom: 4px;
}

.detail-row:last-child {
    margin-bottom: 0;
}

.muted {
    color: var(--vscode-descriptionForeground);
    font-size: 12px;
}

.update-header {
    font-weight: 500;
    margin-bottom: 8px;
}

.button-row {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
}

.action-btn {
    padding: 4px 10px;
    font-size: 12px;
    border: none;
    border-radius: 3px;
    cursor: pointer;
    background: var(--vscode-button-background);
    color: var(--vscode-button-foreground);
}

.action-btn:hover {
    background: var(--vscode-button-hoverBackground);
}

.action-btn.secondary {
    background: var(--vscode-button-secondaryBackground);
    color: var(--vscode-button-secondaryForeground);
}

.action-btn.secondary:hover {
    background: var(--vscode-button-secondaryHoverBackground);
}

.blocker-info {
    margin-top: 8px;
    padding: 6px 8px;
    background: rgba(255, 193, 7, 0.1);
    border-radius: 3px;
    font-size: 12px;
    color: var(--vscode-editorWarning-foreground);
}

.suggestion-text {
    margin-bottom: 6px;
    line-height: 1.4;
}

.suggestion-text:last-child {
    margin-bottom: 0;
}

.alert-item {
    margin-bottom: 6px;
    line-height: 1.4;
}

.alert-item:last-child {
    margin-bottom: 0;
}

.flagged-issue a {
    color: var(--vscode-textLink-foreground);
    text-decoration: none;
}

.flagged-issue a:hover {
    text-decoration: underline;
}

.links-section {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding-top: 8px;
    border-top: 1px solid var(--vscode-widget-border, #333);
    margin-top: 8px;
}

.link {
    color: var(--vscode-textLink-foreground);
    text-decoration: none;
    font-size: 12px;
}

.link:hover {
    text-decoration: underline;
}
`;
}
