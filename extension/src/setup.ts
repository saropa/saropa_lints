/**
 * Setup and run commands: add saropa_lints to pubspec, pub get, init, analyze.
 * Replaces the init process from the user's perspective.
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { spawn, spawnSync, type ChildProcess } from 'node:child_process';
import { logReport, logSection, flushReport, findLatestAnalysisReport } from './reportWriter';
import { getProjectRoot } from './projectRoot';
import { readViolations } from './violationsReader';
import { readInstalledVersion } from './upgrade-checker';
import { pickWorkspaceFolder } from './workspaceFolderPicker';
import { readTierFromAnalysisOptionsYaml } from './config/tierConfig';
import { l10n } from './i18n/runtime';

const SAROPA_LINTS_DEV_DEP = 'saropa_lints';
const DEFAULT_VERSION = '^9.1.0';

/** Composite meta-plugin guide (browser); stable for marketplace installs. */
const COMPOSITE_PLUGIN_SCAFFOLD_GUIDE_URL =
  'https://github.com/saropa/saropa_lints/blob/main/doc/guides/composite_analyzer_plugin.md';

const OUTPUT_CHANNEL_NAME = 'Saropa Lints';

// Lazily-initialized singleton to avoid creating multiple channel objects.
let _outputChannel: vscode.OutputChannel | undefined;

// Cancellation source for the one in-flight full `runAnalysis`. A newer request
// (e.g. toggling several rule packs in quick succession) cancels the previous run
// instead of spawning a second concurrent `dart analyze` + progress notification.
// Without this, rapid pack toggles stacked N "Running analysis" notifications and N
// overlapping analyzer processes (reported 2026-06-23). Newest-wins is always
// correct: two concurrent full analyses race to write the same violations.json.
let _supersedingAnalysisCts: vscode.CancellationTokenSource | undefined;
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

/**
 * Outcome of the pubspec check at the head of Enable.
 *
 * `changed` is what makes the difference between a two-minute Enable and an
 * instant one: `pub get` only has work to do when we actually edited the
 * manifest. Returning a bare boolean (the previous shape) threw that fact away
 * and forced every Enable to re-resolve the whole dependency graph — measured
 * at 116 s on a ~60-plugin Flutter project, which reads as a hang and gets
 * cancelled.
 */
interface PubspecEnsureResult {
  /** False only when there is no pubspec.yaml — the flow cannot continue. */
  ok: boolean;
  /** True when this call wrote the dev-dependency into pubspec.yaml. */
  changed: boolean;
}

function ensureSaropaLintsInPubspec(workspaceRoot: string): PubspecEnsureResult {
  const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
  if (!fs.existsSync(pubspecPath)) {
    void vscode.window.showErrorMessage(
      l10n('notify.setup.requiresDartProject'),
      l10n('notify.setup.actionLearnMore'),
    ).then((choice) => {
      if (choice === l10n('notify.setup.actionLearnMore')) {
        void vscode.env.openExternal(vscode.Uri.parse('https://pub.dev/packages/saropa_lints'));
      }
    });
    return { ok: false, changed: false };
  }
  const content = fs.readFileSync(pubspecPath, 'utf-8');

  // Precision check: match as an actual dependency entry, not a substring
  // in comments or similarly-named packages like saropa_lints_extra.
  // Already declared => nothing written => the caller can skip `pub get`.
  if (/^\s{2}saropa_lints\s*:/m.test(content)) return { ok: true, changed: false };

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
  return { ok: true, changed: true };
}

/**
 * True when `.dart_tool/package_config.json` already resolves saropa_lints AND
 * that resolution is newer than pubspec.yaml — i.e. a `pub get` right now would
 * re-derive the graph it already has.
 *
 * The mtime comparison is the correctness guard: an edit to pubspec.yaml made
 * outside this extension (a hand-bumped constraint, a merge, the upgrade
 * checker) leaves the manifest newer than the resolution, and in that case the
 * resolve is genuinely stale and must not be skipped.
 */
export function isSaropaLintsAlreadyResolved(workspaceRoot: string): boolean {
  const pkgConfigPath = path.join(workspaceRoot, '.dart_tool', 'package_config.json');
  const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
  try {
    if (!resolvesSaropaLints(workspaceRoot)) return false;
    return fs.statSync(pkgConfigPath).mtimeMs >= fs.statSync(pubspecPath).mtimeMs;
  } catch {
    // Missing or unreadable package_config => never resolved => run pub get.
    return false;
  }
}

/**
 * Content-only check: does `.dart_tool/package_config.json` list saropa_lints?
 *
 * Deliberately has NO mtime component, unlike `isSaropaLintsAlreadyResolved`.
 * It is used to verify a `pub get` that has just run, and pub does not rewrite
 * package_config.json when the resolution is unchanged — an mtime test there
 * would report a perfectly good resolve as a failure.
 */
function resolvesSaropaLints(workspaceRoot: string): boolean {
  const pkgConfigPath = path.join(workspaceRoot, '.dart_tool', 'package_config.json');
  try {
    return fs.readFileSync(pkgConfigPath, 'utf-8').includes('"saropa_lints"');
  } catch {
    return false;
  }
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

/**
 * Recursively kills a child process and its descendants.
 *
 * Why: `spawn(..., { shell: true })` runs the requested command (e.g. `dart pub get`)
 * as a *grandchild* of the Node process — Node spawns a shell, the shell spawns dart.
 * `child.kill()` only signals the shell. On POSIX the kernel propagates SIGTERM to the
 * process group; on Windows nothing propagates and dart.exe is orphaned, still holding
 * the .dart_tool lock. `taskkill /T` walks the tree and kills everything.
 */
function killProcessTree(child: ChildProcess): void {
  if (!child.pid) return;
  if (process.platform === 'win32') {
    // /T = tree, /F = force. Best-effort: if taskkill itself fails we have nothing
    // better to fall back to, so swallow the error rather than crash the host.
    try {
      spawnSync('taskkill', ['/pid', String(child.pid), '/T', '/F'], { shell: false });
    } catch {
      // Already gone or taskkill missing — give up silently.
    }
    return;
  }
  try {
    child.kill('SIGTERM');
  } catch {
    // Already exited.
  }
}

/**
 * Reports an elapsed-time-ticking progress message (e.g. "Running pub get… (12s)")
 * every second while `work` is in flight, so a long shelled-out step — `pub get`
 * alone measured 112s on a 60-plugin project — reads as actively running instead
 * of a frozen notification with no feedback (see reports/.../saropa_extension.md
 * "cancelled by user (pub get)" — the user cancelled a step that was working
 * normally, because nothing on screen distinguished "slow" from "stuck").
 */
async function withTickingProgress<T>(
  progress: vscode.Progress<{ message?: string }>,
  messageFor: (elapsedSeconds: number) => string,
  work: Promise<T>,
): Promise<T> {
  const start = Date.now();
  const report = () => progress.report({ message: messageFor(Math.floor((Date.now() - start) / 1000)) });
  report();
  const interval = setInterval(report, 1000);
  try {
    return await work;
  } finally {
    clearInterval(interval);
  }
}

/**
 * Async sibling of `runInWorkspace` — does NOT block the extension host event loop.
 *
 * Why this exists: the synchronous `spawnSync` version freezes the entire extension
 * host (and therefore VS Code's UI thread for any extension-mediated interaction)
 * for the full duration of the child process. Long-running commands like
 * `dart pub get` or `flutter pub get` can take 30s+, which manifests as a complete
 * lockup. Use this variant for any command invoked from a user-facing flow.
 *
 * Cancellation: pass a `CancellationToken` to wire the progress UI's Cancel button
 * to `taskkill /T` (Windows) / `SIGTERM` (POSIX). Without a token the call runs to
 * completion regardless of UI state.
 */
export async function runInWorkspaceAsync(
  workspaceRoot: string,
  command: string,
  args: string[],
  options: { logToOutput?: boolean; token?: vscode.CancellationToken } = {},
): Promise<{ ok: boolean; stderr: string; stdout: string; cancelled: boolean }> {
  const { logToOutput = true, token } = options;
  const ch = logToOutput ? getOutputChannel() : undefined;
  ch?.appendLine(`$ ${command} ${args.join(' ')}`);

  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: workspaceRoot,
      shell: true,
    });

    let stdout = '';
    let stderr = '';
    let cancelled = false;

    // Stream output so the user sees progress in the Output channel during long
    // commands instead of one delayed dump at the end. `append` (not `appendLine`)
    // preserves the child's own line breaks.
    child.stdout?.on('data', (chunk: Buffer) => {
      const text = chunk.toString('utf-8');
      stdout += text;
      ch?.append(text);
    });
    child.stderr?.on('data', (chunk: Buffer) => {
      const text = chunk.toString('utf-8');
      stderr += text;
      ch?.append(text);
    });

    const cancelSub = token?.onCancellationRequested(() => {
      cancelled = true;
      ch?.appendLine('\n[cancelled by user]');
      killProcessTree(child);
    });

    // ENOENT or other spawn-time failure (e.g. `dart` not on PATH).
    child.on('error', (err) => {
      cancelSub?.dispose();
      resolve({
        ok: false,
        stderr: stderr + err.message,
        stdout,
        cancelled,
      });
    });

    // Resolve on `close` (not `exit`) so stdout/stderr pipes are fully flushed.
    child.on('close', (code) => {
      cancelSub?.dispose();
      resolve({
        ok: !cancelled && code === 0,
        stderr: cancelled && !stderr ? 'Cancelled by user.' : stderr,
        stdout,
        cancelled,
      });
    });
  });
}

