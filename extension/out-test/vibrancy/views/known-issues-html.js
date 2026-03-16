"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildKnownIssuesHtml = buildKnownIssuesHtml;
const known_issues_1 = require("../scoring/known-issues");
const report_styles_1 = require("./report-styles");
const known_issues_script_1 = require("./known-issues-script");
const html_utils_1 = require("./html-utils");
/** Build the full HTML for the known issues library browser. */
function buildKnownIssuesHtml() {
    const issues = Array.from((0, known_issues_1.allKnownIssues)().values()).flat();
    const withReplacement = issues.filter(i => i.replacement).length;
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${(0, report_styles_1.getReportStyles)()}${getExtraStyles()}</style>
</head>
<body>
    <h1>Known Issues Library</h1>
    ${buildSummaryCards(issues.length, withReplacement)}
    ${buildToolbar()}
    ${buildTable(issues)}
    <script>${(0, known_issues_script_1.getKnownIssuesScript)()}</script>
</body>
</html>`;
}
function buildSummaryCards(total, withReplacement) {
    return `<div class="summary">
        <div class="summary-card">
            <div class="count" id="visible-count">${total}</div>
            <div class="label">Showing</div>
        </div>
        <div class="summary-card eol">
            <div class="count">${total}</div>
            <div class="label">Total</div>
        </div>
        <div class="summary-card vibrant">
            <div class="count">${withReplacement}</div>
            <div class="label">Has Replacement</div>
        </div>
        <div class="summary-card legacy">
            <div class="count">${total - withReplacement}</div>
            <div class="label">No Replacement</div>
        </div>
    </div>`;
}
function buildToolbar() {
    return `<div class="toolbar">
        <input id="search-input" type="text"
            placeholder="Search packages..." autocomplete="off">
        <label class="filter-label">
            <input id="filter-has-replacement" type="checkbox">
            Has replacement
        </label>
    </div>`;
}
function buildTable(issues) {
    return `<table>
        <thead><tr>
            <th data-col="name">Package<span class="sort-arrow"></span></th>
            <th data-col="reason">Reason<span class="sort-arrow"></span></th>
            <th data-col="replacement">Replacement<span class="sort-arrow"></span></th>
            <th data-col="migration">Migration<span class="sort-arrow"></span></th>
        </tr></thead>
        <tbody id="pkg-body">
            ${issues.map(buildRow).join('\n')}
        </tbody>
    </table>`;
}
function buildRow(issue) {
    const name = (0, html_utils_1.escapeHtml)(issue.name);
    const reason = issue.reason ? (0, html_utils_1.escapeHtml)(issue.reason) : '';
    const replacement = issue.replacement
        ? (0, html_utils_1.escapeHtml)(issue.replacement) : '';
    const migration = issue.migrationNotes
        ? (0, html_utils_1.escapeHtml)(issue.migrationNotes) : '';
    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(issue.name)}`;
    const replacementLink = issue.replacement
        ? formatReplacement(issue.replacement) : '';
    const searchText = [
        issue.name, issue.reason ?? '',
        issue.replacement ?? '', issue.migrationNotes ?? '',
    ].join(' ').toLowerCase();
    return `<tr data-name="${name}" data-reason="${reason}"
        data-replacement="${replacement}" data-migration="${migration}"
        data-searchtext="${(0, html_utils_1.escapeHtml)(searchText)}">
        <td><a href="${pubUrl}">${name}</a></td>
        <td>${reason}</td>
        <td>${replacementLink}</td>
        <td>${migration}</td>
    </tr>`;
}
/** Package names are lowercase, alphanumeric, with underscores only. */
function isPackageName(text) {
    return /^[a-z][a-z0-9_]*$/.test(text);
}
function formatReplacement(text) {
    if (isPackageName(text)) {
        const url = `https://pub.dev/packages/${encodeURIComponent(text)}`;
        return `<a href="${url}">${(0, html_utils_1.escapeHtml)(text)}</a>`;
    }
    return (0, html_utils_1.escapeHtml)(text);
}
function getExtraStyles() {
    return `
        .toolbar {
            display: flex; gap: 16px; align-items: center;
            margin-bottom: 12px;
        }
        #search-input {
            flex: 1; max-width: 400px; padding: 6px 10px;
            font-size: 0.95em;
            color: var(--vscode-input-foreground);
            background: var(--vscode-input-background);
            border: 1px solid var(--vscode-input-border);
            border-radius: 4px; outline: none;
        }
        #search-input:focus {
            border-color: var(--vscode-focusBorder);
        }
        .filter-label {
            font-size: 0.9em; cursor: pointer;
            display: flex; align-items: center; gap: 4px;
        }
    `;
}
//# sourceMappingURL=known-issues-html.js.map