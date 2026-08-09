import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { createWebviewCspNonce, escapeHtml } from '../vibrancy/views/html-utils';
import { getDashboardChromeStyles } from '../views/dashboardChromeStyles';
import { l10n } from '../i18n/runtime';
import { scanWorkspace } from './scanner';
import { computeFileCost, aggregateByFolder, buildExclusionRows } from './scorer';
import {
  readAnalyzerExcludes,
  writeAnalyzerExcludes,
  mergeExclusions,
  computeAnalyzerExcludesContent,
  readAnalysisOptionsPath,
  hasMalformedExcludeSyntax,
  fixMalformedExcludeSyntax,
} from './analyzerExcludeYaml';
import { showAnalyzerExcludeDiff } from './analyzerExcludeDiffProvider';
import { getOptimizerScript } from './analysisOptimizerScript';
import type { AnalysisOptimizerResult, ExclusionRow, FileAnalysisMetrics } from './types';

const PANEL_TYPE = 'saropaLints.analysisOptimizer';
const PRIORITY_RANK: Record<ExclusionRow['priority'], number> = { high: 0, medium: 1, low: 2 };

export class AnalysisOptimizerWebviewProvider {
  private _panel?: vscode.WebviewPanel;
  private _result?: AnalysisOptimizerResult;
  private _scannedFiles: FileAnalysisMetrics[] = [];
  // Guards against stacking concurrent workspace walks: a scan now runs
  // automatically after every Apply/Remove/Fix-Syntax, so a user clicking
  // several per-row Apply buttons in quick succession would otherwise queue
  // up multiple full rescans (each with its own progress notification).
  private _scanInFlight = false;
  private _scanQueued = false;

  constructor(private readonly _extensionUri: vscode.Uri) {}

  openEditorPanel(): void {
    if (this._panel) {
      this._panel.reveal(vscode.ViewColumn.One, false);
      this._refreshExclusions();
      return;
    }

    const panel = vscode.window.createWebviewPanel(
      PANEL_TYPE,
      l10n('analysisOptimizer.tabTitle'),
      vscode.ViewColumn.One,
      {
        enableScripts: true,
        localResourceRoots: [this._extensionUri],
        retainContextWhenHidden: true,
      },
    );
    this._panel = panel;

    panel.webview.onDidReceiveMessage((msg: {
      type: string;
      pattern?: string;
      patterns?: string[];
    }) => {
      switch (msg.type) {
        case 'scan':
          void this._runScan();
          break;
        case 'applyExclusion':
          if (typeof msg.pattern === 'string') {
            void this._applyExclusion(msg.pattern);
          }
          break;
        case 'removeExclusion':
          if (typeof msg.pattern === 'string') {
            void this._removeExclusion(msg.pattern);
          }
          break;
        case 'applyAll':
          void this._applyAllRecommendations();
          break;
        case 'applySelected':
          if (Array.isArray(msg.patterns)) {
            void this._applySelected(msg.patterns);
          }
          break;
        case 'openConfig':
          void this._openConfig();
          break;
        case 'refresh':
          this._refreshExclusions();
          break;
        case 'fixSyntax':
          void this._fixSyntax();
          break;
      }
    });

    panel.onDidDispose(() => {
      this._panel = undefined;
    });

    this._renderPanel();
    if (!this._result) {
      void this._runScan();
    }
  }

  refresh(): void {
    this._refreshExclusions();
  }

  private _refreshExclusions(): void {
    if (!this._result) {
      this._renderPanel();
      return;
    }
    const root = getProjectRoot();
    if (root) {
      const currentExclusions = readAnalyzerExcludes(root);
      this._result.exclusions = buildExclusionRows(this._result.folders, this._scannedFiles, currentExclusions);
    }
    this._renderPanel();
  }

  private async _runScan(): Promise<void> {
    if (this._scanInFlight) {
      // A scan is already running — record that another one was requested
      // and let the in-flight scan's completion trigger it, rather than
      // starting a second concurrent workspace walk right now.
      this._scanQueued = true;
      return;
    }
    this._scanInFlight = true;
    try {
      await this._doScan();
    } finally {
      this._scanInFlight = false;
      if (this._scanQueued) {
        this._scanQueued = false;
        void this._runScan();
      }
    }
  }

  private async _doScan(): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;

