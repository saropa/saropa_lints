import * as vscode from 'vscode';
import * as nodePath from 'node:path';
import { getProjectRoot } from '../projectRoot';
import { runProjectVibrancyScan } from './projectVibrancyCliRunner';
import type { ProjectVibrancyPayload } from './projectVibrancyTypes';

/**
 * **Sidebar webview** host for the project vibrancy report: shells out to [runProjectVibrancyScan],
 * parses stdout into [ProjectVibrancyPayload], renders HTML with theme-safe CSP, and wires `postMessage`
 * handlers (refresh, copy, open paths). Shows progress while the CLI runs on the workspace root.
 */
/** Sidebar webview: runs the vibrancy CLI, renders JSON payload HTML, handles refresh and messages. */

export const PROJECT_VIBRANCY_VIEW_ID = 'saropaLints.projectVibrancy';

export class ProjectVibrancySidebarProvider implements vscode.WebviewViewProvider {
  private _view: vscode.WebviewView | undefined;
  private _payload: ProjectVibrancyPayload | null = null;
  private _lastRawStdout = '';

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
      async () => runProjectVibrancyScan(projectRoot),
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
      .slice(0, 12);
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
    const activeSince = payload?.determinism?.since;
    const gateFailed = payload?.gates?.pass === false;
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';">
  <style>
    * { box-sizing: border-box; }
    body { font-family: var(--vscode-font-family); font-size: 12px; line-height: 1.4; margin: 0; padding: 10px; color: var(--vscode-foreground); }
    .shell { display: grid; gap: 8px; }
    .title { font-weight: 700; font-size: 13px; }
    .meta { opacity: 0.8; font-size: 11px; }
    .scope { display: inline-block; border: 1px solid var(--vscode-panel-border); border-radius: 999px; padding: 2px 8px; font-size: 10px; background: var(--vscode-badge-background); color: var(--vscode-badge-foreground); max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .summary { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; }
    .card { border: 1px solid var(--vscode-panel-border); border-radius: 6px; padding: 7px; background: var(--vscode-editor-background); }
    .k { font-size: 10px; opacity: 0.8; text-transform: uppercase; }
    .v { font-size: 14px; font-weight: 700; margin-top: 2px; }
    .actions { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
    .actions button:nth-child(1),
    .actions button:nth-child(2) { grid-column: span 2; }
    button { font: inherit; border: 1px solid var(--vscode-button-border, var(--vscode-panel-border)); background: var(--vscode-button-secondaryBackground); color: var(--vscode-button-secondaryForeground); border-radius: 5px; padding: 5px 8px; cursor: pointer; text-align: left; }
    button:hover { background: var(--vscode-button-secondaryHoverBackground); }
    .gate-warn { margin: 0; padding: 6px 8px; border-radius: 4px; border-left: 3px solid var(--vscode-inputValidation-errorBorder); background: var(--vscode-inputValidation-errorBackground); color: var(--vscode-inputValidation-errorForeground); font-size: 11px; }
    .risk { border: 1px solid var(--vscode-panel-border); border-radius: 6px; padding: 7px; background: var(--vscode-editor-background); }
    .risk-title { font-size: 10px; opacity: 0.8; text-transform: uppercase; margin-bottom: 6px; }
    .risk-list { display: grid; gap: 4px; max-height: 220px; overflow: auto; }
    .risk-item { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 6px; align-items: center; border: 1px solid var(--vscode-panel-border); border-radius: 5px; padding: 4px 6px; background: var(--vscode-editor-background); cursor: pointer; }
    .risk-item:hover { background: var(--vscode-list-hoverBackground); }
    .score { font-weight: 700; font-size: 11px; min-width: 32px; }
    .name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .path { opacity: 0.8; font-size: 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  </style>
</head>
<body>
  <div class="shell">
    <div class="title">Project Vibrancy</div>
    <div class="meta">Generated: ${escapeHtml(generatedAt)}</div>
    <span class="scope">${activeSince && activeSince.length > 0 ? `since: ${escapeHtml(activeSince)}` : 'all files'}</span>
    ${gateFailed ? '<div class="gate-warn">Quality gates failed (see Settings: Project Vibrancy, or copy JSON).</div>' : ''}
    <div class="summary">
      <div class="card"><div class="k">Average</div><div class="v">${escapeHtml(avgScore)} (${escapeHtml(avgGrade)})</div></div>
      <div class="card"><div class="k">Functions</div><div class="v">${functionCount}</div></div>
      <div class="card"><div class="k">Unused / Uncovered</div><div class="v">${unusedCount} / ${uncoveredCount}</div></div>
      <div class="card"><div class="k">stub / susp / drift</div><div class="v">${stubTestedCount} / ${suspiciousCoverageCount} / ${testDriftCount}</div></div>
    </div>
    <div class="actions">
      <button id="refreshScan">Refresh scan</button>
      <button id="openFullReport">Open full report</button>
      <button id="copyJson">Copy JSON</button>
      <button id="openPvSettings">Settings</button>
    </div>
    <div class="risk">
      <div class="risk-title">Top Risk Functions</div>
      <div class="risk-list">
      ${rows.length === 0 ? '<div class="meta">No results yet. Run refresh scan.</div>' : rows.map((row) => `
        <div class="risk-item file-link" data-file="${escapeHtml(row.file)}" data-line="${row.lineStart}" title="${escapeHtml(row.file)}:${row.lineStart}">
          <span class="score">${row.score.toFixed(1)}</span>
          <span>
            <div class="name">${escapeHtml(row.name)}</div>
            <div class="path">${escapeHtml(row.file)}:${row.lineStart}</div>
          </span>
        </div>
      `).join('')}
      </div>
    </div>
  </div>
  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi();
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

    document.querySelectorAll('.file-link').forEach((el) => {
      el.addEventListener('click', () => {
        vscode.postMessage({
          type: 'openFile',
          file: el.getAttribute('data-file'),
          line: Number(el.getAttribute('data-line') || '1'),
        });
      });
    });
  </script>
</body>
</html>`;
  }

  private async _handleMessage(msg: unknown): Promise<void> {
    const data = msg as { type?: string; file?: string; line?: number };
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
    const uri = resolveReportFileUri(root, relativePath);
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

function resolveReportFileUri(root: string, filePathFromReport: string): vscode.Uri {
  const raw = filePathFromReport.trim();
  const windowsAbsolute = /^[a-zA-Z]:[\\/]/.test(raw);
  const posixAbsolute = raw.startsWith('/');
  if (windowsAbsolute || posixAbsolute) {
    return vscode.Uri.file(raw);
  }
  const normalizedRelative = raw
    .replaceAll('\\', '/')
    .replace(/^(\.\/)+/, '')
    .replace(/^\/+/, '');
  return vscode.Uri.file(nodePath.resolve(root, normalizedRelative));
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll('\'', '&#39;');
}
