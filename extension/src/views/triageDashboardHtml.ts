/**
 * Editor-area **Rule triage** block for Lints Config: same groups and actions as the
 * optional Triage sidebar tree (critical, volume bands, stylistic, info rows).
 */

import { getViolationsTriageState, readViolations, type IssuesByRule, type ViolationsData } from '../violationsReader';
import {
  buildTriageData,
  getTriageGroupChildren,
  type TriageData,
  type TriageGroupNode,
} from './triageTree';
import { l10n } from '../i18n/runtime';

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function rulesPayload(rules: string[]): string {
  return encodeURIComponent(JSON.stringify(rules));
}

function formatStaleAge(ageMs: number): string {
  const h = Math.floor(ageMs / (60 * 60 * 1000));
  if (h >= 24) return `${Math.floor(h / 24)}d`;
  if (h > 0) return `${h}h`;
  const m = Math.floor(ageMs / (60 * 1000));
  return `${m}m`;
}

function renderTriageGroupBlock(group: TriageGroupNode, issuesByRule: IssuesByRule): string {
  const children = getTriageGroupChildren(group, issuesByRule);
  const encAll = rulesPayload(group.rules);
  const actions = `<div class="triage-group-actions">
  <button type="button" class="action-btn triage-btn" data-triage-action="focus" data-rules="${encAll}">${escapeHtml(l10n('triageDash.showInIssues'))}</button>
  <button type="button" class="action-btn triage-btn secondary" data-triage-action="disable" data-rules="${encAll}">${escapeHtml(l10n('triageDash.disableRules'))}</button>
  <button type="button" class="action-btn triage-btn secondary" data-triage-action="enable" data-rules="${encAll}">${escapeHtml(l10n('triageDash.enableRules'))}</button>
</div>`;
  const rows = children
    .map((r) => {
      const encOne = rulesPayload([r.ruleName]);
      return `<tr>
  <td class="triage-rule-name"><code>${escapeHtml(r.ruleName)}</code></td>
  <td class="triage-n">${r.issueCount}</td>
  <td class="triage-row-actions">
    <button type="button" class="linkish triage-btn" data-triage-action="focus" data-rules="${encOne}">${escapeHtml(l10n('triageDash.issues'))}</button>
    <button type="button" class="linkish triage-btn" data-triage-action="disable" data-rules="${encOne}">${escapeHtml(l10n('triageDash.off'))}</button>
    <button type="button" class="linkish triage-btn" data-triage-action="enable" data-rules="${encOne}">${escapeHtml(l10n('triageDash.on'))}</button>
  </td>
</tr>`;
    })
    .join('\n');
  return `<details class="triage-group" open>
  <summary class="triage-group-sum">
    <span class="triage-gl-label">${escapeHtml(group.label)}</span>
    <span class="triage-gl-desc">${escapeHtml(group.description)}</span>
  </summary>
  ${actions}
  <div class="triage-table-wrap">
    <table class="triage-table">
      <thead><tr><th>${escapeHtml(l10n('triageDash.colRule'))}</th><th>${escapeHtml(l10n('triageDash.colIssues'))}</th><th></th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
  </div>
</details>`;
}

function renderTriageBody(data: ViolationsData, triage: TriageData): string {
  const blocks: string[] = [];
  if (triage.criticalGroup) {
    blocks.push(renderTriageGroupBlock(triage.criticalGroup, triage.issuesByRule));
  }
  for (const g of triage.volumeGroups) {
    blocks.push(renderTriageGroupBlock(g, triage.issuesByRule));
  }
  if (triage.zeroIssueCount > 0) {
    blocks.push(
      `<p class="triage-meta">${escapeHtml(l10n('triageDash.zeroIssueRules', { count: String(triage.zeroIssueCount) }))}</p>`,
    );
  }
  if (triage.disabledOverrideCount > 0) {
    blocks.push(
      `<p class="triage-meta">${escapeHtml(l10n('triageDash.disabledOverrides', { count: String(triage.disabledOverrideCount) }))}</p>`,
    );
  }
  if (triage.stylisticGroup) {
    blocks.push(renderTriageGroupBlock(triage.stylisticGroup, triage.issuesByRule));
  }
  return blocks.join('\n');
}

/**
 * Full `<details>` section: rule triage from `violations.json` (same contract as the Triage tree).
 */
