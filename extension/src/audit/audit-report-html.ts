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
 * Styles and client-side script live in the sibling audit-report-styles.ts /
 * audit-report-script.ts modules (kept separate to stay under the project's
 * file-size convention and to match the vibrancy report-*.ts split).
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { createWebviewCspNonce, escapeHtml, escapeJsonStringForScriptBlock, jsonForScriptBlock } from '../vibrancy/views/html-utils';
import { buildAuditStyles } from './audit-report-styles';
import { buildAuditScript } from './audit-report-script';

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

/** Page size for both the server-rendered first page and client "Load more". */
const PAGE_SIZE = 500;

/**
 * Render-time context for buildAuditReportHtml. Groups the webview, project
 * root, and optional payload-threading params into one object so the function
 * stays within the project's ≤3-parameter convention.
 *
 * CONTRACT: when `serializedDiagnostics` is non-null it MUST be
 * `JSON.stringify(auditJson['diagnostics'])` — the same array the function
 * reads as an object for counting/slicing. Passing a string derived from a
 * different snapshot silently diverges the header counts from the inline
 * embed the client renders.
 */
export interface AuditReportRenderContext {
  /** The webview instance — used only for CSP source. */
  webview: vscode.Webview;
  /** Scanned project root — used for relative path display. */
  root: string;
  /**
   * When the diagnostics payload exceeded the inline size threshold (see
   * MAX_INLINE_BYTES in audit-report-panel.ts), the full array is NOT
   * embedded in the page — instead this is a webview-resolved URI the
   * client script fetches lazily. Null for the normal inline path.
   */
  deferredUri: string | null;
  /**
   * Pre-serialized JSON string of the diagnostics array, produced by the
   * same upfront JSON.stringify that feeds the size check in
   * maybeWriteDeferredPayload. Avoids a redundant second serialization.
   * Null when diagnostics were not an array.
   */
  serializedDiagnostics: string | null;
}

/**
 * Builds the complete HTML string for the audit report webview.
 */
