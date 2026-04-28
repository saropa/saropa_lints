import * as vscode from 'vscode';
import type {
  RelatedRuleTelemetry,
  TelemetryStore,
} from '../relatedRuleTelemetry';

let currentPanel: vscode.WebviewPanel | undefined;

function escapeHtml(text: string): string {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function renderRows(snapshot: TelemetryStore): string {
  const events = [
    'ruleExplain.open',
    'ruleExplain.relatedClick',
    'ruleExplain.docClick',
    'suggestions.relatedRuleOpen',
  ];

  return events
    .map((event) => {
      const value = snapshot.counters[event] ?? 0;
      return `<tr><td><code>${escapeHtml(event)}</code></td><td>${value}</td></tr>`;
    })
    .join('');
}

function buildHtml(snapshot: TelemetryStore): string {
  const lastEventAt = snapshot.lastEventAt
    ? escapeHtml(snapshot.lastEventAt)
    : 'Never';
  const lastProps = snapshot.lastProperties
    ? escapeHtml(JSON.stringify(snapshot.lastProperties, null, 2))
    : '{}';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
  <title>Related Rule Telemetry</title>
  <style>
    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
      margin: 0;
      padding: 16px;
      line-height: 1.45;
    }
    h1 { margin: 0 0 12px; font-size: 1.2rem; }
    .toolbar { display: flex; gap: 8px; margin-bottom: 14px; }
    button {
      background: var(--vscode-button-background);
      color: var(--vscode-button-foreground);
      border: none;
      border-radius: 4px;
      padding: 6px 10px;
      cursor: pointer;
    }
    button:hover { background: var(--vscode-button-hoverBackground); }
    table {
      border-collapse: collapse;
      width: 100%;
      max-width: 720px;
      margin-bottom: 14px;
    }
    th, td {
      border: 1px solid var(--vscode-panel-border);
      padding: 8px 10px;
      text-align: left;
    }
    th { background: var(--vscode-editor-inactiveSelectionBackground); }
    .meta {
      color: var(--vscode-descriptionForeground);
      font-size: 0.9rem;
      margin-bottom: 10px;
    }
    pre {
      background: var(--vscode-textBlockQuote-background);
      border-left: 2px solid var(--vscode-panel-border);
      padding: 10px;
      overflow: auto;
      max-width: 720px;
    }
  </style>
</head>
<body>
  <h1>Related Rule Telemetry</h1>
  <div class="toolbar">
    <button id="refresh">Refresh</button>
    <button id="copy">Copy JSON</button>
    <button id="reset">Reset Counters</button>
  </div>
  <div class="meta">Last event: ${lastEventAt}</div>
  <table>
    <thead><tr><th>Event</th><th>Count</th></tr></thead>
    <tbody>
      ${renderRows(snapshot)}
    </tbody>
  </table>
  <div class="meta">Last event properties</div>
  <pre>${lastProps}</pre>
  <script>
    const vscode = acquireVsCodeApi();
    document.getElementById('refresh').addEventListener('click', () => {
      vscode.postMessage({ type: 'refresh' });
    });
    document.getElementById('copy').addEventListener('click', () => {
      vscode.postMessage({ type: 'copy' });
    });
    document.getElementById('reset').addEventListener('click', () => {
      vscode.postMessage({ type: 'reset' });
    });
  </script>
</body>
</html>`;
}

function refreshPanel(telemetry: RelatedRuleTelemetry): void {
  if (!currentPanel) return;
  currentPanel.webview.html = buildHtml(telemetry.snapshot());
}

export function showRelatedRuleTelemetryPanel(
  telemetry: RelatedRuleTelemetry,
): void {
  if (currentPanel) {
    currentPanel.reveal(vscode.ViewColumn.One);
    refreshPanel(telemetry);
    return;
  }

  currentPanel = vscode.window.createWebviewPanel(
    'saropaLints.relatedRuleTelemetry',
    'Saropa Lints: Related Rule Telemetry',
    vscode.ViewColumn.One,
    { enableScripts: true },
  );

  refreshPanel(telemetry);

  currentPanel.webview.onDidReceiveMessage((message: { type?: string }) => {
    if (message.type === 'refresh') {
      refreshPanel(telemetry);
      return;
    }
    if (message.type === 'copy') {
      const raw = JSON.stringify(telemetry.snapshot(), null, 2);
      void vscode.env.clipboard.writeText(raw);
      void vscode.window.showInformationMessage(
        'Saropa Lints: copied related rule telemetry JSON.',
      );
      return;
    }
    if (message.type === 'reset') {
      telemetry.reset();
      refreshPanel(telemetry);
      void vscode.window.showInformationMessage(
        'Saropa Lints: related rule telemetry counters reset.',
      );
    }
  });

  currentPanel.onDidDispose(() => {
    currentPanel = undefined;
  });
}
