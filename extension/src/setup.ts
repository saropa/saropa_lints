/**
 * Setup and run commands: add saropa_lints to pubspec, pub get, init, analyze.
 * Replaces the init process from the user's perspective.
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { spawnSync } from 'child_process';

const SAROPA_LINTS_DEV_DEP = 'saropa_lints';
const DEFAULT_VERSION = '^8.0.0';

const OUTPUT_CHANNEL_NAME = 'Saropa Lints';

// Lazily-initialized singleton to avoid creating multiple channel objects.
let _outputChannel: vscode.OutputChannel | undefined;
function getOutputChannel(): vscode.OutputChannel {
  if (!_outputChannel) _outputChannel = vscode.window.createOutputChannel(OUTPUT_CHANNEL_NAME);
  return _outputChannel;
}

function getWorkspaceRoot(): string | undefined {
  const folder = vscode.workspace.workspaceFolders?.[0];
  if (!folder) return undefined;
  return folder.uri.fsPath;
}

function hasFlutterDep(pubspecPath: string): boolean {
  try {
    const content = fs.readFileSync(pubspecPath, 'utf-8');
    return /flutter:\s*$/m.test(content) || content.includes('sdk: flutter');
  } catch {
    return false;
  }
}

function ensureSaropaLintsInPubspec(workspaceRoot: string): boolean {
  const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
  if (!fs.existsSync(pubspecPath)) {
    vscode.window.showErrorMessage('No pubspec.yaml found in workspace root.');
    return false;
  }
  let content = fs.readFileSync(pubspecPath, 'utf-8');
  if (content.includes(SAROPA_LINTS_DEV_DEP)) return true;

  const devDepsMatch = content.match(/(\s*dev_dependencies:\s*)(\n(?:\s{2}\S+.*\n)*)/);
  if (devDepsMatch) {
    const insert = `${devDepsMatch[1]}  ${SAROPA_LINTS_DEV_DEP}: ${DEFAULT_VERSION}\n${devDepsMatch[2]}`;
    content = content.replace(devDepsMatch[0], insert);
  } else {
    content = content.trimEnd() + `\n\ndev_dependencies:\n  ${SAROPA_LINTS_DEV_DEP}: ${DEFAULT_VERSION}\n`;
  }
  fs.writeFileSync(pubspecPath, content, 'utf-8');
  return true;
}

/** Builds args for non-interactive init (Enable, Initialize config, Set tier). */
function buildInitArgs(workspaceRoot: string, tier: string): string[] {
  return [
    'run',
    'saropa_lints:init',
    '--tier',
    tier,
    '--no-stylistic',
    '--target',
    workspaceRoot,
  ];
}

function runInWorkspace(workspaceRoot: string, command: string, args: string[], logToOutput = true): { ok: boolean; stderr: string; stdout: string } {
  if (logToOutput) {
    const ch = getOutputChannel();
    ch.appendLine(`$ ${command} ${args.join(' ')}`);
  }
  const result = spawnSync(command, args, {
    cwd: workspaceRoot,
    encoding: 'utf-8',
    shell: true,
  });
  const stdout = (result.stdout ?? '') as string;
  const stderr = (result.stderr || result.error?.message || '') as string;
  if (logToOutput) {
    const ch = getOutputChannel();
    if (stdout) ch.appendLine(stdout);
    if (stderr) ch.appendLine(stderr);
  }
  return {
    ok: result.status === 0,
    stderr,
    stdout,
  };
}

export async function runEnable(context: vscode.ExtensionContext): Promise<boolean> {
  const workspaceRoot = getWorkspaceRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage('No workspace folder open.');
    return false;
  }

  let success = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Enabling Saropa Lints',
      cancellable: false,
    },
    async () => {
      if (!ensureSaropaLintsInPubspec(workspaceRoot)) return;

      const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
      const pubCmd = useFlutter ? 'flutter' : 'dart';
      const { ok: pubOk, stderr: pubErr } = runInWorkspace(workspaceRoot, pubCmd, ['pub', 'get']);
      if (!pubOk) {
        vscode.window.showErrorMessage(`Saropa Lints: pub get failed. ${pubErr || 'Check Output.'}`);
        return;
      }

      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const tier = (cfg.get<string>('tier') ?? 'recommended').trim();
      const { ok: initOk, stderr: initErr } = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
      if (!initOk) {
        vscode.window.showErrorMessage(`Saropa Lints: init failed. ${initErr || 'Check Output.'}`);
        return;
      }

      const runAnalysisAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true);
      if (runAnalysisAfter) {
        const analyzeCmd = useFlutter ? 'flutter' : 'dart';
        runInWorkspace(workspaceRoot, analyzeCmd, ['analyze']);
      }
      success = true;
    },
  );

  // I5: Notification moved to extension.ts enable handler where health score is available.
  return success;
}

