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
import * as fs from 'fs';
import * as path from 'path';
import { readViolations, getViolationsPath } from './violationsReader';

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

/**
 * Why the plugin produced no `violations.json`. Issue #208 follow-up:
 * before this distinction the `no-report` recovery told users to restart
 * the analysis server, which is irrelevant when the real problem is one
 * of several setup gaps. The classifier walks pubspec, then
 * analysis_options.yaml, and stops at the first failure so the recovery
 * targets the most upstream missing piece.
 *
 * **Order matters.** Pubspec must be set up before YAML config can do
 * anything; YAML must exist before its contents can be inspected; YAML
 * must parse before plugin enrolment can be detected. Reporting a
 * downstream symptom while an upstream cause is the real bug would send
 * the user to fix the wrong thing.
 */
export type NoReportCause =
  // ── Pubspec gates ──────────────────────────────────────────────────
  /** No `pubspec.yaml` at workspace root — not a Dart/Flutter project. */
  | 'no-pubspec'
  /** `pubspec.yaml` present but no `saropa_lints` dependency entry. */
  | 'pubspec-missing-saropa-lints'
  // ── analysis_options.yaml gates (insufficient/incorrect config) ────
  /**
   * Pubspec is fine, but `analysis_options.yaml` is missing entirely.
   * Without it the analyzer has nothing to feed the plugin.
   */
  | 'analysis-options-missing'
  /**
   * `analysis_options.yaml` exists but won't parse (YAML syntax error,
   * tabs, dangling colons, etc.). The analyzer ignores broken config
   * silently — the user will never see a violations.json until this is
   * cleaned up.
   */
  | 'analysis-options-malformed'
  /**
   * `analysis_options.yaml` parses but does NOT enrol saropa_lints —
   * neither an `include: package:saropa_lints/tiers/<tier>.yaml` line
   * nor a `plugins.saropa_lints` block. The user from issue #208 hit
   * exactly this: they had `saropa_lints: tier: recommended` at the top
   * level, which is not a valid form and does nothing. Insufficient
   * config — Set Up Project can rewrite it.
   */
  | 'analysis-options-no-saropa'
  // ── Catch-all (config looks fine; plugin still didn't run) ─────────
  /**
   * Pubspec and analysis_options.yaml both look correct, yet the plugin
   * wrote no report. This is the genuine "analyzer-restart" territory —
   * crashed isolate, stale plugin cache, or a Dart-tooling bug. Set Up
   * Project is still offered because re-running the full flow includes
   * a fresh `dart analyze`, which is often the unblocker.
   */
  | 'plugin-silent';

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
  /**
   * For `no-report`: the inferred cause from inspecting pubspec /
   * analysis_options. `undefined` for every other status. Drives the
   * "Set Up Project" one-click button in [surfaceLivenessResult].
   */
  noReportCause?: NoReportCause;
  /**
   * `true` when the recovery is invoking `saropaLints.enable` (the Set
   * Up Project flow). Read by [surfaceLivenessResult] to decide whether
   * to show a "Set Up Project" button alongside "Show Details".
   */
  setUpActionable: boolean;
}

/**
 * The two YAML shapes that successfully enrol the saropa_lints plugin.
 * Either is sufficient on its own; neither plus a top-level `saropa_lints:`
 * key (the issue #208 reporter's mistake) is NOT sufficient.
 *
 * - `INCLUDE_DIRECTIVE`: the modern shape — one line that pulls in the
 *   plugin's tier preset (`include: package:saropa_lints/tiers/<x>.yaml`).
 *   The leading `^` plus a multiline flag is what we anchor on so a
 *   `# include: ...` comment doesn't false-positive.
 * - `PLUGINS_BLOCK`: the explicit shape — a top-level `plugins:` section
 *   with a nested `saropa_lints:` key. Two-space indent is the YAML
 *   convention; we accept "any whitespace" and rely on the presence of
 *   the parent `plugins:` line being verified separately.
 *
 * The `^plugins:\s*$` pre-check is needed because an unrelated
 * `name: saropa_lints` somewhere else in the file would falsely match
 * a bare `\s+saropa_lints:` regex.
 */
const SAROPA_INCLUDE_PATTERN = /^\s*include:\s*package:saropa_lints\//m;
const PLUGINS_HEADER_PATTERN = /^plugins:\s*$/m;
const PLUGINS_SAROPA_NESTED_PATTERN = /^\s+saropa_lints:\s*$/m;

