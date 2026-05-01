/**
 * Apply a single `saropaLints.sidebar.show*` boolean from dashboard UI or tests.
 */

import * as vscode from 'vscode';
import { SIDEBAR_SECTION_CONFIG_KEYS } from '../sidebarSectionVisibilityKeys';
import { updateSidebarSectionVisibility } from '../sidebarSectionVisibility';

/**
 * Sets one sidebar visibility key to `enabled` (workspace when a folder is open, else user).
 */
export async function applySidebarSectionSetting(
  _workspaceState: vscode.Memento,
  key: string,
  enabled: boolean,
): Promise<void> {
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  const target = vscode.workspace.workspaceFolders?.length
    ? vscode.ConfigurationTarget.Workspace
    : vscode.ConfigurationTarget.Global;

  await cfg.update(key, enabled, target);
  updateSidebarSectionVisibility();
}

/** True when `key` is one of `saropaLints.sidebar.show*` keys (relative segment under `saropaLints`). */
export function isSidebarSectionConfigKey(key: string): boolean {
  return (SIDEBAR_SECTION_CONFIG_KEYS as readonly string[]).includes(key);
}
