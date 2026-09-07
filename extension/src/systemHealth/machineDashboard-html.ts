import { createWebviewCspNonce, escapeHtml } from '../vibrancy/views/html-utils';
import { l10n } from '../i18n/runtime';
import { getMachineDashboardStyles } from './machineDashboard-styles';
import { getMachineDashboardScript } from './machineDashboard-script';
import { formatBytes } from './processQuery';
import type { DevToolBudget, ProcessGroup, Recommendation } from './machineDashboardData';
import type { SystemMemorySnapshot } from './systemQuery';

/** Full data set the webview renders on every refresh. */
export interface MachineDashboardData {
  system: SystemMemorySnapshot | undefined;
  groups: ProcessGroup[];
  recommendations: Recommendation[];
  budget: DevToolBudget | undefined;
}

// machineDashboardData.ts's ProcessGroup only carries a machine-readable
// `key`, not a display label — this map is the one place that translates
// each key into its l10n string, kept in the rendering layer rather than the
// pure data layer so groupDartProcesses/groupModelHosts stay decoupled from
// which locale is active.
const GROUP_LABEL_KEY: Record<ProcessGroup['key'], string> = {
  analysisServer: 'machineDashboard.group.analysisServer',
  flutterDaemon: 'machineDashboard.group.flutterDaemon',
  saropa: 'machineDashboard.group.saropa',
  otherDart: 'machineDashboard.group.otherDart',
  modelHost: 'machineDashboard.group.modelHost',
};