/**
 * Runs `pub get`, preferring `dart` over `flutter` even on Flutter projects.
 *
 * Why: `flutter pub get` is not a wrapper around `dart pub get` — it boots the
 * flutter_tool (SDK version check, artifact validation, its own package
 * resolution) before pub ever runs. Measured back-to-back on the same
 * unchanged Flutter project: `dart pub get` 1.9 s, `flutter pub get` 116 s.
 * That difference is the whole reason toggling Lint integration on read as a
 * hang. Modern `dart pub` resolves `sdk: flutter` dependencies correctly, so
 * the Flutter path is only needed when it does not.
 *
 * The fallback is what makes the preference safe: if `dart pub get` fails on a
 * project that declares Flutter, we retry with `flutter pub get` and report
 * that result instead. A genuinely Flutter-only resolution therefore still
 * succeeds — it just pays the slow path in the rare case rather than always.
 */
/**
 * Should a failed `dart pub get` be retried as `flutter pub get`?
 *
 * Only when the project declares Flutter AND the failure looks like the one
 * the Flutter path actually cures: `dart` could not locate the Flutter SDK to
 * resolve a `sdk: flutter` dependency. That happens when a standalone Dart SDK
 * precedes the Flutter-bundled one on PATH, so the `dart` on PATH cannot
 * self-locate a Flutter root — it is a PATH-ordering fault, not a pubspec one.
 *
 * Retrying on ANY non-zero exit would be worse than the bug being fixed: an
 * offline machine, an auth failure or a malformed pubspec would fail fast in
 * ~2 s under `dart`, then pay the ~114 s flutter_tool boot to fail again for
 * the same reason. Errors the Flutter wrapper cannot change are reported as-is.
 */
export function shouldRetryWithFlutter(workspaceRoot: string, stderr: string): boolean {
  if (!hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'))) return false;
  // Matched case-insensitively against pub's own wording for an unresolvable
  // SDK dependency; kept broad because the exact phrasing varies by SDK version.
  return /flutter[_ ]?sdk|sdk: *flutter|which sdk|unknown sdk|flutter sdk/i.test(stderr);
}

export async function resolveDependencies(
  workspaceRoot: string,
  token: vscode.CancellationToken,
  progress?: vscode.Progress<{ message?: string }>,
): Promise<{ ok: boolean; stderr: string; cancelled: boolean; command: string }> {
  // Ticking elapsed-time feedback when the caller owns a progress notification;
  // callers without one (the upgrade checker runs under its own progress) just
  // get the plain awaited result.
  const withTick = <T>(work: Promise<T>): Promise<T> =>
    progress
      ? withTickingProgress(
          progress,
          (elapsed) => l10n('notify.setup.progressPubGet', { elapsed: String(elapsed) }),
          work,
        )
      : work;

  const dartResult = await withTick(
    runInWorkspaceAsync(workspaceRoot, 'dart', ['pub', 'get'], { token }),
  );
  if (dartResult.ok || dartResult.cancelled) return { ...dartResult, command: 'dart' };

  if (!shouldRetryWithFlutter(workspaceRoot, dartResult.stderr)) {
    return { ...dartResult, command: 'dart' };
  }

  logReport('- dart pub get failed to resolve the Flutter SDK; retrying with flutter pub get');
  const flutterResult = await withTick(
    runInWorkspaceAsync(workspaceRoot, 'flutter', ['pub', 'get'], { token }),
  );
  return { ...flutterResult, command: 'flutter' };
}

/**
 * Makes sure saropa_lints is resolved on disk, running `pub get` only when it
 * is actually needed.
 *
 * `needsResolve` is the caller's knowledge that the manifest just changed;
 * `isSaropaLintsAlreadyResolved` is the independent on-disk check. Either one
 * demanding a resolve wins — the skip is only taken when the manifest was
 * untouched AND the existing resolution already covers it.
 *
 * The pub-get failure toast is raised here rather than by the caller so the
 * caller stays a linear read; the caller only distinguishes the three outcomes.
 */
async function ensureDependencyResolved(
  workspaceRoot: string,
  options: {
    needsResolve: boolean;
    progress: vscode.Progress<{ message?: string }>;
    token: vscode.CancellationToken;
  },
): Promise<'resolved' | 'cancelled' | 'failed'> {
  const { needsResolve, progress, token } = options;

  if (!needsResolve && isSaropaLintsAlreadyResolved(workspaceRoot)) {
    logReport('- Skipped pub get (saropa_lints already resolved and pubspec unchanged)');
    return 'resolved';
  }

  const pubResult = await resolveDependencies(workspaceRoot, token, progress);
  if (pubResult.cancelled) return 'cancelled';
  if (!pubResult.ok) {
    logReport(`- pub get FAILED: ${pubResult.stderr || '(no details)'}`);
    void vscode.window.showErrorMessage(
      l10n('notify.setup.pubGetFailed', {
        details: pubResult.stderr || l10n('notify.setup.checkOutput'),
      }),
    );
    return 'failed';
  }
  logReport(`- Ran pub get (${pubResult.command})`);

  // A `pub get` that exits 0 without resolving the package means the manifest
  // parsed but did not yield saropa_lints (corrupted YAML, wrong indent level).
  // Reported here so the caller never proceeds to write_config against a
  // package that is not on disk.
  if (!resolvesSaropaLints(workspaceRoot)) {
    logReport('- saropa_lints not found in package_config.json after pub get');
    void vscode.window.showErrorMessage(l10n('notify.setup.pubGetNotResolved'));
    return 'failed';
  }
  return 'resolved';
}

// One in-flight `runEnable` at a time. Unlike the analysis supersede pattern
// (cancel old, start new — safe because a rerun just reads violations), this
// flow WRITES pubspec.yaml/analysis_options.yaml and shells out to pub get /
// write_config: two concurrent runs could race on those files. A user
// repeatedly clicking "Enable" while the ~2-minute pub-get step gives no
// visible feedback (see withTickingProgress above) used to stack N identical
// "Enabling Saropa Lints" notifications and N concurrent write/spawn
// sequences instead of joining the one already running.
let _enableInFlight: Promise<boolean> | undefined;

export async function runEnable(context: vscode.ExtensionContext): Promise<boolean> {
  if (_enableInFlight) return _enableInFlight;
  const run = runEnableExclusive(context).finally(() => {
    _enableInFlight = undefined;
  });
  _enableInFlight = run;
  return run;
}

async function runEnableExclusive(context: vscode.ExtensionContext): Promise<boolean> {
  const workspaceRoot = getProjectRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage(l10n('notify.setup.noWorkspaceFolder'));
    return false;
  }

  let success = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Enabling Saropa Lints',
      // Cancellable + async child processes below: pub get / write_config / analyze
      // used to run via the synchronous runInWorkspace (spawnSync), which blocks
      // the whole extension host — on a large project this reads as a permanent
      // "Enabling Saropa Lints" stall with no way out but reloading the window.
      cancellable: true,
    },
    async (progress, token) => {
      logSection('Enable');

      const pubspec = ensureSaropaLintsInPubspec(workspaceRoot);
      if (!pubspec.ok) return;
      logReport(pubspec.changed
        ? '- Added saropa_lints to pubspec.yaml'
        : '- saropa_lints already declared in pubspec.yaml');

      // Skip the single most expensive step in the whole flow when it has
      // nothing to do. Re-resolving an unchanged manifest took 116 s on a
      // ~60-plugin Flutter project, during which Enable looks frozen — users
      // cancel it and conclude the extension cannot be re-enabled at all.
      const resolveState = await ensureDependencyResolved(workspaceRoot, {
        needsResolve: pubspec.changed,
        progress,
        token,
      });
      if (resolveState !== 'resolved') {
        if (resolveState === 'cancelled') logReport('- Enable cancelled by user (pub get)');
        flushReport(workspaceRoot);
        return;
      }

      // (The "resolved but not in package_config" case — corrupted pubspec YAML
      // letting pub get exit 0 without resolving — is checked and reported
      // inside ensureDependencyResolved, which returns 'failed' for it.)

      // Restore the in-process plugin ONLY if our own Disable is what took it
      // away. Enable still must not switch the memory-heavy plugin on as a
      // side effect for anyone else — write_config (below) preserves whatever
      // state is on disk (live stays live, disabled stays disabled) and
      // defaults a brand-new file to disabled.
      //
      // Without this, the single sidebar toggle was lossy in one direction:
      // Disable commented the block out, Enable left it commented, so Off→On
      // silently cost a user their live plugin with no way back except the
      // separate "Re-enable Plugin" command they had no reason to know about.
      // The memento (not the on-disk sentinel) is what makes this safe — see
      // pluginDisabledByExtensionKey for why the sentinel cannot be used.
      let restoredPlugin = false;
      if (wasPluginDisabledByExtension(context, workspaceRoot)) {
        restoredPlugin = restorePluginsIntegration(workspaceRoot);
        // Clear the flag either way. A false return means the block is no
        // longer sentinel-wrapped (the user uncommented it by hand, or
        // re-ran init), so our claim to own its disabled state is stale.
        await setPluginDisabledByExtension(context, workspaceRoot, false);
        if (restoredPlugin) logReport('- Restored the plugins: block disabled by a previous Disable');
      }

      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const tier = (cfg.get<string>('tier') ?? 'recommended').trim();
      const initResult = await withTickingProgress(
        progress,
        (elapsed) => l10n('notify.setup.progressConfigWrite', { elapsed: String(elapsed) }),
        runInWorkspaceAsync(workspaceRoot, 'dart', buildWriteConfigArgs(workspaceRoot, tier), { token }),
      );
      if (initResult.cancelled) {
        logReport('- Enable cancelled by user (write_config)');
        flushReport(workspaceRoot);
        return;
      }
      if (!initResult.ok) {
        logReport(`- write_config FAILED: ${initResult.stderr || '(no details)'}`);
        flushReport(workspaceRoot);
        vscode.window.showErrorMessage(l10n('notify.setup.configWriteFailedNs', { details: initResult.stderr || l10n('notify.setup.checkOutput') }));
        return;
      }
      logReport(`- Wrote config (tier: ${tier})`);

      // Uncommenting the block only affects the analysis server's NEXT start,
      // so the plugin the user just got back stays dormant until we restart it
      // (same reasoning as runDisable/runReenablePlugin).
      if (restoredPlugin) await restartDartAnalysisServer();

      const { cancelled: analysisCancelled } = await withTickingProgress(
        progress,
        (elapsed) => l10n('notify.setup.progressAnalysis', { elapsed: String(elapsed) }),
        runAnalysisAfterConfigChangeScoped(
          context,
          workspaceRoot,
          '- Ran analysis',
          '- Ran analysis',
          { skipEnabledCheck: true, token },
        ),
      );
      if (analysisCancelled) {
        logReport('- Enable cancelled by user (analysis)');
        flushReport(workspaceRoot);
        return;
      }
      success = true;
      flushReport(workspaceRoot);
    },
  );

  // I5: Notification moved to extension.ts enable handler where health score is available.
  return success;
}