export function buildAuditReportHtml(
  auditJson: Record<string, unknown>,
  ctx: AuditReportRenderContext,
): string {
  const diagnostics = (auditJson['diagnostics'] ?? []) as AuditDiagnostic[];
  const timestamp = (auditJson['timestamp'] as string) ?? '';
  const summary = auditJson['summary'] as Record<string, unknown> | undefined;
  const totalCount = (summary?.['totalCount'] as number) ?? diagnostics.length;
  const baseline = auditJson['baseline'] as Record<string, unknown> | undefined;
  const hasBaseline = baseline !== undefined;

  // Tier breakdown for the summary header. Computed server-side from the
  // full array even in the deferred case — cheap (single pass) and lets the
  // header show accurate totals immediately instead of "0" until the fetch
  // resolves.
  const tierCounts = countBy(diagnostics, (d) => d.tier ?? 'unknown');
  const severityCounts = countBy(diagnostics, (d) => d.severity);
  const impactCounts = countBy(diagnostics, (d) => d.impact ?? 'unknown');

  // Collect unique values for filter chips.
  const tiers = uniqueSorted(diagnostics, (d) => d.tier ?? 'unknown');
  const severities = uniqueSorted(diagnostics, (d) => d.severity);
  const impacts = uniqueSorted(diagnostics, (d) => d.impact ?? 'unknown');

  // CSP nonce — required for the inline <style>/<script> below. See the
  // "html-utils.ts is mandatory for interpolation" rule in
  // saropa-lints-extension-development: every webview script/style tag
  // must carry the same nonce referenced in the CSP meta tag.
  const nonce = createWebviewCspNonce();
  // connect-src is needed only for the deferred-fetch path (>10MB
  // payloads); harmless to always allow it since it's scoped to the
  // webview's own resource origin (cspSource), not arbitrary network access.
  const csp = `default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}'; connect-src ${ctx.webview.cspSource};`;

  const initialPage = diagnostics.slice(0, PAGE_SIZE);
  // Full array embed is skipped when deferring — the client fetches it.
  // When a pre-serialized string is available (from the upfront serialize
  // in openAuditReport), apply only the HTML-safe escaping step instead of
  // re-serializing the full diagnostics array from scratch.
  const embeddedJson = ctx.deferredUri ? null
    : ctx.serializedDiagnostics ? escapeJsonStringForScriptBlock(ctx.serializedDiagnostics)
    : jsonForScriptBlock(diagnostics);
  const initialJson = jsonForScriptBlock(initialPage);
  const rootJson = jsonForScriptBlock(ctx.root);

  return /* html */ `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="${csp}">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(l10n('audit.report.title'))}</title>
  <style nonce="${nonce}">${buildAuditStyles()}</style>
</head>
<body>
  <!-- Summary header -->
  <header class="audit-header">
    <h1>${escapeHtml(l10n('audit.report.heading'))}</h1>
    <p class="audit-subtitle">
      ${escapeHtml(l10n('audit.report.subtitle', { count: String(totalCount), timestamp }))}
      ${hasBaseline ? `<br/><span class="audit-baseline-tag">${escapeHtml(l10n('audit.report.baselineSubtitle', { date: String(baseline?.['comparedTo'] ?? '') }))}</span>` : ''}
    </p>
    <div class="audit-kpi-strip">
      ${buildKpiStrip(tierCounts, severityCounts)}
    </div>
  </header>

  <!-- Shown only while a deferred (>10MB) payload is still loading. -->
  ${ctx.deferredUri ? `<div class="audit-loading-banner" id="audit-loading-banner" data-fail-message="${escapeHtml(l10n('audit.report.deferredLoadFailed', { pageSize: String(PAGE_SIZE) }))}">${escapeHtml(l10n('audit.report.deferredLoading'))}</div>` : ''}

  <!-- Controls: search + filters + actions -->
  <div class="audit-controls">
    <input
      type="text"
      id="audit-search"
      class="audit-search"
      placeholder="${escapeHtml(l10n('audit.report.searchPlaceholder'))}"
    />
    <div class="audit-filters">
      <div class="audit-filter-group">
        <span class="audit-filter-label">${escapeHtml(l10n('audit.report.filterTier'))}</span>
        ${buildFilterChips('tier', tiers, tierCounts)}
      </div>
      <div class="audit-filter-group">
        <span class="audit-filter-label">${escapeHtml(l10n('audit.report.filterSeverity'))}</span>
        ${buildFilterChips('severity', severities, severityCounts)}
      </div>
      <div class="audit-filter-group">
        <span class="audit-filter-label">${escapeHtml(l10n('audit.report.filterImpact'))}</span>
        ${buildFilterChips('impact', impacts, impactCounts)}
      </div>
    </div>
    ${hasBaseline ? `<div class="audit-filter-group">
        <span class="audit-filter-label">${escapeHtml(l10n('audit.report.filterBaselineStatus'))}</span>
        <button class="audit-chip audit-chip-active audit-baseline-new" data-dim="baselineStatus" data-val="new">${escapeHtml(l10n('audit.report.baselineNew'))} <span class="audit-chip-count">(${baseline?.['new'] ?? 0})</span></button>
        <button class="audit-chip audit-chip-active" data-dim="baselineStatus" data-val="unchanged">${escapeHtml(l10n('audit.report.baselineUnchanged'))} <span class="audit-chip-count">(${baseline?.['unchanged'] ?? 0})</span></button>
      </div>` : ''}
    <div class="audit-actions">
      <button id="audit-save-baseline" class="audit-btn">${escapeHtml(l10n('audit.report.saveBaseline'))}</button>
      <button id="audit-copy-json" class="audit-btn">${escapeHtml(l10n('audit.report.copyJson'))}</button>
      <button id="audit-toggle-group" class="audit-btn">${escapeHtml(l10n('audit.report.toggleGroup'))}</button>
    </div>
  </div>

  <!-- Diagnostics table -->
  <div class="audit-table-wrap">
    <table class="audit-table" id="audit-table">
      <thead>
        <tr>
          <th class="audit-col-file" data-sort="file">${escapeHtml(l10n('audit.report.colFile'))}</th>
          <th class="audit-col-line" data-sort="line">${escapeHtml(l10n('audit.report.colLine'))}</th>
          <th class="audit-col-rule" data-sort="rule">${escapeHtml(l10n('audit.report.colRule'))}</th>
          <th class="audit-col-severity" data-sort="severity">${escapeHtml(l10n('audit.report.colSeverity'))}</th>
          <th class="audit-col-tier" data-sort="tier">${escapeHtml(l10n('audit.report.colTier'))}</th>
          <th class="audit-col-message">${escapeHtml(l10n('audit.report.colMessage'))}</th>
        </tr>
      </thead>
      <tbody id="audit-tbody">
        ${buildDiagnosticRows(initialPage, ctx.root)}
      </tbody>
    </table>
    ${diagnostics.length === 0 ? `<div class="audit-empty"><span class="audit-empty-icon">✓</span><p>${escapeHtml(l10n('audit.report.empty'))}</p></div>` : ''}
    <!-- Shown when filters/search produce zero results but diagnostics exist. -->
    <div class="audit-filtered-empty" id="audit-filtered-empty" hidden>
      <span class="audit-empty-icon">⊘</span>
      <p>${escapeHtml(l10n('audit.report.filteredEmpty'))}</p>
    </div>
  </div>

  <!-- Pagination controls for large result sets -->
  <div class="audit-pagination" id="audit-pagination" hidden>
    <button id="audit-load-more" class="audit-btn">${escapeHtml(l10n('audit.report.loadMore'))}</button>
    <span id="audit-shown-count"></span>
  </div>

  <!-- Keyboard navigation hint -->
  ${diagnostics.length > 0 ? `<p class="audit-keyboard-hint">${escapeHtml(l10n('audit.report.keyboardHint'))}</p>` : ''}

  <script nonce="${nonce}">${buildAuditScript(embeddedJson, initialJson, ctx.deferredUri, rootJson)}</script>
</body>
</html>`;
}

