/**
 * Webviews and other in-process call sites use {@link applyDashboardSidebarSectionFromHost}
 * instead of `executeCommand('saropaLints.applyDashboardSidebarSection', …)` to avoid VS Code
 * delegating command wrappers (`<command> /N`) that can race extension-host restarts and fail
 * with "Actual command not found" (see e.g. microsoft/vscode#170117).
 */

import * as vscode from 'vscode';
import { applySidebarSectionSetting, isSidebarSectionConfigKey } from './sidebarSectionApply';
import { l10n } from '../i18n/runtime';

let workspaceState: vscode.Memento | undefined;
let dependentViewRefresh: (() => void) | undefined;

export function registerDashboardSidebarSectionHost(
  workspaceStateMemento: vscode.Memento,
  refreshDependentViews: () => void,
): void {
  workspaceState = workspaceStateMemento;
  dependentViewRefresh = refreshDependentViews;
}

/**
 * Rebuilds Overview, Lints Config dashboard, and open package/project dashboards so UI matches
 * `saropaLints.sidebar.show*`. Call after `updateSidebarSectionVisibility` when the setting
 * was changed without {@link applySidebarSectionSetting} (e.g. toggle).
 */
export function refreshDashboardSidebarDependentViews(): void {
  dependentViewRefresh?.();
}

export async function applyDashboardSidebarSectionFromHost(
  key: string,
  enabled: boolean,
): Promise<void> {
  if (!isSidebarSectionConfigKey(key) || !workspaceState) {
    return;
  }
  try {
    await applySidebarSectionSetting(workspaceState, key, enabled);
    dependentViewRefresh?.();
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    void vscode.window.showErrorMessage(l10n('notify.commands.sidebarSectionUpdateFailed', { message: msg }));
  }
}
