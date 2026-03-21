/**
 * Collapsible "Sidebar" group and leaf rows for per-section visibility toggles.
 */

import * as vscode from 'vscode';
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
    constructor(readonly sectionKey: string, label: string, on: boolean, count?: number) {
        super(label, vscode.TreeItemCollapsibleState.None);
        const state = on ? 'On' : 'Off';
        this.description =
            count !== undefined && Number.isFinite(count) ? `${state} · ${count}` : state;
        this.iconPath = new vscode.ThemeIcon(on ? 'eye' : 'eye-closed');
        this.command = {
            command: 'saropaLints.toggleSidebarSection',
            title: 'Toggle',
            arguments: [sectionKey],
        };
        this.contextValue = 'overviewSidebarToggle';
        if (count !== undefined && Number.isFinite(count)) {
            this.tooltip = `${label}: ${count} (click to show or hide in the activity bar)`;
        }
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
