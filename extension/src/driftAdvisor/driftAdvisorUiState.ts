/**
 * Tracks Drift Advisor server connection for Overview toggles and sidebar visibility.
 * When the user hides Drift while a server is connected, we suppress auto-show until disconnect.
 */

import * as vscode from 'vscode';
import { defaultSidebarSectionVisible } from '../sidebarSectionVisibilityKeys';

const MEMENTO_KEY = 'driftAdvisor.sidebarSuppressed';

let serverConnected = false;

export function setDriftAdvisorServerConnected(connected: boolean): void {
    serverConnected = connected;
}

export function isDriftAdvisorServerConnected(): boolean {
    return serverConnected;
}

/** Sync workspace memento → context key for package.json `when` clauses. */
export function syncDriftSidebarSuppressContext(ws: vscode.Memento): void {
    const suppressed = ws.get<boolean>(MEMENTO_KEY, false) ?? false;
    void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.sidebarSuppressed', suppressed);
}

/** Effective On/Off for the Overview row (user setting OR auto-show when server up and not suppressed). */
export function isDriftSidebarEffectiveVisible(ws: vscode.Memento, cfg: vscode.WorkspaceConfiguration): boolean {
    const def = defaultSidebarSectionVisible('sidebar.showDriftAdvisor');
    const user = cfg.get<boolean>('sidebar.showDriftAdvisor', def) ?? def;
    const suppressed = ws.get<boolean>(MEMENTO_KEY, false) ?? false;
    return user || (serverConnected && !suppressed);
}

export async function applyDriftSidebarToggle(
    ws: vscode.Memento,
    cfg: vscode.WorkspaceConfiguration,
    nextUserVisible: boolean,
    target: vscode.ConfigurationTarget,
): Promise<void> {
    await cfg.update('sidebar.showDriftAdvisor', nextUserVisible, target);
    if (!nextUserVisible && serverConnected) {
        await ws.update(MEMENTO_KEY, true);
    } else {
        await ws.update(MEMENTO_KEY, false);
    }
    syncDriftSidebarSuppressContext(ws);
}

/** Clear suppress when the server disconnects so the next session can auto-show again. */
export async function onDriftAdvisorDisconnected(ws: vscode.Memento): Promise<void> {
    setDriftAdvisorServerConnected(false);
    await ws.update(MEMENTO_KEY, false);
    syncDriftSidebarSuppressContext(ws);
}
