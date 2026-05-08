/**
 * CSS for the **Lints Config** (rule packs) editor webview.
 *
 * The shared chrome stylesheet (header band, KPI cards, toolbar band, button tiers, segmented
 * control, chip strip, gauge, bar+donut, sortable table) is loaded from
 * `views/dashboardChromeStyles.ts` so this surface looks identical to the Findings and Code
 * Health dashboards. Only Lints Config-specific surfaces live here:
 *
 *   - `.tier-control` / `.tier-btn` — segmented radio for the active lint tier
 *   - `.switch` — toggle for per-pack enable
 *   - `.risk-badge` / `.type-badge` — pack categorization on each row
 *   - `.disabled-rules-list` — re-enable list under the pack table
 *   - `.diagnostics` — bottom band with suppressions, platforms, docs
 *
 * Layout zoning (per UX_UI_GUIDELINES §4, §14.6/14.7):
 *   1. Header band (h1 + status line + hero gauge)
 *   2. KPI strip (cards as preset filters — §14.8)
 *   3. Tier control (real radio segmented control — §14.1 fix)
 *   4. Toolbar band (sticky, density-tiered — §4.3, §14.4)
 *   5. Active filter chip strip (rendered when filter state diverges — §8.5, §14.10)
 *   6. Combined packs table (one schema with Type + Risk columns — §14.13 fix)
 *   7. Disabled rules list
 *   8. Conditional pack coverage chart (§14.3 fix; §6.1 bar + donut)
 *   9. Diagnostics band (suppressions, platforms, docs — §14.7 step 6, §14.14 fix)
 */
import { getDashboardChromeStyles } from '../views/dashboardChromeStyles';

export function getConfigDashboardStyles(): string {
  return [
    getDashboardChromeStyles(),
    tierControlStyles(),
    packTableSpecifics(),
    disabledRulesStyles(),
    diagnosticsStyles(),
    sharedAtomStyles(),
  ].join('\n');
}

/** Tier segmented control — real radio buttons, active state with focus ring. */
function tierControlStyles(): string {
  // §14.1 fix: was inert <span>s, now real <button role="radio">.
  return `
/* Tier control — radio segmented control (exactly one tier active at a time).
   Per guideline §14.15 the active button does NOT borrow primary-button colors —
   primary-button vocabulary is reserved for tier-1 actions in the same toolbar.
   Active option gets an inactive-selection backdrop tint; inactive options stay
   transparent at slightly reduced opacity. The track band groups them. */
.tier-control {
  display: inline-flex;
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 2px;
  background: var(--surface-3);
  gap: 2px;
}
.tier-btn {
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  font-size: 0.92em;
  padding: 4px 12px;
  border-radius: 999px;
  cursor: pointer;
  white-space: nowrap;
  opacity: 0.7;
  transition: background 0.15s, opacity 0.15s;
}
.tier-btn:hover { opacity: 1; }
.tier-btn:focus-visible {
  outline: 2px solid var(--vscode-focusBorder);
  outline-offset: 1px;
  opacity: 1;
}
.tier-btn[aria-checked="true"] {
  background: var(--vscode-list-activeSelectionBackground);
  color: var(--vscode-list-activeSelectionForeground);
  font-weight: 600;
  opacity: 1;
}
`;
}

/** Lints Config table-specific styling on top of the shared `.dash-table` base. */
function packTableSpecifics(): string {
  return `
.dash-table.packs td.pack-name { font-weight: 500; }
.dash-table.packs td.ok { color: var(--status-good); }
.dash-table.packs td.muted { color: var(--muted); }
`;
}

/** "Disabled rules" list — a list of rules currently overridden off, with re-enable buttons. */
function disabledRulesStyles(): string {
  return `
.disabled-rules { margin-bottom: 14px; }
/* Group heading sits inside the expander (rule packs already use h2 in the summary).
   Lower visual weight than h2 so the section heading still anchors the block. */
.disabled-rules-group { margin: 8px 0 0; }
.disabled-rules-group-heading {
  font-size: 0.85em;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--muted);
  margin: 0 0 4px;
  font-weight: 600;
}
.disabled-rules-toolbar {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 6px 0 8px;
}
.disabled-rules-search {
  flex: 0 1 320px;
  padding: 4px 8px;
  font: inherit;
  color: var(--vscode-input-foreground);
  background: var(--vscode-input-background);
  border: 1px solid var(--vscode-input-border, var(--border));
  border-radius: 4px;
}
.disabled-rules-search:focus {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: -1px;
}
.disabled-rules-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 6px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface-2);
  padding: 10px 12px;
}
.disabled-rule-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 6px;
  border-radius: 4px;
}
.disabled-rule-row:hover { background: var(--vscode-list-hoverBackground); }
.disabled-rule-row code { font-size: 0.92em; flex: 1; min-width: 0; }

/* ------ Section expander chrome (Rule packs + Disabled rules) ------
   Native <details> with a styled summary so the user can collapse long sections.
   Hide the default disclosure marker and supply a custom rotating chevron so the
   summary aligns with the existing .section h2 visual. */
details.expander { margin-bottom: 14px; }
details.expander > summary {
  cursor: pointer;
  list-style: none;
  user-select: none;
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin: 0 0 8px;
  font-size: 1.05em;
  font-weight: 600;
  letter-spacing: 0.2px;
}
details.expander > summary::-webkit-details-marker { display: none; }
details.expander > summary::before {
  content: '▶';
  display: inline-block;
  font-size: 0.7em;
  width: 0.9em;
  color: var(--muted);
  transition: transform 0.15s ease;
}
details.expander[open] > summary::before { transform: rotate(90deg); }
details.expander > summary .muted {
  font-size: 0.82em;
  font-weight: 500;
  color: var(--muted);
}
details.expander > summary:focus-visible {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: 2px;
  border-radius: 4px;
}
`;
}