export async function runDisable(): Promise<void> {
  await vscode.workspace.getConfiguration('saropaLints').update('enabled', false, vscode.ConfigurationTarget.Workspace);
  vscode.window.showInformationMessage('Saropa Lints is disabled. Project files were not changed.');
}

export async function runAnalysis(context: vscode.ExtensionContext): Promise<boolean> {
  const workspaceRoot = getWorkspaceRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage('No workspace folder open.');
    return false;
  }
  const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
  const cmd = useFlutter ? 'flutter' : 'dart';
  let ok = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Running analysis',
      cancellable: false,
    },
    async () => {
      const result = runInWorkspace(workspaceRoot, cmd, ['analyze']);
      ok = result.ok;
      if (!ok) {
        vscode.window.showWarningMessage(
          `Analysis reported issues. ${result.stderr ? result.stderr.slice(0, 200) : 'See Problems view.'}`,
        );
      }
    },
  );
  return ok;
}

export async function runInitializeConfig(context: vscode.ExtensionContext, title?: string): Promise<boolean> {
  const workspaceRoot = getWorkspaceRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage('No workspace folder open.');
    return false;
  }
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  const tier = (cfg.get<string>('tier') ?? 'recommended').trim();
  let ok = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: title ?? 'Initializing Saropa Lints config',
      cancellable: false,
    },
    async () => {
      const result = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
      ok = result.ok;
      if (!ok) {
        vscode.window.showErrorMessage(`Init failed. ${result.stderr || 'Check Output.'}`);
      } else {
        vscode.window.showInformationMessage(`Saropa Lints config updated (tier: ${tier}).`);
      }
    },
  );
  return ok;
}

export async function openConfig(): Promise<void> {
  const workspaceRoot = getWorkspaceRoot();
  if (!workspaceRoot) return;
  const customPath = path.join(workspaceRoot, 'analysis_options_custom.yaml');
  const uri = fs.existsSync(customPath)
    ? vscode.Uri.file(customPath)
    : vscode.Uri.file(path.join(workspaceRoot, 'analysis_options.yaml'));
  const doc = await vscode.workspace.openTextDocument(uri);
  await vscode.window.showTextDocument(doc);
}

export async function runRepairConfig(context: vscode.ExtensionContext): Promise<boolean> {
  return runInitializeConfig(context);
}

export async function runSetTier(context: vscode.ExtensionContext): Promise<boolean> {
  const tier = await vscode.window.showQuickPick(
    ['essential', 'recommended', 'professional', 'comprehensive', 'pedantic'],
    { placeHolder: 'Select tier', title: 'Saropa Lints: Set tier' },
  );
  if (!tier) return false;
  const workspaceRoot = getWorkspaceRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage('No workspace folder open.');
    return false;
  }
  await vscode.workspace.getConfiguration('saropaLints').update('tier', tier, vscode.ConfigurationTarget.Workspace);
  let ok = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Updating tier',
      cancellable: false,
    },
    async () => {
      const result = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
      ok = result.ok;
      if (!ok) {
        vscode.window.showErrorMessage(`Init failed. ${result.stderr || 'Check Output.'}`);
        return;
      }
      vscode.window.showInformationMessage(`Saropa Lints tier set to ${tier}.`);
      // C6: Re-analyze after tier change so violations.json reflects the new ruleset,
      // matching the behavior of runEnable.
      const cfgAfter = vscode.workspace.getConfiguration('saropaLints');
      const runAnalysisAfter = cfgAfter.get<boolean>('runAnalysisAfterConfigChange', true);
      if (runAnalysisAfter) {
        const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
        const analyzeCmd = useFlutter ? 'flutter' : 'dart';
        runInWorkspace(workspaceRoot, analyzeCmd, ['analyze']);
      }
    },
  );
  return ok;
}

export function showOutputChannel(): void {
  getOutputChannel().show();
}