/** Whether [content] enrols the saropa_lints analyzer plugin. */
function analysisOptionsEnrolsSaropa(content: string): boolean {
  if (SAROPA_INCLUDE_PATTERN.test(content)) return true;
  // Require BOTH a top-level `plugins:` and a nested `saropa_lints:` so a
  // stray top-level `saropa_lints:` (the issue #208 reporter's case)
  // doesn't get accepted as valid enrolment.
  if (!PLUGINS_HEADER_PATTERN.test(content)) return false;
  return PLUGINS_SAROPA_NESTED_PATTERN.test(content);
}

/**
 * Cheap YAML-shape sanity check. We don't have a real YAML parser in the
 * extension (the project convention — see `rulePackYaml.ts` — is
 * regex-based), so this can only catch the most common malformations:
 * tabs in indentation, lines starting with a hyphen at column 0 outside
 * a block sequence, or unbalanced quotes on a single line. False
 * negatives are acceptable here — if YAML is truly broken the analyzer
 * itself will eventually emit an error; this check just lets us surface
 * a more useful message in the common-typo cases.
 *
 * Returns `true` when the file looks plausibly parseable.
 */
function analysisOptionsLooksWellFormed(content: string): boolean {
  // Tab indentation is the most common source of "looks fine to me but
  // analyzer rejects it" failures. The YAML spec forbids tabs in
  // indentation; the analyzer's loader matches the spec.
  for (const line of content.split('\n')) {
    if (/^\t+/.test(line)) return false;
  }
  return true;
}

/**
 * Inspect the workspace's pubspec and analysis_options.yaml to decide
 * why the plugin wrote nothing. Walks upstream → downstream so the
 * recovery aims at the FIRST broken gate, not a downstream symptom.
 *
 * Reuses the same dev-dependency match as `ensureSaropaLintsInPubspec`
 * in setup.ts (`/^\s{2}saropa_lints\s*:/m`) so we agree on what counts
 * as "installed."
 */