    const files = await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: l10n('analysisOptimizer.scanning'),
        cancellable: true,
      },
      (progress, token) => scanWorkspace(root, progress, token),
    );

    if (files.length === 0) {
      this._renderPanel();
      return;
    }

    let totalLines = 0;
    let totalCost = 0;
    for (const f of files) {
      totalLines += f.lineCount;
      totalCost += computeFileCost(f);
    }

    const currentExclusions = readAnalyzerExcludes(root);
    const folders = aggregateByFolder(files);
    const exclusions = buildExclusionRows(folders, files, currentExclusions);

    this._scannedFiles = files;
    this._result = {
      totalFiles: files.length,
      totalLines,
      totalCost,
      folders,
      exclusions,
      scanTimestamp: new Date().toISOString(),
    };

    this._renderPanel();
  }

  private async _applyExclusion(pattern: string): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const current = readAnalyzerExcludes(root);
    const merged = mergeExclusions(current, [pattern]);
    await this._previewDiff(root, merged);
    if (writeAnalyzerExcludes(root, merged)) {
      void vscode.window.showInformationMessage(
        l10n('analysisOptimizer.notify.applied', { count: '1' }),
      );
      void this._runScan();
    } else {
      void vscode.window.showErrorMessage(l10n('analysisOptimizer.notify.writeFailed'));
    }
  }

  private async _removeExclusion(pattern: string): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const current = readAnalyzerExcludes(root);
    const filtered = current.filter(p => p !== pattern);
    if (writeAnalyzerExcludes(root, filtered)) {
      void vscode.window.showInformationMessage(
        l10n('analysisOptimizer.notify.removed'),
      );
      void this._runScan();
    } else {
      void vscode.window.showErrorMessage(l10n('analysisOptimizer.notify.writeFailed'));
    }
  }

  private async _applyAllRecommendations(): Promise<void> {
    if (!this._result) return;
    const patterns = this._result.exclusions.filter(r => !r.isApplied).map(r => r.pattern);
    await this._applySelected(patterns);
  }

  private async _applySelected(patterns: string[]): Promise<void> {
    const root = getProjectRoot();
    if (!root || patterns.length === 0) return;
    const current = readAnalyzerExcludes(root);
    const merged = mergeExclusions(current, patterns);
    if (patterns.length > 1) {
      await this._previewDiff(root, merged);
      const confirmed = await this._confirmBulkApply(patterns);
      if (!confirmed) return;
    }
    if (writeAnalyzerExcludes(root, merged)) {
      void vscode.window.showInformationMessage(
        l10n('analysisOptimizer.notify.applied', { count: String(patterns.length) }),
      );
      void this._runScan();
    } else {
      void vscode.window.showErrorMessage(l10n('analysisOptimizer.notify.writeFailed'));
    }
  }

  // Informational only, not a write lock: the preview and the later
  // writeAnalyzerExcludes() each read the file independently, so an external
  // edit between the two would make the shown diff stale relative to what
  // actually gets written. Acceptable for a single-user local file.
  private async _previewDiff(root: string, mergedPatterns: string[]): Promise<void> {
    const computed = computeAnalyzerExcludesContent(root, mergedPatterns);
    if (!computed) return;
    await showAnalyzerExcludeDiff(
      readAnalysisOptionsPath(root),
      computed.after,
      l10n('analysisOptimizer.diffTitle'),
    );
  }

  private async _confirmBulkApply(patterns: string[]): Promise<boolean> {
    const preview = patterns.slice(0, 5).join(', ');
    const suffix = patterns.length > 5 ? `, +${patterns.length - 5} more` : '';
    const applyLabel = l10n('analysisOptimizer.apply');
    const choice = await vscode.window.showWarningMessage(
      l10n('analysisOptimizer.confirmBulk.prompt', { count: String(patterns.length) }),
      {
        modal: true,
        detail: l10n('analysisOptimizer.confirmBulk.detail', { preview: `${preview}${suffix}` }),
      },
      applyLabel,
    );
    return choice === applyLabel;
  }

  private async _openConfig(): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const uri = vscode.Uri.file(`${root}/analysis_options.yaml`);
    void vscode.window.showTextDocument(uri);
  }

  private async _fixSyntax(): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const { success, duplicatesRemoved } = fixMalformedExcludeSyntax(root);
    if (success) {
      void vscode.window.showInformationMessage(
        duplicatesRemoved > 0
          ? l10n('analysisOptimizer.notify.syntaxFixedWithDuplicates', { count: String(duplicatesRemoved) })
          : l10n('analysisOptimizer.notify.syntaxFixed'),
      );
      void this._runScan();
    } else {
      void vscode.window.showErrorMessage(l10n('analysisOptimizer.notify.writeFailed'));
    }
  }

  private _buildSyntaxWarningBanner(): string {
    const root = getProjectRoot();
    if (!root || !hasMalformedExcludeSyntax(root)) return '';
    return `
<div class="syntax-warning-banner">
  <span class="warning-badge">⚠</span>
  <span>${escapeHtml(l10n('analysisOptimizer.syntaxWarning.message'))}</span>
  <button class="btn btn-sm tier-1" id="fix-syntax-btn">${escapeHtml(l10n('analysisOptimizer.syntaxWarning.fixButton'))}</button>
</div>`;
  }

  private _renderPanel(): void {
    const webview = this._panel?.webview;
    if (!webview) return;
    webview.html = this._buildHtml();
  }

  private _buildHtml(): string {
    const body = this._result
      ? this._buildResultView()
      : this._buildEmptyView();
    return this._wrapHtml(body);
  }

  private _buildEmptyView(): string {
    return `
<div class="dash-hero">
  <h1>${escapeHtml(l10n('analysisOptimizer.title'))}</h1>
  <p class="hero-sub">${escapeHtml(l10n('analysisOptimizer.subtitle'))}</p>
</div>
${this._buildSyntaxWarningBanner()}
<div class="empty-cta">
  <p>${escapeHtml(l10n('analysisOptimizer.emptyDescription'))}</p>
  <button class="btn tier-1" id="scan-btn">${escapeHtml(l10n('analysisOptimizer.scanButton'))}</button>
</div>`;
  }

  private _buildResultView(): string {
    const r = this._result!;
    const notApplied = r.exclusions.filter(e => !e.isApplied);
    const savingsPercent = r.totalCost > 0
      ? Math.round(
        notApplied.reduce((sum, rec) => sum + rec.estimatedCostReduction, 0)
        / r.totalCost * 100
      )
      : 0;
    const costLabel = r.totalCost > 50_000
      ? l10n('analysisOptimizer.costHeavy')
      : r.totalCost > 20_000
        ? l10n('analysisOptimizer.costModerate')
        : l10n('analysisOptimizer.costLight');

    return `
<div class="dash-hero">
  <h1>${escapeHtml(l10n('analysisOptimizer.title'))}</h1>
  <p class="hero-sub">${escapeHtml(l10n('analysisOptimizer.subtitle'))}</p>
  <p class="hero-meta">${escapeHtml(l10n('analysisOptimizer.lastScan', { time: new Date(r.scanTimestamp).toLocaleTimeString() }))}</p>
</div>
${this._buildSyntaxWarningBanner()}

${this._buildKpiStrip(r, costLabel, savingsPercent, notApplied.length)}
${this._buildExclusionsTable(r)}
${this._buildFolderHeatMap(r)}
${this._buildHints()}

<div class="toolbar-band" style="margin-top:16px">
  <button class="btn" id="scan-btn">${escapeHtml(l10n('analysisOptimizer.rescanButton'))}</button>
  <button class="btn" id="open-config-btn">${escapeHtml(l10n('analysisOptimizer.openConfig'))}</button>
</div>`;
  }

  private _buildKpiStrip(
    r: AnalysisOptimizerResult,
    costLabel: string,
    savingsPercent: number,
    recommendedCount: number,
  ): string {
    return `
<div class="kpi-row">
  <div class="kpi-card">
    <span class="kpi-k">${escapeHtml(l10n('analysisOptimizer.kpi.filesInScope'))}</span>
    <span class="kpi-v">${r.totalFiles.toLocaleString()}</span>
    <span class="kpi-sub">${r.totalLines.toLocaleString()} ${escapeHtml(l10n('analysisOptimizer.kpi.lines'))}</span>
  </div>
  <div class="kpi-card">
    <span class="kpi-k">${escapeHtml(l10n('analysisOptimizer.kpi.estimatedCost'))}</span>
    <span class="kpi-v">${escapeHtml(costLabel)}</span>
    <span class="kpi-sub">${r.totalCost.toLocaleString()} ${escapeHtml(l10n('analysisOptimizer.kpi.costUnits'))}</span>
  </div>
  <div class="kpi-card${savingsPercent > 20 ? ' kpi-highlight' : ''}">
    <span class="kpi-k">${escapeHtml(l10n('analysisOptimizer.kpi.potentialSavings'))}</span>
    <span class="kpi-v">${savingsPercent}%</span>
    <span class="kpi-sub">${recommendedCount} ${escapeHtml(l10n('analysisOptimizer.kpi.recommendations'))}</span>
  </div>
</div>`;
  }

  private _buildExclusionsTable(r: AnalysisOptimizerResult): string {
    if (r.exclusions.length === 0) {
      return `
<section class="opt-section">
  <h2>${escapeHtml(l10n('analysisOptimizer.exclusions'))}</h2>
  <p class="hint">${escapeHtml(l10n('analysisOptimizer.noExclusions'))}</p>
</section>`;
    }

    const rows = r.exclusions.map((row, i) => this._buildExclusionRow(row, i)).join('');
    const sortLabel = l10n('analysisOptimizer.sortHint');

    return `
<section class="opt-section">
  <h2>${escapeHtml(l10n('analysisOptimizer.exclusions'))}</h2>
  <div class="toolbar-row" style="margin-bottom:8px">
    <button class="btn tier-1" id="apply-all-btn">${escapeHtml(l10n('analysisOptimizer.applyAll'))}</button>
    <button class="btn" id="apply-selected-btn" disabled>${escapeHtml(l10n('analysisOptimizer.applySelected'))}</button>
  </div>
  <table class="dash-table" id="exclusions-table">
    <thead>
      <tr>
        <th><input type="checkbox" id="select-all-cb" title="${escapeHtml(l10n('analysisOptimizer.selectAll'))}"></th>
        <th class="sortable" data-sort="status" title="${escapeHtml(sortLabel)}">${escapeHtml(l10n('analysisOptimizer.col.status'))}<span class="sort-indicator"></span></th>
        <th class="sortable" data-sort="pattern" title="${escapeHtml(sortLabel)}">${escapeHtml(l10n('analysisOptimizer.col.pattern'))}<span class="sort-indicator"></span></th>
        <th class="sortable" data-sort="files" title="${escapeHtml(sortLabel)}">${escapeHtml(l10n('analysisOptimizer.col.files'))}<span class="sort-indicator"></span></th>
        <th class="sortable" data-sort="cost" title="${escapeHtml(sortLabel)}">${escapeHtml(l10n('analysisOptimizer.col.cost'))}<span class="sort-indicator"></span></th>
        <th class="sortable" data-sort="priority" title="${escapeHtml(sortLabel)}">${escapeHtml(l10n('analysisOptimizer.col.priority'))}<span class="sort-indicator"></span></th>
        <th></th>
      </tr>
    </thead>
    <tbody>${rows}</tbody>
  </table>
</section>`;
  }

  private _buildExclusionRow(row: ExclusionRow, index: number): string {
    const priorityClass = `priority-${row.priority}`;
    const warning = row.hasActiveFiles
      ? ` <span class="warning-badge" title="${escapeHtml(l10n('analysisOptimizer.activeFilesWarning'))}">⚠</span>`
      : '';
    const statusLabel = row.isApplied
      ? l10n('analysisOptimizer.status.applied')
      : l10n('analysisOptimizer.status.recommended');
    const statusClass = row.isApplied ? 'status-applied' : 'status-recommended';
    const priorityRank = PRIORITY_RANK[row.priority];

    const zeroImpact = row.isApplied && row.estimatedFilesExcluded === 0;
    const filesDisplay = zeroImpact ? '—' : row.estimatedFilesExcluded.toLocaleString();
    const costDisplay = zeroImpact ? '—' : row.estimatedCostReduction.toLocaleString();

    const checkboxCell = row.isApplied
      ? '<td></td>'
      : `<td><input type="checkbox" class="rec-cb" data-index="${index}" data-pattern="${escapeHtml(row.pattern)}"></td>`;
    const previewToggle = row.isApplied
      ? ''
      : ` <button class="btn-sm preview-toggle-btn" data-target="preview-${index}" title="${escapeHtml(l10n('analysisOptimizer.previewLine'))}">${escapeHtml(l10n('analysisOptimizer.previewToggle'))}</button>`;
    const actionCell = row.isApplied
      ? `<td><button class="btn btn-sm remove-btn" data-pattern="${escapeHtml(row.pattern)}">${escapeHtml(l10n('analysisOptimizer.remove'))}</button></td>`
      : `<td><button class="btn btn-sm apply-one-btn" data-pattern="${escapeHtml(row.pattern)}">${escapeHtml(l10n('analysisOptimizer.apply'))}</button></td>`;
    // Approximate preview only — the authoritative diff (matching the file's
    // real indentation and preserving neighboring comments) is the vscode.diff
    // tab opened when Apply is actually clicked.
    const previewRow = row.isApplied ? '' : `
    <tr class="preview-row" id="preview-${index}" hidden>
      <td colspan="7"><code class="preview-line">    - ${escapeHtml(row.pattern)}</code> <span class="hint">${escapeHtml(l10n('analysisOptimizer.previewApprox'))}</span></td>
    </tr>`;

    return `
    <tr class="rec-row ${priorityClass}"
      data-status="${row.isApplied ? 1 : 0}"
      data-pattern="${escapeHtml(row.pattern)}"
      data-files="${row.estimatedFilesExcluded}"
      data-cost="${row.estimatedCostReduction}"
      data-priority="${priorityRank}">
      ${checkboxCell}
      <td><span class="chip ${statusClass}">${escapeHtml(statusLabel)}</span></td>
      <td>
        <code>${escapeHtml(row.pattern)}</code>${warning}${previewToggle}
        ${row.isDefault ? `<span class="chip default-chip">${escapeHtml(l10n('analysisOptimizer.defaultLabel'))}</span>` : ''}
        <br><span class="hint">${escapeHtml(row.reason)}</span>
      </td>
      <td>${filesDisplay}</td>
      <td>${costDisplay}</td>
      <td><span class="chip ${priorityClass}">${escapeHtml(l10n(`analysisOptimizer.priority.${row.priority}`))}</span></td>
      ${actionCell}
    </tr>${previewRow}`;
  }

  private _buildFolderHeatMap(r: AnalysisOptimizerResult): string {
    const top = r.folders.slice(0, 15);
    if (top.length === 0) return '';
    const maxCost = top[0].totalCost || 1;

    const bars = top.map(f => {
      const pct = Math.round((f.totalCost / maxCost) * 100);
      const hue = Math.round((1 - f.totalCost / maxCost) * 120);
      return `
    <div class="bar-row">
      <span class="bar-label" title="${escapeHtml(f.folderPath)}">${escapeHtml(f.folderPath)}</span>
      <div class="bar-track">
        <div class="bar-fill" style="width:${pct}%;background:hsl(${hue},60%,45%)"></div>
      </div>
      <span class="bar-value">${f.fileCount} ${escapeHtml(l10n('analysisOptimizer.kpi.files'))} · ${f.totalCost.toLocaleString()}</span>
    </div>`;
    }).join('');

    return `
<section class="opt-section">
  <h2>${escapeHtml(l10n('analysisOptimizer.folderHeatMap'))}</h2>
  <div class="heat-map">${bars}
  </div>
</section>`;
  }

  private _buildHints(): string {
    return `
<details class="more opt-hints">
  <summary>${escapeHtml(l10n('analysisOptimizer.hints.title'))}</summary>
  <div class="hint-body">
    <p>${escapeHtml(l10n('analysisOptimizer.hints.body'))}</p>
    <ul>
      <li>${escapeHtml(l10n('analysisOptimizer.hints.generated'))}</li>
      <li>${escapeHtml(l10n('analysisOptimizer.hints.build'))}</li>
      <li>${escapeHtml(l10n('analysisOptimizer.hints.inactive'))}</li>
      <li>${escapeHtml(l10n('analysisOptimizer.hints.protected'))}</li>
    </ul>
  </div>
</details>`;
  }

  private _wrapHtml(body: string): string {
    const nonce = createWebviewCspNonce();
    const csp = [
      "default-src 'none'",
      `style-src 'nonce-${nonce}' 'unsafe-inline'`,
      `script-src 'nonce-${nonce}'`,
    ].join('; ');
    return `<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<title>${escapeHtml(l10n('analysisOptimizer.tabTitle'))}</title>
<meta http-equiv="Content-Security-Policy" content="${csp}">
<style nonce="${nonce}">${getDashboardChromeStyles()}${getOptimizerStyles()}</style>
</head><body>${body}<script nonce="${nonce}">${getOptimizerScript()}</script></body></html>`;
  }
}