/**
 * Create a baseline (saropa_baseline.json) that suppresses the project's
 * EXISTING violations so only newly-introduced findings surface afterward.
 *
 * Why this exists: the Suggestions view already nudges users to baseline once
 * findings exist, but the action used to open the config editor — leaving the
 * user to discover and run `dart run saropa_lints:baseline` in a terminal
 * themselves. The UI surfaced the suggestion and then dead-ended. This wires the
 * nudge to the actual tool.
 *
 * Async + cancellable: the baseline tool shells out to `dart analyze`, which can
 * run for tens of seconds on a large project. runInWorkspaceAsync keeps the
 * extension host responsive and lets the progress UI's Cancel button kill the
 * child (and its dart grandchild) cleanly via killProcessTree.
 */
// One in-flight `runCreateBaseline` at a time — same rationale as
// `_enableInFlight`: it writes saropa_baseline.json, so two concurrent runs
// could race on that file. A user clicking the command again while a large
// project's `dart analyze` is still working (silently, before the ticking
// progress message below existed) could otherwise stack duplicate runs.
let _baselineInFlight: Promise<boolean> | undefined;

export async function runCreateBaseline(): Promise<boolean> {
  if (_baselineInFlight) return _baselineInFlight;
  const run = runCreateBaselineExclusive().finally(() => {
    _baselineInFlight = undefined;
  });
  _baselineInFlight = run;
  return run;
}

async function runCreateBaselineExclusive(): Promise<boolean> {
  const workspaceRoot = getProjectRoot();
  if (!workspaceRoot) {
    void vscode.window.showErrorMessage(l10n('notify.setup.noWorkspaceFolder'));
    return false;
  }

  let success = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('notify.setup.baselineRunning'),
      cancellable: true,
    },
    async (progress, token) => {
      logSection('Create Baseline');
      const result = await withTickingProgress(
        progress,
        (elapsed) => l10n('notify.setup.progressBaseline', { elapsed: String(elapsed) }),
        runInWorkspaceAsync(
          workspaceRoot,
          'dart',
          ['run', 'saropa_lints:baseline'],
          { token },
        ),
      );
      // User-initiated cancel is not an error: leave the report quiet and skip
      // both the success and failure toasts.
      if (result.cancelled) {
        logReport('- Baseline creation cancelled by user');
        flushReport(workspaceRoot);
        return;
      }
      if (!result.ok) {
        logReport(`- baseline FAILED: ${result.stderr || '(no details)'}`);
        flushReport(workspaceRoot);
        void vscode.window.showErrorMessage(
          l10n('notify.setup.baselineFailed', {
            details: result.stderr || l10n('notify.setup.checkOutput'),
          }),
        );
        return;
      }
      logReport('- Created saropa_baseline.json');
      flushReport(workspaceRoot);
      success = true;
      void vscode.window.showInformationMessage(l10n('notify.setup.baselineCreated'));
    },
  );
  return success;
}

const ANALYSIS_OPTIONS_FILENAME = 'analysis_options.yaml';

// Sentinel lines that bracket the commented-out `plugins:` block while
// integration is off. They let runEnable restore the block byte-for-byte
// (preserving the user's enabled rule_packs and in-file rule overrides)
// instead of regenerating from tier defaults and silently dropping them.
const DISABLE_BEGIN_MARKER =
  '# >>> saropa_lints integration turned OFF by the VS Code extension — toggle "Lint integration" On to restore >>>';
const DISABLE_END_MARKER =
  '# <<< saropa_lints end of disabled integration block <<<';

/**
 * Locate the top-level `plugins:` block (header line through the line before
 * the next column-0 YAML key, or EOF). The Dart analysis server loads
 * saropa_lints through this block, so commenting it out is the ONLY thing that
 * actually stops the analyzer from emitting diagnostics — flipping the
 * `saropaLints.enabled` setting alone never reaches the analyzer, which is why
 * "Lint integration: Off" left every diagnostic in place
 * (plans/history/2026.06/2026.06.18/BUG_cant turn off lints.md).
 */
function findPluginsBlock(lines: string[]): { start: number; end: number } | null {
  const start = lines.findIndex((l) => /^plugins:\s*$/.test(l));
  if (start === -1) return null;

  // Block ends at the next top-level key (matches config_writer's
  // topLevelKeyPattern `^\w+:`), or EOF when plugins is the last section.
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) {
    if (/^\w[\w-]*:/.test(lines[i])) {
      end = i;
      break;
    }
  }
  return { start, end };
}

/** One line of text plus the exact terminator that followed it ('' for a final line with no trailing newline). */
interface EolLine {
  text: string;
  eol: '' | '\n' | '\r\n';
}

/**
 * Split file content into lines while recording each line's OWN terminator.
 *
 * Why not `content.split(eol)` with one guessed EOL for the whole file: a file
 * can legitimately mix CRLF and bare-LF lines (e.g. `write_config`'s Dart writer
 * always emits `\n` for a freshly-generated block, dropped into a file whose
 * other lines are CRLF from a Windows/git checkout). Guessing a single EOL and
 * splitting on it turns most lines into one glued-together array element
 * instead of separate lines, so an exact-match `lines.indexOf(sentinel)` fails
 * even though `content.includes(sentinel)` (substring) still succeeds — this
 * caused `restorePluginsIntegration` to silently report "nothing to restore"
 * on a file that plainly had the sentinel.
 */
function splitLinesPreservingEol(content: string): EolLine[] {
  const result: EolLine[] = [];
  let i = 0;
  while (i < content.length) {
    const next = content.indexOf('\n', i);
    if (next === -1) {
      result.push({ text: content.slice(i), eol: '' });
      break;
    }
    const hasCr = next > i && content[next - 1] === '\r';
    result.push({ text: content.slice(i, hasCr ? next - 1 : next), eol: hasCr ? '\r\n' : '\n' });
    i = next + 1;
  }
  return result;
}

/**
 * Every line except the true last one needs a real terminator — a '' (no
 * trailing newline) eol is only valid on whatever ends up last after
 * inserting/removing sentinel lines, not wherever it originated in the
 * source file. Without this, a sentinel spliced in after an original
 * last-line-with-no-newline would get glued onto it with no line break.
 */
function normalizeInteriorEols(lines: EolLine[], fallback: '\n' | '\r\n'): EolLine[] {
  return lines.map((l, i) => (i < lines.length - 1 && l.eol === '' ? { ...l, eol: fallback } : l));
}

function joinEolLines(lines: EolLine[]): string {
  return lines.map((l) => l.text + l.eol).join('');
}

/**
 * Comment out the `plugins:` block so the analyzer stops loading saropa_lints.
 *
 * Returns 'commented' when it disabled an active block, 'already-off' when the
 * block is already wrapped by the disable sentinels, and 'no-config' when there
 * is no analysis_options.yaml or no plugins block (integration was never set
 * up). Blank lines are left untouched so the restore is exact.
 */
export function disablePluginsIntegration(root: string): 'commented' | 'already-off' | 'no-config' {
  const file = path.join(root, ANALYSIS_OPTIONS_FILENAME);
  if (!fs.existsSync(file)) return 'no-config';

  const content = fs.readFileSync(file, 'utf-8');
  if (content.includes(DISABLE_BEGIN_MARKER)) return 'already-off';

  const lines = splitLinesPreservingEol(content);
  const block = findPluginsBlock(lines.map((l) => l.text));
  if (!block) return 'no-config';

  // New sentinel lines inherit the EOL style already in use at the insertion
  // point, so a homogeneous file (CRLF or LF) stays homogeneous.
  const fallbackEol: '\n' | '\r\n' = lines[block.start]?.eol === '\r\n' ? '\r\n' : '\n';

  // Prefix '# ' onto every non-blank line in the block; restore strips it back.
  const commented: EolLine[] = lines
    .slice(block.start, block.end)
    .map((l) => (l.text.length === 0 ? l : { text: `# ${l.text}`, eol: l.eol }));

  const next: EolLine[] = [
    ...lines.slice(0, block.start),
    { text: DISABLE_BEGIN_MARKER, eol: fallbackEol },
    ...commented,
    { text: DISABLE_END_MARKER, eol: fallbackEol },
    ...lines.slice(block.end),
  ];
  fs.writeFileSync(file, joinEolLines(normalizeInteriorEols(next, fallbackEol)), 'utf-8');
  return 'commented';
}

