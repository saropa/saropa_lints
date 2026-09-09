/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code views: trees, dashboards, or webview HTML builders.
 */

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
import {
  buildKeyboardShortcutsButton,
  buildKeyboardShortcutsOverlay,
  getKeyboardShortcutsScript,
  getKeyboardShortcutsStyles,
} from './keyboard-shortcuts';
// Bug fix (Bug 3): this standalone webview panel had no path to disable/enable a rule — the
// plumbing (readDisabledRules/writeRuleOverrides/removeRuleOverrides) already exists and is
// used today by RulePacksWebviewProvider._handleToggleRule for the Overrides tab; wiring it
// here reuses the same config-write functions rather than duplicating the write logic.
import { readDisabledRules, writeRuleOverrides, removeRuleOverrides } from '../configWriter';
import { getProjectRoot } from '../projectRoot';
import { l10n } from '../i18n/runtime';
import { isStylisticRule, packsForRule } from '../rulePacks/packDomains';
import { RULE_TIER_BY_CODE } from '../rulePacks/ruleTierDefinitions';

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
  /**
   * Whether `ruleName` is currently disabled (via analysis_options.yaml diagnostics or an
   * analysis_options_custom.yaml override). Bug fix: drives the "Disable this rule" / "Enable
   * this rule" toggle button's label. Left undefined by callers that don't compute it — those
   * fall through to `isRuleDisabled()` in `buildHtml()`/`openRuleExplainPanel()`, which reads
   * the live workspace state via the same `readDisabledRules()` the Overrides tab uses.
   */
  disabled?: boolean;
}

/** Look up whether `ruleName` is currently disabled in the active workspace. No workspace
 * (or no root) reads as "not disabled" — same fallback the rest of the dashboard uses when
 * there is nothing to read. */
