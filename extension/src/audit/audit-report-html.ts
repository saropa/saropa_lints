/**
 * HTML generator for the audit report webview.
 *
 * Builds a self-contained HTML document with:
 * - Summary header (total count, per-tier breakdown, per-severity breakdown)
 * - Filter chip bars for tier, severity, and impact
 * - Text search box with debounced filtering
 * - Sortable diagnostic table grouped by file or flat
 * - "Copy JSON" export button
 *
 * All strings are externalized via l10n() under the `audit.report` namespace.
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';

/** A single diagnostic from the audit JSON payload. */
interface AuditDiagnostic {
  filePath: string;
  line: number;
  column: number;
  ruleName: string;
  severity: string;
  impact: string | null;
  tier: string | null;
  problemMessage: string | null;
  correctionMessage: string | null;
  /** Present only when --baseline was used: 'new', 'unchanged', or 'resolved'. */
  baselineStatus: string | null;
}

/** Builds the complete HTML string for the audit report webview. */
export function buildAuditReportHtml(
  auditJson: Record<string, unknown>,
  _webview: vscode.Webview,
  root: string,
): string {
  const diagnostics = (auditJson['diagnostics'] ?? []) as AuditDiagnostic[];
  const timestamp = (auditJson['timestamp'] as string) ?? '';
  const summary = auditJson['summary'] as Record<string, unknown> | undefined;
  const totalCount = (summary?.['totalCount'] as number) ?? diagnostics.length;
  const baseline = auditJson['baseline'] as Record<string, unknown> | undefined;
  const hasBaseline = baseline !== undefined;

  // Tier breakdown for the summary header.
  const tierCounts = countBy(diagnostics, (d) => d.tier ?? 'unknown');
  const severityCounts = countBy(diagnostics, (d) => d.severity);
  const impactCounts = countBy(diagnostics, (d) => d.impact ?? 'unknown');

  // Collect unique values for filter chips.
  const tiers = uniqueSorted(diagnostics, (d) => d.tier ?? 'unknown');
  const severities = uniqueSorted(diagnostics, (d) => d.severity);
  const impacts = uniqueSorted(diagnostics, (d) => d.impact ?? 'unknown');

  return /* html */ `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escHtml(l10n('audit.report.title'))}</title>
  ${buildStyles()}
</head>
<body>
  <!-- Summary header -->
  <header class="audit-header">
    <h1>${escHtml(l10n('audit.report.heading'))}</h1>
    <p class="audit-subtitle">
      ${escHtml(l10n('audit.report.subtitle', { count: String(totalCount), timestamp }))}
      ${hasBaseline ? `<br/><span class="audit-baseline-tag">${escHtml(l10n('audit.report.baselineSubtitle', { date: String(baseline?.['comparedTo'] ?? '') }))}</span>` : ''}
    </p>
    <div class="audit-kpi-strip">
      ${buildKpiStrip(tierCounts, severityCounts)}
    </div>
  </header>

  <!-- Controls: search + filters + actions -->
  <div class="audit-controls">
    <input
      type="text"
      id="audit-search"
      class="audit-search"
      placeholder="${escAttr(l10n('audit.report.searchPlaceholder'))}"
    />
    <div class="audit-filters">
      <div class="audit-filter-group">
        <span class="audit-filter-label">${escHtml(l10n('audit.report.filterTier'))}</span>
        ${buildFilterChips('tier', tiers, tierCounts)}
      </div>
      <div class="audit-filter-group">
        <span class="audit-filter-label">${escHtml(l10n('audit.report.filterSeverity'))}</span>
        ${buildFilterChips('severity', severities, severityCounts)}
      </div>
      <div class="audit-filter-group">
        <span class="audit-filter-label">${escHtml(l10n('audit.report.filterImpact'))}</span>
        ${buildFilterChips('impact', impacts, impactCounts)}
      </div>
    </div>
    ${hasBaseline ? `<div class="audit-filter-group">
        <span class="audit-filter-label">${escHtml(l10n('audit.report.filterBaselineStatus'))}</span>
        <button class="audit-chip audit-chip-active audit-baseline-new" data-dim="baselineStatus" data-val="new">${escHtml(l10n('audit.report.baselineNew'))} <span class="audit-chip-count">(${baseline?.['new'] ?? 0})</span></button>
        <button class="audit-chip audit-chip-active" data-dim="baselineStatus" data-val="unchanged">${escHtml(l10n('audit.report.baselineUnchanged'))} <span class="audit-chip-count">(${baseline?.['unchanged'] ?? 0})</span></button>
      </div>` : ''}
    <div class="audit-actions">
      <button id="audit-save-baseline" class="audit-btn">${escHtml(l10n('audit.report.saveBaseline'))}</button>
      <button id="audit-copy-json" class="audit-btn">${escHtml(l10n('audit.report.copyJson'))}</button>
      <button id="audit-toggle-group" class="audit-btn">${escHtml(l10n('audit.report.toggleGroup'))}</button>
    </div>
  </div>

  <!-- Diagnostics table -->
  <div class="audit-table-wrap">
    <table class="audit-table" id="audit-table">
      <thead>
        <tr>
          <th class="audit-col-file" data-sort="file">${escHtml(l10n('audit.report.colFile'))}</th>
          <th class="audit-col-line" data-sort="line">${escHtml(l10n('audit.report.colLine'))}</th>
          <th class="audit-col-rule" data-sort="rule">${escHtml(l10n('audit.report.colRule'))}</th>
          <th class="audit-col-severity" data-sort="severity">${escHtml(l10n('audit.report.colSeverity'))}</th>
          <th class="audit-col-tier" data-sort="tier">${escHtml(l10n('audit.report.colTier'))}</th>
          <th class="audit-col-message">${escHtml(l10n('audit.report.colMessage'))}</th>
        </tr>
      </thead>
      <tbody id="audit-tbody">
        ${buildDiagnosticRows(diagnostics, root)}
      </tbody>
    </table>
    ${diagnostics.length === 0 ? `<div class="audit-empty"><span class="audit-empty-icon">✓</span><p>${escHtml(l10n('audit.report.empty'))}</p></div>` : ''}
    <!-- Shown when filters/search produce zero results but diagnostics exist. -->
    <div class="audit-filtered-empty" id="audit-filtered-empty" hidden>
      <span class="audit-empty-icon">⊘</span>
      <p>${escHtml(l10n('audit.report.filteredEmpty'))}</p>
    </div>
  </div>

  <!-- Pagination controls for large result sets -->
  <div class="audit-pagination" id="audit-pagination" hidden>
    <button id="audit-load-more" class="audit-btn">${escHtml(l10n('audit.report.loadMore'))}</button>
    <span id="audit-shown-count"></span>
  </div>

  <!-- Keyboard navigation hint -->
  ${diagnostics.length > 0 ? `<p class="audit-keyboard-hint">${escHtml(l10n('audit.report.keyboardHint'))}</p>` : ''}

  ${buildScript(diagnostics, root)}
</body>
</html>`;
}

