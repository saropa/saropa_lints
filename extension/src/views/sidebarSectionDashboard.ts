/**
 * Self-contained **activity bar layout** UI for Saropa dashboards: checkboxes mirror
 * `saropaLints.sidebar.show*` so users can show or hide activity-bar sections from a dashboard.
 */

import type * as vscode from 'vscode';
import { SIDEBAR_SECTIONS, defaultSidebarSectionVisible } from '../sidebarSectionVisibilityKeys';

export interface SidebarSectionToggleRow {
  readonly key: string;
  readonly label: string;
  readonly on: boolean;
}

/** Current workspace values for each `saropaLints.sidebar.show*` key (stored setting only). */
export function getSidebarSectionToggleRows(cfg: vscode.WorkspaceConfiguration): SidebarSectionToggleRow[] {
  return SIDEBAR_SECTIONS.map((s) => {
    const def = defaultSidebarSectionVisible(s.key);
    const on = cfg.get<boolean>(s.key, def) ?? def;
    return { key: s.key, label: s.label, on };
  });
}

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** Collapsed-by-default `<details>` with one row per section (lazy until expanded). */
export function buildDashboardSidebarVisibilityPanelHtml(rows: readonly SidebarSectionToggleRow[]): string {
  if (rows.length === 0) {
    return '';
  }
  const inner = rows
    .map(
      (r) =>
        `<label class="sidebar-vis-row"><span class="sidebar-vis-label">${escapeHtml(r.label)}</span>`
        + `<input type="checkbox" class="sidebar-vis-toggle" data-sidebar-key="${escapeHtml(r.key)}" ${
          r.on ? 'checked' : ''
        } /></label>`,
    )
    .join('');
  return `<details class="dashboard-sidebar-vis">
<summary>Activity bar layout</summary>
<p class="sidebar-vis-hint">Turn Saropa activity-bar sections on or off here (saved with the workspace, without leaving the dashboard).</p>
<div class="sidebar-vis-list">${inner}</div>
</details>`;
}

/** Inline styles for dashboard panels (Lints Config injects its own; Package/Project use report CSS). */
export function buildDashboardSidebarVisibilityStyles(): string {
  return `
.dashboard-sidebar-vis { margin: 12px 0 16px 0; padding: 10px 12px; border: 1px solid var(--vscode-widget-border); border-radius: 8px; background: var(--vscode-editorWidget-background); }
.dashboard-sidebar-vis > summary { cursor: pointer; font-weight: 600; font-size: 13px; }
.sidebar-vis-hint { font-size: 11px; opacity: 0.85; margin: 6px 0 8px 0; }
.sidebar-vis-list { display: flex; flex-direction: column; gap: 6px; }
.sidebar-vis-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; font-size: 12px; }
.sidebar-vis-label { flex: 1; }
.sidebar-vis-toggle { cursor: pointer; }
`;
}

/** Client script: posts `setSidebarSection` when a checkbox changes. */
export function buildDashboardSidebarVisibilityScript(): string {
  return `
(function() {
  document.querySelectorAll('.sidebar-vis-toggle').forEach(function(ch) {
    ch.addEventListener('change', function() {
      var key = ch.getAttribute('data-sidebar-key');
      if (!key) return;
      vscode.postMessage({ type: 'setSidebarSection', key: key, enabled: ch.checked });
    });
  });
})();
`;
}
