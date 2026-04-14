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
.score.stable { background: var(--vscode-editorInfo-foreground); color: #fff; }
.score.outdated { background: var(--vscode-editorWarning-foreground); color: #000; }
.score.abandoned { background: var(--vscode-editorWarning-foreground); color: #000; }
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
.category-badge.stable { background: rgba(23, 162, 184, 0.2); color: var(--vscode-editorInfo-foreground); }
.category-badge.outdated { background: rgba(255, 193, 7, 0.2); color: var(--vscode-editorWarning-foreground); }
.category-badge.abandoned { background: rgba(255, 193, 7, 0.2); color: var(--vscode-editorWarning-foreground); }
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

/* Used by archived-repo row in detail view */
.warning {
    color: var(--vscode-editorWarning-foreground);
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

/* Unique vs shared dependency bar — shows proportion of transitives that
   are already in the project via other direct deps (shared = no added cost). */
.dep-bar {
    display: flex;
    height: 8px;
    border-radius: 4px;
    overflow: hidden;
    margin: 6px 0;
}

.dep-bar-unique {
    background: var(--vscode-editorWarning-foreground);
}

.dep-bar-shared {
    background: var(--vscode-testing-iconPassed);
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
    text-decoration: underline;
    font-size: 12px;
    cursor: pointer;
}

.link:hover {
    color: var(--vscode-textLink-activeForeground, var(--vscode-textLink-foreground));
}

/* ---- Sidebar logo in header ---- */
.sidebar-logo {
    width: 32px;
    height: 32px;
    object-fit: contain;
    border-radius: 4px;
    margin-right: 8px;
    flex-shrink: 0;
}

/* ---- Sidebar description ---- */
.sidebar-description {
    font-size: 12px;
    color: var(--vscode-descriptionForeground);
    margin-bottom: 10px;
    line-height: 1.4;
}

/* ---- Sidebar topic badges ---- */
.sidebar-topics {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-bottom: 12px;
}

.sidebar-topic {
    display: inline-block;
    padding: 1px 8px;
    border-radius: 10px;
    background: var(--vscode-badge-background, #4d4d4d);
    color: var(--vscode-badge-foreground, #fff);
    font-size: 10px;
    text-decoration: none;
    cursor: pointer;
}

.sidebar-topic:hover {
    opacity: 0.85;
}

/* ---- Sidebar direct dependency chips ---- */
.sidebar-dep-list {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
}

.sidebar-dep-chip {
    display: inline-block;
    padding: 1px 8px;
    border-radius: 10px;
    border: 1px solid var(--vscode-widget-border, #333);
    color: var(--vscode-foreground);
    font-size: 10px;
    text-decoration: none;
    cursor: pointer;
}

.sidebar-dep-chip:hover {
    background: var(--vscode-list-hoverBackground, #2a2d2e);
}

/* ---- Sidebar image gallery ---- */
.sidebar-gallery {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
}

.sidebar-gallery img {
    max-width: 120px;
    max-height: 90px;
    object-fit: contain;
    border-radius: 3px;
    border: 1px solid var(--vscode-widget-border, #333);
    cursor: pointer;
}

.sidebar-gallery img:hover {
    border-color: var(--vscode-focusBorder, #007acc);
}
`;
}
