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
import { getDashboardChromeStyles } from './dashboardChromeStyles';
import {
  buildDashboardHero,
  buildDocumentTitle,
  buildStatusLine,
  getFullWidthToggleScript,
} from './dashboardHero';

const VIEW_TYPE = 'saropaLints.ruleExplain';
// Tab label includes the rule name so the user can scan tabs by rule. The hero `<h1>`
// is Saropa-prefixed via the shared helper (guideline §8.1) — both contracts honored.
const PANEL_TITLE = 'Saropa Rule: ';

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

/**
 * Compose the rule explain panel HTML. Exported so unit tests can assert the
 * rendered structure (heading hierarchy, inset card layout, OWASP definition
 * list, doc-link button, omitted-Problem fallback) without standing up a
 * real VS Code webview.
 */
export function buildRuleExplainHtml(input: RuleExplainInput): string {
  return buildHtml(input);
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
  // §8.1 — sub-section headings inside a single detail panel are <h4> per the
  // *Expander detail headings* rule. <h2> is reserved for major page bands;
  // every block in the rule explain panel is a sibling sub-section of the hero.
  const relatedHtml = relatedRules.length
    ? `<section class="block"><h4>Related rules</h4><p>${relatedRules
        .map((r) => `<a href="#" class="related-rule" data-section="related" data-rule="${escapeHtml(r)}"><code>${escapeHtml(r)}</code></a>`)
        .join(', ')}</p></section>`
    : '';
  const sameTagHtml = sameTagRules.length
    ? `<section class="block"><h4>Same-tag discovery</h4><p>${sameTagRules
        .map((r) => `<a href="#" class="related-rule" data-section="sameTag" data-rule="${escapeHtml(r)}"><code>${escapeHtml(r)}</code></a>`)
        .join(', ')}</p></section>`
    : '';
  const supersedesHtml = supersedesRules.length
    ? `<section class="block"><h4>Migration</h4><p>This rule supersedes ${supersedesRules
        .map((r) => `<a href="#" class="related-rule" data-section="supersedes" data-rule="${escapeHtml(r)}"><code>${escapeHtml(r)}</code></a>`)
        .join(', ')}.</p></section>`
    : '';

  // §7.2 — label/value pairs inside a detail card render as a definition list,
  // not as paragraphs. <dl> aligns the *Mobile* / *Web* labels with the
  // muted-label / value-grid pattern used elsewhere in the gold-standard.
  const owaspEntries: Array<{ label: string; value: string }> = [];
  if (input.owasp?.mobile?.length) {
    owaspEntries.push({ label: 'Mobile', value: input.owasp.mobile.join(', ') });
  }
  if (input.owasp?.web?.length) {
    owaspEntries.push({ label: 'Web', value: input.owasp.web.join(', ') });
  }
  const owaspHtml = owaspEntries.length
    ? `<section class="block"><h4>OWASP</h4><dl class="owasp-dl">${owaspEntries
        .map((e) => `<dt>${escapeHtml(e.label)}</dt><dd>${escapeHtml(e.value)}</dd>`)
        .join('')}</dl></section>`
    : '';

  const cspNonce = createWebviewCspNonce();
  // Status line carries the rule's identity facts: where it was triggered, severity, impact.
  // These are the highest-signal facts the panel knows; the existing `.meta` row was
  // visually unstyled and read as a stray string, not as the page's freshness/identity strip.
  const statusPills = [
    ...(location ? [{ glyph: '📍', label: input.location ?? '', title: input.location }] : []),
    ...(severity ? [{ label: `severity: ${input.severity ?? ''}`, tone: severityTone(input.severity) }] : []),
    ...(impact ? [{ label: `impact: ${input.impact ?? ''}`, tone: impactTone(input.impact) }] : []),
    { label: input.ruleName, title: 'Rule identifier' },
  ];
  const statusLineHtml = buildStatusLine(statusPills);
  const heroHtml = buildDashboardHero({
    title: `Rule: ${input.ruleName}`,
    statusLineHtml,
  });
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${cspNonce}'; script-src 'nonce-${cspNonce}';">
  <title>${escapeHtml(buildDocumentTitle(`Rule: ${input.ruleName}`))}</title>
  <style nonce="${cspNonce}">${getDashboardChromeStyles()}${getRuleExplainPanelStyles()}</style>
</head>
<body>
  <a href="#rule-detail" class="skip-link">Skip to rule details</a>
  <header>${heroHtml}</header>

  <main id="rule-detail" tabindex="-1">
  ${
    // §8.16 / §14.3 — Omit the Problem section entirely when there is no
    // message instead of rendering a *No message* placeholder card. Sections
    // are earned by having data; an empty card just advertises absence.
    message ? `<section class="block">
    <h4>Problem</h4>
    <p>${message}</p>
  </section>` : ''}

  ${correction ? `<section class="block"><h4>How to fix</h4><p>${correction}</p></section>` : ''}

  ${owaspHtml}
  ${relatedHtml}
  ${sameTagHtml}
  ${supersedesHtml}

  </main>

  <section class="block" aria-label="Documentation links">
    <h4>Documentation</h4>
    <!-- §8.10 — Render the doc link as a tier-2 button so the panel has one
         emphasized affordance the user's eye can land on for the likely next
         action. The plain-text anchor previously gave the panel no visual
         CTA at all. -->
    <p><a href="${escapeHtml(docUrl)}" data-url="${escapeHtml(docUrl)}" class="doc-link btn">View in ROADMAP</a></p>
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
      ${getFullWidthToggleScript()}
    })();
  </script>
</body>
</html>`;
}

/** Map analyzer severity tokens to status-pill tones for the hero status line. */
function severityTone(severity: string | undefined): 'good' | 'warn' | 'bad' | 'neutral' {
  if (!severity) return 'neutral';
  const s = severity.toLowerCase();
  if (s === 'error') return 'bad';
  if (s === 'warning') return 'warn';
  return 'neutral';
}

/** Map analyzer impact tokens to status-pill tones — critical/high call out the worst cases. */
function impactTone(impact: string | undefined): 'good' | 'warn' | 'bad' | 'neutral' {
  if (!impact) return 'neutral';
  const s = impact.toLowerCase();
  if (s === 'critical') return 'bad';
  if (s === 'high') return 'warn';
  return 'neutral';
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
