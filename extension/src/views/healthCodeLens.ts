/**
 * In-editor "heat" CodeLens: shows the worst functions' cognitive complexity
 * above them in Dart files, read from the last Saropa Project Map scan's NDJSON shard
 * (`reports/.saropa_lints/health/files.ndjson`). Data-gated (nothing shows until
 * a scan has run), parsed once and cached by mtime, and refreshed by a file
 * watcher when a new scan lands — so it never re-reads on every keystroke.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { l10n } from '../i18n/runtime';

interface FnHeat {
  name: string;
  line: number;
  cognitive: number;
  nesting: number;
}

/** Whether the heat CodeLens is enabled (OFF by default — opt-in so it never
 * overwhelms; users flip it with the toggle command or in Settings). */
function heatEnabled(): boolean {
  return vscode.workspace
    .getConfiguration('saropaLints')
    .get<boolean>('projectMap.codeLensHeat', false);
}

/** Registers the heat CodeLens provider, its toggle command, and a refresh
 * watcher. The feature is off until the user opts in. */
export function registerHealthCodeLens(context: vscode.ExtensionContext): void {
  const provider = new HealthCodeLensProvider();
  context.subscriptions.push(
    vscode.languages.registerCodeLensProvider({ language: 'dart', scheme: 'file' }, provider),
    provider,
    // One-click enable/disable so it's trivial to silence.
    vscode.commands.registerCommand('saropaLints.toggleProjectMapCodeLensHeat', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const next = !cfg.get<boolean>('projectMap.codeLensHeat', false);
      await cfg.update('projectMap.codeLensHeat', next, vscode.ConfigurationTarget.Global);
      // Distinct keys per state rather than an in-code enabled/disabled ternary
      // so each form is translatable (word order/agreement differs by locale).
      void vscode.window.showInformationMessage(
        next
          ? l10n('notify.misc.healthCodeLensEnabled')
          : l10n('notify.misc.healthCodeLensDisabled'),
      );
      provider.refresh();
    }),
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration('saropaLints.projectMap.codeLensHeat')) provider.refresh();
    }),
  );
  const root = getProjectRoot();
  if (root) {
    const ndjson = path.join(root, 'reports', '.saropa_lints', 'health', 'files.ndjson');
    const watcher = vscode.workspace.createFileSystemWatcher(ndjson);
    watcher.onDidChange(() => provider.refresh());
    watcher.onDidCreate(() => provider.refresh());
    context.subscriptions.push(watcher);
  }
}

class HealthCodeLensProvider implements vscode.CodeLensProvider, vscode.Disposable {
  private readonly changed = new vscode.EventEmitter<void>();
  readonly onDidChangeCodeLenses = this.changed.event;

  private cache: Map<string, FnHeat[]> | undefined;
  private cacheMtimeMs = 0;
  private cacheRoot: string | undefined;

  refresh(): void {
    this.cache = undefined;
    this.changed.fire();
  }

  dispose(): void {
    this.changed.dispose();
  }

  provideCodeLenses(document: vscode.TextDocument): vscode.CodeLens[] {
    if (!heatEnabled()) return []; // opt-in; off by default
    const root = getProjectRoot();
    if (!root) return [];
    this.ensureCache(root);
    const rel = path.relative(root, document.uri.fsPath).split(path.sep).join('/');
    const fns = this.cache?.get(rel);
    if (!fns) return [];
    return fns.map((fn) => {
      const line = Math.max(0, fn.line - 1);
      return new vscode.CodeLens(new vscode.Range(line, 0, line, 0), {
        title: `🔥 ${fn.name}: cognitive ${fn.cognitive}, nesting ${fn.nesting}`,
        command: '',
      });
    });
  }

  private ensureCache(root: string): void {
    const ndjson = path.join(root, 'reports', '.saropa_lints', 'health', 'files.ndjson');
    if (!fs.existsSync(ndjson)) {
      this.cache = new Map();
      return;
    }
    const mtimeMs = fs.statSync(ndjson).mtimeMs;
    if (this.cache && this.cacheRoot === root && this.cacheMtimeMs === mtimeMs) return;
    this.cache = this.parse(ndjson);
    this.cacheMtimeMs = mtimeMs;
    this.cacheRoot = root;
  }

  private parse(ndjson: string): Map<string, FnHeat[]> {
    const map = new Map<string, FnHeat[]>();
    for (const raw of fs.readFileSync(ndjson, 'utf8').split('\n')) {
      if (raw.trim().length === 0) continue;
      try {
        const row = JSON.parse(raw) as {
          path?: string;
          complexity?: { topFunctions?: FnHeat[] };
        };
        const fns = row.complexity?.topFunctions;
        if (row.path && Array.isArray(fns) && fns.length > 0) {
          map.set(
            row.path,
            fns.map((f) => ({
              name: f.name,
              line: f.line ?? (f as { lineStart?: number }).lineStart ?? 1,
              cognitive: f.cognitive,
              nesting: f.nesting,
            })),
          );
        }
      } catch {
        // Skip a malformed NDJSON line rather than failing the whole provider.
      }
    }
    return map;
  }
}