/**
 * Builds the error/canceled-state HTML shown in place of the report when
 * the audit CLI fails or the user cancels it. No scripts are needed here
 * (no filtering/search to wire up), so the CSP omits script-src entirely —
 * this keeps the failure surface minimal rather than reusing the full
 * report shell for a state that has no table to render.
 */
export function buildAuditErrorHtml(
  message: string,
  canceled: boolean,
): string {
  const nonce = createWebviewCspNonce();
  const csp = `default-src 'none'; style-src 'nonce-${nonce}';`;
  const heading = canceled
    ? l10n('audit.report.canceledHeading')
    : l10n('audit.report.errorHeading');
  const icon = canceled ? '⊘' : '✗';
  const stateClass = canceled ? 'audit-error-canceled' : 'audit-error-failed';

  return /* html */ `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="${csp}">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(l10n('audit.report.title'))}</title>
  <style nonce="${nonce}">${buildAuditStyles()}</style>
</head>
<body>
  <div class="audit-error-state ${stateClass}">
    <span class="audit-empty-icon">${icon}</span>
    <h2>${escapeHtml(heading)}</h2>
    <p>${escapeHtml(message)}</p>
  </div>
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
      `<span class="audit-kpi audit-kpi-${escapeHtml(severity)}">${escapeHtml(severity)}: ${count}</span>`,
    );
  }
  for (const [tier, count] of tierCounts) {
    pills.push(
      `<span class="audit-kpi audit-kpi-tier">${escapeHtml(tier)}: ${count}</span>`,
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
        `<button class="audit-chip audit-chip-active" data-dim="${escapeHtml(dimension)}" data-val="${escapeHtml(v)}">${escapeHtml(v)} <span class="audit-chip-count">(${counts.get(v) ?? 0})</span></button>`,
    )
    .join('');
}

/** Builds table rows for the first page of diagnostics (server-rendered). */
function buildDiagnosticRows(
  page: AuditDiagnostic[],
  root: string,
): string {
  return page.map((d) => diagnosticRow(d, root)).join('\n');
}

/** Single <tr> for a diagnostic. */
function diagnosticRow(d: AuditDiagnostic, root: string): string {
  // Show path relative to the project root for readability.
  const relPath = d.filePath.startsWith(root)
    ? d.filePath.slice(root.length + 1).split('\\').join('/')
    : d.filePath.split('\\').join('/');

  const severityClass = `audit-sev-${(d.severity ?? '').toLowerCase()}`;
  const baselineClass = d.baselineStatus === 'new' ? ' audit-baseline-new-row' : '';
  return `<tr class="audit-row ${severityClass}${baselineClass}" data-file="${escapeHtml(d.filePath)}" data-severity="${escapeHtml(d.severity)}" data-tier="${escapeHtml(d.tier ?? 'unknown')}" data-impact="${escapeHtml(d.impact ?? 'unknown')}" data-rule="${escapeHtml(d.ruleName)}" data-baseline-status="${escapeHtml(d.baselineStatus ?? '')}">
  <td class="audit-col-file audit-clickable" data-path="${escapeHtml(d.filePath)}" data-line="${d.line}">${escapeHtml(relPath)}</td>
  <td class="audit-col-line">${d.line}:${d.column}</td>
  <td class="audit-col-rule"><code>${escapeHtml(d.ruleName)}</code></td>
  <td class="audit-col-severity"><span class="audit-sev-pill ${severityClass}">${escapeHtml(d.severity)}</span></td>
  <td class="audit-col-tier">${escapeHtml(d.tier ?? '')}</td>
  <td class="audit-col-message">${escapeHtml(d.problemMessage ?? '')}</td>
</tr>`;
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
