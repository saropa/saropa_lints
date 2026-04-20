/**
 * Setup and run commands: add saropa_lints to pubspec, pub get, init, analyze.
 * Replaces the init process from the user's perspective.
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { spawnSync } from 'node:child_process';
import { logReport, logSection, flushReport } from './reportWriter';
import { getProjectRoot } from './projectRoot';

const SAROPA_LINTS_DEV_DEP = 'saropa_lints';
const DEFAULT_VERSION = '^9.1.0';

const OUTPUT_CHANNEL_NAME = 'Saropa Lints';

// Lazily-initialized singleton to avoid creating multiple channel objects.
let _outputChannel: vscode.OutputChannel | undefined;
function getOutputChannel(): vscode.OutputChannel {
  _outputChannel ??= vscode.window.createOutputChannel(OUTPUT_CHANNEL_NAME);
  return _outputChannel;
}

export function hasFlutterDep(pubspecPath: string): boolean {
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
  const content = fs.readFileSync(pubspecPath, 'utf-8');

  // Precision check: match as an actual dependency entry, not a substring
  // in comments or similarly-named packages like saropa_lints_extra.
  if (/^\s{2}saropa_lints\s*:/m.test(content)) return true;

  // Line-based insertion avoids regex backtracking bugs that corrupted YAML
  // by placing the dependency on the same line as dev_dependencies:.
  // Preserve original line endings (CRLF on Windows) to avoid git noise.
  const eol = content.includes('\r\n') ? '\r\n' : '\n';
  const lines = content.split(eol);
  const devDepsIdx = lines.findIndex(l => /^dev_dependencies:\s*$/.test(l));
  const entry = `  ${SAROPA_LINTS_DEV_DEP}: ${DEFAULT_VERSION}`;

  if (devDepsIdx === -1) {
    lines.push('', 'dev_dependencies:', entry);
  } else {
    lines.splice(devDepsIdx + 1, 0, entry);
  }
  fs.writeFileSync(pubspecPath, lines.join(eol), 'utf-8');
  return true;
}

/** Builds args for headless config write (Enable, Initialize config, Set tier). Uses write_config so the extension does not shell out to init. */
function buildWriteConfigArgs(workspaceRoot: string, tier: string): string[] {
  return [
    'run',
    'saropa_lints:write_config',
    '--tier',
    tier,
    '--target',
    workspaceRoot,
  ];
}