/**
 * Reverse [disablePluginsIntegration]: strip the sentinels and the '# ' prefix
 * so the live `plugins:` block returns with the user's rule_packs and overrides
 * intact. Called by runEnable before write_config (only when this extension is
 * the one that turned the block off — see [wasPluginDisabledByExtension]) so
 * the regeneration edits the real block in place instead of appending a
 * duplicate below the commented one. Returns true when a disabled block was
 * restored.
 */
export function restorePluginsIntegration(root: string): boolean {
  const file = path.join(root, ANALYSIS_OPTIONS_FILENAME);
  if (!fs.existsSync(file)) return false;

  const content = fs.readFileSync(file, 'utf-8');
  if (!content.includes(DISABLE_BEGIN_MARKER)) return false;

  const lines = splitLinesPreservingEol(content);
  const begin = lines.findIndex((l) => l.text === DISABLE_BEGIN_MARKER);
  const end = lines.findIndex((l) => l.text === DISABLE_END_MARKER);
  if (begin === -1 || end === -1 || end <= begin) return false;

  const restored: EolLine[] = lines
    .slice(begin + 1, end)
    .map((l) => (l.text.startsWith('# ') ? { text: l.text.slice(2), eol: l.eol } : l));

  const next: EolLine[] = [...lines.slice(0, begin), ...restored, ...lines.slice(end + 1)];
  const fallbackEol: '\n' | '\r\n' = lines[begin]?.eol === '\r\n' ? '\r\n' : '\n';
  fs.writeFileSync(file, joinEolLines(normalizeInteriorEols(next, fallbackEol)), 'utf-8');
  return true;
}

/** On-disk state of the `plugins:` block, independent of `saropaLints.enabled`. */
export type PluginsIntegrationState = 'live' | 'disabled' | 'absent';

/**
 * Read whether the in-process analyzer plugin is actually wired up on disk.
 *
 * This is a DIFFERENT subsystem from the `saropaLints.enabled` setting: that
 * setting gates scan-on-save delivery, while this block is the only thing the
 * Dart analysis server reads to decide whether to load the plugin at all. The
 * sidebar used to surface only the setting, so it happily reported
 * "Lint integration: On" over a file whose plugins block was commented out —
 * which is what a user sees as "enabled but the yaml says disabled".
 */
export function getPluginsIntegrationState(root: string): PluginsIntegrationState {
  const file = path.join(root, ANALYSIS_OPTIONS_FILENAME);
  if (!fs.existsSync(file)) return 'absent';
  const content = fs.readFileSync(file, 'utf-8');

  // A live (column-0) `plugins:` header is what the analysis server actually
  // acts on, so it OUTRANKS the sentinel. Checking the sentinel first would
  // report 'disabled' for a file that has a stray/orphaned marker above a
  // live block — the analyzer would be loading the plugin while this row
  // claimed it was off, which is the same category of lie this row exists to
  // eliminate. Orphaned markers are reachable: restore strips the sentinel
  // pair together, but a partial hand-edit or a merge conflict can leave one
  // behind.
  const lines = splitLinesPreservingEol(content).map((l) => l.text);
  if (findPluginsBlock(lines)) return 'live';
  if (content.includes(DISABLE_BEGIN_MARKER)) return 'disabled';
  return 'absent';
}

/**
 * Memento key recording that OUR `runDisable` commented out a block that was
 * live at the time. Keyed by project root so a multi-root window tracks each
 * folder separately.
 *
 * Why a memento instead of just checking for the disable sentinel: the sentinel
 * cannot distinguish the two ways a block ends up disabled. `write_config`
 * writes the exact same marker for a BRAND-NEW project
 * (`willBeDisabled = isNewFile || wasDisabled` in write_config_runner.dart),
 * because the in-process plugin costs several GB and new projects deliberately
 * default to daemon-only delivery. Restoring on "sentinel present" would
 * therefore switch that heavy plugin on for every new user the first time they
 * hit Enable — the precise outcome the default exists to prevent. The memento
 * is only ever set on a live→disabled transition we performed ourselves, so
 * Enable restores exactly what Disable took away and nothing else.
 *
 * Trade-off accepted: workspaceState is per-machine, so on a fresh clone the
 * flag is absent and Enable leaves the block alone — i.e. it degrades to the
 * previous behavior rather than guessing wrong in the expensive direction.
 */
function pluginDisabledByExtensionKey(root: string): string {
  return `saropaLints.pluginDisabledByExtension:${root}`;
}

/**
 * Durable mirror of the memento, written next to the project instead of into
 * VS Code's per-workspace storage.
 *
 * Why BOTH records exist: the memento alone makes the whole restore inert if
 * `workspaceState` is ever cleared, and — this is the dangerous part — the
 * resulting failure is indistinguishable from the original bug (Enable simply
 * stops restoring, silently). `workspaceState` is documented as persistent but
 * is scoped to the extension's storage for that workspace, so an extension
 * storage reset, a VS Code profile switch, or a workspace re-opened under a
 * different folder identity can drop it. The two records fail in DIFFERENT
 * situations and therefore cover each other:
 *
 *   - the memento survives `flutter clean` / `dart run build_runner clean`
 *     (which delete `.dart_tool/` wholesale) but not a storage/profile reset;
 *   - this file survives storage and profile resets but not `.dart_tool/`
 *     deletion.
 *
 * `.dart_tool/` is the right home rather than the project tree proper: it is
 * gitignored by every Dart/Flutter project, so a committed claim can never
 * follow the repo onto a teammate's machine and switch the multi-GB in-process
 * plugin on for someone who never disabled anything. It also cannot live
 * INSIDE the commented `plugins:` block — `write_config` regenerates that whole
 * block from scratch (`replacePluginsSection`), so any marker parked in there
 * is erased the next time a tier change runs while integration is off.
 */
function pluginOwnershipFilePath(root: string): string {
  return path.join(root, '.dart_tool', 'saropa_lints', 'plugin_ownership.json');
}

/** True when the durable sidecar claims our Disable owns this root's off state. */
function readPluginOwnershipFile(root: string): boolean {
  try {
    const file = pluginOwnershipFilePath(root);
    if (!fs.existsSync(file)) return false;
    const parsed: unknown = JSON.parse(fs.readFileSync(file, 'utf-8'));
    // Defensive shape check: a hand-mangled or truncated file must read as
    // "no claim" rather than throw during activation.
    return typeof parsed === 'object' && parsed !== null
      && (parsed as { disabledByExtension?: unknown }).disabledByExtension === true;
  } catch {
    // Unreadable/corrupt sidecar degrades to the memento — never fatal.
    return false;
  }
}

/** Write or delete the durable sidecar. Failures are logged, never thrown. */
function writePluginOwnershipFile(root: string, value: boolean): void {
  const file = pluginOwnershipFilePath(root);
  try {
    if (!value) {
      if (fs.existsSync(file)) fs.rmSync(file);
      return;
    }
    fs.mkdirSync(path.dirname(file), { recursive: true });
    // `root` is recorded so a copied/moved .dart_tool is still diagnosable from
    // the file alone; only `disabledByExtension` is load-bearing.
    fs.writeFileSync(file, `${JSON.stringify({ disabledByExtension: true, root }, null, 2)}\n`, 'utf-8');
  } catch (e) {
    // A read-only or missing .dart_tool is survivable: the memento still holds
    // the claim. Log rather than fail the Disable the user asked for.
    getOutputChannel().appendLine(`[saropa] could not persist plugin ownership to ${file}: ${String(e)}`);
  }
}

/**
 * True when EITHER record claims ownership. OR (not AND) is deliberate: both
 * records are only ever written by our own live→disabled transition, so
 * neither can produce a false claim, and each one's disappearance is a
 * survivable data loss rather than evidence that the claim was never made.
 */
export function wasPluginDisabledByExtension(context: vscode.ExtensionContext, root: string): boolean {
  const memento = context.workspaceState.get<boolean>(pluginDisabledByExtensionKey(root), false) ?? false;
  return memento || readPluginOwnershipFile(root);
}

async function setPluginDisabledByExtension(
  context: vscode.ExtensionContext,
  root: string,
  value: boolean,
): Promise<void> {
  // `undefined` removes the key entirely rather than leaving a `false` behind.
  await context.workspaceState.update(pluginDisabledByExtensionKey(root), value ? true : undefined);
  writePluginOwnershipFile(root, value);
}

/**
 * One-line activation probe for the ownership records.
 *
 * The restore path is invisible when it fails — Enable just quietly does not
 * restore — so the only way a user or a bug report can tell "the claim was
 * never made" from "the claim was lost" is a log line stating what each record
 * held at startup. Cheap (two existence checks) and written once per folder.
 */
export function describePluginOwnership(context: vscode.ExtensionContext, root: string): string {
  const memento = context.workspaceState.get<boolean>(pluginDisabledByExtensionKey(root), false) ?? false;
  const sidecar = readPluginOwnershipFile(root);
  return `[saropa] plugin ownership for ${root}: block=${getPluginsIntegrationState(root)}`
    + `, memento=${memento}, sidecar=${sidecar}`;
}

