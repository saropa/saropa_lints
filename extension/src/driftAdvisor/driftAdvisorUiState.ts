/**
 * Tracks Drift Advisor server connection state for diagnostics and Findings dashboard.
 */

import * as vscode from 'vscode';

let serverConnected = false;

export function setDriftAdvisorServerConnected(connected: boolean): void {
    serverConnected = connected;
}

export function isDriftAdvisorServerConnected(): boolean {
    return serverConnected;
}

/** Clear suppress memento when the server disconnects (legacy key kept for workspace state hygiene). */
export async function onDriftAdvisorDisconnected(ws: vscode.Memento): Promise<void> {
    setDriftAdvisorServerConnected(false);
    await ws.update('driftAdvisor.sidebarSuppressed', false);
    void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.sidebarSuppressed', false);
}
