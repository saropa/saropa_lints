/**
 * Drift Advisor auth token reader — single source of truth for the
 * saropaLints.driftAdvisor.authToken setting. Separated from client.ts
 * so that client.ts stays vscode-free and testable without mocks.
 */

import * as vscode from 'vscode';

/** Read the configured Drift Advisor auth token from VS Code settings. */
export function getDriftAuthToken(): string | undefined {
  const raw = vscode.workspace
    .getConfiguration('saropaLints.driftAdvisor')
    .get<string>('authToken', '')
    .trim();
  return raw || undefined;
}