/**
 * Drop a stale ownership claim when the `plugins:` block went live without us.
 *
 * The claim means "our Disable commented out a block that was live". Anything
 * that puts the block back independently — `dart run saropa_lints:init`, a git
 * checkout, a hand-edit, a merge — invalidates it. Left stale, the next Enable
 * would call restore on an already-live block; that is harmless today (restore
 * no-ops and the claim is cleared) but it means the claim silently describes
 * something untrue for an unbounded stretch, which is exactly the drift this
 * whole change is about. Reconciling on file change keeps the claim honest.
 *
 * Returns true when a stale claim was cleared, so callers can log it.
 */
export async function reconcilePluginOwnership(
  context: vscode.ExtensionContext,
  root: string,
): Promise<boolean> {
  if (!wasPluginDisabledByExtension(context, root)) return false;
  if (getPluginsIntegrationState(root) !== 'live') return false;
  await setPluginDisabledByExtension(context, root, false);
  return true;
}

// Editing analysis_options.yaml only changes what the Dart analysis server
// will load on its NEXT start — the already-running plugin host process (a
// separate long-lived `dart.exe`, several GB once warmed up) keeps running
// until the server actually restarts. `dart.restartAnalysisServer` is owned
// by the official Dart extension; guarded because that extension is not a
// hard dependency here and the command may not exist in every host.
async function restartDartAnalysisServer(): Promise<void> {
  try {
    await vscode.commands.executeCommand('dart.restartAnalysisServer');
  } catch {
    // Dart extension not installed/active — nothing to restart.
  }
}

export async function runDisable(context: vscode.ExtensionContext): Promise<void> {
  await vscode.workspace.getConfiguration('saropaLints').update('enabled', false, vscode.ConfigurationTarget.Workspace);

  // Setting the flag is not enough: the analyzer keeps emitting diagnostics
  // until the plugins block is gone. Comment it out so "Off" actually clears
  // the Problems pane (plans/history/2026.06/2026.06.18/BUG_cant turn off lints.md).
  const root = getProjectRoot();
  const result = root ? disablePluginsIntegration(root) : 'no-config';
  if (result === 'commented' && root) {
    // Remember that WE took a live block away, so the matching Enable can put
    // it back. Only on 'commented': 'already-off' means someone else (or a
    // new-project default) disabled it and Enable must not claim ownership.
    await setPluginDisabledByExtension(context, root, true);
  }
  if (result === 'commented') {
    // The commented-out block only stops future loads — restart now so the
    // already-running plugin host process actually exits and its memory is
    // freed, instead of surviving until the user manually reloads/restarts.
    await restartDartAnalysisServer();
  }
  vscode.window.showInformationMessage(
    result === 'commented'
      ? l10n('notify.setup.disabledAnalyzer')
      : l10n('notify.setup.disabled'),
  );
}

/**
 * Restore the in-process plugin after `runDisable` commented it out.
 *
 * `runEnable` deliberately never calls `restorePluginsIntegration` (see the
 * comment above its `write_config` call) — enabling scan-on-save must not
 * silently bring back the memory-heavy in-process plugin as a side effect.
 * This is the dedicated, explicit counterpart a user reaches for when they
 * DO want the in-process plugin (live in-editor squiggles) back, rather than
 * hand-editing analysis_options.yaml to uncomment the sentinel block.
 */
export async function runReenablePlugin(context: vscode.ExtensionContext): Promise<void> {
  const root = getProjectRoot();
  if (!root) {
    vscode.window.showErrorMessage(l10n('notify.setup.noWorkspaceFolder'));
    return;
  }

  const restored = restorePluginsIntegration(root);
  // The block is live again however it got there, so drop any claim that our
  // Disable still owns its off state — otherwise the next Enable would try to
  // "restore" an already-restored block.
  await setPluginDisabledByExtension(context, root, false);
  if (!restored) {
    // A block that is ALREADY live still justifies a restart: Enable restores
    // the block and restarts the server as two separate steps, so cancelling
    // in between (or any crash there) leaves the plugin declared-but-dormant.
    // Reporting "nothing to restore" there was a dead end — the state looks
    // correct on disk and the only fix was reloading the window by hand.
    if (getPluginsIntegrationState(root) === 'live') {
      await restartDartAnalysisServer();
      vscode.window.showInformationMessage(l10n('notify.setup.reenabledPlugin'));
      return;
    }
    vscode.window.showInformationMessage(l10n('notify.setup.reenableNothingToRestore'));
    return;
  }

  // Same reasoning as runDisable: editing the yaml only affects the NEXT
  // analysis server start, so restart now to actually load the plugin.
  await restartDartAnalysisServer();
  vscode.window.showInformationMessage(l10n('notify.setup.reenabledPlugin'));
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
  // The `saropaLints.enable` command calls this mid-transition, before it flips
  // `enabled` to true, so that specific call site opts out of the check below —
  // every other caller (e.g. a tier change while integration is off) must not
  // bypass it. `token` lets a cancellable caller (e.g. runEnable) stop a
  // long-running `dart analyze` instead of leaving it to finish unattended.
  options?: { skipEnabledCheck?: boolean; token?: vscode.CancellationToken },
  // Reports whether the analysis step was cancelled, so a cancellable caller
  // (runEnable) can avoid treating a cancelled run as a completed success —
  // without this, cancelling mid-analyze still marked the whole Enable flow
  // successful and flipped `saropaLints.enabled` on regardless.
): Promise<{ cancelled: boolean }> {
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  if (!options?.skipEnabledCheck && !(cfg.get<boolean>('enabled', true) ?? true)) return { cancelled: false };
  const runAnalysisAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true);
  if (!runAnalysisAfter) return { cancelled: false };

  const openEditorsOnly = cfg.get<boolean>('runAnalysisOpenEditorsOnly', false) ?? false;
  if (openEditorsOnly) {
    const files = getOpenDartFilePaths(workspaceRoot);
    if (files.length > 0) {
      await runAnalysisForFiles(context, files, { showProgress: false });
    } else {
      logReport('- Skipped analysis (no open Dart files)');
    }
    return { cancelled: false };
  }

  // Always `dart`, never `flutter`, even on Flutter projects: both run the same
  // analyzer, but the flutter wrapper boots the flutter_tool first (SDK version
  // check, artifact validation, its own resolution) — measured at ~114 s of pure
  // overhead on a large project. See runPubGet for the measurement.
  const analyzeCmd = 'dart';
  // Async spawn: `dart analyze` on a large project can run for tens of seconds,
  // and the synchronous spawnSync variant used to block the whole extension
  // host for that entire duration — the root cause of the "Enabling Saropa
  // Lints" progress notification appearing permanently stalled.
  const analysisResult = await runInWorkspaceAsync(workspaceRoot, analyzeCmd, ['analyze'], { token: options?.token });
  if (analysisResult.cancelled) {
    logReport('- Analysis cancelled by user');
    return { cancelled: true };
  }
  logReport(analysisResult.ok ? fullOkMessage : fullFailMessage);
  return { cancelled: false };
}

/**
 * Compose the warning-popup text for the analysis-reported-issues path.
 *
 * Why a pure helper: the prior implementation spliced the first 200 chars of
 * `dart analyze`'s stderr into the popup (bugs/infra_run_analysis_popup_dumps_progress_stderr.md).
 * stderr carries the progress bar, not diagnostics, so the popup was always
 * garbled progress chrome. Isolating the message composition here (a) keeps the
 * real count (from violations.json) in one place instead of reconstructing it
 * at two call sites, and (b) makes the pluralization / scope-label / zero-count
 * branches unit-testable without stubbing the vscode UI module.
 *
 * Exported for testing; call sites use showAnalysisIssuesNotification().
 */
/**
 * Resolve the saropa_lints version currently pinned in the workspace's
 * `pubspec.lock`, plus the source (`hosted`, `path`, `git`, …). Returns
 * `undefined` for missing/unreadable/unparseable locks — silent failure
 * is preferred over a misleading `unknown` placeholder, because the
 * downstream `flushReport` omits the field entirely when no value is
 * supplied.
 *
 * Why read `pubspec.lock` rather than `pubspec.yaml`: the yaml carries a
 * constraint (`^12.4.0`) while the lock carries the *resolved* version
 * (`12.4.2`) — and when diagnosing "is the plugin I expect actually
 * running?" the resolved version is what matters. Reuses the existing
 * `readInstalledVersion` helper so lock-parsing lives in one place.
 */
function resolveSaropaLintsVersion(
  workspaceRoot: string,
): { version: string; source: string } | undefined {
  try {
    const lockPath = path.join(workspaceRoot, 'pubspec.lock');
    if (!fs.existsSync(lockPath)) return undefined;
    const content = fs.readFileSync(lockPath, 'utf-8');
    return readInstalledVersion(content) ?? undefined;
  } catch {
    return undefined;
  }
}

/** Extension version from its own `package.json` (VSIX version). */
function resolveExtensionVersion(): string | undefined {
  // The extension's own manifest is reachable via the well-known
  // publisher id; fall back silently when the extension API isn't
  // available (e.g. unit-test environments without vscode host).
  const self = vscode.extensions.getExtension('saropa.saropa-lints');
  const version = (self?.packageJSON as { version?: string } | undefined)?.version;
  return typeof version === 'string' && version.length > 0 ? version : undefined;
}