export function runInWorkspace(workspaceRoot: string, command: string, args: string[], logToOutput = true): { ok: boolean; stderr: string; stdout: string } {
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
  const workspaceRoot = getProjectRoot();
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

      // Verify saropa_lints was actually resolved — corrupted pubspec YAML
      // can cause pub get to exit 0 without resolving the package.
      const pkgConfigPath = path.join(workspaceRoot, '.dart_tool', 'package_config.json');
      if (!fs.existsSync(pkgConfigPath) || !fs.readFileSync(pkgConfigPath, 'utf-8').includes('"saropa_lints"')) {
        logReport('- saropa_lints not found in package_config.json after pub get');
        flushReport(workspaceRoot);
        vscode.window.showErrorMessage(
          'Saropa Lints: pub get succeeded but saropa_lints was not resolved. Check pubspec.yaml formatting.',
        );
        return;
      }

      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const tier = (cfg.get<string>('tier') ?? 'recommended').trim();
      const { ok: initOk, stderr: initErr } = runInWorkspace(workspaceRoot, 'dart', buildWriteConfigArgs(workspaceRoot, tier));
      if (!initOk) {
        logReport(`- write_config FAILED: ${initErr || '(no details)'}`);
        flushReport(workspaceRoot);
        vscode.window.showErrorMessage(`Saropa Lints: config write failed. ${initErr || 'Check Output.'}`);
        return;
      }
      logReport(`- Wrote config (tier: ${tier})`);

      await runAnalysisAfterConfigChangeScoped(
        context,
        workspaceRoot,
        '- Ran analysis',
        '- Ran analysis',
      );
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

const RUN_ANALYSIS_FOR_FILES_CAP = 50;

// Directories to ignore when deriving the "open editors only" file list.
const OPEN_DART_ANALYSIS_SKIP_SUBSTRINGS = [
  '/.dart_tool/',
  '/build/',
  '/node_modules/',
  '/.git/',
  '/reports/',
  '/coverage/',
  '/dist/',
];

/** Collects `.dart` files from VS Code open editors under the detected project root. */
function getOpenDartFilePaths(workspaceRoot: string): string[] {
  const rootNorm = path.normalize(workspaceRoot).replaceAll('\\', '/');
  const rootNormLower = rootNorm.toLowerCase();

  const normalized = new Set<string>();
  for (const doc of vscode.workspace.textDocuments) {
    if (doc.uri.scheme !== 'file') continue;

    const fileNameLower = doc.fileName.toLowerCase();
    if (!fileNameLower.endsWith('.dart')) continue;

    const abs = doc.uri.fsPath;
    const absNorm = abs.replaceAll('\\', '/');
    const absNormLower = absNorm.toLowerCase();

    // Must be under the project root (dir containing pubspec.yaml).
    if (!absNormLower.startsWith(`${rootNormLower}/`) && absNormLower !== rootNormLower) continue;

    const rel = path.relative(workspaceRoot, abs);
    if (!rel || rel.startsWith('..')) continue;

    const relNorm = rel.replaceAll('\\', '/');

    const shouldSkip = OPEN_DART_ANALYSIS_SKIP_SUBSTRINGS
      .some(substr => relNorm.toLowerCase().includes(substr));
    if (shouldSkip) continue;

    normalized.add(relNorm);
  }

  return [...normalized];
}

/** Shared logic so Enable + tier changes can reuse open-editor scoping. */
async function runAnalysisAfterConfigChangeScoped(
  context: vscode.ExtensionContext,
  workspaceRoot: string,
  fullOkMessage: string,
  fullFailMessage: string,
): Promise<void> {
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  const runAnalysisAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true);
  if (!runAnalysisAfter) return;

  const openEditorsOnly = cfg.get<boolean>('runAnalysisOpenEditorsOnly', false) ?? false;
  if (openEditorsOnly) {
    const files = getOpenDartFilePaths(workspaceRoot);
    if (files.length > 0) {
      await runAnalysisForFiles(context, files, { showProgress: false });
    } else {
      logReport('- Skipped analysis (no open Dart files)');
    }
    return;
  }

  const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
  const analyzeCmd = useFlutter ? 'flutter' : 'dart';
  const analysisResult = runInWorkspace(workspaceRoot, analyzeCmd, ['analyze']);
  logReport(analysisResult.ok ? fullOkMessage : fullFailMessage);
}

export async function runAnalysis(context: vscode.ExtensionContext): Promise<boolean> {
  const workspaceRoot = getProjectRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage('No workspace folder open.');
    return false;
  }
  let ok = false;
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  const openEditorsOnly = cfg.get<boolean>('runAnalysisOpenEditorsOnly', false) ?? false;

  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: openEditorsOnly ? 'Running analysis (open editors)' : 'Running analysis',
      cancellable: false,
    },
    async () => {
      if (openEditorsOnly) {
        const files = getOpenDartFilePaths(workspaceRoot);
        if (files.length === 0) {
          vscode.window.showInformationMessage(
            'Saropa Lints: no open Dart files found. Re-open a Dart file or turn off the "Open editors only" setting.',
          );
          ok = false;
          return;
        }
        ok = await runAnalysisForFiles(context, files, { showProgress: false });
        if (!ok) {
          vscode.window.showWarningMessage('Analysis reported violations (open Dart files only). Check the Violations view.');
        }
        return;
      }

      const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
      const cmd = useFlutter ? 'flutter' : 'dart';
      logSection('Analysis');
      const result = runInWorkspace(workspaceRoot, cmd, ['analyze']);
      ok = result.ok;
      if (ok) {
        logReport('- Analysis completed clean');
      } else {
        logReport(`- Analysis reported issues (${cmd} analyze)`);
        vscode.window.showWarningMessage(
          `Analysis reported issues. ${result.stderr ? result.stderr.slice(0, 200) : 'See Problems view.'}`,
        );
      }
      flushReport(workspaceRoot);
    },
  );
  return ok;
}

/**
 * Run analysis only for the given files (e.g. stack-trace files for Log Capture).
 * Same as runAnalysis but passes file paths to dart/flutter analyze.
 * Paths are normalized (relative → absolute under workspace), deduplicated, and capped at 50.
 * When invoked via API, no progress UI is shown unless showProgress is true.
 */
