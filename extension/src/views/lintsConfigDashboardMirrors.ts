/**
 * HTML fragments for **Lints Config**: summaries from `violations.json`
 * (suppressions export totals, OWASP-mapped violation signal, riskiest files) in the editor tab.
 */

import type { Violation, ViolationsData } from '../violationsReader';
import { buildFileRisks, type FileRisk } from './fileRiskTree';
import { l10n } from '../i18n/runtime';

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function countOwaspMappedViolations(violations: readonly Violation[]): number {
  let n = 0;
  for (const v of violations) {
    const ow = v.owasp;
    if (!ow || typeof ow !== 'object') continue;
    const mob = ow.mobile;
    const web = ow.web;
    if ((Array.isArray(mob) && mob.length > 0) || (Array.isArray(web) && web.length > 0)) {
      n++;
    }
  }
  return n;
}

function buildFileRiskLines(risks: readonly FileRisk[]): string {
  if (risks.length === 0) {
    return `<p class="hint">${escapeHtml(l10n('configMirrors.noFileRisk'))}</p>`;
  }
  return `<ol class="risk-list">${risks
    .map(
      (r) =>
        `<li><code>${escapeHtml(r.filePath)}</code> — score ${r.riskScore.toFixed(1)} (${r.critical} critical, ${r.high} high, ${r.total} total)</li>`,
    )
    .join('')}</ol>`;
}

/**
 * Collapsible panels mirroring **Suppressions**, **Security posture** (OWASP signal), and **File risk**
 * from the current `violations.json` slice (after YAML-disabled-rule filter, same violations array
 * as the violations dashboard disk read — not live view-suppression toggles).
 */
export function buildSidebarMirrorPanelsHtml(data: ViolationsData): string {
  const sup = data.summary?.suppressions;
  const supBlock =
    sup && typeof sup.total === 'number'
      ? `<p class="hint">Total suppressed in export: <strong>${escapeHtml(String(sup.total))}</strong>${sup.byKind
        ? ` — ignore ${escapeHtml(String(sup.byKind.ignore ?? 0))}, ignore_for_file ${escapeHtml(String(sup.byKind.ignoreForFile ?? 0))}, baseline ${escapeHtml(String(sup.byKind.baseline ?? 0))}`
        : ''}.</p><p class="hint">${escapeHtml(l10n('configMirrors.suppressionNote'))}</p>`
      : `<p class="hint">${escapeHtml(l10n('configMirrors.noSuppression'))}</p>`;

  const owaspN = countOwaspMappedViolations(data.violations);
  const secBlock = `<p class="hint">${escapeHtml(l10n('configMirrors.owaspSignal', { count: String(owaspN) }))}</p>`;

  const risks = buildFileRisks(data.violations).slice(0, 6);
  const riskBlock = buildFileRiskLines(risks);

  return `<details class="mirror-panel">
<summary>${escapeHtml(l10n('configMirrors.summarySuppressions'))}</summary>
${supBlock}
</details>
<details class="mirror-panel">
<summary>${escapeHtml(l10n('configMirrors.summaryOwasp'))}</summary>
${secBlock}
</details>
<details class="mirror-panel">
<summary>${escapeHtml(l10n('configMirrors.summaryFileRisk'))}</summary>
${riskBlock}
</details>`;
}