export function formatAnalysisIssuesMessage(
  total: number,
  scope?: string,
  saropaLintsVersion?: string,
): string {
  // Leading space inside the parens so the undefined branch doesn't leave a
  // stray " ()" at the end — the bug report's fixture explicitly calls this out.
  const scopeLabel = scope ? ` (${scope})` : '';
  // Version suffix (optional): `Saropa Lints v12.4.2: 5,234 issues…`.
  // Omitted entirely when unresolved — no `unknown` placeholder.
  const versionLabel = saropaLintsVersion ? ` v${saropaLintsVersion}` : '';
  if (total > 0) {
    const noun = total === 1 ? 'issue' : 'issues';
    // toLocaleString for thousands separators — 5,234 reads much better than
    // 5234 in a two-line warning popup on a large project.
    return `Saropa Lints${versionLabel}: ${total.toLocaleString()} ${noun} found${scopeLabel}.`;
  }
  // total === 0 path: violations.json missing/unreadable OR a zero-length list
  // accompanied by a non-zero analyze exit (e.g. analyzer crash, compile error,
  // plugin fail). Can't promise a count, so direct users to Output instead.
  return `Saropa Lints${versionLabel} analysis finished with a non-zero exit${scopeLabel}. See Output for details.`;
}

/**
 * Decide which action buttons the post-analysis popup may show, given how
 * many violations the dashboard can actually render and whether the Dart
 * plugin's `*_saropa_lint_report.log` exists on disk.
 *
 * Why this is a separate, pure function: the popup historically offered
 * "View Violations", "Copy Report" and "Open Report" *unconditionally* —
 * even when there was nothing to view and no report file to copy/open. The
 * `dart analyze` the extension spawns can exit non-zero for reasons that
 * have nothing to do with saropa_lints (a core analyzer error, a compile
 * failure), while the plugin writes `violations.json` and the report log
 * together on a 3s idle debounce inside the analysis server
 * (`AnalysisReporter._writeReport`). Those two signals are decoupled, so the
 * popup could fire with zero renderable violations and no report — leaving
 * three of its four buttons inert (a transient "no report found" toast that
 * reads as broken). Gating each button on the thing it acts upon keeps the
 * popup honest: a button appears only when it has a target.
 *
 * - "View Violations" requires at least one violation the dashboard renders.
 * - "Copy Report" / "Open Report" require the report log to exist.
 * - "Show Output" is always available — the Output channel always has the
 *   run's stderr/diagnosis even when nothing else was produced.
 *
 * Exported for unit testing so the gating matrix is verified without driving
 * the live VS Code notification UI.
 */
export function analysisIssuesActions(
  renderableViolations: number,
  hasReport: boolean,
): string[] {
  const actions: string[] = [];
  if (renderableViolations > 0) actions.push('View Violations');
  if (hasReport) actions.push('Copy Report', 'Open Report');
  actions.push('Show Output');
  return actions;
}

/**
 * Max time to wait for the plugin to write a fresh `violations.json` after an
 * analysis run before falling back to whatever is on disk. The analyzer writes
 * on a 3s idle debounce (`AnalysisReporter._debounce`); 6s leaves margin for a
 * multi-isolate consolidation without pinning the progress toast for an
 * unreasonable time.
 */
const FRESH_VIOLATIONS_TIMEOUT_MS = 6000;

/** Poll interval while waiting for the fresh `violations.json` write. */
const FRESH_VIOLATIONS_POLL_MS = 250;

/**
 * Wait until `reports/.saropa_lints/violations.json` has been written newer
 * than [sinceMs], or [timeoutMs] elapses. Returns true when a fresh write
 * landed.
 *
 * Why this exists: the post-analysis popup must reflect the plugin's ACTUAL
 * output, not the bare `dart analyze` exit code. The plugin (the live analysis
 * server) writes `violations.json` and the `*_saropa_lint_report.log` together
 * on a debounce, decoupled from the one-shot `dart analyze` the extension
 * spawns. Firing the popup immediately off the exit code produced the "claims
 * violations, empty dashboard, dead Copy/Open Report buttons" bug: the exit
 * code can be non-zero (a core analyzer error, a compile failure) while the
 * plugin's fresh write hasn't landed — or never lands for this run. Gating on
 * a fresh write makes the popup honest: when it fires off fresh data, the
 * dashboard is populated and the report exists, so every button has a target.
 *
 * Robust to both runtime realities — whether the spawned `dart analyze`
 * triggers the write or the live server does — because it keys off the real
 * artifact's mtime, not the subprocess. When no fresh write lands within the
 * timeout, the caller still shows the gated notification, which then reflects
 * whatever is on disk (typically the honest "see Output" no-findings message).
 */
async function awaitFreshViolations(
  workspaceRoot: string,
  sinceMs: number,
  timeoutMs: number = FRESH_VIOLATIONS_TIMEOUT_MS,
): Promise<boolean> {
  const p = path.join(workspaceRoot, 'reports', '.saropa_lints', 'violations.json');
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    try {
      // mtimeMs strictly greater than the run start means the plugin rewrote
      // the file for THIS run, not a leftover from a prior session.
      if (fs.existsSync(p) && fs.statSync(p).mtimeMs > sinceMs) return true;
    } catch {
      // stat race: the exporter writes temp-then-rename (ViolationExporter
      // ._writeAtomicFile), so a stat can briefly hit a mid-rename gap. Retry.
    }
    if (Date.now() >= deadline) return false;
    await new Promise((resolve) => setTimeout(resolve, FRESH_VIOLATIONS_POLL_MS));
  }
}

/**
 * Warn the user that `dart analyze` reported issues, with the real count and
 * clickable buttons for the next step.
 *
 * Why fire-and-forget: the caller wraps analysis in `window.withProgress`, so
 * awaiting the popup would keep the progress indicator pinned until the user
 * dismisses the popup — a bad UX. The popup is modeless; the button handlers
 * dispatch their own commands asynchronously.
 */
function showAnalysisIssuesNotification(workspaceRoot: string, scope?: string): void {
  const data = readViolations(workspaceRoot);
  // Count what the Findings dashboard will actually render — the
  // `violations[]` array — NOT `summary.totalViolations`. The summary is a
  // plugin-written aggregate that can diverge from (or outlive) the array
  // it summarizes; keying the popup off the array guarantees the popup can
  // never claim "N violations found" while the dashboard shows none. That
  // exact mismatch is what made the popup look like it was lying.
  const renderableViolations = data?.violations.length ?? 0;
  // The plugin writes `violations.json` and the `*_saropa_lint_report.log`
  // together in one atomic pass (`AnalysisReporter._writeReport`). A missing
  // report therefore means the plugin produced no findings this run — even
  // when `dart analyze` exited non-zero for an unrelated reason (compile
  // error, core analyzer diagnostic). Resolve it once so both the message
  // and the button set agree on what data actually exists.
  const reportPath = findLatestAnalysisReport(workspaceRoot);
  const hasReport = reportPath !== undefined;
  // Surface the resolved saropa_lints version in the popup so users can tell
  // at a glance which plugin build produced these diagnostics — previously
  // users had to open the report file (and that field was broken too).
  const installed = resolveSaropaLintsVersion(workspaceRoot);
  // When nothing renderable exists, formatAnalysisIssuesMessage(0, …) already
  // produces the honest "analysis finished with a non-zero exit. See Output"
  // text — so a no-findings run shows that message with only the always-valid
  // "Show Output" action (analysisIssuesActions gates the rest away).
  const message = formatAnalysisIssuesMessage(renderableViolations, scope, installed?.version);

  // Each action is gated on the artifact it acts upon (see
  // analysisIssuesActions): "Copy Report" / "Open Report" only appear when
  // the report log exists, "View Violations" only when there is something to
  // view. This removes the dead buttons that previously fired a transient
  // "no report found" toast and read as broken.
  const actions = analysisIssuesActions(renderableViolations, hasReport);
  void vscode.window
    .showWarningMessage(message, ...actions)
    .then((choice) => {
      if (choice === 'View Violations') {
        void vscode.commands.executeCommand('saropaLints.focusIssues');
      } else if (choice === 'Copy Report') {
        void vscode.commands.executeCommand('saropaLints.copyLatestReport');
      } else if (choice === 'Open Report') {
        void vscode.commands.executeCommand('saropaLints.openLatestReport');
      } else if (choice === 'Show Output') {
        void vscode.commands.executeCommand('saropaLints.showOutput');
      }
    });
}

/**
 * Add suppression stats to the extension action report so exported markdown
 * includes suppression debt context alongside issue counts.
 */
function logSuppressionSummary(workspaceRoot: string): void {
  const data = readViolations(workspaceRoot);
  const sup = data?.summary?.suppressions;
  const total = sup?.total ?? 0;
  if (total <= 0) return;

  logSection('Suppressions');
  logReport(`- Total: ${total}`);
  if (sup?.byKind) {
    const byKind = Object.entries(sup.byKind)
      .sort((a, b) => (b[1] ?? 0) - (a[1] ?? 0))
      .map(([kind, count]) => `${kind}=${count}`)
      .join(', ');
    if (byKind) logReport(`- By kind: ${byKind}`);
  }
  if (sup?.byRule) {
    const topRules = Object.entries(sup.byRule)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([rule, count]) => `${rule} (${count})`)
      .join(', ');
    if (topRules) logReport(`- Top rules: ${topRules}`);
  }
  if (sup?.byFile) {
    const topFiles = Object.entries(sup.byFile)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([file, count]) => `${file} (${count})`)
      .join(', ');
    if (topFiles) logReport(`- Top files: ${topFiles}`);
  }
}

