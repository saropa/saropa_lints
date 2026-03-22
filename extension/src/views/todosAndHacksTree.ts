/**
 * # TODOs & Hacks — tree data provider
 *
 * Lists task markers (TODO, FIXME, …) as **folder → file → line**, or **tag → file → line**
 * when `groupByTag` is on. Globs and tags default from `./todosAndHacksDefaults.ts`.
 *
 * ## Workspace scan gate
 *
 * Scanning many files is CPU/disk heavy. `saropaLints.todosAndHacks.workspaceScanEnabled`
 * defaults **false**; until the user opts in, the root is a single row that runs
 * `saropaLints.todosAndHacks.enableWorkspaceScan`. Extension save debounce and “Scanning…”
 * messages only apply when the gate is on.
 *
 * ## Concurrency
 *
 * `ensureScanPromise` prevents duplicate full scans when multiple tag nodes expand together.
 */

import * as vscode from 'vscode';
import * as path from 'node:path';
import { scanWorkspace } from '../services/todosAndHacksScanner';
import type { TaskMarker, ScanResult } from './todosAndHacksTypes';
import {
  DEFAULT_TODOS_AND_HACKS_EXCLUDE_GLOBS,
  DEFAULT_TODOS_AND_HACKS_INCLUDE_GLOBS,
  DEFAULT_TODOS_AND_HACKS_TAGS,
} from './todosAndHacksDefaults';

type TodoTreeNode =
  | { kind: 'folder'; folder: vscode.WorkspaceFolder }
  | { kind: 'file'; folderUri: string; filePath: string; markers: TaskMarker[] }
  | { kind: 'line'; marker: TaskMarker }
  | { kind: 'tag'; tag: string }
  | { kind: 'placeholder'; message: string }
  | { kind: 'enableWorkspaceScan' };

type Options = ReturnType<typeof getOptions>;

function getOptions(): {
  tags: string[];
  includeGlobs: string[];
  excludeGlobs: string[];
  maxFilesToScan: number;
  groupByTag: boolean;
  workspaceScanEnabled: boolean;
  customRegex?: string;
} {
  const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
  return {
    tags: cfg.get<string[]>('tags', [...DEFAULT_TODOS_AND_HACKS_TAGS]),
    includeGlobs: cfg.get<string[]>('includeGlobs', [...DEFAULT_TODOS_AND_HACKS_INCLUDE_GLOBS]),
    excludeGlobs: cfg.get<string[]>('excludeGlobs', [...DEFAULT_TODOS_AND_HACKS_EXCLUDE_GLOBS]),
    maxFilesToScan: cfg.get<number>('maxFilesToScan', 2000),
    groupByTag: cfg.get<boolean>('groupByTag', false),
    workspaceScanEnabled: cfg.get<boolean>('workspaceScanEnabled', false) ?? false,
    customRegex: cfg.get<string>('customRegex') || undefined,
  };
}

export class TodosAndHacksTreeProvider implements vscode.TreeDataProvider<TodoTreeNode> {
  private readonly _onDidChangeTreeData = new vscode.EventEmitter<TodoTreeNode | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  private readonly cacheByFolder = new Map<string, ScanResult>();
  private allMarkers: TaskMarker[] | null = null;
  private allCapped = false;
  /** Guards ensureAllScanned so concurrent getChildren (e.g. two tag nodes) don't run duplicate scans. */
  private ensureScanPromise: Promise<void> | null = null;

  refresh(): void {
    this.cacheByFolder.clear();
    this.allMarkers = null;
    this.allCapped = false;
    this.ensureScanPromise = null;
    this._onDidChangeTreeData.fire();
  }

  /** Total markers from last scan(s), or undefined if TODOs view has not been scanned yet. */
  getCachedMarkerCount(): number | undefined {
    if (this.allMarkers !== null) {
      return this.allMarkers.length;
    }
    let total = 0;
    let any = false;
    for (const r of this.cacheByFolder.values()) {
      any = true;
      total += r.markers.length;
    }
    return any ? total : undefined;
  }

