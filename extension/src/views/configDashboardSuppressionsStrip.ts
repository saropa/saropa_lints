/**
 * Read-only **Config Dashboard** hint: export `summary.suppressions` totals from `violations.json`.
 *
 * Renders three states:
 *   1. No `violations.json` yet — collapsed muted line (no border, no CTA).
 *   2. `violations.json` exists with zero suppressions — collapsed muted line (no border, no CTA).
 *   3. Suppressions present — full strip with by-kind breakdown and the *Open Findings* CTA.
 *
 * The collapsed variants follow UX_UI_GUIDELINES §8.16 / §14.3: empty optional sections must not
 * advertise their emptiness with full-width bordered bands. Full breakdown, drill-down, and
 * workspace view hides live on the Findings dashboard.
 */

import type { ViolationsData } from '../violationsReader';
import { sortedNumericCountEntries } from '../keyedCountBreakdown';
import { l10n } from '../i18n/runtime';

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/**
 * One muted line for a state with nothing to act on. The text is escaped because a
 * translated value holding `<` or `&` would otherwise be read as markup.
 */
function collapsedLine(text: string): string {
  return `<p class="sup-snap strip collapsed" role="note">${escapeHtml(text)}</p>`;
}

/**
 * Compact HTML for the Config Dashboard suppressions snapshot (no VS Code dependency).
 * Lists every kind in the export, so a new kind (such as `accepted`) shows without a change here.
 */
export function buildSuppressionsExportSnapshotStripHtml(data: ViolationsData | null): string {
  if (!data) {
    // No analysis run yet. One muted line is enough — the page header already shows freshness.
    return collapsedLine(l10n('suppressionsStrip.noData'));
  }
  const sup = data.summary?.suppressions;
  const total = typeof sup?.total === 'number' ? sup.total : 0;
  if (!sup || total <= 0) {
    // Zero suppressions in this export — compact, no CTA. The user has nothing to act on here.
    return collapsedLine(l10n('suppressionsStrip.zeroTotal'));
  }
  const kinds = sortedNumericCountEntries(sup.byKind);
  const kindLine =
    kinds.length === 0
      ? escapeHtml(l10n('suppressionsStrip.noKindBreakdown'))
      : kinds
          .map(([k, v]) => `${escapeHtml(k.replace(/_/g, ' '))} ${escapeHtml(String(v))}`)
          .join(' · ');
  // Escape the translated sentence first, then insert the markup, so the catalog
  // value cannot inject HTML and each language places the number where it needs it.
  const totalHtml = escapeHtml(l10n('suppressionsStrip.total')).replace( // l10n:passthrough
    '{total}',
    `<strong>${escapeHtml(String(total))}</strong>`,
  );
  return `<div class="sup-snap strip" role="note">
  <span class="sup-snap-title">${escapeHtml(l10n('suppressionsStrip.title'))}</span>
  <span class="sup-snap-body">${totalHtml} — ${kindLine} <span class="sup-snap-muted">${escapeHtml(l10n('suppressionsStrip.readOnlyNote'))}</span></span>
  <button type="button" class="btn sup-snap-btn" data-command="openFindingsDashboard">${escapeHtml(l10n('suppressionsStrip.openFindings'))}</button>
</div>`;
}
