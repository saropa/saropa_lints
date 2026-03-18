/**
 * "Explain rule" panel: opens a webview tab beside the editor with full rule details
 * (message, correction, severity, impact, OWASP, doc link). Invoked from Issues tree
 * right-click or command palette. Reuses a single panel; link clicks open in browser via postMessage.
 */

import * as vscode from 'vscode';
import { Violation, OwaspData } from '../violationsReader';
import { getRuleDocUrl } from '../ruleMetadata';

const VIEW_TYPE = 'saropaLints.ruleExplain';
const PANEL_TITLE = 'Rule: ';

export interface RuleExplainInput {
  ruleName: string;
  message?: string;
  correction?: string;
  severity?: string;
  impact?: string;
  owasp?: OwaspData;
  /** Optional location for context (e.g. "lib/main.dart:42") */
  location?: string;
}

function fromViolation(v: Violation): RuleExplainInput {
  return {
    ruleName: v.rule,
    message: v.message,
    correction: v.correction,
    severity: v.severity,
    impact: v.impact,
    owasp: v.owasp,
    location: `${v.file}:${v.line}`,
  };
}

/** Escape user content for HTML (matches vibrancy/views/html-utils for consistency). */
function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function buildHtml(input: RuleExplainInput): string {
  const rule = escapeHtml(input.ruleName);
  const message = input.message ? escapeHtml(input.message) : '';
  const correction = input.correction ? escapeHtml(input.correction) : '';
  const severity = input.severity ? escapeHtml(input.severity) : '';
  const impact = input.impact ? escapeHtml(input.impact) : '';
  const location = input.location ? escapeHtml(input.location) : '';
  const docUrl = getRuleDocUrl(input.ruleName);

  const owaspLines: string[] = [];
  if (input.owasp?.mobile?.length) {
    owaspLines.push(`Mobile: ${input.owasp.mobile.join(', ')}`);
  }
  if (input.owasp?.web?.length) {
    owaspLines.push(`Web: ${input.owasp.web.join(', ')}`);
  }
  const owaspHtml = owaspLines.length
    ? `<section class="block"><h3>OWASP</h3><p>${owaspLines.map((l) => escapeHtml(l)).join('</p><p>')}</p></section>`
    : '';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
  <title>${rule}</title>
  <style>
    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
      padding: 1rem 1.5rem;
      line-height: 1.5;
      margin: 0;
    }
    h1 {
      font-size: 1.25rem;
      font-weight: 600;
      margin: 0 0 0.5rem 0;
      word-break: break-all;
    }
    h2, h3 {
      font-size: 0.9rem;
      font-weight: 600;
      margin: 1rem 0 0.4rem 0;
      color: var(--vscode-descriptionForeground);
    }
    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem 1.5rem;
      margin-bottom: 1rem;
      font-size: 0.85rem;
      color: var(--vscode-descriptionForeground);
    }
    .meta span {
      display: inline-flex;
      align-items: center;
      gap: 0.25rem;
    }
    .meta .badge {
      padding: 0.15rem 0.5rem;
      border-radius: 4px;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
    }
    section.block {
      margin-top: 1rem;
      padding-top: 1rem;
      border-top: 1px solid var(--vscode-widget-border);
    }
    section.block p {
      margin: 0.25rem 0 0 0;
      white-space: pre-wrap;
      word-break: break-word;
    }
    a {
      color: var(--vscode-textLink-foreground);
    }
    a:hover {
      color: var(--vscode-textLink-activeForeground);
    }
    .empty {
      color: var(--vscode-descriptionForeground);
      font-style: italic;
    }
  </style>
</head>
<body>
  <h1>${rule}</h1>
  <div class="meta">
    ${location ? `<span>📍 ${location}</span>` : ''}
    ${severity ? `<span><span class="badge">${severity}</span></span>` : ''}
    ${impact ? `<span><span class="badge">${impact}</span></span>` : ''}
  </div>

  <section class="block">
    <h2>Problem</h2>
    <p>${message || '<span class="empty">No message</span>'}</p>
  </section>

  ${correction ? `<section class="block"><h2>How to fix</h2><p>${correction}</p></section>` : ''}

  ${owaspHtml}

  <section class="block">
    <h2>Documentation</h2>
    <p><a href="${escapeHtml(docUrl)}" data-url="${escapeHtml(docUrl)}" class="doc-link">View in ROADMAP</a></p>
  </section>
  <script>
    (function() {
      const vscode = acquireVsCodeApi();
      document.querySelectorAll('a.doc-link[data-url]').forEach(function(link) {
        link.addEventListener('click', function(e) {
          e.preventDefault();
          vscode.postMessage({ type: 'openUrl', url: link.dataset.url });
        });
      });
    })();
  </script>
</body>
</html>`;
}

let activePanel: vscode.WebviewPanel | undefined;

/**
 * Opens the rule explain panel to the side of the active editor with the given
 * rule details. Reuses the existing panel if already open (updates title and content).
 */
export function openRuleExplainPanel(input: RuleExplainInput): void {
  const title = PANEL_TITLE + input.ruleName;

  if (activePanel) {
    activePanel.reveal(vscode.ViewColumn.Beside);
    activePanel.title = title;
    activePanel.webview.html = buildHtml(input);
    return;
  }

  activePanel = vscode.window.createWebviewPanel(
    VIEW_TYPE,
    title,
    vscode.ViewColumn.Beside,
    { enableScripts: true },
  );

  activePanel.webview.html = buildHtml(input);

  activePanel.webview.onDidReceiveMessage((msg: { type: string; url?: string }) => {
    if (msg.type === 'openUrl' && msg.url) {
      void vscode.env.openExternal(vscode.Uri.parse(msg.url));
    }
  });

  activePanel.onDidDispose(() => {
    activePanel = undefined;
  });
}

/**
 * Opens the rule explain panel from a violation (e.g. Issues tree context menu).
 */
export function openRuleExplainPanelForViolation(violation: Violation): void {
  openRuleExplainPanel(fromViolation(violation));
}