export async function runAnalysis(context: vscode.ExtensionContext): Promise<boolean> {
  const workspaceRoot = getProjectRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage(l10n('notify.setup.noWorkspaceFolder'));
    return false;
  }
  let ok = false;
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  // "Lint integration: Off" must stop every analyze run this function can be
  // reached from — manual command, dependency-change watcher, config-change
  // auto-run, enableRulePack — not just diagnostics rendering. Silent no-op:
  // the auto-trigger callers should not pop a message on every save while
  // disabled; the manual command surfaces its own message before calling in.
  if (!(cfg.get<boolean>('enabled', true) ?? true)) return false;
  const openEditorsOnly = cfg.get<boolean>('runAnalysisOpenEditorsOnly', false) ?? false;

  // Supersede any previous in-flight full analysis before starting this one, so a
  // burst of config changes (pack toggles) collapses to a single live run rather
  // than stacking notifications and analyzer processes. The previous run's child
  // is killed via its token; its progress notification then resolves and closes.
  _supersedingAnalysisCts?.cancel();
  _supersedingAnalysisCts?.dispose();
  const supersedeCts = new vscode.CancellationTokenSource();
  _supersedingAnalysisCts = supersedeCts;

  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: openEditorsOnly ? 'Running analysis (open editors)' : 'Running analysis',
      // Cancellable so a wedged `dart analyze` can be killed. Critical when this
      // flow is nested inside another progress (e.g. the upgrade checker awaits
      // initializeConfig -> runAnalysis): the old synchronous `runInWorkspace`
      // here blocked the extension-host event loop for the FULL analyze duration,
      // which froze the outer "Upgrading…" notification with a dead Cancel
      // button and made it look like it never closed. The async variant below
      // keeps the loop responsive and forwards this token to kill the child tree.
      cancellable: true,
    },
    async (_progress, token) => {
      // Funnel the UI Cancel button into the supersede token so the analyzer child
      // sees a single cancellation source whether the user clicked Cancel or a newer
      // run superseded this one. Disposed in finally so the listener never leaks.
      const cancelBridge = token.onCancellationRequested(() => supersedeCts.cancel());
      try {
      // Stamp the run start so the post-analysis popup can wait for the
      // plugin's fresh violations.json write (newer than this) before firing,
      // instead of racing the bare `dart analyze` exit code. See
      // awaitFreshViolations for the decoupling rationale.
      const runStartMs = Date.now();
      if (openEditorsOnly) {
        const files = getOpenDartFilePaths(workspaceRoot);
        if (files.length === 0) {
          vscode.window.showInformationMessage(
            l10n('notify.setup.noOpenDartFiles'),
          );
          ok = false;
          return;
        }
        ok = await runAnalysisForFiles(context, files, { showProgress: false });
        if (!ok) {
          // See bugs/infra_run_analysis_popup_dumps_progress_stderr.md — scope
          // label tells the user why the count may differ from a full run.
          // Wait for the plugin's fresh write so the popup reflects real data
          // (and the report log exists) rather than a stale/empty snapshot.
          await awaitFreshViolations(workspaceRoot, runStartMs);
          showAnalysisIssuesNotification(workspaceRoot, 'open editors only');
        }
        return;
      }

      // `dart`, not `flutter` — same analyzer, none of the flutter_tool boot
      // cost (see the comment on analyzeCmd above).
      const cmd = 'dart';
      logSection('Analysis');
      // Async + cancellable: never block the extension-host event loop (see the
      // cancellable rationale on this progress above). The token wires the
      // Cancel button to a process-tree kill.
      const result = await runInWorkspaceAsync(workspaceRoot, cmd, ['analyze'], { token: supersedeCts.token });
      if (result.cancelled) {
        // Cancelled either by the user's Cancel button or because a newer run
        // superseded this one (rapid pack toggles). Either way: stop quietly.
        logReport('- Analysis cancelled (user or superseded by a newer run)');
        flushReport(workspaceRoot);
        ok = false;
        return;
      }
      ok = result.ok;
      if (ok) {
        logReport('- Analysis completed clean');
      } else {
        logReport(`- Analysis reported issues (${cmd} analyze)`);
        // See bugs/infra_run_analysis_popup_dumps_progress_stderr.md — the old
        // code sliced result.stderr into the popup, but dart analyze writes a
        // progress bar to stderr, so the popup was always garbled chrome.
        // Read the authoritative count from violations.json instead — but only
        // after waiting for the plugin's fresh write so the popup, the report
        // buttons, and the dashboard all agree on the same data.
        await awaitFreshViolations(workspaceRoot, runStartMs);
        showAnalysisIssuesNotification(workspaceRoot);
      }
      logSuppressionSummary(workspaceRoot);
      // Tag the extension report with the extension version and the resolved
      // saropa_lints version from pubspec.lock — so every
      // `<ts>_saropa_extension.md` file is self-identifying. When a user
      // asks "is the rule still firing 14k times?" the first useful fact is
      // which plugin build produced the numbers.
      const installed = resolveSaropaLintsVersion(workspaceRoot);
      flushReport(workspaceRoot, {
        extensionVersion: resolveExtensionVersion(),
        saropaLintsVersion: installed?.version,
        saropaLintsSource: installed?.source,
      });
      } finally {
        cancelBridge.dispose();
      }
    },
  );
  // Only clear the shared slot if this run still owns it — a newer run may have
  // already replaced (and disposed) it. dispose() is idempotent, so the extra
  // call when superseded is harmless.
  if (_supersedingAnalysisCts === supersedeCts) _supersedingAnalysisCts = undefined;
  supersedeCts.dispose();
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
  const enabled = vscode.workspace.getConfiguration('saropaLints').get<boolean>('enabled', true) ?? true;
  if (!enabled) return false;

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

  // `dart`, not `flutter` — same analyzer, none of the flutter_tool boot cost
  // (see the comment on analyzeCmd above).
  const cmd = 'dart';
  const args = ['analyze', ...toRun];

  const doRun = (): boolean => {
    logSection('Analysis (files)');
    const result = runInWorkspace(workspaceRoot, cmd, args, true);
    if (result.ok) {
      logReport('- Analysis completed');
    } else {
      logReport(`- Analysis reported issues (${cmd} analyze ${toRun.length} files)`);
    }
    logSuppressionSummary(workspaceRoot);
    // Same reasoning as the full-workspace runAnalysis flow — stamp the
    // extension report with the versions that produced the run, so the
    // file is self-identifying.
    const installed = resolveSaropaLintsVersion(workspaceRoot);
    flushReport(workspaceRoot, {
      extensionVersion: resolveExtensionVersion(),
      saropaLintsVersion: installed?.version,
      saropaLintsSource: installed?.source,
    });
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
    vscode.window.showErrorMessage(l10n('notify.setup.noWorkspaceFolder'));
    return false;
  }
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  const tier = (cfg.get<string>('tier') ?? 'recommended').trim();
  let ok = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: title ?? 'Initializing Saropa Lints config',
      // Cancellable so a wedged `dart` invocation doesn't lock VS Code. The token
      // is forwarded to `runInWorkspaceAsync` which kills the child process tree.
      cancellable: true,
    },
    async (_progress, token) => {
      logSection('Initialize Config');
      const result = await runInWorkspaceAsync(
        workspaceRoot,
        'dart',
        buildWriteConfigArgs(workspaceRoot, tier),
        { token },
      );
      ok = result.ok;
      if (result.cancelled) {
        logReport('- Initialize Config cancelled by user');
        flushReport(workspaceRoot);
        return;
      }
      if (ok) {
        logReport(`- Config initialized (tier: ${tier})`);
        flushReport(workspaceRoot);
        vscode.window.showInformationMessage(l10n('notify.setup.configUpdated', { tier }));
      } else {
        logReport(`- write_config FAILED: ${result.stderr || '(no details)'}`);
        flushReport(workspaceRoot);
        vscode.window.showErrorMessage(l10n('notify.setup.configWriteFailed', { details: result.stderr || l10n('notify.setup.checkOutput') }));
      }
    },
  );
  return ok;
}

/** Workspace-relative path must stay under the project root (no `..` segments). */
function isSafeCompositeScaffoldRelativePath(rel: string): boolean {
  if (!rel.trim()) return false;
  if (path.isAbsolute(rel)) return false;
  const segments = rel.replaceAll('\\', '/').split('/');
  return !segments.some((s) => s === '..');
}

/**
 * Runs `dart run saropa_lints:init --emit-composite-plugin-scaffold` in the
 * workspace so users can create a composite meta-plugin from the IDE.
 *
 * Shows a preflight notification (Continue / Open guide) so users understand
 * disk writes and can open documentation before choosing an output folder.
 */
