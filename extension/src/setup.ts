/**
 * Setup and run commands: add saropa_lints to pubspec, pub get, init, analyze.
 * Replaces the init process from the user's perspective.
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { spawnSync } from 'child_process';
import { logReport, logSection, flushReport } from './reportWriter';

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
    void vscode.window.showErrorMessage(
      'Saropa Lints requires a Dart or Flutter project (no pubspec.yaml found).',
      'Learn More',
    ).then((choice) => {
      if (choice === 'Learn More') {
        void vscode.env.openExternal(vscode.Uri.parse('https://pub.dev/packages/saropa_lints'));
      }
    });
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
      logSection('Enable');

      if (!ensureSaropaLintsInPubspec(workspaceRoot)) return;
      logReport('- Added saropa_lints to pubspec.yaml');

      const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
      const pubCmd = useFlutter ? 'flutter' : 'dart';
      const { ok: pubOk, stderr: pubErr } = runInWorkspace(workspaceRoot, pubCmd, ['pub', 'get']);
      if (!pubOk) {
        logReport(`- pub get FAILED: ${pubErr || '(no details)'}`);
        flushReport(workspaceRoot);
        vscode.window.showErrorMessage(`Saropa Lints: pub get failed. ${pubErr || 'Check Output.'}`);
        return;
      }
      logReport(`- Ran pub get (${pubCmd})`);

      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const tier = (cfg.get<string>('tier') ?? 'recommended').trim();
      const { ok: initOk, stderr: initErr } = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
      if (!initOk) {
        logReport(`- init FAILED: ${initErr || '(no details)'}`);
        flushReport(workspaceRoot);
        vscode.window.showErrorMessage(`Saropa Lints: init failed. ${initErr || 'Check Output.'}`);
        return;
      }
      logReport(`- Ran init --tier ${tier} --no-stylistic`);

      const runAnalysisAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true);
      if (runAnalysisAfter) {
        const analyzeCmd = useFlutter ? 'flutter' : 'dart';
        runInWorkspace(workspaceRoot, analyzeCmd, ['analyze']);
        logReport('- Ran analysis');
      }
      success = true;
      flushReport(workspaceRoot);
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
      logSection('Analysis');
      const result = runInWorkspace(workspaceRoot, cmd, ['analyze']);
      ok = result.ok;
      if (!ok) {
        logReport(`- Analysis reported issues (${cmd} analyze)`);
        vscode.window.showWarningMessage(
          `Analysis reported issues. ${result.stderr ? result.stderr.slice(0, 200) : 'See Problems view.'}`,
        );
      } else {
        logReport('- Analysis completed clean');
      }
      flushReport(workspaceRoot);
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
      logSection('Initialize Config');
      const result = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
      ok = result.ok;
      if (!ok) {
        logReport(`- Init FAILED: ${result.stderr || '(no details)'}`);
        flushReport(workspaceRoot);
        vscode.window.showErrorMessage(`Init failed. ${result.stderr || 'Check Output.'}`);
      } else {
        logReport(`- Config initialized (tier: ${tier})`);
        flushReport(workspaceRoot);
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

/** Tier metadata for the picker — labels, cumulative rule counts, short descriptions. */
const TIER_INFO = [
  { id: 'essential', label: 'Essential', rules: 297, desc: 'Security and critical issues only' },
  { id: 'recommended', label: 'Recommended', rules: 895, desc: 'Best practices for most projects' },
  { id: 'professional', label: 'Professional', rules: 1834, desc: 'Comprehensive coverage for teams' },
  { id: 'comprehensive', label: 'Comprehensive', rules: 1959, desc: 'Thorough analysis with minor rules' },
  { id: 'pedantic', label: 'Pedantic', rules: 1984, desc: 'Every rule enabled' },
] as const;

/** Ordered tier IDs for upgrade/downgrade comparison. Exported for use in extension.ts. */
export const TIER_ORDER: readonly string[] = TIER_INFO.map(t => t.id);

/** Result of a successful tier change — includes both tiers for delta display. */
export interface TierChangeResult {
  tier: string;
  tierLabel: string;
  previousTier: string;
}

/** Look up the capitalized label for a tier id (e.g. 'recommended' → 'Recommended'). */
function tierLabel(id: string): string {
  return TIER_INFO.find(t => t.id === id)?.label ?? id;
}

/** Run init + optional analysis for a tier change; returns true on success. */
function applyTierChange(workspaceRoot: string, tier: string, previousTier: string): boolean {
  logSection('Set Tier');
  logReport(`- Changed tier: ${previousTier} → ${tier}`);
  const initResult = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
  if (!initResult.ok) {
    logReport(`- Init FAILED: ${initResult.stderr || '(no details)'}`);
    flushReport(workspaceRoot);
    vscode.window.showErrorMessage(`Init failed. ${initResult.stderr || 'Check Output.'}`);
    return false;
  }
  logReport(`- Ran init --tier ${tier} --no-stylistic`);
  // C6: Re-analyze after tier change so violations.json reflects the new ruleset.
  const runAnalysisAfter = vscode.workspace.getConfiguration('saropaLints')
    .get<boolean>('runAnalysisAfterConfigChange', true);
  if (runAnalysisAfter) {
    const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
    const analyzeCmd = useFlutter ? 'flutter' : 'dart';
    const analyzeResult = runInWorkspace(workspaceRoot, analyzeCmd, ['analyze']);
    // Log whether analysis succeeded — a non-zero exit is expected when violations exist.
    logReport(analyzeResult.ok ? '- Analysis completed' : '- Analysis reported issues');
  }
  flushReport(workspaceRoot);
  return true;
}

/**
 * Show an enhanced tier picker and run init + analysis for the selected tier.
 * Returns the new and previous tier on success, or null on cancel/failure/same-tier.
 */
export async function runSetTier(context: vscode.ExtensionContext): Promise<TierChangeResult | null> {
  const previousTier = (vscode.workspace.getConfiguration('saropaLints').get<string>('tier') ?? 'recommended').trim();

  // Build descriptive pick items — current tier marked with checkmark, rule counts shown.
  interface TierPickItem extends vscode.QuickPickItem { id: string }
  const items: TierPickItem[] = TIER_INFO.map(t => ({
    label: t.id === previousTier ? `$(check) ${t.label}` : t.label,
    description: `${t.rules} rules${t.id === previousTier ? ' (current)' : ''}`,
    detail: t.desc,
    id: t.id,
  }));

  const pick = await vscode.window.showQuickPick(items, {
    placeHolder: `Current: ${tierLabel(previousTier)}`,
    title: 'Saropa Lints: Set tier',
  });
  if (!pick) return null;
  const tier = pick.id;

  // Same-tier guard — no-op, skip the expensive init + analysis cycle.
  if (tier === previousTier) {
    void vscode.window.showInformationMessage(`Already on ${tierLabel(tier)} tier.`);
    return null;
  }

  const workspaceRoot = getWorkspaceRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage('No workspace folder open.');
    return null;
  }
  await vscode.workspace.getConfiguration('saropaLints').update('tier', tier, vscode.ConfigurationTarget.Workspace);
  let ok = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: `Updating tier to ${tierLabel(tier)}`,
      cancellable: false,
    },
    // Smart notification is shown by the handler in extension.ts after we return.
    async () => { ok = applyTierChange(workspaceRoot, tier, previousTier); },
  );
  return ok ? { tier, tierLabel: tierLabel(tier), previousTier } : null;
}

export function showOutputChannel(): void {
  getOutputChannel().show();
}
