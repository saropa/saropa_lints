/**
 * Post-enable plugin-liveness probe.
 *
 * Purpose: detect the "plugin loaded but silent" failure mode where the
 * analyzer launches saropa_lints successfully, processes context roots
 * and file updates, but emits zero diagnostics because the plugin couldn't
 * read its config from the consumer's project root. Historically this
 * failure was invisible — the Problems pane shows no warnings, and users
 * cannot tell whether their project is simply clean or whether the plugin
 * is catastrophically mis-wired.
 *
 * Signals (derived from the plugin's own `violations.json` report):
 *
 *   | report state                                 | diagnosis        |
 *   | -------------------------------------------- | ---------------- |
 *   | file missing after analysis                  | plugin silent    |
 *   | file present, `enabledRuleCount` undefined/0 | config not read  |
 *   | file present, `filesAnalyzed` undefined/0    | plugin inert     |
 *   | file present, `enabledRuleCount > 0`         | plugin alive     |
 *
 * The probe is intentionally quiet when the plugin is alive — no banner,
 * no status change. It fires only when the plugin is clearly mis-wired,
 * so consumers see a specific, actionable error instead of a silent zero.
 */

import * as vscode from 'vscode';
import { readViolations, getViolationsPath } from './violationsReader';
import * as fs from 'fs';

/** What the liveness probe concluded about the plugin's runtime state. */
export type PluginLivenessStatus =
  /** violations.json present and `enabledRuleCount > 0`. Plugin is alive. */
  | 'alive'
  /** violations.json missing after analysis. Plugin emitted nothing. */
  | 'no-report'
  /** Report present but `enabledRuleCount` is 0/undefined. Config not read. */
  | 'config-not-loaded'
  /** Report present but `filesAnalyzed` is 0/undefined. Plugin inert. */
  | 'no-files-analyzed';

export interface PluginLivenessResult {
  status: PluginLivenessStatus;
  /** Rule count the plugin reports as enabled. 0/undefined when mis-wired. */
  enabledRuleCount: number;
  /** File count the plugin reports as analyzed. 0/undefined when inert. */
  filesAnalyzed: number;
  /** Absolute path of the report file consulted (even when missing). */
  reportPath: string;
  /**
   * Human-readable one-line summary, suitable for a notification or status
   * tooltip. Empty string when status === 'alive'.
   */
  message: string;
  /**
   * Specific, actionable recovery step when status !== 'alive'. Empty
   * string when status === 'alive'.
   */
  recovery: string;
}

/**
 * Probe the plugin's liveness by inspecting `violations.json`.
 *
 * Call after `dart analyze` (or the equivalent enable flow) completes.
 * Returns `alive` when the plugin reports a non-zero enabled rule count
 * AND a non-zero analyzed file count — both must be true for the plugin
 * to be producing diagnostics.
 */
export function verifyPluginLiveness(workspaceRoot: string): PluginLivenessResult {
  const reportPath = getViolationsPath(workspaceRoot);

  // Case 1: no report file exists. Plugin either never ran or is silently
  // failing at the register() kill-switch stage (pre-fix versions of
  // saropa_lints) or at the analysis-isolate-crashed stage.
  if (!fs.existsSync(reportPath)) {
    return {
      status: 'no-report',
      enabledRuleCount: 0,
      filesAnalyzed: 0,
      reportPath,
      message:
        'saropa_lints ran but wrote no report. The plugin may not be loading.',
      recovery:
        'Try: Command Palette → "Dart: Restart Analysis Server", then re-run ' +
        'Saropa Lints: Run Analysis. If this persists, check the analyzer log ' +
        'for "loadNativePluginConfig failed" messages.',
    };
  }

  const data = readViolations(workspaceRoot);
  const enabledRuleCount = data?.config?.enabledRuleCount ?? 0;
  const filesAnalyzed = data?.summary?.filesAnalyzed ?? 0;

  // Case 2: report present but enabledRuleCount is 0. Plugin wrote the
  // report but had no rules enabled — usually because the config loader
  // couldn't find analysis_options.yaml at Directory.current (pre-fix
  // bug affecting all IDE-launched analyzer plugins).
  if (enabledRuleCount === 0) {
    return {
      status: 'config-not-loaded',
      enabledRuleCount,
      filesAnalyzed,
      reportPath,
      message:
        'saropa_lints loaded but has zero rules enabled. Your ' +
        'analysis_options.yaml was not read by the plugin.',
      recovery:
        'Run: Saropa Lints: Set Up Project (command palette) to regenerate ' +
        'the config. If the problem persists, ensure VS Code was launched ' +
        'with the project folder as the workspace root (File → Open Folder, ' +
        'or `code .` from the project directory).',
    };
  }

  // Case 3: rules enabled but no files analyzed. Plugin has config but
  // wasn't handed any files — likely the analyzer never forwarded context
  // roots, or the exclude list swallowed everything.
  if (filesAnalyzed === 0) {
    return {
      status: 'no-files-analyzed',
      enabledRuleCount,
      filesAnalyzed,
      reportPath,
      message:
        `saropa_lints has ${enabledRuleCount} rules enabled but analyzed ` +
        '0 files. Check your analyzer exclude list.',
      recovery:
        'Review analysis_options.yaml > analyzer > exclude. Common culprits: ' +
        'excluding lib/** or test/** by mistake, or a glob that matches every ' +
        'Dart file. Run Saropa Lints: Run Analysis again after fixing.',
    };
  }

  // Alive: config loaded AND files analyzed. Zero diagnostics is a valid
  // outcome (clean project) and does NOT indicate mis-wiring.
  return {
    status: 'alive',
    enabledRuleCount,
    filesAnalyzed,
    reportPath,
    message: '',
    recovery: '',
  };
}

/**
 * Surface a non-alive liveness result to the user as a warning notification
 * with a "Show Details" button that opens an output channel with the
 * diagnosis + recovery steps. No-op when status === 'alive' — alive should
 * be quiet.
 */
export async function surfaceLivenessResult(
  result: PluginLivenessResult,
  outputChannel: vscode.OutputChannel,
): Promise<void> {
  if (result.status === 'alive') return;

  // Write a detailed diagnosis to the output channel for users who want to
  // inspect the report path, copy-paste, or share the error.
  outputChannel.appendLine('');
  outputChannel.appendLine('='.repeat(80));
  outputChannel.appendLine(`Saropa Lints: Plugin liveness check — ${result.status}`);
  outputChannel.appendLine('='.repeat(80));
  outputChannel.appendLine(result.message);
  outputChannel.appendLine('');
  outputChannel.appendLine('Recovery steps:');
  outputChannel.appendLine(`  ${result.recovery}`);
  outputChannel.appendLine('');
  outputChannel.appendLine(`Report path: ${result.reportPath}`);
  outputChannel.appendLine(`Enabled rules: ${result.enabledRuleCount}`);
  outputChannel.appendLine(`Files analyzed: ${result.filesAnalyzed}`);
  outputChannel.appendLine('='.repeat(80));

  const choice = await vscode.window.showWarningMessage(
    result.message,
    'Show Details',
    'Dismiss',
  );
  if (choice === 'Show Details') {
    outputChannel.show(true);
  }
}