export function buildMachineDashboardHtml(data: MachineDashboardData): string {
  const nonce = createWebviewCspNonce();
  const styles = getMachineDashboardStyles();
  const script = getMachineDashboardScript();
  const title = l10n('machineDashboard.title');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  <style nonce="${nonce}">${styles}</style>
</head>
<body>
  ${buildSystemSummary(data.system)}
  ${buildBudgetBar(data.budget)}
  ${buildRecommendationsSection(data.recommendations)}
  ${buildGroupsSection(data.groups)}
  <script nonce="${nonce}">${script}</script>
</body>
</html>`;
}

function buildSystemSummary(system: SystemMemorySnapshot | undefined): string {
  const refreshBtn = `<button class="btn-refresh" data-action="refresh">${escapeHtml(l10n('machineDashboard.refresh'))}</button>`;
  // undefined system means querySystemMemory() failed or this is a non-Windows
  // host (see systemQuery.ts) — show a plain unknown-state bar rather than
  // pretending 0% used, which would read as "machine is fine" when it might not be.
  if (!system) {
    return `<div class="summary-bar">
  <span class="summary-stat">${escapeHtml(l10n('machineDashboard.systemUnknown'))}</span>
  ${refreshBtn}
</div>`;
  }
  const usedFraction = 1 - system.freeFraction;
  // Thresholds independent of the per-group process warnings below — this
  // bar answers "is the machine as a whole under pressure", which can be
  // true even when every individual Dart/Ollama process looks reasonable
  // (e.g. many small VS Code windows adding up).
  const severity = usedFraction >= 0.85 ? 'critical' : usedFraction >= 0.70 ? 'warning' : 'healthy';
  return `<div class="summary-bar summary-${severity}">
  <span class="summary-stat"><strong>${escapeHtml(formatBytes(system.freeBytes))}</strong> ${escapeHtml(l10n('machineDashboard.freeOf'))} <strong>${escapeHtml(formatBytes(system.totalBytes))}</strong></span>
  <span class="summary-stat">${Math.round(usedFraction * 100)}% ${escapeHtml(l10n('machineDashboard.used'))}</span>
  ${refreshBtn}
</div>`;
}

/** Renders the dev-tool memory budget bar — a single percentage showing how
 *  much of the machine's RAM dev tools consume vs the configured target. */
function buildBudgetBar(budget: DevToolBudget | undefined): string {
  if (!budget) return '';
  const severity = budget.overBudget ? 'over' : 'under';
  // Clamp the visual bar width to 100% even if usage exceeds the total
  // (theoretically impossible but defensive against rounding).
  const barWidth = Math.min(budget.usedPercent, 100);
  const budgetMarker = Math.min(budget.budgetPercent, 100);
  return `<div class="budget-bar">
  <div class="budget-label">
    <span>${escapeHtml(l10n('machineDashboard.budget.title'))}</span>
    <span class="budget-value budget-${severity}">${escapeHtml(l10n('machineDashboard.budget.value', {
      used: String(budget.usedPercent),
      budget: String(budget.budgetPercent),
      size: formatBytes(budget.devToolBytes),
    }))}</span>
  </div>
  <div class="budget-track">
    <div class="budget-fill budget-${severity}" style="width:${barWidth}%"></div>
    <div class="budget-target" style="left:${budgetMarker}%"></div>
  </div>
</div>`;
}

function buildRecommendationsSection(recommendations: Recommendation[]): string {
  if (recommendations.length === 0) {
    return `<div class="recommendations-empty">${escapeHtml(l10n('machineDashboard.recommendationsNone'))}</div>`;
  }
  const items = recommendations.map((r) => {
    // Serialized as one JSON attribute rather than N positional data-arg1/2
    // attributes — actionArgs today is only ever a single model name, but a
    // fixed-arity attribute scheme would need renaming the moment a second
    // recommendation needs two arguments.
    const argsAttr = r.actionArgs
      ? ` data-args="${escapeHtml(JSON.stringify(r.actionArgs))}"`
      : '';
    const action = r.actionCommand
      ? `<button class="btn-action" data-action="runCommand" data-command="${escapeHtml(r.actionCommand)}" data-rec-id="${escapeHtml(r.id)}"${argsAttr}>${escapeHtml(r.actionLabel ?? '')}</button>`
      : '';
    return `<div class="rec-card rec-${r.severity}" data-rec-id="${escapeHtml(r.id)}">
  <span class="rec-text">${escapeHtml(r.text)}</span>
  ${action}
</div>`;
  });
  return `<div class="recommendations">
  <h2 class="section-title">${escapeHtml(l10n('machineDashboard.recommendationsTitle'))}</h2>
  ${items.join('')}
</div>`;
}

function buildGroupsSection(groups: ProcessGroup[]): string {
  const nonEmpty = groups.filter((g) => g.processCount > 0);
  if (nonEmpty.length === 0) {
    return `<div class="empty-state">${escapeHtml(l10n('machineDashboard.noProcesses'))}</div>`;
  }
  // Largest RSS first — the group most worth looking at belongs at the top,
  // not wherever its category happened to land in the grouping map's iteration order.
  const sorted = [...nonEmpty].sort((a, b) => b.totalRssBytes - a.totalRssBytes);
  return `<div class="groups">${sorted.map(buildGroupCard).join('')}</div>`;
}

function buildGroupCard(group: ProcessGroup): string {
  const label = escapeHtml(l10n(GROUP_LABEL_KEY[group.key]));
  const rss = escapeHtml(formatBytes(group.totalRssBytes));
  const orphanBadge = group.orphanCount > 0
    ? `<span class="pill pill-orphan">${escapeHtml(l10n('machineDashboard.orphanCount', { count: String(group.orphanCount) }))}</span>`
    : '';
  const rows = group.rows
    // Largest process first within the group too — same "most worth looking
    // at goes first" rule as the group ordering above, one level down.
    .sort((a, b) => b.rssBytes - a.rssBytes)
    .map((row) => {
      // Kill button only for orphans — a live, parented process (a running
      // debug session's Flutter daemon, the active analysis server) is doing
      // its job; offering to kill it here would invite exactly the kind of
      // accidental termination this dashboard's orphan-only gating exists to prevent.
      const killBtn = row.isOrphan
        ? `<button class="btn-kill" data-action="kill" data-pid="${row.processId}" data-group="${group.key}">${escapeHtml(l10n('machineDashboard.kill'))}</button>`
        : '';
      return `<tr>
  <td>${row.processId}</td>
  <td>${escapeHtml(formatBytes(row.rssBytes))}</td>
  <td class="cmd-cell" title="${escapeHtml(row.commandLine)}">${escapeHtml(row.commandLine)}</td>
  <td>${killBtn}</td>
</tr>`;
    })
    .join('');

  return `<details class="group-card" open>
  <summary>
    <span class="group-label">${label}</span>
    <span class="group-count">${group.processCount}</span>
    <span class="group-rss">${rss}</span>
    ${orphanBadge}
  </summary>
  <div class="group-table-wrap">
    <table class="group-table">
      <tbody>${rows}</tbody>
    </table>
  </div>
</details>`;
}
