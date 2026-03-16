import { KnownIssue } from '../types';
import { allKnownIssues } from '../scoring/known-issues';
import { getReportStyles } from './report-styles';
import { getKnownIssuesScript } from './known-issues-script';
import { escapeHtml } from './html-utils';

/** Build the full HTML for the known issues library browser. */
export function buildKnownIssuesHtml(): string {
    const issues = Array.from(allKnownIssues().values()).flat();
    const withReplacement = issues.filter(i => i.replacement).length;

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${getReportStyles()}${getExtraStyles()}</style>
</head>
<body>
    <h1>Known Issues Library</h1>
    ${buildSummaryCards(issues.length, withReplacement)}
    ${buildToolbar()}
    ${buildTable(issues)}
    <script>${getKnownIssuesScript()}</script>
</body>
</html>`;
}

function buildSummaryCards(total: number, withReplacement: number): string {
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

function buildToolbar(): string {
    return `<div class="toolbar">
        <input id="search-input" type="text"
            placeholder="Search packages..." autocomplete="off">
        <label class="filter-label">
            <input id="filter-has-replacement" type="checkbox">
            Has replacement
        </label>
    </div>`;
}

function buildTable(issues: KnownIssue[]): string {
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

function buildRow(issue: KnownIssue): string {
    const name = escapeHtml(issue.name);
    const reason = issue.reason ? escapeHtml(issue.reason) : '';
    const replacement = issue.replacement
        ? escapeHtml(issue.replacement) : '';
    const migration = issue.migrationNotes
        ? escapeHtml(issue.migrationNotes) : '';
    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(issue.name)}`;
    const replacementLink = issue.replacement
        ? formatReplacement(issue.replacement) : '';

    const searchText = [
        issue.name, issue.reason ?? '',
        issue.replacement ?? '', issue.migrationNotes ?? '',
    ].join(' ').toLowerCase();

    return `<tr data-name="${name}" data-reason="${reason}"
        data-replacement="${replacement}" data-migration="${migration}"
        data-searchtext="${escapeHtml(searchText)}">
        <td><a href="${pubUrl}">${name}</a></td>
        <td>${reason}</td>
        <td>${replacementLink}</td>
        <td>${migration}</td>
    </tr>`;
}

/** Package names are lowercase, alphanumeric, with underscores only. */
function isPackageName(text: string): boolean {
    return /^[a-z][a-z0-9_]*$/.test(text);
}

function formatReplacement(text: string): string {
    if (isPackageName(text)) {
        const url = `https://pub.dev/packages/${encodeURIComponent(text)}`;
        return `<a href="${url}">${escapeHtml(text)}</a>`;
    }
    return escapeHtml(text);
}

function getExtraStyles(): string {
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