function getOptimizerStyles(): string {
  return `
.syntax-warning-banner { display:flex; align-items:center; gap:10px; margin-top:12px; padding:10px 14px; border-radius:4px; background:var(--vscode-inputValidation-warningBackground, rgba(196,146,0,0.15)); border:1px solid var(--vscode-inputValidation-warningBorder, #c18401); }
.syntax-warning-banner .btn { margin-left:auto; }

.empty-cta { text-align:center; padding:48px 24px; }
.empty-cta p { margin-bottom:24px; max-width:480px; margin-inline:auto; color:var(--vscode-descriptionForeground); }

.opt-section { margin:16px 0; }
.opt-section h2 { font-size:14px; font-weight:600; margin-bottom:8px; text-transform:uppercase; letter-spacing:0.05em; color:var(--vscode-foreground); }

.rec-row { border-left:3px solid transparent; }
.rec-row.priority-high { border-left-color:var(--vscode-charts-red, #e45649); }
.rec-row.priority-medium { border-left-color:var(--vscode-charts-yellow, #c18401); }
.rec-row.priority-low { border-left-color:var(--vscode-charts-green, #50a14f); }

.preview-toggle-btn { padding:0 4px; font-size:11px; border:none; background:transparent; color:var(--vscode-textLink-foreground); cursor:pointer; }
.preview-toggle-btn:hover { text-decoration:underline; }
.preview-row td { background:var(--vscode-textCodeBlock-background, var(--vscode-editor-background)); padding:6px 12px; }
.preview-line { color:var(--vscode-charts-green, #50a14f); }

.chip { display:inline-block; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:500; }
.chip.priority-high { background:var(--vscode-charts-red, #e45649); color:#fff; }
.chip.priority-medium { background:var(--vscode-charts-yellow, #c18401); color:#fff; }
.chip.priority-low { background:var(--vscode-charts-green, #50a14f); color:#fff; }
.chip.default-chip { background:var(--vscode-badge-background); color:var(--vscode-badge-foreground); margin-left:6px; }
.chip.status-applied { background:var(--vscode-charts-green, #50a14f); color:#fff; }
.chip.status-recommended { background:var(--vscode-charts-blue, #4078c0); color:#fff; }

.warning-badge { color:var(--vscode-charts-yellow, #c18401); cursor:help; }

.dash-table th.sortable { cursor:pointer; user-select:none; }
.dash-table th.sortable:hover { color:var(--vscode-textLink-foreground); }
.sort-indicator { display:inline-block; width:1em; margin-left:2px; opacity:0.6; }
.dash-table th.sort-asc .sort-indicator::after { content:'▲'; }
.dash-table th.sort-desc .sort-indicator::after { content:'▼'; }

.heat-map { display:flex; flex-direction:column; gap:4px; }
.bar-row { display:flex; align-items:center; gap:8px; }
.bar-label { flex:0 0 180px; font-size:12px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; text-align:right; }
.bar-track { flex:1; height:16px; background:var(--vscode-editor-background); border-radius:3px; overflow:hidden; }
.bar-fill { height:100%; border-radius:3px; transition:width 0.3s ease; }
.bar-value { flex:0 0 120px; font-size:11px; color:var(--vscode-descriptionForeground); }

.kpi-highlight { border:1px solid var(--vscode-charts-green, #50a14f); }

.opt-hints { margin:16px 0; }
.hint-body { padding:8px 16px; color:var(--vscode-descriptionForeground); font-size:13px; }
.hint-body ul { margin-top:8px; padding-left:20px; }
.hint-body li { margin-bottom:4px; }

.hero-meta { font-size:12px; color:var(--vscode-descriptionForeground); margin-top:4px; }

.btn-sm { padding:2px 8px; font-size:12px; }

@media (max-width: 600px) {
  .bar-label { flex:0 0 100px; }
  .bar-value { flex:0 0 80px; }
}
`;
}
