/**
 * Mirrors `saropaLints.sidebar.show*` into VS Code context keys when section toggles exist.
 * After the dashboard migration, {@link SIDEBAR_SECTION_CONFIG_KEYS} is empty; **Overview**
 * visibility uses `config.saropaLints.sidebar.showOverview` directly in `package.json`.
 */

import * as vscode from 'vscode';
import {
    SIDEBAR_SECTION_CONFIG_KEYS,
    defaultSidebarSectionVisible,
    sidebarSectionContextKey,
} from './sidebarSectionVisibilityKeys';

export { SIDEBAR_SECTION_COUNT } from './sidebarSectionVisibilityKeys';

export function updateSidebarSectionVisibility(): void {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    for (const rel of SIDEBAR_SECTION_CONFIG_KEYS) {
        const def = defaultSidebarSectionVisible(rel);
        const v = cfg.get<boolean>(rel, def) ?? def;
        void vscode.commands.executeCommand('setContext', sidebarSectionContextKey(rel), v);
    }
}

export function registerSidebarSectionVisibility(context: vscode.ExtensionContext): void {
    context.subscriptions.push(
        vscode.workspace.onDidChangeConfiguration((e) => {
            for (const rel of SIDEBAR_SECTION_CONFIG_KEYS) {
                if (e.affectsConfiguration(sidebarSectionContextKey(rel))) {
                    updateSidebarSectionVisibility();
                    return;
                }
            }
        }),
    );
}
