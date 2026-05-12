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
import {
  buildKeyboardShortcutsButton,
  buildKeyboardShortcutsOverlay,
  getKeyboardShortcutsScript,
  getKeyboardShortcutsStyles,
} from './keyboard-shortcuts';
import { pluralize } from './webview-format';
import { l10n } from '../i18n/runtime';

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

  // §7.1 / §8.3 — count column is right-aligned and nowrap so wide integers
  // do not wrap mid-number on narrow panes; the .num class hooks the CSS.
  return events
    .map((event) => {
      const value = snapshot.counters[event] ?? 0;
      return `<tr><td><code>${escapeHtml(event)}</code></td><td class="num">${value}</td></tr>`;
    })
    .join('');
}

/**
 * Compose the Related Rule Telemetry HTML. Exported so unit tests can assert
 * the rendered structure (numeric column alignment, button tier hierarchy,
 * disabled-Reset state, empty-state CTA) without standing up a real webview.
 */
export function buildRelatedRuleTelemetryHtml(snapshot: TelemetryStore): string {
  return buildHtml(snapshot);
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
      label: relative ? l10n('telemetry.lastEvent', { relative }) : l10n('telemetry.noEvents'),
      tone: relative ? 'neutral' : 'warn',
      title: snapshot.lastEventAt ?? 'Never',
    },
    { label: pluralize(totalEvents, { one: l10n('telemetry.totalEventOne'), other: l10n('telemetry.totalEventOther') }) },
  ]);
  const heroHtml = buildDashboardHero({
    title: l10n('telemetry.heroTitle'),
    statusLineHtml,
    extraToggleHtml: buildKeyboardShortcutsButton(),
  });

  // §8.10 — *Reset* targets an empty set when no events have fired; render
  // it disabled with a tooltip explaining why instead of letting the click
  // fire silently. *Refresh* drops its tier-1 styling: on a counter table
  // no action dominates strongly enough to deserve primary emphasis, so
  // every action is a tier-2 .btn and tier-1 stays unused (§8.10's
  // "one emphasized button per region" — zero is also valid).
  const resetDisabled = totalEvents === 0;
  const resetAttrs = resetDisabled
    ? ` disabled aria-disabled="true" title="${escapeHtml(l10n('telemetry.noCountersTitle'))}"`
    : ` title="${escapeHtml(l10n('telemetry.resetTitle'))}"`;


  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <title>${escapeHtml(buildDocumentTitle(l10n('telemetry.heroTitle')))}</title>
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
    /* §7.1 / §8.3 — numeric columns right-align with nowrap so wide
       integers (1.2M, 12.3k) stay readable in narrow panes. */
    table.tel-table th:last-child,
    table.tel-table td.num {
      text-align: right;
      white-space: nowrap;
      font-variant-numeric: tabular-nums;
      width: 96px;
    }
    pre.tel-pre {
      background: var(--surface-2);
      border: 1px solid var(--border);
      border-inline-start: 2px solid var(--border-strong);
      border-radius: 8px;
      padding: 10px 12px;
      overflow: auto;
    }
    /* §8.16 — empty-state pattern: dashed border + centered CTA so the
       block is clearly an actionable empty state, not absent content. */
    .empty-cta {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 10px;
      padding: 24px 16px;
      margin: 0 0 12px;
      border: 1px dashed var(--border);
      border-radius: 6px;
      background: var(--surface-2);
    }
    .empty-cta .empty-msg {
      margin: 0;
      color: var(--muted);
      font-size: 0.95em;
      text-align: center;
    }
    ${getKeyboardShortcutsStyles()}
  </style>
