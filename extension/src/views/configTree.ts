/**
 * Tree data provider for Saropa Lints Config view.
 * Shows current extension settings and quick actions.
 */

import * as vscode from 'vscode';

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
    const tier = cfg.get<string>('tier', 'recommended') ?? 'recommended';
    const runAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true) ?? true;

    return [
      new ConfigItem('Enabled', enabled ? 'Yes' : 'No'),
      new ConfigItem('Tier', tier),
      new ConfigItem('Run analysis after config change', runAfter ? 'Yes' : 'No'),
      new ConfigItem('Open analysis_options_custom.yaml', undefined, 'saropaLints.openConfig'),
      new ConfigItem('Initialize / Update config', undefined, 'saropaLints.initializeConfig'),
      new ConfigItem('Run analysis', undefined, 'saropaLints.runAnalysis'),
    ];
  }
}