// ── HTML builders ────────────────────────────────────────────────────

/** KPI strip: total + per-tier + per-severity counts. */
function buildKpiStrip(
  tierCounts: Map<string, number>,
  severityCounts: Map<string, number>,
): string {
  const pills: string[] = [];
  for (const [severity, count] of severityCounts) {
    pills.push(
      `<span class="audit-kpi audit-kpi-${escAttr(severity)}">${escHtml(severity)}: ${count}</span>`,
    );
  }
  for (const [tier, count] of tierCounts) {
    pills.push(
      `<span class="audit-kpi audit-kpi-tier">${escHtml(tier)}: ${count}</span>`,
    );
  }
  return pills.join('');
}

/** Builds a set of toggle-able filter chips for a dimension. */
function buildFilterChips(
  dimension: string,
  values: string[],
  counts: Map<string, number>,
): string {
  return values
    .map(
      (v) =>
        `<button class="audit-chip audit-chip-active" data-dim="${escAttr(dimension)}" data-val="${escAttr(v)}">${escHtml(v)} <span class="audit-chip-count">(${counts.get(v) ?? 0})</span></button>`,
    )
    .join('');
}

/** Builds table rows for all diagnostics, limiting to PAGE_SIZE for initial render. */
function buildDiagnosticRows(
  diagnostics: AuditDiagnostic[],
  root: string,
): string {
  // Initial render caps at 500 rows for DOM performance.
  const pageSize = 500;
  const initial = diagnostics.slice(0, pageSize);
  return initial.map((d) => diagnosticRow(d, root)).join('\n');
}