function isRuleDisabled(ruleName: string): boolean {
  const root = getProjectRoot();
  return root ? readDisabledRules(root).has(ruleName) : false;
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

  // Minimal fallback for a rule that has never fired in this workspace: violations.json has
  // no message/correction/severity for it (getRuleDescription() in ruleMetadata.ts is a
  // permanent stub — the extension ships no per-rule prose catalog), but pack membership and
  // introducing tier are already-generated data covering every rule, so use them instead of
  // rendering nothing but the rule name.
  let noDataHtml = '';
  if (!message) {
    const tier = RULE_TIER_BY_CODE[input.ruleName];
    const packs = packsForRule(input.ruleName);
    const tierLine = tier
      ? escapeHtml(l10n('ruleExplain.noData.tierLine', { tier }))
      : '';
    const packsLine = packs.length
      ? escapeHtml(l10n('ruleExplain.noData.packsLine', { packs: packs.join(', ') }))
      : '';
    noDataHtml = `<section class="block">
    <h4>${escapeHtml(l10n('ruleExplain.noData.heading'))}</h4>
    <p>${escapeHtml(l10n('ruleExplain.noData.body'))}</p>
    ${tierLine ? `<p>${tierLine}</p>` : ''}
    ${packsLine ? `<p>${packsLine}</p>` : ''}
  </section>`;
  }

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
  // Bug fix (Bug 3): disable/enable toggle, placed in the hero's trailing-actions slot ahead of
  // the keyboard-shortcuts button — the same slot/ordering convention buildDashboardHero already
  // documents (extra actions before the full-width toggle). `disabled` defaults to a live lookup
  // when the caller didn't already resolve it (e.g. openRuleExplainPanel recomputes it after a
  // toggle write so the freshly rendered panel reflects the state that was just written).
  const disabled = input.disabled ?? isRuleDisabled(input.ruleName);
  const toggleLabel = disabled ? l10n('ruleExplain.toggle.enableButton') : l10n('ruleExplain.toggle.disableButton');
  const toggleTitle = disabled ? l10n('ruleExplain.toggle.enableTitle') : l10n('ruleExplain.toggle.disableTitle');
  const toggleButtonHtml = `<button type="button" id="rule-toggle-btn" class="btn" data-disabled="${disabled ? '1' : '0'}" title="${escapeHtml(toggleTitle)}">${escapeHtml(toggleLabel)}</button>`;
  const heroHtml = buildDashboardHero({
    title: `Rule: ${input.ruleName}`,
    statusLineHtml,
    extraToggleHtml: `${toggleButtonHtml}${buildKeyboardShortcutsButton()}`,
  });
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${cspNonce}'; script-src 'nonce-${cspNonce}';">
  <title>${escapeHtml(buildDocumentTitle(`Rule: ${input.ruleName}`))}</title>
  <style nonce="${cspNonce}">${getDashboardChromeStyles()}${getRuleExplainPanelStyles()}${getKeyboardShortcutsStyles()}</style>
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
  </section>` : noDataHtml}

  ${correction ? `<section class="block"><h4>How to fix</h4><p>${correction}</p></section>` : ''}

  ${owaspHtml}
  ${relatedHtml}
  ${sameTagHtml}
  ${supersedesHtml}

  </main>

  ${buildKeyboardShortcutsOverlay([
    { key: '?', label: 'Show this shortcut overlay' },
    { key: 'Esc', label: 'Close the keyboard-shortcut overlay' },
  ])}
  <script nonce="${cspNonce}">
    (function() {
      const vscode = acquireVsCodeApi();
      // jsonForScriptBlock instead of bare JSON.stringify: a rule name containing
      // a literal closing-script-tag sequence would otherwise terminate this script
      // block and let the rest parse as HTML. JSON.stringify does not escape it.
      // NOTE: this comment must NOT itself contain that raw sequence — the HTML
      // parser would terminate the block here, before jsonForScriptBlock can run.
      const sourceRuleName = ${jsonForScriptBlock(input.ruleName)};
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
      // Bug fix (Bug 3): disable/enable toggle button. Posts the SAME 'toggleRule' shape the
      // Config Dashboard's Overrides tab and rule-finder already use, even though this
      // standalone panel writes it via its own onDidReceiveMessage handler in ruleExplainView.ts
      // (not RulePacksWebviewProvider) — keeping the message shape identical means both host
      // handlers could share validation/write logic if that's ever consolidated later.
      const toggleBtn = document.getElementById('rule-toggle-btn');
      if (toggleBtn) {
        toggleBtn.addEventListener('click', function() {
          vscode.postMessage({
            type: 'toggleRule',
            ruleName: sourceRuleName,
            enabled: toggleBtn.getAttribute('data-disabled') === '1',
          });
        });
      }
      ${getFullWidthToggleScript()}
      ${getKeyboardShortcutsScript()}
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
// Bug fix: the panel is reused across "open a related rule" navigations (the
// `activePanel` branch below only reassigns `webview.html`, it never re-registers
// onDidReceiveMessage), so a handler that closed over its constructor's `input`
// parameter kept acting on whichever rule was showing when the panel was FIRST
// created. `currentInput` tracks whatever is actually rendered right now so the
// toggle handler always re-renders the rule the user is currently looking at.
let currentInput: RuleExplainInput | undefined;

/**
 * Opens the rule explain panel to the side of the active editor with the given
 * rule details. Reuses the existing panel if already open (updates title and content).
 */
export function openRuleExplainPanel(input: RuleExplainInput): void {
  ruleExplainTelemetry?.('open', { ruleName: input.ruleName });
  const title = PANEL_TITLE + input.ruleName;
  currentInput = input;

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
      ruleName?: string;
      sourceRule?: string;
      section?: string;
      enabled?: boolean;
    }) => {
      if (msg.type === 'openRule' && typeof msg.ruleName === 'string') {
        ruleExplainTelemetry?.('relatedClick', {
          sourceRule: msg.sourceRule ?? currentInput?.ruleName ?? input.ruleName,
          targetRule: msg.ruleName,
          section: msg.section ?? 'unknown',
        });
        openRuleExplainPanel({ ruleName: msg.ruleName });
        return;
      }
      // Bug fix (Bug 3): this standalone panel has no async infra like
      // RulePacksWebviewProvider's message handler does (no re-run-analysis-then-refresh
      // pipeline) — configWriter's write functions are synchronous file edits, so writing the
      // override then immediately re-rendering with the just-written state is correct without
      // an intervening await. Deliberately does NOT re-run analysis here (unlike the Overrides
      // tab): this is a read-detail panel, not the dashboard, and re-running analysis from a
      // side panel would be a surprising side effect for a "read about this rule" surface.
      if (msg.type === 'toggleRule' && typeof msg.ruleName === 'string' && typeof msg.enabled === 'boolean') {
        if (!/^[a-z][a-z0-9_]*$/.test(msg.ruleName)) return; // same untrusted-postMessage guard as RulePacksWebviewProvider
        const root = getProjectRoot();
        if (!root) return;
        // msg.enabled here means "make the rule disabled" is false / "make it enabled" is true —
        // i.e. it already carries the TARGET enabled-state, not a disable flag. Stylistic
        // (opt-in, off-by-default) rules and ordinary tier/pack (on-by-default) rules need
        // opposite override-write conventions to reach that target state — see
        // RulePacksWebviewProvider._handleDisableRule's doc comment in rulePacksWebviewProvider.ts
        // for the full rationale; this mirrors that same branch.
        const isStylistic = isStylisticRule(msg.ruleName);
        if (isStylistic) {
          if (msg.enabled) {
            writeRuleOverrides(root, [{ rule: msg.ruleName, enabled: true }]);
          } else {
            removeRuleOverrides(root, [msg.ruleName]);
          }
        } else if (msg.enabled) {
          removeRuleOverrides(root, [msg.ruleName]);
        } else {
          writeRuleOverrides(root, [{ rule: msg.ruleName, enabled: false }]);
        }
        if (activePanel && currentInput) {
          currentInput = { ...currentInput, disabled: !msg.enabled };
          activePanel.webview.html = buildHtml(currentInput);
        }
      }
    }
  );

  activePanel.onDidDispose(() => {
    activePanel = undefined;
    currentInput = undefined;
  });
}

/**
 * Opens the rule explain panel from a violation (e.g. Issues tree context menu).
 */
export function openRuleExplainPanelForViolation(violation: Violation): void {
  openRuleExplainPanel(fromViolation(violation));
}
