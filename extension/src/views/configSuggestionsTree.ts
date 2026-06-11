/**
 * Tree provider for the dedicated **Suggestions** view.
 *
 * Proactive, config-driven (NOT violation-driven): it lists the hidden `init`
 * step and applicable-but-disabled rule packs computed by
 * {@link computeConfigSuggestions}, so the sidebar badge gives the user a visible
 * count of config actions they would otherwise never discover.
 *
 * Display strings are localized here through `l10n()`; the detection module stays
 * string-free and unit-testable.
 */

import * as vscode from 'vscode';

import {
  computeConfigSuggestions,
  countConfigSuggestions,
  type ConfigSuggestion,
} from '../config/configSuggestions';
import { getProjectRoot } from '../projectRoot';
import { l10n } from '../i18n/runtime';

class ConfigSuggestionItem extends vscode.TreeItem {
  constructor(
    label: string,
    description: string | undefined,
    iconId: string,
    commandId: string,
    args: unknown[] = [],
  ) {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.description = description;
    this.iconPath = new vscode.ThemeIcon(iconId);
    this.contextValue = 'configSuggestionItem';
    this.command = { command: commandId, title: label, arguments: args };
  }
}

/** Maps one structured suggestion to a localized, clickable tree item. */
function toItem(s: ConfigSuggestion): ConfigSuggestionItem {
  if (s.kind === 'init-missing') {
    return new ConfigSuggestionItem(
      l10n('configSuggestions.initMissing.title'),
      l10n('configSuggestions.initMissing.detail'),
      'rocket',
      'saropaLints.initializeConfig',
    );
  }
  // pack-available
  return new ConfigSuggestionItem(
    l10n('configSuggestions.packAvailable.title', { pack: s.packLabel ?? s.id }),
    l10n('configSuggestions.packAvailable.detail', { count: String(s.ruleCount ?? 0) }),
    'extensions',
    'saropaLints.enableRulePack',
    [s.packId],
  );
}

export class ConfigSuggestionsTreeProvider
  implements vscode.TreeDataProvider<ConfigSuggestionItem>
{
  private _onDidChangeTreeData = new vscode.EventEmitter<
    ConfigSuggestionItem | undefined | void
  >();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: ConfigSuggestionItem): vscode.TreeItem {
    return element;
  }

  async getChildren(): Promise<ConfigSuggestionItem[]> {
    const root = getProjectRoot();
    // Empty array lets the view's viewsWelcome ("all set up") render.
    if (!root) return [];
    return computeConfigSuggestions(root).map(toItem);
  }

  /** Badge count without building tree items (kept cheap for frequent refresh). */
  count(): number {
    const root = getProjectRoot();
    return root ? countConfigSuggestions(root) : 0;
  }
}
