// Single webview: rule text, impact, related rules, and external doc links.
/**
 * "Explain rule" panel: opens a webview tab beside the editor with full rule details
 * (message, correction, severity, impact, OWASP, doc link). Invoked from Issues tree
 * right-click or command palette. Reuses a single panel; link clicks open in browser via postMessage.
 */

import * as vscode from 'vscode';
import { createWebviewCspNonce, jsonForScriptBlock } from '../vibrancy/views/html-utils';
import { Violation, OwaspData } from '../violationsReader';
import { getRuleExplainPanelStyles } from './ruleExplainPanelStyles';
import {
  getRelatedRules,
  getRuleDocUrl,
  getSameTagRules,
  getSupersedesRules,
} from '../ruleMetadata';

const VIEW_TYPE = 'saropaLints.ruleExplain';
const PANEL_TITLE = 'Rule: ';

type RuleExplainTelemetryEvent = 'open' | 'relatedClick' | 'docClick';
type RuleExplainTelemetry = (
  event: RuleExplainTelemetryEvent,
  props?: Record<string, string>,
) => void;

let ruleExplainTelemetry: RuleExplainTelemetry | undefined;

export function setRuleExplainTelemetry(telemetry?: RuleExplainTelemetry): void {
  ruleExplainTelemetry = telemetry;
}

export interface RuleExplainInput {
  ruleName: string;
  message?: string;
  correction?: string;
  severity?: string;
  impact?: string;
  owasp?: OwaspData;
  /** Optional location for context (e.g. "lib/main.dart:42") */
  location?: string;
  relatedRules?: string[];
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
  const relatedRules = (input.relatedRules ?? getRelatedRules(input.ruleName))
    .filter((r) => r !== input.ruleName);
  const sameTagRules = getSameTagRules(input.ruleName).filter((r) => r !== input.ruleName);
  const supersedesRules = getSupersedesRules(input.ruleName).filter((r) => r !== input.ruleName);
  const relatedHtml = relatedRules.length
    ? `<section class="block"><h2>Related rules</h2><p>${relatedRules
        .map((r) => `<a href="#" class="related-rule" data-section="related" data-rule="${escapeHtml(r)}"><code>${escapeHtml(r)}</code></a>`)
        .join(', ')}</p></section>`
    : '';
  const sameTagHtml = sameTagRules.length
    ? `<section class="block"><h2>Same-tag discovery</h2><p>${sameTagRules
        .map((r) => `<a href="#" class="related-rule" data-section="sameTag" data-rule="${escapeHtml(r)}"><code>${escapeHtml(r)}</code></a>`)
        .join(', ')}</p></section>`
    : '';
  const supersedesHtml = supersedesRules.length
    ? `<section class="block"><h2>Migration</h2><p>This rule supersedes ${supersedesRules
        .map((r) => `<a href="#" class="related-rule" data-section="supersedes" data-rule="${escapeHtml(r)}"><code>${escapeHtml(r)}</code></a>`)
        .join(', ')}.</p></section>`
    : '';

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

  const cspNonce = createWebviewCspNonce();
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${cspNonce}'; script-src 'nonce-${cspNonce}';">
  <title>${rule}</title>
  <style nonce="${cspNonce}">${getRuleExplainPanelStyles()}</style>
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
  ${relatedHtml}
  ${sameTagHtml}
  ${supersedesHtml}

  <section class="block">
    <h2>Documentation</h2>
    <p><a href="${escapeHtml(docUrl)}" data-url="${escapeHtml(docUrl)}" class="doc-link">View in ROADMAP</a></p>
  </section>
  <script nonce="${cspNonce}">
    (function() {
      const vscode = acquireVsCodeApi();
      // jsonForScriptBlock instead of bare JSON.stringify: a rule name containing
      // the substring "</script>" would otherwise terminate this script block and
      // let the rest parse as HTML. JSON.stringify does not escape that sequence.
      const sourceRuleName = ${jsonForScriptBlock(input.ruleName)};
      document.querySelectorAll('a.doc-link[data-url]').forEach(function(link) {
        link.addEventListener('click', function(e) {
          e.preventDefault();
          vscode.postMessage({ type: 'openUrl', url: link.dataset.url, ruleName: sourceRuleName });
        });
      });
      document.querySelectorAll('a.related-rule[data-rule]').forEach(function(link) {
        link.addEventListener('click', function(e) {
          e.preventDefault();
          vscode.postMessage({
            type: 'openRule',
            ruleName: link.dataset.rule,
            sourceRule: sourceRuleName,
            section: link.dataset.section,
          });
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
  ruleExplainTelemetry?.('open', { ruleName: input.ruleName });
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

  activePanel.webview.onDidReceiveMessage(
    (msg: {
      type: string;
      url?: string;
      ruleName?: string;
      sourceRule?: string;
      section?: string;
    }) => {
    if (msg.type === 'openUrl' && msg.url) {
      ruleExplainTelemetry?.('docClick', {
        ruleName: msg.ruleName ?? input.ruleName,
      });
      void vscode.env.openExternal(vscode.Uri.parse(msg.url));
    }
      if (msg.type === 'openRule' && typeof msg.ruleName === 'string') {
        ruleExplainTelemetry?.('relatedClick', {
          sourceRule: msg.sourceRule ?? input.ruleName,
          targetRule: msg.ruleName,
          section: msg.section ?? 'unknown',
        });
        openRuleExplainPanel({ ruleName: msg.ruleName });
      }
    }
  );

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
