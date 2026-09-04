import { createWebviewCspNonce, escapeHtml } from '../vibrancy/views/html-utils';
import { l10n } from '../i18n/runtime';
import { getHealthPanelStyles } from './healthPanel-styles';
import { getHealthPanelScript } from './healthPanel-script';
import { formatBytes, isDaemonProcess, isSaropaProcess } from './processQuery';
import { buildEnginesSection, buildActionsBar, buildLogSection, type EngineStatus } from './engineCardsHtml';
import type { DartProcessInfo } from './types';

export interface HealthPanelData {
  processes: DartProcessInfo[];
  orphanPids: Set<number>;
  totalRssBytes: number;
}

// Renders the full panel document (not a partial update) because the
// webview has no incremental-DOM path — every refresh/kill action
// reassigns webview.html wholesale, so client-side JS re-applies its own
// sort/scroll state on load (see healthPanel-script.ts).
//
// `engines` and `logEntries` render the "Diagnostic Engines" section that
// moved in from the former standalone Debug Panel sidebar webview — omitted
// entirely when the caller has no engine deps configured yet.
export function buildHealthPanelHtml(
  data: HealthPanelData | null,
  engines?: EngineStatus[],
  logEntries?: string[],
): string {
  const nonce = createWebviewCspNonce();
  const styles = getHealthPanelStyles();
  const script = getHealthPanelScript();

  const title = l10n('systemHealth.panel.title');
  const body = data && data.processes.length > 0
    ? buildTableHtml(data)
    : `<div class="empty-state">${escapeHtml(l10n('systemHealth.panel.empty'))}</div>`;

  const enginesHtml = engines && engines.length > 0
    ? `${buildEnginesSection(engines)}${buildActionsBar()}${buildLogSection(logEntries ?? [])}`
    : '';

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
  ${enginesHtml}
  ${data ? buildSummaryBar(data) : ''}
  ${body}
  <script nonce="${nonce}">${script}</script>
</body>
</html>`;
}

function buildSummaryBar(data: HealthPanelData): string {
  const total = data.processes.length;
  const orphans = data.orphanPids.size;
  const rss = formatBytes(data.totalRssBytes);

  return `<div class="summary-bar">
  <span class="summary-stat"><strong>${total}</strong> ${escapeHtml(l10n('systemHealth.panel.processes'))}</span>
  <span class="summary-stat"><strong>${rss}</strong> ${escapeHtml(l10n('systemHealth.panel.totalRss'))}</span>
  <span class="summary-stat"><strong>${orphans}</strong> ${escapeHtml(l10n('systemHealth.panel.orphaned'))}</span>
  <button class="btn-refresh" data-action="refresh">${escapeHtml(l10n('systemHealth.panel.refresh'))}</button>
</div>`;
}

function buildTableHtml(data: HealthPanelData): string {
  const pidHeader = escapeHtml(l10n('systemHealth.panel.colPid'));
  const parentHeader = escapeHtml(l10n('systemHealth.panel.colParent'));
  const rssHeader = escapeHtml(l10n('systemHealth.panel.colRss'));
  const typeHeader = escapeHtml(l10n('systemHealth.panel.colType'));
  const cmdHeader = escapeHtml(l10n('systemHealth.panel.colCommand'));
  const actionHeader = escapeHtml(l10n('systemHealth.panel.colAction'));

  const killedLabel = escapeHtml(l10n('systemHealth.panel.killed'));
  const failedLabel = escapeHtml(l10n('systemHealth.panel.killFailed'));

  const rows = data.processes.map((p) => {
    const isOrphan = data.orphanPids.has(p.processId);
    const isDaemon = isDaemonProcess(p);
    const isSaropa = isSaropaProcess(p);

    // Orphan takes priority over daemon in the type pill because an
    // orphaned daemon is the actionable case (has a kill button below);
    // a live daemon with a parent is normal and not worth flagging.
    // Saropa processes get their own pill so users can distinguish
    // saropa_lints scan daemons from the Dart analysis server.
    let typePill: string;
    if (isOrphan) {
      typePill = `<span class="pill pill-orphan">${escapeHtml(l10n('systemHealth.panel.typeOrphan'))}</span>`;
    } else if (isSaropa) {
      typePill = `<span class="pill pill-daemon">${escapeHtml(l10n('systemHealth.panel.typeSaropa'))}</span>`;
    } else if (isDaemon) {
      typePill = `<span class="pill pill-daemon">${escapeHtml(l10n('systemHealth.panel.typeDaemon'))}</span>`;
    } else {
      typePill = `<span class="pill pill-process">${escapeHtml(l10n('systemHealth.panel.typeProcess'))}</span>`;
    }

    const killBtn = isOrphan
      ? `<button class="btn-kill" data-action="kill" data-pid="${p.processId}" data-label-killed="${killedLabel}" data-label-failed="${failedLabel}">${escapeHtml(l10n('systemHealth.panel.kill'))}</button>`
      : '';

    return `<tr>
  <td>${p.processId}</td>
  <td>${p.parentProcessId}</td>
  <td>${escapeHtml(formatBytes(p.workingSetSize))}</td>
  <td>${typePill}</td>
  <td class="cmd-cell" title="${escapeHtml(p.commandLine)}">${escapeHtml(p.commandLine)}</td>
  <td>${killBtn}</td>
</tr>`;
  });

  return `<table class="health-table">
<thead><tr>
  <th>${pidHeader}</th>
  <th>${parentHeader}</th>
  <th>${rssHeader}</th>
  <th>${typeHeader}</th>
  <th>${cmdHeader}</th>
  <th>${actionHeader}</th>
</tr></thead>
<tbody>${rows.join('')}</tbody>
</table>`;
}
