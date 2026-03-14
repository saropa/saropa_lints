/**
 * Tree data provider for Saropa Lints Config view.
 * Shows current extension settings, detected platform/packages, and quick actions.
 */

import * as vscode from 'vscode';
import { readPubspec } from '../pubspecReader';

class ConfigItem extends vscode.TreeItem {
  constructor(
    label: string,
    description?: string,
    command?: string,
  ) {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.description = description;
    if (command) {
      this.command = { command, title: label, arguments: [] };
    }
  }
}

export class ConfigTreeProvider implements vscode.TreeDataProvider<ConfigItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<ConfigItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: ConfigItem): vscode.TreeItem {
    return element;
  }

  async getChildren(): Promise<ConfigItem[]> {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const enabled = cfg.get<boolean>('enabled', false) ?? false;

    // C5: When disabled, return empty so viewsWelcome "Enable" shows.
    if (!enabled) return [];

    const tier = cfg.get<string>('tier', 'recommended') ?? 'recommended';
    const runAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true) ?? true;

    const items: ConfigItem[] = [
      new ConfigItem('Enabled', enabled ? 'Yes' : 'No', enabled ? 'saropaLints.disable' : 'saropaLints.enable'),
      new ConfigItem('Tier', tier, 'saropaLints.setTier'),
      new ConfigItem('Run analysis after config change', runAfter ? 'Yes' : 'No'),
    ];

    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (root) {
      const pubspec = readPubspec(root);
      const parts: string[] = [];
      if (pubspec.isFlutter) parts.push('Flutter');
      if (pubspec.packages.length > 0) {
        parts.push(pubspec.packages.slice(0, 5).join(', ') + (pubspec.packages.length > 5 ? '…' : ''));
      }
      const detectedDesc = parts.length > 0 ? parts.join(' · ') : undefined;
      items.push(new ConfigItem('Detected', detectedDesc));
    }

    items.push(
      new ConfigItem('Open analysis_options_custom.yaml', undefined, 'saropaLints.openConfig'),
      new ConfigItem('Initialize / Update config', undefined, 'saropaLints.initializeConfig'),
      new ConfigItem('Run analysis', undefined, 'saropaLints.runAnalysis'),
    );
    return items;
  }
}