/** Bottom diagnostics band — suppressions, platforms, docs side by side. */
function diagnosticsStyles(): string {
  // §14.7 step 6, §14.14 — reference / diagnostics content goes below the data.
  return `
.diagnostics {
  margin-top: 24px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 16px;
}
.diagnostics h3 {
  font-size: 0.95em;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--muted);
  margin: 0 0 6px;
  font-weight: 600;
}
.diagnostics .docs {
  list-style: none; padding: 0; margin: 0;
  display: flex; flex-direction: column; gap: 4px;
}
.diagnostics .plat {
  width: 100%; border-collapse: collapse; font-size: 0.92em;
}
.diagnostics .plat th, .diagnostics .plat td {
  padding: 3px 6px;
  border-bottom: 1px solid var(--border);
  text-align: left;
}
.diagnostics .plat th { font-weight: 600; opacity: 0.85; }
.diagnostics .plat tr:last-child td { border-bottom: 0; }
.diagnostics .plat td.ok { color: var(--status-good); }
.diagnostics .plat td.muted { color: var(--muted); }
.sup-snap.strip {
  display: flex; flex-wrap: wrap; align-items: center;
  gap: 6px 10px;
  padding: 8px 10px;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--surface-2);
  font-size: 0.92em;
}
.sup-snap.strip.collapsed {
  border: 0; padding: 0; background: transparent;
  color: var(--muted); font-size: 0.92em;
}
.sup-snap-title {
  font-weight: 600; font-size: 0.85em;
  text-transform: uppercase; letter-spacing: 0.04em;
  color: var(--muted); flex: 0 0 auto;
}
.sup-snap-body { flex: 1 1 200px; min-width: 0; line-height: 1.45; }
.sup-snap-muted { color: var(--muted); }
.sup-snap-btn { flex: 0 0 auto; }
`;
}

/** Pack-specific atoms: enable switch, risk and type badges. */
function sharedAtomStyles(): string {
  return `
.switch { position: relative; display: inline-block; width: 32px; height: 18px; vertical-align: middle; }
.switch input { opacity: 0; width: 0; height: 0; }
.switch input:focus-visible + .slider {
  outline: 2px solid var(--vscode-focusBorder);
  outline-offset: 2px;
}
.slider {
  position: absolute; cursor: pointer; inset: 0;
  background: var(--inset);
  border-radius: 10px;
  border: 1px solid var(--border);
}
.slider:before {
  position: absolute; content: "";
  height: 12px; width: 12px;
  inset-inline-start: 2px;
  inset-block-end: 2px;
  background: var(--vscode-foreground);
  border-radius: 50%; opacity: 0.5;
  transition: 0.15s;
}
input:checked + .slider:before { transform: translateX(14px); opacity: 1; }
[dir="rtl"] input:checked + .slider:before { transform: translateX(-14px); opacity: 1; }
@media (prefers-reduced-motion: reduce) {
  .slider:before { transition: none; }
}
.risk-badge {
  display: inline-block;
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 0 6px;
  font-size: 0.78em;
  line-height: 16px;
  white-space: nowrap;
}
.risk-badge.sdk {
  border-color: var(--link);
  color: var(--link);
}
.risk-badge.breaking {
  border-color: var(--accent-error);
  color: var(--accent-error);
}
.risk-badge.deprecation {
  border-color: var(--accent-warning);
  color: var(--accent-warning);
}
.risk-badge.none { opacity: 0.4; }
.type-badge {
  display: inline-block;
  border-radius: 4px;
  padding: 1px 6px;
  font-size: 0.78em;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  background: var(--vscode-badge-background);
  color: var(--vscode-badge-foreground);
}
.hint { font-size: 0.85em; color: var(--muted); margin: 6px 0 0 0; }
`;
}
