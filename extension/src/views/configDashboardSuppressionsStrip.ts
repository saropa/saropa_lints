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

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** Compact HTML for the Config Dashboard suppressions snapshot (no VS Code dependency). */
export function buildSuppressionsExportSnapshotStripHtml(data: ViolationsData | null): string {
  if (!data) {
    // No analysis run yet. One muted line is enough — the page header already shows freshness.
    return `<p class="sup-snap strip collapsed" role="note">No <code>violations.json</code> yet — run analysis to populate the suppression snapshot.</p>`;
  }
  const sup = data.summary?.suppressions;
  const total = typeof sup?.total === 'number' ? sup.total : 0;
  if (!sup || total <= 0) {
    // Zero suppressions in this export — compact, no CTA. The user has nothing to act on here.
    return `<p class="sup-snap strip collapsed" role="note"><strong>0</strong> analyzer suppressions in the latest export.</p>`;
  }
  const kinds = sortedNumericCountEntries(sup.byKind);
  const kindLine =
    kinds.length === 0
      ? 'No by-kind breakdown in this export.'
      : kinds
          .map(([k, v]) => `${escapeHtml(k.replace(/_/g, ' '))} ${escapeHtml(String(v))}`)
          .join(' · ');
  return `<div class="sup-snap strip" role="note">
  <span class="sup-snap-title">Suppressions (export)</span>
  <span class="sup-snap-body">Total <strong>${escapeHtml(String(total))}</strong> — ${kindLine} <span class="sup-snap-muted">(read-only; open Findings to browse and act.)</span></span>
  <button type="button" class="btn sup-snap-btn" data-command="openFindingsDashboard">Open Findings Dashboard</button>
</div>`;
}
