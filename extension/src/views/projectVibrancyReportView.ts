import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { runProjectVibrancyScan } from './projectVibrancyCliRunner';
import type { ProjectVibrancyPayload } from './projectVibrancyTypes';

let currentPanel: vscode.WebviewPanel | undefined;
let lastReportRawStdout = '';

export async function openProjectVibrancyReport(): Promise<void> {
  const projectRoot = getProjectRoot();
  if (!projectRoot) {
    void vscode.window.showErrorMessage('Open a Dart/Flutter workspace first.');
    return;
  }

  const scan = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Project Vibrancy: scanning functions...',
      cancellable: false,
    },
    async () => runProjectVibrancyScan(projectRoot, {}),
  );

  if (!scan.payload) {
    return;
  }

  lastReportRawStdout = scan.rawStdout;
  const panel = getOrCreatePanel();
  panel.webview.html = buildHtml(scan.payload);
  panel.reveal(vscode.ViewColumn.One);
}

function getOrCreatePanel(): vscode.WebviewPanel {
  if (currentPanel) {
    return currentPanel;
  }

  currentPanel = vscode.window.createWebviewPanel(
    'saropaProjectVibrancyReport',
    'Project Vibrancy Report',
    vscode.ViewColumn.One,
    { enableScripts: true, retainContextWhenHidden: true },
  );

  currentPanel.onDidDispose(() => {
    currentPanel = undefined;
  });

  currentPanel.webview.onDidReceiveMessage(async (msg: unknown) => {
    const data = msg as { type?: string; file?: string; line?: number };
    if (data.type === 'copyJson') {
      if (lastReportRawStdout.trim().length === 0) {
        void vscode.window.showInformationMessage('Run the report again, then copy JSON.');
        return;
      }
      await vscode.env.clipboard.writeText(lastReportRawStdout);
      void vscode.window.showInformationMessage('Project Vibrancy JSON copied to clipboard.');
      return;
    }
    if (data.type === 'openProjectVibrancySettings') {
      await vscode.commands.executeCommand('saropaLints.openProjectVibrancySettings');
      return;
    }
    if (data.type !== 'openFile' || typeof data.file !== 'string') {
      return;
    }
    await openFileAtLine(data.file, data.line ?? 1);
  });

  return currentPanel;
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

function buildHtml(payload: ProjectVibrancyPayload): string {
  const summary = payload.summary ?? {};
  const rows = [...(payload.functions ?? [])]
    .sort((a, b) => a.score - b.score)
    .slice(0, 200);
  const nonce = String(Date.now());
  const generatedAt = payload.generatedAt ?? 'unknown';
  const averageScore = (summary.averageScore ?? 0).toFixed(1);
  const avgGrade = summary.averageGrade ?? '—';
  const functionCount = summary.functionCount ?? rows.length;
  const unusedCount = summary.unusedCount ?? rows.filter((r) => r.flags.includes('unused')).length;
  const uncoveredCount = summary.uncoveredCount ?? rows.filter((r) => r.flags.includes('uncovered')).length;
  const stubTestedCount =
    summary.stubTestedCount ?? rows.filter((r) => r.flags.includes('stub_tested')).length;
  const suspiciousCoverageCount =
    summary.suspiciousCoverageCount ??
    rows.filter((r) => r.flags.includes('suspicious_coverage')).length;
  const testDriftCount =
    summary.testDriftCount ?? rows.filter((r) => r.flags.includes('test_drift')).length;
  const gateFailed = payload.gates?.pass === false;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';">
  <style>
    body { font-family: var(--vscode-font-family); padding: 16px; color: var(--vscode-foreground); }
    .toolbar { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 12px; }
    .toolbar button { border: 1px solid var(--vscode-button-border, var(--vscode-panel-border)); background: var(--vscode-button-secondaryBackground); color: var(--vscode-button-secondaryForeground); border-radius: 5px; padding: 4px 10px; cursor: pointer; }
    .gate-warn { margin: 0 0 12px 0; padding: 8px 10px; border-radius: 4px; border-left: 3px solid var(--vscode-inputValidation-errorBorder); background: var(--vscode-inputValidation-errorBackground); color: var(--vscode-inputValidation-errorForeground); font-size: 12px; }
    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 8px; margin-bottom: 16px; }
    .card { border: 1px solid var(--vscode-panel-border); border-radius: 8px; padding: 10px; background: var(--vscode-editor-background); }
    .k { font-size: 11px; opacity: 0.8; text-transform: uppercase; }
    .v { font-size: 20px; font-weight: 700; margin-top: 4px; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; }
    th, td { border-bottom: 1px solid var(--vscode-panel-border); padding: 6px 8px; text-align: left; }
    th { position: sticky; top: 0; background: var(--vscode-editor-background); }
    .file-link { cursor: pointer; color: var(--vscode-textLink-foreground); text-decoration: underline; }
    .flags { opacity: 0.85; }
  </style>
</head>
<body>
  <h2>Project Vibrancy Report</h2>
  <div class="toolbar">
    <button id="copyJson">Copy JSON</button>
    <button id="openPvSettings">Project Vibrancy settings</button>
  </div>
  ${gateFailed ? '<div class="gate-warn">Quality gates failed. Adjust <strong>Project Vibrancy</strong> in Settings, or inspect copied JSON (<code>gates.violations</code>).</div>' : ''}
  <p>Generated: ${escapeHtml(generatedAt)} · Showing worst 200 functions by score</p>
  <div class="summary">
    <div class="card"><div class="k">Average</div><div class="v">${escapeHtml(averageScore)} (${escapeHtml(avgGrade)})</div></div>
    <div class="card"><div class="k">Functions</div><div class="v">${functionCount}</div></div>
    <div class="card"><div class="k">Unused / Uncovered</div><div class="v">${unusedCount} / ${uncoveredCount}</div></div>
    <div class="card"><div class="k">stub / susp / drift</div><div class="v">${stubTestedCount} / ${suspiciousCoverageCount} / ${testDriftCount}</div></div>
    <div class="card"><div class="k">Top risk (rows)</div><div class="v">${rows.length}</div></div>
  </div>
  <table>
    <thead><tr>
      <th>Grade</th><th>Score</th><th>Function</th><th>File</th><th>Line</th>
      <th>Usage</th><th>Coverage</th><th>Complexity</th><th>Flags</th>
    </tr></thead>
    <tbody>
      ${rows.map((row) => `
      <tr>
        <td>${escapeHtml(row.grade)}</td>
        <td>${row.score.toFixed(1)}</td>
        <td>${escapeHtml(row.name)}</td>
        <td><span class="file-link" data-file="${escapeHtml(row.file)}" data-line="${row.lineStart}">${escapeHtml(row.file)}</span></td>
        <td>${row.lineStart}-${row.lineEnd}</td>
        <td>${row.usageCount}</td>
        <td>${row.coveragePercent.toFixed(1)}%</td>
        <td>${row.complexity}</td>
        <td class="flags">${escapeHtml(row.flags.join(', '))}</td>
      </tr>
      `).join('')}
    </tbody>
  </table>
  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi();
    document.getElementById('copyJson').addEventListener('click', () => {
      vscode.postMessage({ type: 'copyJson' });
    });
    document.getElementById('openPvSettings').addEventListener('click', () => {
      vscode.postMessage({ type: 'openProjectVibrancySettings' });
    });
    document.querySelectorAll('.file-link').forEach((el) => {
      el.addEventListener('click', () => {
        const file = el.getAttribute('data-file');
        const line = Number(el.getAttribute('data-line') || '1');
        if (!file) return;
        vscode.postMessage({ type: 'openFile', file, line });
      });
    });
  </script>
</body>
</html>`;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll('\'', '&#39;');
}