export async function runAnalysisForFiles(
  context: vscode.ExtensionContext,
  files: string[],
  options?: { showProgress?: boolean },
): Promise<boolean> {
  const workspaceRoot = getProjectRoot();
  if (!workspaceRoot || !files.length) return false;

  const normalized = new Set<string>();
  for (const f of files) {
    const trimmed = f.trim();
    if (!trimmed) continue;
    const absolute = path.isAbsolute(trimmed)
      ? path.normalize(trimmed)
      : path.join(workspaceRoot, path.normalize(trimmed));
    normalized.add(absolute.replaceAll('\\', '/'));
  }

  let toRun = [...normalized].sort((a, b) => a.localeCompare(b));
  if (toRun.length > RUN_ANALYSIS_FOR_FILES_CAP) {
    toRun = toRun.slice(0, RUN_ANALYSIS_FOR_FILES_CAP);
    console.warn(
      `[Saropa Lints] runAnalysisForFiles: capped at ${RUN_ANALYSIS_FOR_FILES_CAP} files (${normalized.size} requested).`,
    );
  }

  const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
  const cmd = useFlutter ? 'flutter' : 'dart';
  const args = ['analyze', ...toRun];

  const doRun = (): boolean => {
    logSection('Analysis (files)');
    const result = runInWorkspace(workspaceRoot, cmd, args, true);
    if (result.ok) {
      logReport('- Analysis completed');
    } else {
      logReport(`- Analysis reported issues (${cmd} analyze ${toRun.length} files)`);
    }
    flushReport(workspaceRoot);
    return result.ok;
  };

  if (options?.showProgress) {
    let ok = false;
    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Running analysis (selected files)',
        cancellable: false,
      },
      async () => { ok = doRun(); },
    );
    return ok;
  }
  return doRun();
}

export async function runInitializeConfig(context: vscode.ExtensionContext, title?: string): Promise<boolean> {
  const workspaceRoot = getProjectRoot();
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
      const result = runInWorkspace(workspaceRoot, 'dart', buildWriteConfigArgs(workspaceRoot, tier));
      ok = result.ok;
      if (ok) {
        logReport(`- Config initialized (tier: ${tier})`);
        flushReport(workspaceRoot);
        vscode.window.showInformationMessage(`Saropa Lints config updated (tier: ${tier}).`);
      } else {
        logReport(`- write_config FAILED: ${result.stderr || '(no details)'}`);
        flushReport(workspaceRoot);
        vscode.window.showErrorMessage(`Config write failed. ${result.stderr || 'Check Output.'}`);
      }
    },
  );
  return ok;
}

export async function openConfig(): Promise<void> {
  const workspaceRoot = getProjectRoot();
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

/** Run write_config + optional analysis for a tier change; returns true on success. */
async function applyTierChange(
  context: vscode.ExtensionContext,
  workspaceRoot: string,
  tier: string,
  previousTier: string,
): Promise<boolean> {
  logSection('Set Tier');
  logReport(`- Changed tier: ${previousTier} → ${tier}`);
  const writeResult = runInWorkspace(workspaceRoot, 'dart', buildWriteConfigArgs(workspaceRoot, tier));
  if (!writeResult.ok) {
    logReport(`- write_config FAILED: ${writeResult.stderr || '(no details)'}`);
    flushReport(workspaceRoot);
    vscode.window.showErrorMessage(`Config write failed. ${writeResult.stderr || 'Check Output.'}`);
    return false;
  }
  logReport(`- Wrote config (tier: ${tier})`);
  // C6: Re-analyze after tier change so violations.json reflects the new ruleset.
  await runAnalysisAfterConfigChangeScoped(
    context,
    workspaceRoot,
    '- Analysis completed',
    '- Analysis reported issues',
  );
  flushReport(workspaceRoot);
  return true;
}

/**
 * Show an enhanced tier picker and run write_config + analysis for the selected tier.
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

  const workspaceRoot = getProjectRoot();
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
    async () => { ok = await applyTierChange(context, workspaceRoot, tier, previousTier); },
  );
  return ok ? { tier, tierLabel: tierLabel(tier), previousTier } : null;
}

export function showOutputChannel(): void {
  getOutputChannel().show();
}

/**
 * Expose the output channel for consumers that need to append their own
 * diagnostic text (e.g. plugin liveness probe). Returns the shared instance
 * — do NOT call `.dispose()` on the returned channel; ownership stays here.
 */
export function getSharedOutputChannel(): vscode.OutputChannel {
  return getOutputChannel();
}