  getTreeItem(element: TodoTreeNode): vscode.TreeItem {
    if (element.kind === 'enableWorkspaceScan') {
      const item = new vscode.TreeItem('Enable workspace scan…', vscode.TreeItemCollapsibleState.None);
      item.description = 'TODO/FIXME search (resource-intensive)';
      item.tooltip = 'Turn on to scan files for comment markers (up to saropaLints.todosAndHacks.maxFilesToScan). Off by default.';
      item.contextValue = 'todosEnableScan';
      item.command = {
        command: 'saropaLints.todosAndHacks.enableWorkspaceScan',
        title: 'Enable workspace scan',
        arguments: [],
      };
      item.iconPath = new vscode.ThemeIcon('search');
      return item;
    }
    if (element.kind === 'placeholder') {
      const item = new vscode.TreeItem(element.message, vscode.TreeItemCollapsibleState.None);
      item.contextValue = 'todosPlaceholder';
      return item;
    }
    if (element.kind === 'folder') {
      const item = new vscode.TreeItem(
        element.folder.name,
        vscode.TreeItemCollapsibleState.Collapsed,
      );
      item.description = element.folder.uri.fsPath;
      item.contextValue = 'todosFolder';
      item.iconPath = new vscode.ThemeIcon('folder');
      return item;
    }
    if (element.kind === 'tag') {
      const item = new vscode.TreeItem(
        element.tag,
        vscode.TreeItemCollapsibleState.Collapsed,
      );
      item.contextValue = 'todosTag';
      item.iconPath = new vscode.ThemeIcon('symbol-misc');
      return item;
    }
    if (element.kind === 'file') {
      const basename = path.basename(element.filePath);
      const item = new vscode.TreeItem(
        basename,
        vscode.TreeItemCollapsibleState.Collapsed,
      );
      item.description = `${element.markers.length} marker${element.markers.length === 1 ? '' : 's'}`;
      item.contextValue = 'todosFile';
      item.iconPath = new vscode.ThemeIcon('document');
      return item;
    }
    // line
    const { marker } = element;
    const label = marker.snippet.length > 60 ? `${marker.snippet.slice(0, 57)}…` : marker.snippet;
    const item = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.None);
    const wf = vscode.workspace.getWorkspaceFolder(marker.uri);
    item.description = wf ? path.relative(wf.uri.fsPath, marker.uri.fsPath).replaceAll('\\', '/') : path.basename(marker.uri.fsPath);
    item.tooltip = marker.fullLine;
    item.contextValue = 'todosLine';
    item.command = {
      command: 'vscode.open',
      title: 'Go to line',
      arguments: [
        marker.uri,
        { selection: new vscode.Range(marker.lineIndex, 0, marker.lineIndex, 0), preview: false },
      ],
    };
    item.iconPath = new vscode.ThemeIcon('symbol-misc');
    return item;
  }

  async getChildren(element?: TodoTreeNode): Promise<TodoTreeNode[]> {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) {
      return [{ kind: 'placeholder', message: 'No workspace folder open' }];
    }
    const options = getOptions();
    if (element === undefined && !options.workspaceScanEnabled) {
      return [{ kind: 'enableWorkspaceScan' }];
    }
    if (element === undefined) return this.getRootChildren(folders, options);
    if (element.kind === 'folder') return this.getFolderChildren(element, options);
    if (element.kind === 'tag') return this.getTagChildren(element, folders, options);
    if (element.kind === 'file') {
      return element.markers.map((marker) => ({ kind: 'line' as const, marker }));
    }
    return [];
  }

  private cappedPlaceholder(opts: Options): TodoTreeNode {
    return {
      kind: 'placeholder',
      message: `Limited to ${opts.maxFilesToScan} files (increase saropaLints.todosAndHacks.maxFilesToScan in settings)`,
    };
  }

  private fileNodesFromByFile(
    byFile: Map<string, TaskMarker[]>,
    folderUri: string,
  ): TodoTreeNode[] {
    const filePaths = Array.from(byFile.keys()).sort((a, b) => a.localeCompare(b));
    return filePaths.map((filePath) => {
      const markers = byFile.get(filePath);
      return markers
        ? { kind: 'file' as const, folderUri, filePath, markers }
        : null;
    }).filter((n): n is NonNullable<typeof n> => n !== null);
  }

  private async getRootChildren(
    folders: readonly vscode.WorkspaceFolder[],
    options: Options,
  ): Promise<TodoTreeNode[]> {
    if (!options.groupByTag) {
      return folders.map((f) => ({ kind: 'folder' as const, folder: f }));
    }
    await this.ensureAllScanned(folders, options);
    if (this.allMarkers === null) return [];
    const tagSet = new Set(this.allMarkers.map((m) => m.tag));
    const tags = options.tags.filter((t) => tagSet.has(t));
    const opts = getOptions();
    if (tags.length === 0 && this.allMarkers.length === 0) {
      return this.allCapped
        ? [this.cappedPlaceholder(opts)]
        : [{ kind: 'placeholder', message: 'No task markers found' }];
    }
    const tagNodes = tags.map((tag) => ({ kind: 'tag' as const, tag }));
    if (this.allCapped) return [this.cappedPlaceholder(opts), ...tagNodes];
    return tagNodes;
  }

  private async getFolderChildren(
    element: Extract<TodoTreeNode, { kind: 'folder' }>,
    options: Options,
  ): Promise<TodoTreeNode[]> {
    const key = element.folder.uri.toString();
    const cached = this.cacheByFolder.get(key);
    const result = cached ?? await scanWorkspace(element.folder, options);
    if (!cached) this.cacheByFolder.set(key, result);
    const byFile = new Map<string, TaskMarker[]>();
    for (const m of result.markers) {
      const rel = path.relative(element.folder.uri.fsPath, m.uri.fsPath);
      const filePath = rel.replaceAll('\\', '/');
      const list = byFile.get(filePath) ?? [];
      list.push(m);
      byFile.set(filePath, list);
    }
    const fileNodes = this.fileNodesFromByFile(byFile, element.folder.uri.toString());
    const opts = getOptions();
    if (result.capped) return [this.cappedPlaceholder(opts), ...fileNodes];
    if (fileNodes.length === 0) return [{ kind: 'placeholder', message: 'No markers in this folder' }];
    return fileNodes;
  }

  private async getTagChildren(
    element: Extract<TodoTreeNode, { kind: 'tag' }>,
    folders: readonly vscode.WorkspaceFolder[],
    options: Options,
  ): Promise<TodoTreeNode[]> {
    await this.ensureAllScanned(folders, options);
    if (this.allMarkers === null) return [];
    const forTag = this.allMarkers.filter((m) => m.tag === element.tag);
    const byFile = new Map<string, TaskMarker[]>();
    for (const m of forTag) {
      const folder = folders.find((f) => m.uri.fsPath.startsWith(f.uri.fsPath));
      const rel = folder ? path.relative(folder.uri.fsPath, m.uri.fsPath) : m.uri.fsPath;
      const filePath = rel.replaceAll('\\', '/');
      const list = byFile.get(filePath) ?? [];
      list.push(m);
      byFile.set(filePath, list);
    }
    return this.fileNodesFromByFile(byFile, '');
  }

  private async ensureAllScanned(
    folders: readonly vscode.WorkspaceFolder[],
    options: ReturnType<typeof getOptions>,
  ): Promise<void> {
    if (this.allMarkers !== null) return;
    const existing = this.ensureScanPromise;
    if (existing != null) return existing;
    this.ensureScanPromise = this.runEnsureAllScanned(folders, options);
    return this.ensureScanPromise;
  }

  private async runEnsureAllScanned(
    folders: readonly vscode.WorkspaceFolder[],
    options: ReturnType<typeof getOptions>,
  ): Promise<void> {
    const all: TaskMarker[] = [];
    let capped = false;
    for (const folder of folders) {
      const result = await scanWorkspace(folder, options);
      this.cacheByFolder.set(folder.uri.toString(), result);
      all.push(...result.markers);
      if (result.capped) capped = true;
    }
    this.allMarkers = all;
    this.allCapped = capped;
  }

  /** Call after refresh to set the tree view message when scan was capped. */
  getCappedMessage(): string | undefined {
    if (!this.allCapped && this.cacheByFolder.size === 0) return undefined;
    const opts = getOptions();
    if (this.allCapped) {
      return `Limited to ${opts.maxFilesToScan} files (increase saropaLints.todosAndHacks.maxFilesToScan in settings)`;
    }
    const cached = Array.from(this.cacheByFolder.values());
    if (cached.some((r) => r.capped)) {
      return `Limited to ${opts.maxFilesToScan} files (increase saropaLints.todosAndHacks.maxFilesToScan in settings)`;
    }
    return undefined;
  }
}
