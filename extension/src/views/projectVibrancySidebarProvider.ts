import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { runProjectVibrancyScan } from './projectVibrancyCliRunner';
import type { ProjectVibrancyPayload } from './projectVibrancyTypes';

/** Sidebar webview: runs the vibrancy CLI, renders JSON payload HTML, handles refresh and messages. */

export const PROJECT_VIBRANCY_VIEW_ID = 'saropaLints.projectVibrancy';

export class ProjectVibrancySidebarProvider implements vscode.WebviewViewProvider {
  private _view: vscode.WebviewView | undefined;
  private _payload: ProjectVibrancyPayload | null = null;
  private _lastRawStdout = '';
  private _sinceRef = '';

  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken,
  ): void {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };
    webviewView.webview.html = this._buildHtml();
    webviewView.webview.onDidReceiveMessage((msg: unknown) => {
      void this._handleMessage(msg);
    });
    void this.refresh();
  }

  async refresh(): Promise<void> {
    if (!this._view) {
      return;
    }
    const projectRoot = getProjectRoot();
    if (!projectRoot) {
      void vscode.window.showErrorMessage('Open a Dart/Flutter workspace first.');
      return;
    }
    const scan = await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Project Vibrancy: scanning...',
        cancellable: false,
      },
      async () => runProjectVibrancyScan(projectRoot, { since: this._sinceRef }),
    );
    if (!scan.payload) {
      return;
    }
    this._payload = scan.payload;
    this._lastRawStdout = scan.rawStdout;
    this._view.webview.html = this._buildHtml();
  }

  private _buildHtml(): string {
    const nonce = String(Date.now());
    const payload = this._payload;
    const rows = [...(payload?.functions ?? [])]
      .sort((a, b) => a.score - b.score)
      .slice(0, 300);
    const summary = payload?.summary;
    const avgScore = summary?.averageScore?.toFixed(1) ?? '0.0';
    const avgGrade = summary?.averageGrade ?? '—';
    const functionCount = summary?.functionCount ?? rows.length;
    const unusedCount = summary?.unusedCount ?? rows.filter((r) => r.flags.includes('unused')).length;
    const uncoveredCount = summary?.uncoveredCount ?? rows.filter((r) => r.flags.includes('uncovered')).length;
    const stubTestedCount =
      summary?.stubTestedCount ?? rows.filter((r) => r.flags.includes('stub_tested')).length;
    const suspiciousCoverageCount =
      summary?.suspiciousCoverageCount ??
      rows.filter((r) => r.flags.includes('suspicious_coverage')).length;
    const testDriftCount =
      summary?.testDriftCount ?? rows.filter((r) => r.flags.includes('test_drift')).length;
    const generatedAt = payload?.generatedAt ?? 'Not scanned yet';
    const activeSince = payload?.determinism?.since ?? this._sinceRef;
    const gateFailed = payload?.gates?.pass === false;
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';">
  <style>
    body { font-family: var(--vscode-font-family); font-size: 12px; margin: 0; padding: 8px; color: var(--vscode-foreground); }
    .header { display: grid; gap: 6px; margin-bottom: 8px; }
    .meta { opacity: 0.8; }
    .scope-row { display: flex; gap: 6px; align-items: center; }
    .badge { border: 1px solid var(--vscode-panel-border); border-radius: 999px; padding: 1px 8px; font-size: 11px; background: var(--vscode-badge-background); color: var(--vscode-badge-foreground); }
    .count { font-size: 11px; opacity: 0.85; }
    .summary { display: grid; grid-template-columns: repeat(2, minmax(0,1fr)); gap: 6px; }
    .card { border: 1px solid var(--vscode-panel-border); border-radius: 6px; padding: 6px; background: var(--vscode-editor-background); }
    .k { font-size: 10px; text-transform: uppercase; opacity: 0.8; }
    .v { font-size: 16px; font-weight: 700; }
    .filters { display: grid; gap: 6px; margin: 8px 0; }
    .row { display: grid; grid-template-columns: 1fr 90px 90px; gap: 6px; }
    .btns { display: flex; gap: 6px; flex-wrap: wrap; }
    button { border: 1px solid var(--vscode-button-border, var(--vscode-panel-border)); background: var(--vscode-button-secondaryBackground); color: var(--vscode-button-secondaryForeground); border-radius: 5px; padding: 3px 7px; cursor: pointer; }
    button:hover { background: var(--vscode-button-secondaryHoverBackground); }
    table { width: 100%; border-collapse: collapse; }
    th, td { border-bottom: 1px solid var(--vscode-panel-border); padding: 4px; text-align: left; }
    th { position: sticky; top: 0; background: var(--vscode-editor-background); }
    .file-link { color: var(--vscode-textLink-foreground); text-decoration: underline; cursor: pointer; }
    .hidden { display: none; }
    .gate-warn { margin: 6px 0; padding: 6px 8px; border-radius: 4px; border-left: 3px solid var(--vscode-inputValidation-errorBorder); background: var(--vscode-inputValidation-errorBackground); color: var(--vscode-inputValidation-errorForeground); font-size: 11px; }
  </style>
</head>
<body>
  <div class="header">
    <strong>Project Vibrancy</strong>
    <div class="meta">Generated: ${escapeHtml(generatedAt)}</div>
    <div class="scope-row">
      <span class="badge" id="scopeBadge">${activeSince && activeSince.length > 0 ? `since: ${escapeHtml(activeSince)}` : 'all files'}</span>
      <span class="count" id="filteredCount"></span>
    </div>
    ${gateFailed ? '<div class="gate-warn">Quality gates failed (see Settings: Project Vibrancy, or copy JSON).</div>' : ''}
    <div class="summary">
      <div class="card"><div class="k">Average</div><div class="v">${escapeHtml(avgScore)} (${escapeHtml(avgGrade)})</div></div>
      <div class="card"><div class="k">Functions</div><div class="v">${functionCount}</div></div>
      <div class="card"><div class="k">Unused / Uncovered</div><div class="v">${unusedCount} / ${uncoveredCount}</div></div>
      <div class="card"><div class="k">stub / susp / drift</div><div class="v">${stubTestedCount} / ${suspiciousCoverageCount} / ${testDriftCount}</div></div>
    </div>
  </div>

  <div class="filters">
    <div class="row">
      <input id="textFilter" type="text" placeholder="Filter by function or file..." />
      <select id="gradeFilter">
        <option value="">All grades</option>
        <option value="A">A</option><option value="B">B</option><option value="C">C</option>
        <option value="D">D</option><option value="E">E</option><option value="F">F</option>
      </select>
      <select id="flagFilter">
        <option value="">All flags</option>
        <option value="unused">unused</option>
        <option value="uncovered">uncovered</option>
        <option value="stub_tested">stub_tested</option>
        <option value="suspicious_coverage">suspicious_coverage</option>
        <option value="test_drift">test_drift</option>
        <option value="complex">complex</option>
        <option value="undocumented">undocumented</option>
      </select>
    </div>
      <div class="row">
        <input id="sinceRef" type="text" placeholder="Git ref for changed files (e.g. main, HEAD~1)" value="${escapeHtml(activeSince ?? '')}" />
        <button id="applySince">Apply --since</button>
        <button id="clearSince">All files</button>
      </div>
    <div class="btns">
      <button id="quickUnused">Unused only</button>
      <button id="quickUncovered">Uncovered only</button>
      <button id="quickStub">stub_tested</button>
      <button id="quickSuspicious">suspicious_coverage</button>
      <button id="quickDrift">test_drift</button>
      <button id="clearFilters">Clear filters</button>
      <button id="openFullReport">Open full report</button>
      <button id="copyJson">Copy JSON</button>
      <button id="openPvSettings">Settings</button>
      <button id="refreshScan">Refresh scan</button>
    </div>
  </div>

  <table>
    <thead><tr>
      <th>Grade</th><th>Score</th><th>Function</th><th>File</th><th>Usage</th><th>Coverage</th><th>Cx</th><th>Flags</th>
    </tr></thead>
    <tbody id="rows">
      ${rows.map((row) => `
      <tr data-grade="${escapeHtml(row.grade)}" data-flags="${escapeHtml(row.flags.join(','))}" data-search="${escapeHtml((`${row.name} ${row.file}`).toLowerCase())}">
        <td>${escapeHtml(row.grade)}</td>
        <td>${row.score.toFixed(1)}</td>
        <td>${escapeHtml(row.name)}</td>
        <td><span class="file-link" data-file="${escapeHtml(row.file)}" data-line="${row.lineStart}">${escapeHtml(row.file)}:${row.lineStart}</span></td>
        <td>${row.usageCount}</td>
        <td>${row.coveragePercent.toFixed(1)}%</td>
        <td>${row.complexity}</td>
        <td>${escapeHtml(row.flags.join(', '))}</td>
      </tr>
      `).join('')}
    </tbody>
  </table>
  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi();
    const rows = [...document.querySelectorAll('#rows tr')];
    const textFilter = document.getElementById('textFilter');
    const gradeFilter = document.getElementById('gradeFilter');
    const flagFilter = document.getElementById('flagFilter');
    const scopeBadge = document.getElementById('scopeBadge');
    const filteredCount = document.getElementById('filteredCount');
    const sinceRef = document.getElementById('sinceRef');
    const applySince = document.getElementById('applySince');
    const clearSince = document.getElementById('clearSince');
    const state = vscode.getState() || {};
    if (typeof state.textFilter === 'string') textFilter.value = state.textFilter;
    if (typeof state.gradeFilter === 'string') gradeFilter.value = state.gradeFilter;
    if (typeof state.flagFilter === 'string') flagFilter.value = state.flagFilter;
    if (typeof state.sinceRef === 'string' && sinceRef && !sinceRef.value) sinceRef.value = state.sinceRef;

    function applyFilters() {
      const text = (textFilter.value || '').toLowerCase().trim();
      const grade = gradeFilter.value;
      const flag = flagFilter.value;
      let visible = 0;
      rows.forEach((row) => {
        const rowText = row.getAttribute('data-search') || '';
        const rowGrade = row.getAttribute('data-grade') || '';
        const rowFlags = row.getAttribute('data-flags') || '';
        const ok = (!text || rowText.includes(text))
          && (!grade || rowGrade === grade)
          && (!flag || rowFlags.split(',').includes(flag));
        row.classList.toggle('hidden', !ok);
        if (ok) visible += 1;
      });
      if (filteredCount) {
        filteredCount.textContent = visible + ' / ' + rows.length + ' visible';
      }
      vscode.setState({
        textFilter: textFilter.value || '',
        gradeFilter: gradeFilter.value || '',
        flagFilter: flagFilter.value || '',
        sinceRef: sinceRef ? (sinceRef.value || '') : '',
      });
    }

    textFilter.addEventListener('input', applyFilters);
    gradeFilter.addEventListener('change', applyFilters);
    flagFilter.addEventListener('change', applyFilters);

    document.getElementById('quickUnused').addEventListener('click', () => { flagFilter.value = 'unused'; applyFilters(); });
    document.getElementById('quickUncovered').addEventListener('click', () => { flagFilter.value = 'uncovered'; applyFilters(); });
    document.getElementById('quickStub').addEventListener('click', () => { flagFilter.value = 'stub_tested'; applyFilters(); });
    document.getElementById('quickSuspicious').addEventListener('click', () => { flagFilter.value = 'suspicious_coverage'; applyFilters(); });
    document.getElementById('quickDrift').addEventListener('click', () => { flagFilter.value = 'test_drift'; applyFilters(); });
    document.getElementById('clearFilters').addEventListener('click', () => {
      textFilter.value = '';
      gradeFilter.value = '';
      flagFilter.value = '';
      applyFilters();
    });
    document.getElementById('openFullReport').addEventListener('click', () => {
      vscode.postMessage({ type: 'openFullReport' });
    });
    document.getElementById('refreshScan').addEventListener('click', () => {
      vscode.postMessage({ type: 'refreshScan' });
    });
    document.getElementById('copyJson').addEventListener('click', () => {
      vscode.postMessage({ type: 'copyJson' });
    });
    document.getElementById('openPvSettings').addEventListener('click', () => {
      vscode.postMessage({ type: 'openProjectVibrancySettings' });
    });
    applySince.addEventListener('click', () => {
      if (scopeBadge) scopeBadge.textContent = (sinceRef && sinceRef.value.trim().length > 0) ? ('since: ' + sinceRef.value.trim()) : 'all files';
      vscode.postMessage({ type: 'setSinceRef', since: sinceRef ? sinceRef.value : '' });
    });
    clearSince.addEventListener('click', () => {
      if (sinceRef) sinceRef.value = '';
      if (scopeBadge) scopeBadge.textContent = 'all files';
      vscode.postMessage({ type: 'setSinceRef', since: '' });
    });

    document.querySelectorAll('.file-link').forEach((el) => {
      el.addEventListener('click', () => {
        vscode.postMessage({
          type: 'openFile',
          file: el.getAttribute('data-file'),
          line: Number(el.getAttribute('data-line') || '1'),
        });
      });
    });
    applyFilters();
  </script>
</body>
</html>`;
  }

  private async _handleMessage(msg: unknown): Promise<void> {
    const data = msg as { type?: string; file?: string; line?: number; since?: string };
    if (data.type === 'openFullReport') {
      await vscode.commands.executeCommand('saropaLints.openProjectVibrancyReport');
      return;
    }
    if (data.type === 'refreshScan') {
      await this.refresh();
      return;
    }
    if (data.type === 'copyJson') {
      if (this._lastRawStdout.trim().length === 0) {
        void vscode.window.showInformationMessage('Run a scan first, then copy JSON.');
        return;
      }
      await vscode.env.clipboard.writeText(this._lastRawStdout);
      void vscode.window.showInformationMessage('Project Vibrancy JSON copied to clipboard.');
      return;
    }
    if (data.type === 'openProjectVibrancySettings') {
      await vscode.commands.executeCommand('saropaLints.openProjectVibrancySettings');
      return;
    }
    if (data.type === 'setSinceRef') {
      this._sinceRef = (data.since ?? '').trim();
      await this.refresh();
      return;
    }
    if (data.type === 'openFile' && typeof data.file === 'string') {
      await openFileAtLine(data.file, data.line ?? 1);
    }
  }
}

async function openFileAtLine(relativePath: string, line: number): Promise<void> {
  const root = getProjectRoot();
  if (!root) {
    return;
  }
  try {
    const uri = vscode.Uri.joinPath(vscode.Uri.file(root), relativePath);
    const doc = await vscode.workspace.openTextDocument(uri);
    const editor = await vscode.window.showTextDocument(doc);
    const targetLine = Math.max(0, line - 1);
    const pos = new vscode.Position(targetLine, 0);
    editor.selection = new vscode.Selection(pos, pos);
    editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
  } catch {
    void vscode.window.showErrorMessage(`Could not open file: ${relativePath}`);
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll('\'', '&#39;');
}