/** Single <tr> for a diagnostic. */
function diagnosticRow(d: AuditDiagnostic, root: string): string {
  // Show path relative to the project root for readability.
  const relPath = d.filePath.startsWith(root)
    ? d.filePath.slice(root.length + 1).replace(/\\/g, '/')
    : d.filePath.replace(/\\/g, '/');

  const severityClass = `audit-sev-${(d.severity ?? '').toLowerCase()}`;
  const baselineClass = d.baselineStatus === 'new' ? ' audit-baseline-new-row' : '';
  return `<tr class="audit-row ${severityClass}${baselineClass}" data-file="${escAttr(d.filePath)}" data-severity="${escAttr(d.severity)}" data-tier="${escAttr(d.tier ?? 'unknown')}" data-impact="${escAttr(d.impact ?? 'unknown')}" data-rule="${escAttr(d.ruleName)}" data-baseline-status="${escAttr(d.baselineStatus ?? '')}">
  <td class="audit-col-file audit-clickable" data-path="${escAttr(d.filePath)}" data-line="${d.line}">${escHtml(relPath)}</td>
  <td class="audit-col-line">${d.line}:${d.column}</td>
  <td class="audit-col-rule"><code>${escHtml(d.ruleName)}</code></td>
  <td class="audit-col-severity"><span class="audit-sev-pill ${severityClass}">${escHtml(d.severity)}</span></td>
  <td class="audit-col-tier">${escHtml(d.tier ?? '')}</td>
  <td class="audit-col-message">${escHtml(d.problemMessage ?? '')}</td>
</tr>`;
}

// ── Client-side script ───────────────────────────────────────────────