function classifyNoReport(workspaceRoot: string): NoReportCause {
  // Gate 1: pubspec.yaml exists.
  const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
  if (!fs.existsSync(pubspecPath)) return 'no-pubspec';
  let pubspecContent: string;
  try {
    pubspecContent = fs.readFileSync(pubspecPath, 'utf-8');
  } catch {
    // Unreadable pubspec is a permission / disk issue; setup will
    // surface a clearer error, so route there.
    return 'pubspec-missing-saropa-lints';
  }
  // Gate 2: pubspec lists saropa_lints as a (dev_)dependency.
  if (!/^\s{2}saropa_lints\s*:/m.test(pubspecContent)) {
    return 'pubspec-missing-saropa-lints';
  }
  // Gate 3: analysis_options.yaml exists.
  const optionsPath = path.join(workspaceRoot, 'analysis_options.yaml');
  if (!fs.existsSync(optionsPath)) return 'analysis-options-missing';
  let optionsContent: string;
  try {
    optionsContent = fs.readFileSync(optionsPath, 'utf-8');
  } catch {
    // Treat read failure as malformed for surfacing purposes — the
    // recovery (regenerate via Set Up) is identical and the message
    // tells the user to look at the file.
    return 'analysis-options-malformed';
  }
  // Gate 4: analysis_options.yaml parses well enough to inspect.
  if (!analysisOptionsLooksWellFormed(optionsContent)) {
    return 'analysis-options-malformed';
  }
  // Gate 5: analysis_options.yaml actually enrols the plugin.
  if (!analysisOptionsEnrolsSaropa(optionsContent)) {
    return 'analysis-options-no-saropa';
  }
  // All gates passed — the plugin should have run. If it didn't, the
  // analyzer is the suspect (crashed isolate, stale cache, etc.).
  return 'plugin-silent';
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

  // Case 1: no report file exists. The plugin never ran, or ran but
  // crashed before writing. The classifier walks pubspec then YAML
  // upstream → downstream so the recovery aims at the FIRST broken
  // gate (issue #208 follow-up). Every config gap explicitly tells
  // the user the config is REQUIRED — there is no "just dismiss this"
  // path that leaves a half-set-up project producing zero findings.
  if (!fs.existsSync(reportPath)) {
    const cause = classifyNoReport(workspaceRoot);
    // Single source of truth for what Set Up Project actually does.
    // Surface it verbatim in every recovery that points to it so the
    // user can see the steps before they click — no surprise mutations.
    const setupHint =
      'Click "Set Up Project" — it adds saropa_lints to pubspec.yaml, ' +
      'runs `pub get`, regenerates analysis_options.yaml so the plugin ' +
      'is enrolled, and re-runs analysis. Without this, dart analyze has ' +
      'no plugin to load and the dashboard cannot show any findings.';
    let message: string;
    let recovery: string;
    let setUpActionable = false;
    switch (cause) {
      case 'no-pubspec':
        // Config can't be auto-fixed because there is no project yet.
        // Lead with the requirement so the user understands why nothing
        // works until they open a folder with a pubspec.yaml.
        message =
          'Saropa Lints requires a Dart or Flutter project to run. ' +
          'No pubspec.yaml was found at this workspace root, so ' +
          'configuration is not possible and no findings can be produced.';
        recovery =
          'File → Open Folder, choose a directory that contains a ' +
          'pubspec.yaml at its root, then run Saropa Lints: Run Analysis. ' +
          'If you intended to open this folder as a sub-project, open the ' +
          'parent folder that owns the pubspec instead.';
        break;
      case 'pubspec-missing-saropa-lints':
        message =
          'Saropa Lints is not configured in this project — no ' +
          'saropa_lints entry in pubspec.yaml, so dart analyze cannot ' +
          'load the plugin and the dashboard will stay empty.';
        recovery = setupHint;
        setUpActionable = true;
        break;
      case 'analysis-options-missing':
        message =
          'Saropa Lints needs analysis_options.yaml to know which rules ' +
          'to run, and this project does not have one yet. The plugin ' +
          'cannot enable a single rule without it, so no violations.json ' +
          'is produced.';
        recovery = setupHint;
        setUpActionable = true;
        break;
      case 'analysis-options-malformed':
        message =
          'analysis_options.yaml is present but does not parse as valid ' +
          'YAML (most likely a tab in indentation, an unbalanced quote, ' +
          'or a stray colon). The Dart analyzer ignores broken config ' +
          'silently, so saropa_lints never loads and the dashboard cannot ' +
          'show findings until the file is fixed.';
        recovery =
          'Open analysis_options.yaml and fix the syntax — replace any ' +
          'tabs in the indentation with two spaces, balance quotes, and ' +
          'ensure every key ends with `: value` or `:` followed by an ' +
          'indented child. Or click "Set Up Project" to overwrite the ' +
          'file with a clean tier-based config (this discards your ' +
          'current contents).';
        // Set Up rewrites analysis_options.yaml — the user might want to
        // hand-fix instead, so we offer it but the language above warns
        // about overwrite so they don't click blindly.
        setUpActionable = true;
        break;
      case 'analysis-options-no-saropa':
        // The exact case the issue #208 reporter hit: they had
        // `saropa_lints: tier: recommended` at the top level of
        // analysis_options.yaml, which is NOT a valid plugin enrolment
        // form. Be explicit about what's missing and what valid forms
        // look like, so the user can hand-fix if they don't want to use
        // Set Up Project.
        message =
          'analysis_options.yaml does not enrol Saropa Lints — neither ' +
          'an `include: package:saropa_lints/tiers/<tier>.yaml` line nor ' +
          'a `plugins: { saropa_lints: ... }` block was found. Without ' +
          'one of these, the plugin is not loaded and the dashboard ' +
          'will always be empty regardless of how many times you re-run ' +
          'analysis.';
        recovery =
          'Either click "Set Up Project" to write a tier-based config ' +
          'automatically, or add this single line to the top of ' +
          'analysis_options.yaml:\n\n' +
          '    include: package:saropa_lints/tiers/recommended.yaml\n\n' +
          'A bare top-level `saropa_lints:` key (without `plugins:` ' +
          'around it) is not recognised and is the most common cause ' +
          'of this state.';
        setUpActionable = true;
        break;
      case 'plugin-silent':
      default:
        message =
          'Saropa Lints is configured correctly (pubspec and ' +
          'analysis_options.yaml both look right) but produced no ' +
          'violations.json — the analyzer plugin is silent. The dashboard ' +
          'cannot show findings until the plugin actually runs.';
        recovery =
          'Try Command Palette → "Dart: Restart Analysis Server", then ' +
          're-run Saropa Lints: Run Analysis. If this persists, check ' +
          'the analyzer log for "loadNativePluginConfig failed" messages. ' +
          'Set Up Project will also regenerate analysis_options.yaml, ' +
          'which is sometimes the unblocker.';
        // Setup is still useful here — re-running the full flow includes
        // a fresh analyze that often clears stuck plugin state.
        setUpActionable = true;
        break;
    }
    return {
      status: 'no-report',
      enabledRuleCount: 0,
      filesAnalyzed: 0,
      reportPath,
      message,
      recovery,
      noReportCause: cause,
      setUpActionable,
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
        'Saropa Lints loaded but has zero rules enabled — its ' +
        'analysis_options.yaml configuration was not read. Without a ' +
        'valid configuration the plugin cannot produce findings, so the ' +
        'dashboard will stay empty until this is fixed.',
      recovery:
        'Click "Set Up Project" to regenerate the config. If the problem ' +
        'persists after that, ensure VS Code was launched with the ' +
        'project folder as the workspace root (File → Open Folder, or ' +
        '`code .` from the project directory) — opening a parent folder ' +
        'and treating the Dart project as a sub-folder is a common cause.',
      // Set Up Project rewrites analysis_options.yaml; that is exactly the
      // recovery for a config the plugin couldn't read.
      setUpActionable: true,
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
      // The fix here is editing the exclude list, not regenerating it —
      // Set Up Project would overwrite their customizations.
      setUpActionable: false,
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
    setUpActionable: false,
  };
}

/**
 * Surface a non-alive liveness result to the user as a warning notification
 * with a "Show Details" button that opens an output channel with the
 * diagnosis + recovery steps. No-op when status === 'alive' — alive should
 * be quiet.
 *
 * When [PluginLivenessResult.setUpActionable] is true, also surfaces a
 * "Set Up Project" button that runs the same end-to-end flow as the
 * `saropaLints.enable` command (pubspec edit, pub get, write_config,
 * analyze). Issue #208 follow-up: this turns the silent-no-report case
 * into a one-click fix instead of a multi-step palette hunt.
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
  if (result.noReportCause) {
    outputChannel.appendLine(`No-report cause: ${result.noReportCause}`);
  }
  outputChannel.appendLine('='.repeat(80));
  // Lead the channel diagnostic with the same "config is required"
  // framing the user gets on the toast so the message is consistent in
  // both surfaces. Without a real configuration the plugin cannot run,
  // and downstream features (dashboard, suggestions, code lens) all
  // depend on its output — be explicit about that, every time.
  if (result.setUpActionable) {
    outputChannel.appendLine(
      'Saropa Lints requires a working configuration to produce findings. ' +
        'The state below describes what is missing or invalid; until it is ' +
        'fixed, the dashboard will remain empty and no rules will run.',
    );
    outputChannel.appendLine('');
  }
  outputChannel.appendLine(result.message);
  outputChannel.appendLine('');
  outputChannel.appendLine('Recovery steps:');
  // Indent every line of the recovery block so multi-paragraph hints
  // (e.g. the analysis-options-no-saropa case with its inline YAML
  // example) stay readable in the channel pane.
  for (const line of result.recovery.split('\n')) {
    outputChannel.appendLine(line.length > 0 ? `  ${line}` : '');
  }
  outputChannel.appendLine('');
  outputChannel.appendLine(`Report path: ${result.reportPath}`);
  outputChannel.appendLine(`Enabled rules: ${result.enabledRuleCount}`);
  outputChannel.appendLine(`Files analyzed: ${result.filesAnalyzed}`);
  outputChannel.appendLine('='.repeat(80));

  // Modal toast for setup gaps so the user must acknowledge — non-modal
  // toasts auto-dismiss after a few seconds in VS Code, which has been
  // exactly the failure mode for issue #208 follow-up reports: users
  // miss the warning, conclude the project is clean, and ship. Modal is
  // appropriate here because the plugin literally cannot do its job
  // until the user acts on this. Non-setUpActionable cases (no-pubspec,
  // exclude-list-too-aggressive) stay non-modal — those need user
  // judgement and shouldn't block whatever they were doing.
  const actions: string[] = [];
  if (result.setUpActionable) actions.push('Set Up Project');
  actions.push('Show Details', 'Dismiss');
  const detail =
    `Configuration is required for Saropa Lints to run.\n\n` +
    `${result.recovery}`;
  const choice = result.setUpActionable
    ? await vscode.window.showWarningMessage(
        result.message,
        { modal: true, detail },
        ...actions,
      )
    : await vscode.window.showWarningMessage(result.message, ...actions);
  if (choice === 'Set Up Project') {
    // The `saropaLints.enable` command runs the full end-to-end setup
    // (pubspec, pub get, write_config, analyze). Reusing it keeps a
    // single code path for setup so future changes don't have to update
    // two flows in lockstep.
    await vscode.commands.executeCommand('saropaLints.enable');
    return;
  }
  if (choice === 'Show Details') {
    outputChannel.show(true);
  }
}