export async function runEmitCompositePluginScaffold(): Promise<boolean> {
  const workspaceRoot = getProjectRoot();
  if (!workspaceRoot) {
    void vscode.window.showErrorMessage(l10n('notify.setup.noWorkspaceFolder'));
    return false;
  }

  const gate = await vscode.window.showInformationMessage(
    l10n('notify.setup.scaffoldGateTitle'),
    {
      detail: l10n('notify.setup.scaffoldGateDetail'),
    },
    l10n('notify.setup.actionContinue'),
    l10n('notify.setup.actionOpenGuide'),
  );
  if (gate === l10n('notify.setup.actionOpenGuide')) {
    await vscode.env.openExternal(vscode.Uri.parse(COMPOSITE_PLUGIN_SCAFFOLD_GUIDE_URL));
    return false;
  }
  if (gate !== l10n('notify.setup.actionContinue')) {
    return false;
  }

  const defaultRel = 'packages/composite_saropa_plugin';
  const rel = await vscode.window.showInputBox({
    title: 'Composite analyzer plugin folder',
    prompt:
      'Workspace-relative folder for the generated package (pubspec.yaml + lib/main.dart + README).',
    value: defaultRel,
    validateInput: (v) => {
      const t = v.trim();
      if (!t) return 'Enter a relative path.';
      if (!isSafeCompositeScaffoldRelativePath(t)) {
        return 'Use a workspace-relative path without .. segments (no absolute paths).';
      }
      return undefined;
    },
  });
  if (rel === undefined) return false;

  const trimmed = rel.trim();
  const outAbs = path.resolve(workspaceRoot, trimmed);
  const rootResolved = path.resolve(workspaceRoot);
  if (outAbs !== rootResolved && !outAbs.startsWith(rootResolved + path.sep)) {
    void vscode.window.showErrorMessage(l10n('notify.setup.scaffoldPathOutsideWorkspace'));
    return false;
  }

  if (fs.existsSync(outAbs)) {
    const pick = await vscode.window.showWarningMessage(
      l10n('notify.setup.scaffoldFolderExists', { folder: trimmed }),
      { modal: true },
      l10n('notify.setup.actionContinue'),
    );
    if (pick !== l10n('notify.setup.actionContinue')) return false;
  }

  let ok = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Creating composite analyzer plugin scaffold',
      cancellable: false,
    },
    async () => {
      logSection('Composite plugin scaffold');
      const args = [
        'run',
        'saropa_lints:init',
        '--emit-composite-plugin-scaffold',
        trimmed,
        '--target',
        workspaceRoot,
      ];
      const result = runInWorkspace(workspaceRoot, 'dart', args);
      ok = result.ok;
      if (ok) {
        logReport(`- Wrote scaffold under ${trimmed}`);
        flushReport(workspaceRoot);
        const action = await vscode.window.showInformationMessage(
          l10n('notify.setup.scaffoldCreated'),
          l10n('notify.setup.actionOpenMainDart'),
          l10n('notify.setup.actionOpenReadme'),
        );
        if (action === l10n('notify.setup.actionOpenMainDart')) {
          const mainPath = path.join(outAbs, 'lib', 'main.dart');
          if (fs.existsSync(mainPath)) {
            const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(mainPath));
            await vscode.window.showTextDocument(doc);
          }
        } else if (action === l10n('notify.setup.actionOpenReadme')) {
          const readmePath = path.join(outAbs, 'README.md');
          if (fs.existsSync(readmePath)) {
            const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(readmePath));
            await vscode.window.showTextDocument(doc);
          }
        }
      } else {
        logReport(`- scaffold FAILED: ${result.stderr || '(no details)'}`);
        flushReport(workspaceRoot);
        void vscode.window.showErrorMessage(
          l10n('notify.setup.scaffoldFailed', { details: result.stderr || l10n('notify.setup.scaffoldFailedHint') }),
        );
      }
    },
  );
  return ok;
}

export async function openConfig(): Promise<void> {
  // Multi-root: never default to `workspaceFolders[0]`; resolve via the
  // shared picker so the active editor's folder wins, with a fallback prompt
  // if there is genuine ambiguity. Previously this opened the wrong project's
  // analysis_options_custom.yaml whenever a sibling project (e.g.
  // saropa_drift_advisor) was first in the workspace folders list.
  const folder = await pickWorkspaceFolder({
    placeHolder: 'Choose the project whose analysis options to open',
  });
  if (!folder) return;
  const workspaceRoot = folder.uri.fsPath;
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
  { id: 'essential', label: 'Essential', rules: 297, desc: 'Security and must-fix errors only' },
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

/**
 * Run write_config + analysis for a tier change; returns true on success.
 *
 * Async and cancellable throughout. The original used the synchronous
 * `runInWorkspace`, which blocks the extension host event loop for the whole
 * child process — on a large project `write_config` writes a ~2000-rule block
 * and the Set Tier command froze the entire window until it finished, with a
 * non-cancellable notification showing one static title. That is the same
 * freeze-bug class already fixed in Enable and Create Baseline. A ticking
 * elapsed-time message cannot work before this conversion: `setInterval` never
 * fires while `spawnSync` holds the loop.
 */
async function applyTierChange(
  context: vscode.ExtensionContext,
  workspaceRoot: string,
  tiers: { next: string; previous: string },
  ui: { progress: vscode.Progress<{ message?: string }>; token: vscode.CancellationToken },
): Promise<boolean> {
  logSection('Set Tier');
  logReport(`- Changed tier: ${tiers.previous} → ${tiers.next}`);
  const writeResult = await withTickingProgress(
    ui.progress,
    (elapsed) => l10n('notify.setup.progressConfigWrite', { elapsed: String(elapsed) }),
    runInWorkspaceAsync(workspaceRoot, 'dart', buildWriteConfigArgs(workspaceRoot, tiers.next), { token: ui.token }),
  );
  if (writeResult.cancelled) {
    // Cancelling mid-write leaves analysis_options.yaml in whatever state the
    // killed child got to, so report failure rather than claim the tier moved.
    logReport('- Tier change cancelled by user (write_config)');
    flushReport(workspaceRoot);
    return false;
  }
  if (!writeResult.ok) {
    logReport(`- write_config FAILED: ${writeResult.stderr || '(no details)'}`);
    flushReport(workspaceRoot);
    vscode.window.showErrorMessage(l10n('notify.setup.configWriteFailed', { details: writeResult.stderr || l10n('notify.setup.checkOutput') }));
    return false;
  }
  logReport(`- Wrote config (tier: ${tiers.next})`);

  // C6: Re-analyze after tier change so violations.json reflects the new ruleset.
  // The config is already written at this point, so a cancelled analysis still
  // leaves the tier change itself valid — only the violations are stale.
  const { cancelled } = await withTickingProgress(
    ui.progress,
    (elapsed) => l10n('notify.setup.progressAnalysis', { elapsed: String(elapsed) }),
    runAnalysisAfterConfigChangeScoped(
      context,
      workspaceRoot,
      '- Analysis completed',
      '- Analysis reported issues',
      { token: ui.token },
    ),
  );
  if (cancelled) logReport('- Analysis cancelled by user; violations may be stale for the new tier');
  flushReport(workspaceRoot);
  return true;
}

/**
 * Show an enhanced tier picker and run write_config + analysis for the selected tier.
 * Returns the new and previous tier on success, or null on cancel/failure/same-tier.
 */
// One in-flight tier change at a time — same rationale as `_enableInFlight`
// and `_baselineInFlight`: it rewrites analysis_options.yaml and shells out to
// write_config, so two concurrent runs race on that file. Reaching the command
// twice is easy (the sidebar row, the command palette, and the status bar all
// route here), and before the flow was cancellable and ticking there was
// nothing on screen to say the first one was still working.
let _tierChangeInFlight: Promise<TierChangeResult | null> | undefined;

export async function runSetTier(context: vscode.ExtensionContext): Promise<TierChangeResult | null> {
  if (_tierChangeInFlight) return _tierChangeInFlight;
  const run = runSetTierExclusive(context).finally(() => {
    _tierChangeInFlight = undefined;
  });
  _tierChangeInFlight = run;
  return run;
}

async function runSetTierExclusive(context: vscode.ExtensionContext): Promise<TierChangeResult | null> {
  const workspaceRoot = getProjectRoot();
  if (!workspaceRoot) {
    vscode.window.showErrorMessage(l10n('notify.setup.noWorkspaceFolder'));
    return null;
  }
  // analysis_options.yaml is the source of truth for the current tier — only
  // fall back to the saropaLints.tier setting when the project has never been
  // initialized (no yaml tier configured yet), so the picker always reflects
  // what's actually on disk instead of a setting that can drift from it.
  const previousTier = readTierFromAnalysisOptionsYaml(workspaceRoot)
    ?? (vscode.workspace.getConfiguration('saropaLints').get<string>('tier') ?? 'recommended').trim();

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
    void vscode.window.showInformationMessage(l10n('notify.setup.alreadyOnTier', { tier: tierLabel(tier) }));
    return null;
  }

  await vscode.workspace.getConfiguration('saropaLints').update('tier', tier, vscode.ConfigurationTarget.Workspace);
  let ok = false;
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: `Updating tier to ${tierLabel(tier)}`,
      // Cancellable now that the work is off the event loop: write_config on a
      // large project takes long enough that a user with no Cancel button and a
      // static title reasonably concludes the window has hung.
      cancellable: true,
    },
    // Smart notification is shown by the handler in extension.ts after we return.
    async (progress, token) => {
      ok = await applyTierChange(context, workspaceRoot, { next: tier, previous: previousTier }, { progress, token });
    },
  );
  if (!ok) {
    // The setting was moved optimistically before the work started, so a
    // cancelled or failed write would otherwise leave `saropaLints.tier`
    // claiming a tier that analysis_options.yaml never received — the same
    // setting-contradicts-the-file drift the analyzer-plugin row exists to
    // eliminate. Put it back.
    await vscode.workspace.getConfiguration('saropaLints').update('tier', previousTier, vscode.ConfigurationTarget.Workspace);
  }
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
