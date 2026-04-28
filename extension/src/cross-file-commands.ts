import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { runInWorkspace, getSharedOutputChannel } from './setup';
import { getProjectRoot } from './projectRoot';
import { hasSaropaLintsDep } from './pubspecReader';

type CrossFileSummary = {
  unusedFiles?: unknown[];
  circularDependencies?: unknown[];
  featureDependencies?: Record<string, unknown[]>;
  crossFeatureImports?: unknown[];
  deadImports?: Record<string, unknown[]>;
  unusedSymbols?: Record<string, unknown[]>;
  missingMirrorTests?: unknown[];
  stats?: {
    fileCount?: number;
    totalImports?: number;
  };
};

/**
 * Registers cross-file analysis commands that wrap `dart run saropa_lints:cross_file`.
 * This keeps CLI-only features discoverable for extension users.
 */
export function registerCrossFileCommands(context: vscode.ExtensionContext): void {
  const commandSpecs: Array<{
    id: string;
    command: string;
    title: string;
  }> = [
    { id: 'saropaLints.crossFile.unusedFiles', command: 'unused-files', title: 'Unused files' },
    { id: 'saropaLints.crossFile.circularDeps', command: 'circular-deps', title: 'Circular dependencies' },
    { id: 'saropaLints.crossFile.importStats', command: 'import-stats', title: 'Import statistics' },
    { id: 'saropaLints.crossFile.featureDeps', command: 'feature-deps', title: 'Feature dependencies' },
    { id: 'saropaLints.crossFile.deadImports', command: 'dead-imports', title: 'Dead imports' },
    { id: 'saropaLints.crossFile.unusedSymbols', command: 'unused-symbols', title: 'Unused symbols' },
  ];

  for (const spec of commandSpecs) {
    context.subscriptions.push(
      vscode.commands.registerCommand(spec.id, async () => {
        const root = getWorkspaceRootOrError();
        if (!root) return;
        if (!ensureSaropaDependency(root)) return;

        const args = [
          'run',
          'saropa_lints:cross_file',
          '--path',
          root,
          '--output',
          'json',
          spec.command,
        ];
        const result = runInWorkspace(root, 'dart', args, true);
        getSharedOutputChannel().show(true);
        if (!result.ok) {
          const message = summarizeError(result.stderr);
          void vscode.window.showErrorMessage(`Saropa Lints ${spec.title} failed: ${message}`);
          return;
        }

        const summary = parseSummary(result.stdout);
        const status = buildStatusMessage(spec.command, summary);
        if (status) {
          vscode.window.setStatusBarMessage(`Saropa Lints: ${status}`, 5000);
        }
      }),
    );
  }

  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.crossFile.graph', async () => {
      const root = getWorkspaceRootOrError();
      if (!root) return;
      if (!ensureSaropaDependency(root)) return;

      const outputDir = path.join(root, 'reports', '.saropa_lints', 'cross_file');
      const args = [
        'run',
        'saropa_lints:cross_file',
        '--path',
        root,
        'graph',
        '--output-dir',
        outputDir,
      ];
      const result = runInWorkspace(root, 'dart', args, true);
      getSharedOutputChannel().show(true);
      if (!result.ok) {
        const message = summarizeError(result.stderr);
        void vscode.window.showErrorMessage(`Saropa Lints graph export failed: ${message}`);
        return;
      }

      const dotPath = path.join(outputDir, 'import_graph.dot');
      if (!fs.existsSync(dotPath)) {
        void vscode.window.showWarningMessage('Cross-file graph completed but no DOT file was found.');
        return;
      }
      const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(dotPath));
      await vscode.window.showTextDocument(doc, { preview: false });
      void vscode.window.showInformationMessage('Cross-file graph exported to reports/.saropa_lints/cross_file/import_graph.dot');
    }),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.crossFile.report', async () => {
      const root = getWorkspaceRootOrError();
      if (!root) return;
      if (!ensureSaropaDependency(root)) return;

      const outputDir = path.join(root, 'reports', '.saropa_lints', 'cross_file');
      const args = [
        'run',
        'saropa_lints:cross_file',
        '--path',
        root,
        'report',
        '--output-dir',
        outputDir,
      ];
      const result = runInWorkspace(root, 'dart', args, true);
      getSharedOutputChannel().show(true);
      if (!result.ok) {
        const message = summarizeError(result.stderr);
        void vscode.window.showErrorMessage(`Cross-file HTML report failed: ${message}`);
        return;
      }

      const indexPath = path.join(outputDir, 'index.html');
      if (!fs.existsSync(indexPath)) {
        void vscode.window.showWarningMessage('Cross-file report completed but index.html was not found.');
        return;
      }

      const uri = vscode.Uri.file(indexPath);
      const openExternal = await vscode.window.showInformationMessage(
        'Cross-file HTML report generated.',
        'Open in Browser',
        'Open File',
      );
      if (openExternal === 'Open in Browser') {
        await vscode.env.openExternal(uri);
        return;
      }
      const doc = await vscode.workspace.openTextDocument(uri);
      await vscode.window.showTextDocument(doc, { preview: false });
    }),
  );
}

function getWorkspaceRootOrError(): string | null {
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(
      'Saropa Lints: no Dart/Flutter workspace found. Open a project with pubspec.yaml first.',
    );
    return null;
  }
  return root;
}

function ensureSaropaDependency(workspaceRoot: string): boolean {
  if (hasSaropaLintsDep(workspaceRoot)) return true;
  void vscode.window.showErrorMessage(
    'Saropa Lints: add saropa_lints to pubspec.yaml before running cross-file analysis.',
  );
  return false;
}

function summarizeError(stderr: string): string {
  const trimmed = stderr.trim();
  if (!trimmed) return 'See Output for details.';
  const firstLine = trimmed.split(/\r?\n/)[0] ?? 'See Output for details.';
  return firstLine.length > 180 ? `${firstLine.slice(0, 177)}...` : firstLine;
}

function parseSummary(stdout: string): CrossFileSummary | null {
  const trimmed = stdout.trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed) as CrossFileSummary;
  } catch {
    return null;
  }
}

function count(items: unknown[] | undefined): number {
  return Array.isArray(items) ? items.length : 0;
}

function buildStatusMessage(command: string, summary: CrossFileSummary | null): string | null {
  if (!summary) return null;
  if (command === 'unused-files') {
    return `${count(summary.unusedFiles)} unused file(s)`;
  }
  if (command === 'circular-deps') {
    return `${count(summary.circularDependencies)} circular dependency chain(s)`;
  }
  if (command === 'import-stats') {
    const fileCount = summary.stats?.fileCount ?? 0;
    const totalImports = summary.stats?.totalImports ?? 0;
    return `${fileCount} file(s), ${totalImports} import edge(s)`;
  }
  if (command === 'feature-deps') {
    const featureCount = Object.keys(summary.featureDependencies ?? {}).length;
    const edgeCount = count(summary.crossFeatureImports);
    return `${featureCount} feature(s), ${edgeCount} cross-feature import(s)`;
  }
  if (command === 'unused-symbols') {
    const values = Object.values(summary.unusedSymbols ?? {});
    const total = values.reduce((sum, items) => sum + (Array.isArray(items) ? items.length : 0), 0);
    return `${total} likely unused symbol(s)`;
  }
  if (command === 'dead-imports') {
    const values = Object.values(summary.deadImports ?? {});
    const total = values.reduce((sum, items) => sum + (Array.isArray(items) ? items.length : 0), 0);
    return `${total} likely dead import(s)`;
  }
  return null;
}