export function buildTriageDashboardSectionHtml(root: string): string {
  const data = readViolations(root);
  if (!data) {
    return `<details class="triage-dash">
<summary>${escapeHtml(l10n('triageDash.summaryRuleTriage'))}</summary>
<p class="hint">${escapeHtml(l10n('triageDash.hintNoViolations'))}</p>
<div class="actions"><button type="button" class="action-btn" data-command="runAnalysis">${escapeHtml(l10n('toolbar.runAnalysis'))}</button></div>
</details>`;
  }

  const { triage: tri } = getViolationsTriageState(root, data);
  if (tri.kind === 'missing' || (tri.kind === 'incomplete' && tri.reason === 'unreadable')) {
    return `<details class="triage-dash" open>
<summary>${escapeHtml(l10n('triageDash.summaryRuleTriage'))}</summary>
<p class="hint warn">${escapeHtml(l10n('triageDash.hintUnreadable'))}</p>
<div class="actions"><button type="button" class="action-btn" data-command="runAnalysis">${escapeHtml(l10n('toolbar.runAnalysis'))}</button></div>
</details>`;
  }
  if (tri.kind === 'stale') {
    return `<details class="triage-dash" open>
<summary>${escapeHtml(l10n('triageDash.summaryRuleTriage'))}</summary>
<p class="hint warn">${escapeHtml(l10n('triageDash.hintStale', { age: formatStaleAge(tri.ageMs) }))}</p>
<div class="actions"><button type="button" class="action-btn" data-command="runAnalysis">${escapeHtml(l10n('toolbar.runAnalysis'))}</button></div>
</details>`;
  }
  if (tri.kind === 'incomplete' && tri.reason === 'no_per_rule') {
    return `<details class="triage-dash" open>
<summary>${escapeHtml(l10n('triageDash.summaryRuleTriage'))}</summary>
<p class="hint warn">${escapeHtml(l10n('triageDash.hintNoPerRule'))}</p>
<div class="actions"><button type="button" class="action-btn" data-command="runAnalysis">${escapeHtml(l10n('toolbar.runAnalysis'))}</button></div>
</details>`;
  }

  const triage = buildTriageData(data, root);
  if (!triage) {
    return `<details class="triage-dash" open>
<summary>${escapeHtml(l10n('triageDash.summaryRuleTriage'))}</summary>
<p class="hint warn">${escapeHtml(l10n('triageDash.hintBuildFailed'))}</p>
<div class="actions"><button type="button" class="action-btn" data-command="runAnalysis">${escapeHtml(l10n('toolbar.runAnalysis'))}</button></div>
</details>`;
  }

  const body = renderTriageBody(data, triage);
  return `<details class="triage-dash" open>
<summary>${escapeHtml(l10n('triageDash.summaryVolume'))}</summary>
<p class="hint">${escapeHtml(l10n('triageDash.hintSameAsTree'))}</p>
${body}
</details>`;
}

/** Styles for the triage block (injected into the config dashboard <style>). */
export function buildTriageDashboardStyles(): string {
  return `
.triage-dash { margin: 12px 0 14px; border: 1px solid var(--vscode-widget-border); border-radius: 8px; padding: 8px 10px; background: var(--vscode-sideBarSectionHeader-background); }
.triage-dash > summary { cursor: pointer; font-weight: 600; font-size: 13px; }
.triage-meta { margin: 8px 0; font-size: 12px; opacity: 0.95; }
.hint.warn { color: var(--vscode-list-warningForeground); }
.triage-group { margin: 10px 0; border: 1px solid var(--vscode-widget-border); border-radius: 6px; background: var(--vscode-editor-background); }
.triage-group > summary { cursor: pointer; padding: 8px 10px; list-style-position: outside; }
.triage-gl-label { font-weight: 600; }
.triage-gl-desc { display: block; font-size: 11px; opacity: 0.88; font-weight: 400; margin-top: 4px; }
.triage-group-actions { display: flex; flex-wrap: wrap; gap: 6px; padding: 0 10px 8px; }
.triage-btn.secondary { opacity: 0.95; }
.triage-table-wrap { max-height: 280px; overflow: auto; border-top: 1px solid var(--vscode-widget-border); }
.triage-table { width: 100%; border-collapse: collapse; font-size: 11px; }
.triage-table th, .triage-table td { padding: 6px 8px; border-bottom: 1px solid var(--vscode-widget-border); text-align: left; }
.triage-n { text-align: right; white-space: nowrap; width: 56px; }
.triage-row-actions { white-space: nowrap; text-align: right; }
.triage-row-actions .linkish { background: none; border: none; color: var(--vscode-textLink-foreground); cursor: pointer; margin-inline-start: 8px; padding: 0; font-size: 11px; }
.triage-row-actions .linkish:hover { text-decoration: underline; }
/* §15 — explicit themed focus ring on both triage button styles. Native
   buttons keep a default outline, but the rest of the dashboard standardizes
   on focusBorder so keyboard focus reads consistently across every surface. */
.triage-btn:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
.triage-row-actions .linkish:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
`;
}

/** Script fragment: wire <button class="triage-btn"> to post triageAction messages. */
export function buildTriageDashboardScript(): string {
  return `
  document.querySelectorAll('button.triage-btn').forEach(function(btn) {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      var action = btn.getAttribute('data-triage-action');
      var raw = btn.getAttribute('data-rules');
      if (!action || !raw) { return; }
      try {
        var rules = JSON.parse(decodeURIComponent(raw));
        if (!Array.isArray(rules) || rules.length === 0) { return; }
        vscode.postMessage({ type: 'triageAction', action: action, rules: rules });
      } catch (err) { /* ignore */ }
    });
  });
`;
}