/** Builds the inline <script> for search, filter, sort, pagination. */
function buildScript(
  diagnostics: AuditDiagnostic[],
  root: string,
): string {
  // Embed the full diagnostics array as JSON so the client can re-render
  // on filter/sort changes without round-tripping to the extension host.
  const escapedJson = JSON.stringify(diagnostics).replace(/<\//g, '<\\/');
  const escapedRoot = JSON.stringify(root).replace(/<\//g, '<\\/');

  return `<script>
(function() {
  const vscode = acquireVsCodeApi();
  const ALL_DIAGNOSTICS = ${escapedJson};
  const ROOT = ${escapedRoot};
  const PAGE_SIZE = 500;
  let shownCount = Math.min(PAGE_SIZE, ALL_DIAGNOSTICS.length);
  let groupByFile = false;

  // Active filters: dimension -> Set of active values.
  const filters = {
    tier: new Set(),
    severity: new Set(),
    impact: new Set(),
    baselineStatus: new Set(),
  };

  // Initialize filters: all values active.
  document.querySelectorAll('.audit-chip').forEach(chip => {
    const dim = chip.dataset.dim;
    const val = chip.dataset.val;
    if (dim && val) filters[dim].add(val);
  });

  // Filter chip toggle.
  document.querySelectorAll('.audit-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      const dim = chip.dataset.dim;
      const val = chip.dataset.val;
      if (!dim || !val) return;
      if (filters[dim].has(val)) {
        filters[dim].delete(val);
        chip.classList.remove('audit-chip-active');
      } else {
        filters[dim].add(val);
        chip.classList.add('audit-chip-active');
      }
      rerender();
    });
  });

  // Search with debounce.
  const searchInput = document.getElementById('audit-search');
  let searchTimeout;
  searchInput.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(rerender, 200);
  });

  // Copy JSON button.
  document.getElementById('audit-copy-json').addEventListener('click', () => {
    vscode.postMessage({ type: 'copyJson', json: JSON.stringify(ALL_DIAGNOSTICS, null, 2) });
  });

  // Save as baseline button — sends the full audit JSON back to the host.
  const saveBaselineBtn = document.getElementById('audit-save-baseline');
  if (saveBaselineBtn) {
    saveBaselineBtn.addEventListener('click', () => {
      vscode.postMessage({ type: 'saveBaseline', json: JSON.stringify(ALL_DIAGNOSTICS, null, 2) });
    });
  }

  // Toggle group-by-file.
  document.getElementById('audit-toggle-group').addEventListener('click', () => {
    groupByFile = !groupByFile;
    rerender();
  });

  // Load more button.
  const loadMoreBtn = document.getElementById('audit-load-more');
  loadMoreBtn.addEventListener('click', () => {
    shownCount = Math.min(shownCount + PAGE_SIZE, ALL_DIAGNOSTICS.length);
    rerender();
  });

  // File click: open in editor.
  document.getElementById('audit-tbody').addEventListener('click', (e) => {
    const cell = e.target.closest('.audit-clickable');
    if (!cell) return;
    vscode.postMessage({ type: 'openFile', path: cell.dataset.path });
  });

  // Sort by clicking column headers.
  let sortCol = null;
  let sortAsc = true;
  document.querySelectorAll('th[data-sort]').forEach(th => {
    th.style.cursor = 'pointer';
    th.addEventListener('click', () => {
      const col = th.dataset.sort;
      if (sortCol === col) {
        sortAsc = !sortAsc;
      } else {
        sortCol = col;
        sortAsc = true;
      }
      rerender();
    });
  });

  // Keyboard navigation: arrow keys move between rows, Enter opens file.
  let activeRowIdx = -1;
  document.addEventListener('keydown', (e) => {
    const rows = document.querySelectorAll('#audit-tbody .audit-row');
    if (!rows.length) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      activeRowIdx = Math.min(activeRowIdx + 1, rows.length - 1);
      highlightRow(rows);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      activeRowIdx = Math.max(activeRowIdx - 1, 0);
      highlightRow(rows);
    } else if (e.key === 'Enter' && activeRowIdx >= 0 && activeRowIdx < rows.length) {
      // Open the file at the active row.
      const cell = rows[activeRowIdx].querySelector('.audit-clickable');
      if (cell) {
        vscode.postMessage({ type: 'openFile', path: cell.dataset.path });
      }
    }
  });

  function highlightRow(rows) {
    // Remove previous highlight.
    rows.forEach(r => r.classList.remove('audit-row-active'));
    if (activeRowIdx >= 0 && activeRowIdx < rows.length) {
      rows[activeRowIdx].classList.add('audit-row-active');
      rows[activeRowIdx].scrollIntoView({ block: 'nearest' });
    }
  }

  function rerender() {
    // Reset keyboard focus on re-render.
    activeRowIdx = -1;

    const query = (searchInput.value || '').toLowerCase();
    // Only apply baseline status filter when baseline data is present.
    const hasBaselineData = filters.baselineStatus.size > 0;

    let filtered = ALL_DIAGNOSTICS.filter(d => {
      if (!filters.tier.has(d.tier || 'unknown')) return false;
      if (!filters.severity.has(d.severity)) return false;
      if (!filters.impact.has(d.impact || 'unknown')) return false;
      if (hasBaselineData && d.baselineStatus && !filters.baselineStatus.has(d.baselineStatus)) return false;
      if (query) {
        const haystack = (d.filePath + ' ' + d.ruleName + ' ' + (d.problemMessage || '')).toLowerCase();
        if (!haystack.includes(query)) return false;
      }
      return true;
    });

    // Sort.
    if (sortCol) {
      filtered.sort((a, b) => {
        let va, vb;
        switch (sortCol) {
          case 'file': va = a.filePath; vb = b.filePath; break;
          case 'line': return sortAsc ? a.line - b.line : b.line - a.line;
          case 'rule': va = a.ruleName; vb = b.ruleName; break;
          case 'severity': va = sevRank(a.severity); vb = sevRank(b.severity);
            return sortAsc ? va - vb : vb - va;
          case 'tier': va = a.tier || ''; vb = b.tier || ''; break;
          default: va = ''; vb = '';
        }
        if (typeof va === 'string') {
          const cmp = va.localeCompare(vb);
          return sortAsc ? cmp : -cmp;
        }
        return 0;
      });
    }

    // Pagination.
    const page = filtered.slice(0, shownCount);
    const tbody = document.getElementById('audit-tbody');
    tbody.innerHTML = page.map(d => rowHtml(d)).join('');

    // Show filtered-empty state when filters produce zero results but
    // diagnostics exist (distinguishes "clean project" from "too narrow").
    const filteredEmpty = document.getElementById('audit-filtered-empty');
    if (ALL_DIAGNOSTICS.length > 0 && filtered.length === 0) {
      filteredEmpty.hidden = false;
    } else {
      filteredEmpty.hidden = true;
    }

    // Pagination controls.
    const pagination = document.getElementById('audit-pagination');
    const countSpan = document.getElementById('audit-shown-count');
    if (filtered.length > shownCount) {
      pagination.hidden = false;
      countSpan.textContent = shownCount + ' / ' + filtered.length;
    } else {
      pagination.hidden = true;
    }
  }

  function rowHtml(d) {
    const rel = d.filePath.startsWith(ROOT)
      ? d.filePath.slice(ROOT.length + 1).replace(/\\\\/g, '/')
      : d.filePath.replace(/\\\\/g, '/');
    const sevClass = 'audit-sev-' + (d.severity || '').toLowerCase();
    const baselineClass = d.baselineStatus === 'new' ? ' audit-baseline-new-row' : '';
    // Show a small badge next to the rule name when baseline data is present.
    const statusBadge = d.baselineStatus === 'new'
      ? ' <span class="audit-status-badge audit-status-new">NEW</span>'
      : d.baselineStatus === 'unchanged'
        ? ' <span class="audit-status-badge audit-status-unchanged">—</span>'
        : '';
    return '<tr class="audit-row ' + sevClass + baselineClass + '" data-baseline-status="' + escA(d.baselineStatus || '') + '">'
      + '<td class="audit-col-file audit-clickable" data-path="' + escA(d.filePath) + '" data-line="' + d.line + '">' + esc(rel) + '</td>'
      + '<td class="audit-col-line">' + d.line + ':' + d.column + '</td>'
      + '<td class="audit-col-rule"><code>' + esc(d.ruleName) + '</code>' + statusBadge + '</td>'
      + '<td class="audit-col-severity"><span class="audit-sev-pill ' + sevClass + '">' + esc(d.severity) + '</span></td>'
      + '<td class="audit-col-tier">' + esc(d.tier || '') + '</td>'
      + '<td class="audit-col-message">' + esc(d.problemMessage || '') + '</td>'
      + '</tr>';
  }

  function esc(s) { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function escA(s) { return s.replace(/&/g,'&amp;').replace(/"/g,'&quot;'); }
  function sevRank(s) { return s === 'error' ? 3 : s === 'warning' ? 2 : s === 'info' ? 1 : 0; }
})();
</script>`;
}

// ── Styles ───────────────────────────────────────────────────────────

/** Builds the <style> block for the audit report. */
function buildStyles(): string {
  return `<style>
/* Audit report — uses VS Code theme tokens for seamless integration. */
:root {
  --audit-bg: var(--vscode-editor-background);
  --audit-fg: var(--vscode-editor-foreground);
  --audit-border: var(--vscode-panel-border, #333);
  --audit-header-bg: var(--vscode-sideBar-background, #252526);
  --audit-hover: var(--vscode-list-hoverBackground, #2a2d2e);
  --audit-chip-bg: var(--vscode-badge-background, #4d4d4d);
  --audit-chip-fg: var(--vscode-badge-foreground, #fff);
  --audit-chip-active-bg: var(--vscode-button-background, #0e639c);
  --audit-chip-active-fg: var(--vscode-button-foreground, #fff);
  --audit-sev-error: var(--vscode-editorError-foreground, #f44747);
  --audit-sev-warning: var(--vscode-editorWarning-foreground, #cca700);
  --audit-sev-info: var(--vscode-editorInfo-foreground, #3794ff);
}

body {
  background: var(--audit-bg);
  color: var(--audit-fg);
  font-family: var(--vscode-font-family);
  font-size: var(--vscode-font-size, 13px);
  margin: 0;
  padding: 0;
}

.audit-header {
  padding: 16px 20px 12px;
  border-bottom: 1px solid var(--audit-border);
  background: var(--audit-header-bg);
}
.audit-header h1 { margin: 0 0 4px; font-size: 1.4em; font-weight: 600; }
.audit-subtitle { margin: 0 0 10px; opacity: 0.7; font-size: 0.9em; }

.audit-kpi-strip { display: flex; gap: 8px; flex-wrap: wrap; }
.audit-kpi {
  padding: 3px 10px;
  border-radius: 12px;
  font-size: 0.85em;
  font-weight: 500;
  background: var(--audit-chip-bg);
  color: var(--audit-chip-fg);
}
.audit-kpi-error { background: var(--audit-sev-error); }
.audit-kpi-warning { background: var(--audit-sev-warning); color: #000; }
.audit-kpi-info { background: var(--audit-sev-info); }

.audit-controls {
  padding: 10px 20px;
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: flex-start;
  border-bottom: 1px solid var(--audit-border);
}

.audit-search {
  flex: 1 1 200px;
  padding: 5px 10px;
  border: 1px solid var(--audit-border);
  border-radius: 4px;
  background: var(--vscode-input-background);
  color: var(--vscode-input-foreground);
  font-size: 0.95em;
}
.audit-search:focus { outline: 1px solid var(--vscode-focusBorder); }

.audit-filters { display: flex; gap: 12px; flex-wrap: wrap; }
.audit-filter-group { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
.audit-filter-label { font-size: 0.8em; opacity: 0.6; margin-right: 2px; }

.audit-chip {
  padding: 2px 8px;
  border: 1px solid var(--audit-border);
  border-radius: 10px;
  background: transparent;
  color: var(--audit-fg);
  font-size: 0.8em;
  cursor: pointer;
  opacity: 0.5;
}
.audit-chip-active {
  background: var(--audit-chip-active-bg);
  color: var(--audit-chip-active-fg);
  border-color: transparent;
  opacity: 1;
}
.audit-chip-count { font-size: 0.85em; opacity: 0.7; }

.audit-actions { display: flex; gap: 6px; }
.audit-btn {
  padding: 4px 12px;
  border: 1px solid var(--audit-border);
  border-radius: 4px;
  background: var(--vscode-button-secondaryBackground, #3a3d41);
  color: var(--vscode-button-secondaryForeground, #fff);
  cursor: pointer;
  font-size: 0.85em;
}
.audit-btn:hover { background: var(--vscode-button-secondaryHoverBackground, #45494e); }

.audit-table-wrap { overflow-x: auto; }
.audit-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9em;
}
.audit-table th {
  position: sticky;
  top: 0;
  background: var(--audit-header-bg);
  padding: 8px 10px;
  text-align: left;
  border-bottom: 2px solid var(--audit-border);
  font-weight: 600;
  white-space: nowrap;
}
.audit-table td {
  padding: 5px 10px;
  border-bottom: 1px solid var(--audit-border);
  vertical-align: top;
}
.audit-row:hover { background: var(--audit-hover); }

/* Zebra striping. */
.audit-row:nth-child(even) { background: rgba(128,128,128,0.04); }
.audit-row:nth-child(even):hover { background: var(--audit-hover); }

.audit-clickable { cursor: pointer; text-decoration: underline; }
.audit-clickable:hover { color: var(--vscode-textLink-foreground); }

.audit-sev-pill {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 8px;
  font-size: 0.85em;
  font-weight: 500;
}
.audit-sev-error { color: var(--audit-sev-error); }
.audit-sev-warning { color: var(--audit-sev-warning); }
.audit-sev-info { color: var(--audit-sev-info); }

.audit-col-file { max-width: 300px; overflow: hidden; text-overflow: ellipsis; }
.audit-col-line { white-space: nowrap; min-width: 60px; }
.audit-col-rule { white-space: nowrap; }
.audit-col-message { max-width: 500px; }

.audit-empty, .audit-filtered-empty {
  text-align: center;
  padding: 40px 20px;
  opacity: 0.6;
  font-size: 1.1em;
}
.audit-empty-icon {
  display: block;
  font-size: 2.5em;
  margin-bottom: 8px;
  opacity: 0.5;
}

/* Active row highlight for keyboard navigation. */
.audit-row-active {
  outline: 2px solid var(--vscode-focusBorder, #007fd4);
  outline-offset: -2px;
  background: var(--audit-hover) !important;
}

.audit-keyboard-hint {
  text-align: center;
  padding: 6px;
  opacity: 0.4;
  font-size: 0.8em;
  margin: 0;
}

/* Baseline diffing: "new" rows get a left accent border. */
.audit-baseline-new-row { border-left: 3px solid var(--audit-sev-error); }
.audit-baseline-tag {
  font-size: 0.85em;
  opacity: 0.6;
  font-style: italic;
}
.audit-baseline-new { border-color: var(--audit-sev-error); }

/* Status badges next to rule names when baseline data is present. */
.audit-status-badge {
  display: inline-block;
  padding: 0 4px;
  border-radius: 3px;
  font-size: 0.7em;
  font-weight: 600;
  vertical-align: middle;
  margin-left: 4px;
}
.audit-status-new {
  background: var(--audit-sev-error);
  color: #fff;
}
.audit-status-unchanged {
  opacity: 0.4;
}

.audit-pagination {
  padding: 10px 20px;
  text-align: center;
  display: flex;
  gap: 10px;
  justify-content: center;
  align-items: center;
}
</style>`;
}

// ── Utilities ────────────────────────────────────────────────────────

/** Counts occurrences of each value extracted by `fn`. */
function countBy<T>(items: T[], fn: (item: T) => string): Map<string, number> {
  const counts = new Map<string, number>();
  for (const item of items) {
    const key = fn(item);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}

/** Returns sorted unique values extracted by `fn`. */
function uniqueSorted<T>(items: T[], fn: (item: T) => string): string[] {
  return [...new Set(items.map(fn))].sort();
}

/** HTML-escapes a string for element content. */
function escHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

/** Escapes a string for use in an HTML attribute value. */
function escAttr(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}