</head>
<body>
  <a href="#tel-main" class="skip-link">${escapeHtml(l10n('telemetry.skipToCounters'))}</a>
  <div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
  <header>${heroHtml}</header>
  <section class="toolbar-band" aria-label="${escapeHtml(l10n('telemetry.countersAria'))}">
    <div class="toolbar-row">
      <button type="button" class="btn" id="refresh" title="${escapeHtml(l10n('telemetry.refreshTitle'))}">
        <span class="glyph" aria-hidden="true">⟳</span>${escapeHtml(l10n('telemetry.refresh'))}
      </button>
      <button type="button" class="btn" id="copy" title="${escapeHtml(l10n('telemetry.copyTitle'))}">
        <span class="glyph" aria-hidden="true">⎘</span>${escapeHtml(l10n('telemetry.copyJson'))}
      </button>
      <button type="button" class="btn danger" id="reset"${resetAttrs}>
        <span class="glyph" aria-hidden="true">⊘</span>${escapeHtml(l10n('telemetry.resetCounters'))}
      </button>
    </div>
  </section>
  <main id="tel-main" tabindex="-1">
  <section class="section" aria-label="${escapeHtml(l10n('telemetry.countersAria'))}">
    <h2>${escapeHtml(l10n('telemetry.countersHeading'))}</h2>
    ${totalEvents === 0
      ? `<!-- §8.16 — empty-state CTA replaces the blank counter table when
              no events have fired. The Findings Dashboard is the natural
              place users open rules from, which is what generates the
              ruleExplain.* counters tracked here. -->
         <div class="empty-cta" role="status">
           <p class="empty-msg">${escapeHtml(l10n('telemetry.emptyMessage'))}</p>
           <button type="button" class="btn tier-1" id="openFindings"
             title="${escapeHtml(l10n('telemetry.openFindingsTitle'))}">${escapeHtml(l10n('telemetry.openFindings'))}</button>
         </div>`
      : `<table class="tel-table">
      <thead><tr><th>${escapeHtml(l10n('telemetry.thEvent'))}</th><th>${escapeHtml(l10n('telemetry.thCount'))}</th></tr></thead>
      <tbody>
        ${renderRows(snapshot)}
      </tbody>
    </table>`}
  </section>
  <section class="section" aria-label="${escapeHtml(l10n('telemetry.lastPropsHeading'))}">
    <h2>${escapeHtml(l10n('telemetry.lastPropsHeading'))}</h2>
    <pre class="tel-pre">${lastProps}</pre>
  </section>
  </main>
  ${buildKeyboardShortcutsOverlay([
    { key: '?', label: 'Show this shortcut overlay' },
    { key: 'Esc', label: 'Close the keyboard-shortcut overlay' },
  ])}
  <script nonce="${nonce}">
    (function () {
      const vscode = acquireVsCodeApi();
      document.getElementById('refresh').addEventListener('click', () => {
        vscode.postMessage({ type: 'refresh' });
      });
      document.getElementById('copy').addEventListener('click', () => {
        vscode.postMessage({ type: 'copy' });
      });
      // §8.10 — Reset is rendered disabled when totalEvents === 0; the
      // listener must guard against the disabled click slipping through
      // (some hosts dispatch click on disabled buttons via keyboard).
      const resetBtn = document.getElementById('reset');
      if (resetBtn) {
        resetBtn.addEventListener('click', () => {
          if (resetBtn.hasAttribute('disabled')) return;
          vscode.postMessage({ type: 'reset' });
        });
      }
      // §8.16 — Empty-state CTA. Only rendered when totalEvents === 0.
      const openFindings = document.getElementById('openFindings');
      if (openFindings) {
        openFindings.addEventListener('click', () => {
          vscode.postMessage({ type: 'openFindingsDashboard' });
        });
      }
      ${getFullWidthToggleScript()}
      ${getKeyboardShortcutsScript()}
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
    l10n('telemetry.heroTitle'),
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
        l10n('telemetry.copiedJson'),
      );
      return;
    }
    if (message.type === 'reset') {
      telemetry.reset();
      refreshPanel(telemetry);
      void vscode.window.showInformationMessage(
        l10n('telemetry.countersReset'),
      );
      return;
    }
    if (message.type === 'openFindingsDashboard') {
      // §8.16 — empty-state CTA dispatches the same command the sidebar
      // *Findings Dashboard* tree node uses; reusing the registered
      // command keeps a single open path so any future telemetry around
      // dashboard opens fires consistently regardless of entry point.
      void vscode.commands.executeCommand('saropaLints.openViolationsWideReport');
    }
  });

  currentPanel.onDidDispose(() => {
    currentPanel = undefined;
  });
}
