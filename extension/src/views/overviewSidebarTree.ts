/**
 * Activity-bar section visibility toggles shown under **Overview & options → Sidebar**.
 *
 * **Label format:** `{section label} ({count})` when the section count is a finite number;
 * otherwise the base label only. **Description:** `On` or `Off` (counts are not duplicated
 * in the description — that was previous UX).
 *
 */

import * as vscode from 'vscode';
import { formatSidebarToggleLabel } from '../sidebarToggleLabel';
import { isDriftSidebarEffectiveVisible } from '../driftAdvisor/driftAdvisorUiState';
import { defaultSidebarSectionVisible, SIDEBAR_SECTIONS } from '../sidebarSectionVisibilityKeys';

export class OverviewSidebarSectionParent extends vscode.TreeItem {
    constructor() {
        super('Sidebar', vscode.TreeItemCollapsibleState.Expanded);
        this.contextValue = 'overviewSidebarSection';
        this.iconPath = new vscode.ThemeIcon('layout-panel');
        this.tooltip = 'Show or hide sections in the Saropa Lints activity bar';
    }
}

export class OverviewSidebarToggleItem extends vscode.TreeItem {
    constructor(readonly sectionKey: string, baseLabel: string, on: boolean, count?: number) {
        super(formatSidebarToggleLabel(baseLabel, count), vscode.TreeItemCollapsibleState.None);
        this.description = on ? 'On' : 'Off';
        this.iconPath = new vscode.ThemeIcon(on ? 'eye' : 'eye-closed');
        this.command = {
            command: 'saropaLints.toggleSidebarSection',
            title: 'Toggle',
            arguments: [sectionKey],
        };
        this.contextValue = 'overviewSidebarToggle';
        const countHint =
            count !== undefined && Number.isFinite(count) ? `${count} in this section. ` : '';
        this.tooltip = `${baseLabel}: ${countHint}Click to show or hide in the activity bar.`;
    }
}

export function buildSidebarToggleItems(
    cfg: vscode.WorkspaceConfiguration,
    workspaceState: vscode.Memento,
    counts?: ReadonlyMap<string, number | undefined>,
): OverviewSidebarToggleItem[] {
    return SIDEBAR_SECTIONS.map((s) => {
        const on = s.key === 'sidebar.showDriftAdvisor'
            ? isDriftSidebarEffectiveVisible(workspaceState, cfg)
            : (cfg.get<boolean>(s.key, defaultSidebarSectionVisible(s.key)) ?? defaultSidebarSectionVisible(s.key));
        const count = counts?.get(s.key);
        return new OverviewSidebarToggleItem(s.key, s.label, on, count);
    });
}
