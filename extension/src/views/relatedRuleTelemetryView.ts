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
import { getDashboardChromeStyles } from './dashboardChromeStyles';
import {
  buildDashboardHero,
  buildDocumentTitle,
  buildStatusLine,
  formatRelativeTimestamp,
  getFullWidthToggleScript,
} from './dashboardHero';

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

  // Status line carries the highest-signal facts: how recent the data is, how many
  // events fired, when the last event landed. Plain "Never" if nothing has fired.
  const totalEvents = Object.values(snapshot.counters).reduce((n, v) => n + (v ?? 0), 0);
  const relative = formatRelativeTimestamp(snapshot.lastEventAt);
  const statusLineHtml = buildStatusLine([
    {
      glyph: '⟳',
      label: relative ? `Last event ${relative}` : 'No events recorded',
      tone: relative ? 'neutral' : 'warn',
      title: snapshot.lastEventAt ?? 'Never',
    },
    { label: `${totalEvents} total event${totalEvents === 1 ? '' : 's'}` },
  ]);
  const heroHtml = buildDashboardHero({
    title: 'Related Rule Telemetry',
    statusLineHtml,
  });

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <title>${escapeHtml(buildDocumentTitle('Related Rule Telemetry'))}</title>
  <style nonce="${nonce}">
    ${getDashboardChromeStyles()}
    table.tel-table {
      border-collapse: collapse;
      width: 100%;
      margin-bottom: 14px;
      background: var(--surface-2);
      border: 1px solid var(--border);
      border-radius: 8px;
      overflow: hidden;
    }
    table.tel-table th, table.tel-table td {
      padding: 8px 12px;
      text-align: left;
      border-bottom: 1px solid var(--border);
    }
    table.tel-table tbody tr:last-child td { border-bottom: 0; }
    table.tel-table th {
      background: var(--surface-3);
      font-weight: 600;
      font-size: 0.82em;
      text-transform: uppercase;
      letter-spacing: 0.3px;
      color: var(--muted);
    }
    pre.tel-pre {
      background: var(--surface-2);
      border: 1px solid var(--border);
      border-left: 2px solid var(--border-strong);
      border-radius: 8px;
      padding: 10px 12px;
      overflow: auto;
    }
  </style>
</head>
<body>
  ${heroHtml}
  <section class="toolbar-band" aria-label="Telemetry actions">
    <div class="toolbar-row">
      <button type="button" class="btn tier-1" id="refresh" title="Reload telemetry counters from disk">
        <span class="glyph">⟳</span>Refresh
      </button>
      <button type="button" class="btn" id="copy" title="Copy snapshot as JSON">
        <span class="glyph">⎘</span>Copy JSON
      </button>
      <button type="button" class="btn danger" id="reset" title="Reset all counters">
        <span class="glyph">⊘</span>Reset counters
      </button>
    </div>
  </section>
  <section class="section" aria-label="Counters">
    <h2>Event counters</h2>
    <table class="tel-table">
      <thead><tr><th>Event</th><th>Count</th></tr></thead>
      <tbody>
        ${renderRows(snapshot)}
      </tbody>
    </table>
  </section>
  <section class="section" aria-label="Last event properties">
    <h2>Last event properties</h2>
    <pre class="tel-pre">${lastProps}</pre>
  </section>
  <script nonce="${nonce}">
    (function () {
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
      ${getFullWidthToggleScript()}
    })();
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
