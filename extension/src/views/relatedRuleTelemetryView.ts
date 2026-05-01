/**
 * Related-rule telemetry webview: builds static HTML + inline script to post messages
 * back to the extension (`refresh`, `copy`, `reset`). Single panel instance reused
 * via [currentPanel]; disposal clears the handle so a new panel can open later.
 */
import * as vscode from 'vscode';
import { createWebviewCspNonce } from '../vibrancy/views/html-utils';
import type {
  RelatedRuleTelemetry,
  TelemetryStore,
} from '../relatedRuleTelemetry';

/** Active panel reference; undefined after dispose or before first open. */
let currentPanel: vscode.WebviewPanel | undefined;

/** Escape text for safe insertion into HTML text nodes and `<code>`. */
function escapeHtml(text: string): string {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** One table row per known telemetry event key; missing counters default to 0. */
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

/** Full HTML document with CSP allowing inline script for webview message bridge. */
function buildHtml(snapshot: TelemetryStore): string {
  const nonce = createWebviewCspNonce();
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
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <title>Related Rule Telemetry</title>
  <style nonce="${nonce}">
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
    .toolbar { display: flex; gap: 8px; margin-bottom: 14px; flex-wrap: wrap; }
    /* Pill shape consistent with the canonical .saropa-pill-button helper. */
    button {
      background: var(--vscode-button-secondaryBackground);
      color: var(--vscode-button-secondaryForeground);
      border: 1px solid var(--vscode-button-border, transparent);
      border-radius: 999px;
      padding: 6px 12px;
      cursor: pointer;
      transition: background 0.12s ease, border-color 0.12s ease;
    }
    button:hover {
      background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
      border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, var(--vscode-button-border, transparent));
    }
    button:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
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
    th {
      background: var(--vscode-editor-inactiveSelectionBackground);
      position: sticky;
      top: 0;
      z-index: 1;
    }
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
  <script nonce="${nonce}">
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

/** Replaces webview HTML from latest [telemetry.snapshot] if a panel is open. */
function refreshPanel(telemetry: RelatedRuleTelemetry): void {
  if (!currentPanel) return;
  currentPanel.webview.html = buildHtml(telemetry.snapshot());
}

/** Opens or focuses the telemetry panel and wires message handlers for user actions. */
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

  // Bridge: webview buttons only send types; all mutations go through [telemetry] service.
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
