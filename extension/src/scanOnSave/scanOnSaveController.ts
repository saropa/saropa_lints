/**
 * Wires `onDidSaveTextDocument` to `runScanOnSave` and publishes results as
 * VS Code diagnostics — the Lane 1 delivery mechanism from
 * plans/PLAN_scan_only_diagnostics.md (issues surfaced via squiggles +
 * Problems panel, ~5s after save, instead of the in-process analyzer plugin).
 *
 * Queue discipline is the load-bearing part: saving 5 files in a burst must
 * coalesce into ONE scan invocation, and two scans must never run
 * concurrently from the same project root. `dart run` scans contend on the
 * pub/build-snapshot lock when run concurrently from the same cwd and hang
 * each other — this is a fenced wrong path
 * (.claude/skills/saropa-lints-performance-campaign, "dashboards-hub hang").
 */
import * as vscode from 'vscode';
import * as path from 'node:path';
import { runScanOnSave, type ScanOnSaveDiagnostic, type ScanOnSaveResult } from './scanOnSaveRunner';
import { ScanDaemonManager } from './scanDaemonManager';
import { runBaselineScan } from './baselineScanRunner';
import { readTierFromAnalysisOptionsYaml } from '../config/tierConfig';
import { getEnabledSeverities, affectsSeveritySettings } from '../config/severityConfig';
import { l10n } from '../i18n/runtime';

/**
 * Resolves the tier to scan with — `analysis_options.yaml` is the source of
 * truth (see `readTierFromAnalysisOptionsYaml`); the `saropaLints.tier`
 * setting is only a fallback for a project that hasn't been initialized yet
 * (no yaml tier configured), so a picker default never silently overrides
 * what the project's own config file actually says.
 */
function resolveEffectiveTier(root: string): string {
  const fromYaml = readTierFromAnalysisOptionsYaml(root);
  if (fromYaml) return fromYaml;
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  return (cfg.get<string>('tier') ?? 'recommended').trim();
}

const DEBOUNCE_MS = 1500;

/**
 * Hard ceiling on how many OPEN-derived files one debounced batch may scan.
 *
 * It deliberately does NOT apply to saved files: a refactor across 30 files
 * followed by Save All is a legitimate user action, and dropping it would
 * leave the user with no diagnostics and nothing but an output-channel line
 * to explain why. Saves are always real user intent, so a save-derived batch
 * of any size scans.
 *
 * Open events are different: `onDidOpenTextDocument` can be driven by other
 * extensions on a timer. Above this count, an open-derived batch that somehow
 * survived {@link isDocumentUserOpen} is a bug signal. That is exactly what
 * happened in
 * `plans/history/2026.09/2026.09.05/infra_drift_poll_opens_every_dart_file_triggers_full_project_scan.md`:
 * the Drift Advisor poll called `workspace.openTextDocument()` on all 4,598
 * Dart files every 30 s, each open fired `onDidOpenTextDocument`, and the
 * controller launched a full-project *resolved* scan 33 times in 50 minutes.
 * Two `dart.exe` processes reached 22 GB and 13 GB of commit memory and
 * VS Code was killed by the low-memory condition.
 *
 * The visible-editor gate in {@link isDocumentUserOpen} is the real fix; this
 * cap is only the backstop behind it, so that no *future* regression in the
 * open-event path can ever again turn an event storm into a whole-project
 * scan. Whole-project scanning has a deliberate, user-triggered home: the
 * Lane 3 baseline scan command (`runBaselineScanCommand`), which chunks the
 * work and shows progress.
 *
 * Why 200 and not a tighter number: because Gate O runs FIRST, everything
 * that reaches this cap is a file the user genuinely has open in a tab or an
 * editor. Restoring a workspace with 30 or 50 Dart tabs is an ordinary
 * working session, and a cap of 20 would deny startup diagnostics to exactly
 * the users who keep the most files open. This is not a performance budget —
 * it is a backstop against an event storm, and the storm it was written for
 * was 4,598 files. Two hundred still catches that by more than an order of
 * magnitude while leaving every realistic human tab count alone. A 200-file
 * scan is one bounded `dart` invocation with an explicit file list, not a
 * whole-project resolve.
 *
 * A drop is still reported in the status bar, not only the log, so that on
 * the rare occasion the backstop does fire the user can see it happened.
 */
export const MAX_QUEUED_SCAN_FILES = 200;

/**
 * True when a queued batch is too large to be a real user action and must be
 * dropped rather than scanned. Exported so the backstop is unit-testable
 * without a live workspace.
 */
export function queuedBatchExceedsCap(fileCount: number): boolean {
  return fileCount > MAX_QUEUED_SCAN_FILES;
}

/**
 * Why a path is sitting in the pending queue.
 *
 * Provenance has to be carried through the debounce because the two origins
 * get different treatment at scan time: a `save` is proof of user intent and
 * is scanned unconditionally, while an `open` is not (see Gate O on
 * {@link isDocumentUserOpen}) and must be re-checked against the window's
 * editor/tab state once the debounce has elapsed.
 */
export type ScanQueueOrigin = 'save' | 'open';

/** How many file paths a scan log line prints before summarizing the rest. */
const LOG_FILE_SAMPLE_SIZE = 5;

/**
 * Renders a file batch for the output channel as a count plus a short sample.
 *
 * The previous implementation logged `files.join(', ')`. During the incident
 * above that produced a single 354 KB log line per scan and drove the
 * extension output logs to 10-20 MB, which is itself a memory and disk
 * problem and makes the log unreadable for the bug reporter. Sampling keeps
 * the line diagnostic (you can still see *which* files) and bounded.
 *
 * Developer diagnostic text only — deliberately NOT routed through `l10n()`
 * per `.claude/rules/i18n.md` (log strings are exempt).
 */
export function formatScanFileListForLog(files: readonly string[]): string {
  const sample = files.slice(0, LOG_FILE_SAMPLE_SIZE).join(', ');
  const remaining = files.length - LOG_FILE_SAMPLE_SIZE;
  // Only append the suffix when something was actually elided, so the common
  // one-file save reads as a plain path with no noise after it.
  return remaining > 0 ? `${sample} and ${remaining} more` : sample;
}

/**
 * True when [fsPath] is a document the USER has open, as opposed to one some
 * extension opened programmatically via `workspace.openTextDocument()`.
 *
 * `onDidOpenTextDocument` fires for BOTH cases and cannot tell them apart —
 * that conflation is the root of the crash documented on
 * {@link MAX_QUEUED_SCAN_FILES}. A programmatically opened document has no
 * editor and no tab, so intersecting against the window's own state is what
 * separates them.
 *
 * Both inputs matter and neither alone is sufficient:
 * - [openTabPaths] (from `window.tabGroups`) is the load-bearing one: it
 *   includes background tabs, so a file the user has open but is not
 *   currently looking at still gets scanned, as it did before this fix.
 * - [visibleEditorPaths] (from `window.visibleTextEditors`) covers editors
 *   that exist without a normal tab entry, so nothing the user can actually
 *   see is dropped.
 *
 * Pure and exported so the gate is unit-testable without a live workspace.
 */
export function isDocumentUserOpen(
  fsPath: string,
  visibleEditorPaths: readonly string[],
  openTabPaths: readonly string[],
): boolean {
  return visibleEditorPaths.includes(fsPath) || openTabPaths.includes(fsPath);
}

/**
 * fsPaths of every text editor the window is currently showing.
 *
 * Defensive `?? []`: the API is always present in a real host, but a test
 * double (or a future proposed-API shuffle) may not define it, and a missing
 * property must degrade to "nothing is visible" rather than throw inside an
 * event handler where the exception would be swallowed.
 */
function currentVisibleEditorPaths(): string[] {
  return (vscode.window.visibleTextEditors ?? []).map((e) => e.document.uri.fsPath);
}

/**
 * Every property name on a `Tab.input` union member that carries a `Uri`.
 *
 * `tab.input` is a union and only ONE of its members (`TabInputText`,
 * `TabInputNotebook`, `TabInputCustom`) exposes a plain `uri`. The comparison
 * shapes hide their URIs behind other names:
 *  - `TabInputTextDiff` / `TabInputNotebookDiff`: `original` + `modified`
 *  - `TabInputTextMerge`: `base` + `input1` + `input2` + `result`
 * Reading only `uri` therefore reported a Dart file that is open as the
 * modified side of a diff as "not open", so Gate O dropped it and the user
 * silently lost that file's diagnostics.
 */
const TAB_INPUT_URI_KEYS = [
  'uri',
  'original',
  'modified',
  'base',
  'input1',
  'input2',
  'result',
] as const;

/**
 * Collects every fsPath a single tab input exposes.
 *
 * Duck-typed on purpose rather than `instanceof`-checked against the
 * `TabInput*` classes: this runs inside an event handler where a throw would
 * be swallowed, and VS Code adds union members over time. Anything that is not
 * an object, or whose named property is not a `Uri`-shaped value with a string
 * `fsPath`, contributes nothing instead of failing — so a future member the
 * table does not know about degrades to "this tab holds no files", which is
 * the same conservative answer the old code gave for every non-`uri` shape.
 *
 * Pure and exported so the diff and merge shapes are unit-testable without a
 * live window.
 */
export function tabInputUriPaths(input: unknown): string[] {
  if (input === null || typeof input !== 'object') return [];
  const record = input as Record<string, unknown>;
  const paths: string[] = [];
  for (const key of TAB_INPUT_URI_KEYS) {
    // Optional chaining covers a property that is absent, null, or a
    // primitive; the typeof check covers one that exists but is not a Uri.
    const fsPath = (record[key] as { fsPath?: unknown } | undefined)?.fsPath;
    if (typeof fsPath === 'string' && fsPath.length > 0) paths.push(fsPath);
  }
  return paths;
}

/**
 * fsPaths of every tab open in every tab group, including background tabs the
 * user is not currently looking at — those must still be scanned.
 *
 * Flattens {@link tabInputUriPaths} over every tab, so a file counts as open
 * whether it is a normal editor tab or one side of a diff or merge view. The
 * `?? []` on `tabGroups` keeps a test double (or a proposed-API shuffle) that
 * lacks the API from throwing inside the save handler.
 */
function currentOpenTabPaths(): string[] {
  const groups = vscode.window.tabGroups?.all ?? [];
  const paths: string[] = [];
  for (const group of groups) {
    for (const tab of group.tabs) {
      paths.push(...tabInputUriPaths(tab.input));
    }
  }
  return paths;
}

const SEVERITY_MAP: Record<string, vscode.DiagnosticSeverity> = {
  ERROR: vscode.DiagnosticSeverity.Error,
  WARNING: vscode.DiagnosticSeverity.Warning,
  INFO: vscode.DiagnosticSeverity.Information,
};

/**
 * Scan-on-save is the delivery path for `saropaLints.enabled` — there is no
 * separate toggle for it. A prior revision gated it behind its own
 * `scanOnSave.enabled` setting (default off); that setting was unreachable
 * for anyone who hadn't read the changelog, so turning the extension "on"
 * via the master switch silently did nothing. Deleted in favor of this
 * single switch.
 *
 * Pure and exported so the gate is unit-testable without a live workspace.
 */
export function scanOnSaveIsEnabled(masterEnabled: boolean): boolean {
  return masterEnabled;
}

/** Maps one scan diagnostic onto a `vscode.Diagnostic` for its source line. */
export function toVscodeDiagnostic(d: ScanOnSaveDiagnostic): vscode.Diagnostic {
  // Scan CLI lines/columns are 1-based; VS Code Positions are 0-based. Column
  // can be absent/0 for file-level findings — clamp to a valid non-negative.
  const line = Math.max(0, d.line - 1);
  const column = Math.max(0, (d.column || 1) - 1);
  // Use the full diagnostic span so clicking the problem highlights the
  // offending declaration, not a single character (which triggers VS Code's
  // "highlight all occurrences" and selects every matching letter in the file).
  // When endLine/endColumn are absent (legacy scan output) OR produce a
  // zero-width range (some rules report at a point, not a span), fall back to
  // highlighting to end-of-line so the diagnostic is always visible.
  let endLine = d.endLine != null ? Math.max(0, d.endLine - 1) : line;
  let endColumn = d.endColumn != null ? Math.max(0, d.endColumn - 1) : column + 1;
  // Guard: zero-width ranges are invisible in VS Code — extend to end-of-line.
  if (endLine === line && endColumn <= column) {
    endColumn = Number.MAX_SAFE_INTEGER;
  }
  const range = new vscode.Range(line, column, endLine, endColumn);
  const severity = SEVERITY_MAP[d.severity.toUpperCase()] ?? vscode.DiagnosticSeverity.Information;
  const message = d.correctionMessage
    ? `${d.problemMessage ?? d.ruleName}\n${d.correctionMessage}`
    : d.problemMessage ?? d.ruleName;
  const diagnostic = new vscode.Diagnostic(range, message, severity);
  diagnostic.source = 'saropa_lints';
  diagnostic.code = d.ruleName;
  return diagnostic;
}

/** Groups scan diagnostics by absolute file path for per-file `DiagnosticCollection.set`. */
export function groupDiagnosticsByFile(
  diagnostics: readonly ScanOnSaveDiagnostic[],
): Map<string, ScanOnSaveDiagnostic[]> {
  const byFile = new Map<string, ScanOnSaveDiagnostic[]>();
  for (const d of diagnostics) {
    const list = byFile.get(d.filePath);
    if (list) {
      list.push(d);
    } else {
      byFile.set(d.filePath, [d]);
    }
  }
  return byFile;
}

/**
 * Shed level at or above which the scan daemon is suspended. At level 2+
 * most rules are shed (expensive + INFO severity), so the daemon's warm
 * AnalysisContextCollection costs more memory than the few remaining
 * rules justify. The daemon auto-resumes when pressure drops below this.
 */
const DAEMON_SUSPEND_SHED_LEVEL = 2;

export class ScanOnSaveController implements vscode.Disposable {
  private readonly _disposables: vscode.Disposable[] = [];
  private readonly _statusBarItem: vscode.StatusBarItem;
  /**
   * Absolute file paths queued since the last scan started, mapped to why they
   * were queued. A Map rather than a Set because the visibility filter is
   * applied at scan time, not queue time, and by then the origin is the only
   * way to tell a user's Save All from another extension's open storm.
   */
  private _pendingFiles = new Map<string, ScanQueueOrigin>();
  private _debounceTimer: NodeJS.Timeout | undefined;
  private _scanInFlight = false;
  /** Files the in-flight scan is covering — used to decide whether a newly
   *  queued batch makes that scan redundant (see _supersedeStaleScan). */
  private _inFlightFiles: readonly string[] = [];
  /** Cancels the in-flight scan's child process. One source per scan; cancelled
   *  when the scan is superseded by a newer batch, and on dispose so a shutdown
   *  never leaves an orphaned `dart` process holding resolved-analysis memory. */
  private _scanCancelSource: vscode.CancellationTokenSource | undefined;
  /** Set when saves arrive while a scan is already running — triggers one more pass after it finishes. */
  private _rescanQueued = false;
  private readonly _daemonManager = new ScanDaemonManager();
  /** True while a Lane 3 baseline scan is running — guards against a second concurrent invocation. */
  private _baselineScanInFlight = false;
  /** Last raw scan results per file — retained so severity toggles can
   *  re-filter without rescanning (no _pendingFiles to trigger a rescan). */
  private _lastDiagnosticsByFile = new Map<string, ScanOnSaveDiagnostic[]>();
  /** True when the daemon has been suspended due to heavy memory pressure. */
  private _daemonSuspended = false;
  /**
   * Files dropped by the over-cap backstop that the user has not been told about yet.
   *
   * Needed because `_dropOversizedOpenBatch` and `_beginScan` write to the same status bar item:
   * when one queued batch contained both an over-cap open storm and a saved file, the "scan
   * skipped" text was overwritten by "scanning ..." microseconds later and the drop became
   * invisible. Carrying the count forward lets the post-scan status line report it instead.
   */
  private _droppedFileCount = 0;

  /** Public read access for the debug panel to display daemon suspension state. */
  get isDaemonSuspended(): boolean {
    return this._daemonSuspended;
  }

  /** Manually suspend the scan daemon — kills the process and prevents
   *  respawning on save. Used by the debug panel toggle. */
  suspendDaemon(): void {
    if (this._daemonSuspended) return;
    this._daemonSuspended = true;
    this._daemonManager.dispose();
    console.log('saropa_lints: scan daemon suspended via debug panel');
  }

  /** Manually resume the scan daemon — lifts the suspension so the next
   *  save triggers a respawn. Used by the debug panel toggle. */
  resumeDaemon(): void {
    if (!this._daemonSuspended) return;
    this._daemonSuspended = false;
    console.log('saropa_lints: scan daemon resumed via debug panel');
  }

  /**
   * Dumps the full pipeline state to the output channel and reveals it.
   * Wired to the status bar item click — one-click "why is nothing happening?"
   * diagnostic for users and bug reporters.
   */
  diagnose(): void {
    const ch = this._outputChannel;
    if (!ch) return;
    ch.appendLine('');
    ch.appendLine('=== Scan-on-save pipeline diagnosis ===');
    ch.appendLine(`  enabled:          ${this._isEnabled()}`);
    const root = this._getProjectRoot();
    ch.appendLine(`  project root:     ${root ?? '(none — no pubspec.yaml found)'}`);
    // Daemon state: not spawned → warming → alive → backoff (after crash).
    const daemonState = this._daemonSuspended
      ? 'suspended (memory pressure)'
      : this._daemonManager.isInBackoff
        ? 'backoff (crashed recently, waiting to respawn)'
        : this._daemonManager.isWarming
          ? 'warming up (first scan in progress)'
          : this._daemonManager.isAlive
            ? 'alive'
            : 'not spawned (starts on first Dart save)';
    ch.appendLine(`  daemon:           ${daemonState}`);
    ch.appendLine(`  scan in flight:   ${this._scanInFlight}`);
    ch.appendLine(`  rescan queued:    ${this._rescanQueued}`);
    ch.appendLine(`  pending files:    ${this._pendingFiles.size}`);
    ch.appendLine(`  cached results:   ${this._lastDiagnosticsByFile.size} file(s)`);
    // Severity filter state — shows which severities are turned off.
    const enabled = getEnabledSeverities();
    const severityNames = ['Error', 'Warning', 'Information', 'Hint'];
    const severityState = severityNames
      .map((name, i) => `${name}=${enabled.has(i) ? 'on' : 'OFF'}`)
      .join(', ');
    ch.appendLine(`  severity filters: ${severityState}`);
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    ch.appendLine(`  tier:             ${cfg.get<string>('tier', 'recommended')}`);
    ch.appendLine(`  resolveTypes:     ${cfg.get<boolean>('scanOnSave.resolveTypes', true)}`);
    ch.appendLine(`  baseline running: ${this._baselineScanInFlight}`);
    ch.appendLine('=======================================');
    ch.show(true);
  }

  /**
   * Clears all scan-on-save diagnostics and rescans open editors.
   * Call after "Restart Analysis Server" or any event that invalidates
   * the in-process plugin's diagnostics, so the scan-on-save channel
   * (which is independent of the analysis server) stays in sync.
   */
  clearAndRescan(): void {
    this._collection.clear();
    this._lastDiagnosticsByFile.clear();
    this._log('clearAndRescan: diagnostics cleared, rescanning open editors');
    this._scanOpenEditors();
  }

  constructor(
    private readonly _collection: vscode.DiagnosticCollection,
    private readonly _getProjectRoot: () => string | undefined,
    private readonly _outputChannel?: vscode.OutputChannel,
  ) {
    this._statusBarItem = vscode.window.createStatusBarItem(
      'saropaLints.scanOnSave',
      vscode.StatusBarAlignment.Right,
      99,
    );
    this._statusBarItem.name = l10n('scanOnSave.statusBar.name');
    // Click → dump full pipeline state to the output channel and reveal it.
    this._statusBarItem.command = 'saropaLints.scanOnSave.diagnose';
    this._disposables.push(this._statusBarItem);

    // Show initial state immediately so the user never stares at silence.
    // A missing project root or disabled state is visible from the first tick.
    this._showInitialState();

    this._disposables.push(
      vscode.workspace.onDidSaveTextDocument((doc) => this._onSave(doc)),
    );
    // Scan Dart files when opened — diagnostics should appear without
    // requiring a save. Uses the same debounce+queue as save events.
    this._disposables.push(
      vscode.workspace.onDidOpenTextDocument((doc) => this._queueIfDart(doc)),
    );
    // Scan all currently open Dart editors on activation so diagnostics
    // are visible immediately — not just after the first save or open.
    this._scanOpenEditors();
    // A tier or resolveTypes settings change invalidates the running daemon
    // (it was spawned with the old tier); drop it so the next save respawns
    // with current config. `saropaLints.enabled` is watched too because it
    // gates this feature (see _isEnabled): turning the extension off must
    // not leave a multi-GB daemon resident, and must not leave its squiggles
    // on screen after the user believes they disabled the linter.
    this._disposables.push(
      vscode.workspace.onDidChangeConfiguration((e) => {
        if (
          e.affectsConfiguration('saropaLints.enabled') ||
          e.affectsConfiguration('saropaLints.tier') ||
          e.affectsConfiguration('saropaLints.scanOnSave.resolveTypes')
        ) {
          this._daemonManager.restart();
          // Stale diagnostics outlive the daemon otherwise — the collection
          // is only rewritten on the next scan, which never comes once the
          // feature is off. Clearing unconditionally is safe: an enabled
          // feature repopulates on the next save.
          if (!this._isEnabled()) {
            this._collection.clear();
            // Clear the raw-diagnostic cache so a future severity toggle
            // doesn't re-publish stale data from before the feature was off.
            this._lastDiagnosticsByFile.clear();
          }
          // Refresh state whether enabling or disabling — _showInitialState
          // handles both (disabled text vs. ready/noProject).
          this._showInitialState();
        }
        // When a severity toggle changes, re-filter the existing
        // diagnostics in-place. A clear+rescan approach fails because
        // _pendingFiles is empty (no save happened), so _runQueuedScan
        // no-ops and the Problems panel goes blank.
        if (affectsSeveritySettings(e) && this._isEnabled()) {
          this._refilterDiagnostics();
        }
      }),
    );
  }

  /**
   * Called when the memory-pressure state changes. Suspends the daemon when
   * shedding is heavy (level 2+: most rules shed) to reclaim the ~1 GB
   * AnalysisContextCollection it holds. Resumes when pressure drops.
   */
  onMemoryPressureChange(shedLevel: number): void {
    const shouldSuspend = shedLevel >= DAEMON_SUSPEND_SHED_LEVEL;
    if (shouldSuspend && !this._daemonSuspended) {
      // Kill the daemon — its warm analyzer state is the dominant cost
      // and the few remaining rules don't justify it.
      this._daemonSuspended = true;
      this._daemonManager.dispose();
      console.log(`saropa_lints: scan daemon suspended (shed level ${shedLevel})`);
    } else if (!shouldSuspend && this._daemonSuspended) {
      // Pressure dropped — let the next save respawn the daemon.
      this._daemonSuspended = false;
      console.log('saropa_lints: scan daemon suspension lifted');
    }
  }

  /** Reads the master toggle from config and applies {@link scanOnSaveIsEnabled}. */
  private _isEnabled(): boolean {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    return scanOnSaveIsEnabled(cfg.get<boolean>('enabled', true) ?? true);
  }

  /** Logs to the Saropa Lints output channel so silent failures are diagnosable. */
  private _log(message: string): void {
    this._outputChannel?.appendLine(`[scan-on-save] ${message}`);
  }

  /**
   * Sets the status bar to the correct initial state on activation, so the
   * user sees feedback before any save event fires. Without this, a broken
   * pipeline (no project root, disabled) produces absolute silence — the
   * extension looks dead.
   */
  private _showInitialState(): void {
    if (!this._isEnabled()) {
      this._statusBarItem.text = l10n('scanOnSave.statusBar.disabled');
      this._statusBarItem.tooltip = l10n('scanOnSave.statusBar.disabled');
      this._statusBarItem.show();
      this._log('disabled via saropaLints.enabled setting');
      return;
    }
    const root = this._getProjectRoot();
    if (!root) {
      this._statusBarItem.text = l10n('scanOnSave.statusBar.noProject');
      this._statusBarItem.tooltip = l10n('scanOnSave.statusBar.noProject');
      this._statusBarItem.show();
      this._log('no Dart project root found (no pubspec.yaml at workspace root or one level deep)');
      return;
    }
    // Everything looks viable — show "ready" and wait for saves.
    this._statusBarItem.text = l10n('scanOnSave.statusBar.ready');
    this._statusBarItem.tooltip = l10n('scanOnSave.statusBar.ready');
    this._statusBarItem.show();
    this._log(`ready — project root: ${root}`);
  }

  /**
   * Queues a Dart file that was opened, so diagnostics appear without needing
   * a save. Wired to `onDidOpenTextDocument`.
   *
   * Queuing here is deliberately OPTIMISTIC — only the language and
   * project-root gates apply. The "is this really the user's file?" question
   * (Gate O) is answered later, in {@link _runQueuedScan}, for two reasons:
   *
   * 1. `onDidOpenTextDocument` fires when the document loads, which for a
   *    user-initiated open can be BEFORE the tab is registered in
   *    `window.tabGroups`. Checking here would race that registration and
   *    could silently deny diagnostics to a file the user really did open.
   *    Deferring past the debounce makes the ordering irrelevant.
   * 2. The check is only meaningful at the moment the scan is about to spawn
   *    a process; a document opened and closed inside the debounce window
   *    should not be scanned at all, and the deferred check gets that right
   *    for free.
   *
   * The gate itself is not optional: `onDidOpenTextDocument` also fires for
   * every `workspace.openTextDocument()` call made by ANY extension. The Drift
   * Advisor integration opened all 4,598 workspace Dart files on a 30-second
   * timer, which became 33 full-project resolved scans and crashed VS Code —
   * see `plans/history/2026.09/2026.09.05/infra_drift_poll_opens_every_dart_file_triggers_full_project_scan.md`.
   */
  private _queueIfDart(doc: vscode.TextDocument): void {
    if (doc.languageId !== 'dart') return;
    if (!this._isEnabled()) return;
    const root = this._getProjectRoot();
    if (!root) return;
    const relative = path.relative(root, doc.uri.fsPath);
    if (relative.startsWith('..') || path.isAbsolute(relative)) return;

    this._enqueue(doc.uri.fsPath, 'open');
    if (this._debounceTimer) clearTimeout(this._debounceTimer);
    this._debounceTimer = setTimeout(() => this._runQueuedScan(root), DEBOUNCE_MS);
  }

  /**
   * Adds a path to the pending queue, keeping the STRONGER provenance when the
   * same file arrives twice. A save must never be downgraded to an open: a
   * file saved and then re-opened by some background tool would otherwise lose
   * its guaranteed scan and be subjected to the visibility filter.
   */
  private _enqueue(fsPath: string, origin: ScanQueueOrigin): void {
    if (origin === 'open' && this._pendingFiles.get(fsPath) === 'save') return;
    this._pendingFiles.set(fsPath, origin);
  }

  /**
   * Scans all Dart files currently open in the editor on activation.
   * Without this, the extension shows zero diagnostics until the user
   * saves or opens a new file — making it look dead on startup.
   */
  private _scanOpenEditors(): void {
    if (!this._isEnabled()) return;
    const root = this._getProjectRoot();
    if (!root) return;
    // `workspace.textDocuments` is NOT "the files the user has open" — it is
    // every document any extension currently holds open, including the ones
    // opened programmatically that caused the full-project-scan crash. These
    // are therefore queued with 'open' provenance and filtered through Gate O
    // in _runQueuedScan, after the debounce has let the window's tab state
    // settle. The document list is still the iteration source because it is
    // the only place `languageId` is available; tabs carry a URI, no language.
    let queued = 0;
    for (const doc of vscode.workspace.textDocuments) {
      if (doc.languageId !== 'dart') continue;
      const relative = path.relative(root, doc.uri.fsPath);
      if (relative.startsWith('..') || path.isAbsolute(relative)) continue;
      this._enqueue(doc.uri.fsPath, 'open');
      queued++;
    }
    if (queued > 0) {
      this._log(`activation: queued ${queued} open Dart file(s) for initial scan`);
      // Longer debounce for the initial batch — VS Code fires
      // onDidOpenTextDocument for each already-open file during activation,
      // so the debounce timer will keep resetting. This explicit queue
      // ensures a single coalesced scan after all open files are collected.
      if (this._debounceTimer) clearTimeout(this._debounceTimer);
      this._debounceTimer = setTimeout(() => this._runQueuedScan(root), DEBOUNCE_MS);
    }
  }

  private _onSave(doc: vscode.TextDocument): void {
    // Check language FIRST — non-Dart saves should exit silently without
    // hitting the config read or writing to the output channel. Logging
    // every JSON/MD/etc. save when disabled is pure spam.
    if (doc.languageId !== 'dart') return;
    if (!this._isEnabled()) {
      // Gate C: master toggle is off — log so the output channel reveals
      // why a Dart save produced nothing.
      this._log(`skipped ${doc.uri.fsPath}: saropaLints.enabled is false`);
      return;
    }
    const root = this._getProjectRoot();
    if (!root) {
      // Gate E: no pubspec.yaml found — the most common silent killer.
      this._log(`skipped ${doc.uri.fsPath}: no Dart project root found`);
      this._statusBarItem.text = l10n('scanOnSave.statusBar.noProject');
      this._statusBarItem.show();
      return;
    }
    // Only queue files under the resolved Dart project root — a save in an
    // unrelated open file (e.g. a sibling non-Dart workspace folder) must
    // not trigger or pollute this project's scan.
    const relative = path.relative(root, doc.uri.fsPath);
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
      // Gate F: file is outside the project boundary.
      this._log(`skipped ${doc.uri.fsPath}: outside project root ${root}`);
      return;
    }

    // 'save' provenance — a save is unconditional proof of user intent, so
    // this path bypasses both the visibility filter and the batch cap.
    this._enqueue(doc.uri.fsPath, 'save');
    if (this._debounceTimer) clearTimeout(this._debounceTimer);
    this._debounceTimer = setTimeout(() => this._runQueuedScan(root), DEBOUNCE_MS);
  }

  private _runQueuedScan(root: string): void {
    this._debounceTimer = undefined;
    if (this._scanInFlight) {
      // A scan is already running; another save arrived after it started.
      // Don't spawn a second concurrent scan (contends on dart's build lock
      // and hangs) — flag one more pass for when the current scan finishes.
      this._rescanQueued = true;
      this._supersedeStaleScan();
      return;
    }
    const queued = [...this._pendingFiles.entries()];
    this._pendingFiles.clear();
    if (queued.length === 0) return;
    const files = this._selectFilesToScan(queued);
    if (files.length === 0) {
      // Nothing follows to overwrite the status bar, so the drop notice written by
      // `_dropOversizedOpenBatch` is already standing on its own. Clear the carry-forward count
      // so a later, unrelated scan does not re-announce a drop the user has already seen.
      this._droppedFileCount = 0;
      return;
    }
    void this._scan(root, files);
  }

  /**
   * Decides which of the debounced queue entries actually get scanned.
   *
   * Saves pass through untouched — a Save All across 30 files is a real user
   * action and must produce diagnostics for all 30. Open-derived paths run the
   * Gate O gauntlet HERE rather than at queue time, because the tab state is
   * only reliably settled after the debounce (see _queueIfDart), and then the
   * survivors face the {@link MAX_QUEUED_SCAN_FILES} backstop.
   */
  private _selectFilesToScan(queued: readonly [string, ScanQueueOrigin][]): string[] {
    const saved = queued.filter(([, origin]) => origin === 'save').map(([f]) => f);
    const opened = queued.filter(([, origin]) => origin === 'open').map(([f]) => f);
    // Snapshot the window state once: the gate must judge every file in this
    // batch against the same instant, and a second pass would re-read state
    // that can change mid-loop.
    const visible = currentVisibleEditorPaths();
    const tabs = currentOpenTabPaths();
    const userOpened: string[] = [];
    const programmatic: string[] = [];
    for (const file of opened) {
      (isDocumentUserOpen(file, visible, tabs) ? userOpened : programmatic).push(file);
    }
    if (programmatic.length > 0) {
      // One sampled line for the whole batch, never one line per file: the
      // old per-file logging is what produced multi-megabyte output logs.
      this._log(
        `skipped ${programmatic.length} file(s) opened programmatically (no editor, no tab): ` +
          formatScanFileListForLog(programmatic),
      );
    }
    // Cap applies to the open-derived survivors only. Saves are exempt by
    // design — see the doc comment on MAX_QUEUED_SCAN_FILES.
    const accepted = queuedBatchExceedsCap(userOpened.length)
      ? this._dropOversizedOpenBatch(userOpened)
      : userOpened;
    // Dedupe: a file can appear in both lists only if provenance was upgraded,
    // which _enqueue prevents, but the Set keeps the contract explicit.
    return [...new Set([...saved, ...accepted])];
  }

  /**
   * Drops an over-cap open-derived batch and makes the drop VISIBLE.
   *
   * Dropping rather than truncating is deliberate: a batch this large was
   * filled by something other than a person, so no subset of it is worth
   * spawning a `dart` process for. The status bar update is not optional —
   * an action that silently produces nothing violates the project rule that
   * every outcome must be visible, and the output channel alone is not a
   * surface any user watches.
   */
  private _dropOversizedOpenBatch(files: readonly string[]): string[] {
    this._log(
      `ABORTED batch of ${files.length} opened file(s) — over the ${MAX_QUEUED_SCAN_FILES}-file cap, ` +
        `so this is an event storm, not a user action. Dropped without scanning. ` +
        `Sample: ${formatScanFileListForLog(files)}`,
    );
    const count = String(files.length);
    // Written unconditionally so the drop is visible when NO scan follows. When one does, this
    // text is immediately overwritten by `_beginScan`; the carry-forward count below is what
    // makes the drop survive that, via `_appendDropNotice` on the post-scan line.
    this._droppedFileCount += files.length;
    this._statusBarItem.text = l10n('scanOnSave.statusBar.dropped', { count });
    this._statusBarItem.tooltip = l10n('scanOnSave.statusBar.droppedTooltip', { count });
    this._statusBarItem.show();
    return [];
  }

  /**
   * Folds a pending drop notice into whatever the finished scan just reported.
   *
   * Chosen over a timed toast or a delayed status flip because it rides the existing status bar
   * lifecycle exactly: the status bar already ends every scan with a single terminal line, so
   * appending there needs no new timer, cannot be clobbered by the next `_beginScan`, and keeps
   * the "every asynchronous action emits a visible outcome" rule satisfied for both outcomes of
   * one queued batch. Cleared after appending so the drop is announced once and only once.
   */
  private _appendDropNotice(): void {
    if (this._droppedFileCount === 0) return;
    const count = String(this._droppedFileCount);
    this._droppedFileCount = 0;
    this._statusBarItem.text += l10n('scanOnSave.statusBar.droppedSuffix', { count });
    const tooltip = this._statusBarItem.tooltip;
    // Only a plain-string tooltip can be extended safely; every writer in this class sets one.
    const base = typeof tooltip === 'string' ? `${tooltip}\n` : '';
    this._statusBarItem.tooltip = base + l10n('scanOnSave.statusBar.droppedSuffixTooltip', { count });
  }

  /**
   * Cancels the in-flight scan when a newly queued batch already covers every
   * file it is scanning.
   *
   * In that case the running scan can only produce results the follow-up pass
   * is about to overwrite — and it produces them from the file contents as
   * they were BEFORE the newest save, so waiting for it delays correct
   * diagnostics behind stale ones. Cancelling frees the `dart` child
   * immediately; the in-flight scan's own `finally` then starts the queued
   * rescan, so no run is lost. A batch that only partially overlaps is left
   * alone — those extra files would otherwise never get their diagnostics.
   */
  private _supersedeStaleScan(): void {
    if (this._inFlightFiles.length === 0) return;
    const pending = this._pendingFiles;
    if (!this._inFlightFiles.every((f) => pending.has(f))) return;
    this._log(`superseding in-flight scan of ${this._inFlightFiles.length} file(s): newer batch covers them all`);
    this._scanCancelSource?.cancel();
  }

  /**
   * Marks a scan as started and hands back the token that kills its child
   * process. Split out of `_scan` to keep that method inside the 50-line
   * limit; it owns every piece of per-scan state that `_endScan` must undo.
   */
  private _beginScan(files: string[]): vscode.CancellationToken {
    this._scanInFlight = true;
    this._inFlightFiles = files;
    // Fresh source per scan — a cancelled token stays cancelled forever, so
    // reusing one would make every later scan abort instantly.
    this._scanCancelSource?.dispose();
    this._scanCancelSource = new vscode.CancellationTokenSource();
    // Count first, then a bounded sample. Joining the whole list produced a
    // 354 KB single log line during the event-storm incident and pushed the
    // extension output logs to 10-20 MB.
    this._log(`scanning ${files.length} file(s): ${formatScanFileListForLog(files)}`);
    const scanning = l10n('scanOnSave.statusBar.scanning', { count: String(files.length) });
    this._statusBarItem.text = scanning;
    this._statusBarItem.tooltip = scanning;
    this._statusBarItem.show();
    return this._scanCancelSource.token;
  }

  /**
   * Clears every piece of per-scan state. MUST run on all exit paths — a
   * leaked `_scanInFlight` silently kills scan-on-save for the rest of the
   * session, and a leaked token source leaves a `dart` child unkillable.
   */
  private _endScan(): void {
    this._scanInFlight = false;
    this._inFlightFiles = [];
    this._scanCancelSource?.dispose();
    this._scanCancelSource = undefined;
  }

  /** Surfaces a failed run in the log, the status bar, and a toast. */
  private _reportScanFailure(result: ScanOnSaveResult): void {
    // Log the full error so it's visible in the output channel even
    // after the transient warning toast auto-dismisses.
    this._log(`scan FAILED (exit ${result.exitCode}): ${result.errorMessage}`);
    this._statusBarItem.text = l10n('scanOnSave.statusBar.failed');
    this._statusBarItem.tooltip = result.errorMessage;
    // A failed scan is still the end of the batch, so a drop queued alongside it must be
    // reported here too — otherwise the failure text would bury it exactly as `_beginScan` did.
    this._appendDropNotice();
    void vscode.window.showWarningMessage(
      l10n('notify.commands.scanOnSaveFailedDetails', { details: result.errorMessage ?? '' }),
    );
  }

  /**
   * Publishes a completed scan's findings and reports it in the log and the
   * status bar. The `scan complete` log line is the counterpart every
   * `scanning ...` line must eventually get — its absence is how the hung-scan
   * bug was spotted (57 starts, 1 completion), so it stays a single line
   * emitted from exactly one place.
   */
  private _reportScanSuccess(
    files: string[],
    diagnostics: readonly ScanOnSaveDiagnostic[],
    startMs: number,
  ): void {
    const publishedCount = this._applyDiagnostics(files, diagnostics);
    const elapsedS = ((Date.now() - startMs) / 1000).toFixed(1);
    this._log(`scan complete: ${diagnostics.length} raw finding(s), ${publishedCount} published after severity filter, ${elapsedS}s`);
    this._statusBarItem.text = l10n('scanOnSave.statusBar.done', {
      count: String(publishedCount),
      elapsed: elapsedS,
    });
    this._statusBarItem.tooltip = l10n('scanOnSave.statusBar.doneTooltip', {
      total: String(diagnostics.length),
      shown: String(publishedCount),
    });
    // The same queued batch may have dropped an over-cap open storm before this scan ran; that
    // notice was overwritten by `_beginScan`, so re-surface it on this terminal line.
    this._appendDropNotice();
  }

  private async _scan(root: string, files: string[]): Promise<void> {
    const cancelToken = this._beginScan(files);
    const start = Date.now();
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const tier = resolveEffectiveTier(root);
    const resolveTypes = cfg.get<boolean>('scanOnSave.resolveTypes', true) ?? true;

    try {
      // Resolved scans go through the persistent daemon — spawn-per-save
      // `scan --resolve` pays a fixed ~80s warmup per invocation. The
      // syntactic path stays spawn-per-save (fast, no warm state to keep).
      // When the daemon is suspended due to memory pressure, fall back to
      // the lightweight syntactic scan — better partial coverage than a
      // multi-GB daemon holding memory while most rules are shed anyway.
      const useDaemon = resolveTypes && !this._daemonSuspended;
      this._log(`tier=${tier}, resolveTypes=${resolveTypes}, useDaemon=${useDaemon}, daemonSuspended=${this._daemonSuspended}`);
      const result = useDaemon
        ? await this._scanViaDaemon(root, files, tier)
        // The token reaches the spawn path only: the daemon path multiplexes
        // one long-lived process and has its own request timeout, so killing
        // it on cancellation would tear down the warm state every other
        // queued file still needs.
        : await runScanOnSave(root, files, tier, false, cancelToken);
      if (result.errorMessage) {
        // Early return — the `finally` below still runs, so the in-flight
        // state is released on this path too (a failure that leaked it would
        // be the same permanent-death bug as a hung child).
        this._reportScanFailure(result);
        return;
      }
      this._reportScanSuccess(files, result.payload?.diagnostics ?? [], start);
    } finally {
      // Reached on every exit path, including the early `return` in the
      // errorMessage branch above and any thrown exception — `_scanInFlight`
      // must never be left true, or the feature is silently dead for the rest
      // of the session and every later save is swallowed by the guard in
      // _runQueuedScan.
      this._endScan();
      if (this._rescanQueued) {
        this._rescanQueued = false;
        // Files saved mid-scan are already in `_pendingFiles` (added by
        // `_onSave` regardless of in-flight state); run them now.
        this._runQueuedScan(root);
      }
    }
  }

  private _scanViaDaemon(root: string, files: string[], tier: string): Promise<ScanOnSaveResult> {
    const scanPromise = this._daemonManager.scan(root, files, tier);
    // scan() spawns the client synchronously before its first await, so
    // isWarming is accurate here: true only until the first response lands.
    if (this._daemonManager.isWarming) {
      this._statusBarItem.text = l10n('scanOnSave.statusBar.warming');
    }
    return scanPromise;
  }

  /**
   * Replaces diagnostics for exactly the scanned [files] — including
   * clearing a file that scanned clean, which a naive "only set when
   * non-empty" approach would leave stale. Files outside this batch (not
   * scanned this pass) are left untouched.
   *
   * Diagnostics whose severity is toggled off in `saropaLints.severity.*`
   * settings are dropped before reaching the collection, so they never
   * appear in the Problems panel.
   */
  private _applyDiagnostics(files: readonly string[], diagnostics: readonly ScanOnSaveDiagnostic[]): number {
    const byFile = groupDiagnosticsByFile(diagnostics);
    // Cache raw results so _refilterDiagnostics can re-apply severity
    // toggles without rescanning.
    for (const filePath of files) {
      const raw = byFile.get(filePath) ?? [];
      if (raw.length > 0) {
        this._lastDiagnosticsByFile.set(filePath, raw);
      } else {
        this._lastDiagnosticsByFile.delete(filePath);
      }
    }
    return this._publishFiltered(byFile, files);
  }

  /** Convert + filter + push diagnostics to the collection. */
  private _publishFiltered(
    byFile: Map<string, ScanOnSaveDiagnostic[]>,
    files: Iterable<string>,
  ): number {
    // Read enabled severities once per batch instead of per-diagnostic.
    const enabled = getEnabledSeverities();
    let total = 0;
    for (const filePath of files) {
      const fileDiagnostics = byFile.get(filePath) ?? [];
      const mapped = fileDiagnostics
        .map(toVscodeDiagnostic)
        .filter((d) => enabled.has(d.severity));
      this._collection.set(vscode.Uri.file(filePath), mapped);
      total += mapped.length;
    }
    return total;
  }

  /** Re-filter cached diagnostics when severity toggles change —
   *  avoids the clear+rescan path that no-ops on empty _pendingFiles. */
  private _refilterDiagnostics(): void {
    if (this._lastDiagnosticsByFile.size === 0) return;
    this._publishFiltered(
      this._lastDiagnosticsByFile,
      this._lastDiagnosticsByFile.keys(),
    );
  }

  /**
   * Lane 3 (plans/PLAN_scan_only_diagnostics.md): on-demand whole-project
   * scan so files never saved this session still show up in the Problems
   * panel. Deliberately command-triggered, never called on activation — a
   * measured full pass on `contacts` (4,478 files) ran ~25 minutes, past
   * the plan's own "tens of minutes -> on-demand only" threshold.
   *
   * Runs as a cancelable notification progress; each chunk's diagnostics
   * are applied to the collection as it completes, so a cancel or crash
   * partway through still leaves earlier chunks' findings visible.
   */
  async runBaselineScanCommand(): Promise<void> {
    if (!this._isEnabled()) {
      void vscode.window.showWarningMessage(l10n('notify.commands.scanOnSaveBaselineDisabled'));
      return;
    }
    const root = this._getProjectRoot();
    if (!root) return;
    if (this._baselineScanInFlight) {
      void vscode.window.showWarningMessage(l10n('notify.commands.scanOnSaveBaselineAlreadyRunning'));
      return;
    }
    this._baselineScanInFlight = true;
    const tier = resolveEffectiveTier(root);
    try {
      await vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Notification,
          title: l10n('scanOnSave.baseline.progressTitle'),
          cancellable: true,
        },
        async (progress, token) => {
          const result = await runBaselineScan(this._daemonManager, root, tier, {
            isCanceled: () => token.isCancellationRequested,
            onProgress: (p) => {
              progress.report({
                message: l10n('scanOnSave.baseline.progressMessage', {
                  scanned: String(p.filesScanned),
                  total: String(p.totalFiles),
                  issues: String(p.issuesFound),
                }),
              });
            },
            onChunk: (chunkFiles, diagnostics) => this._applyDiagnostics(chunkFiles, diagnostics),
          });
          if (result.canceled) {
            void vscode.window.showInformationMessage(
              l10n('notify.commands.scanOnSaveBaselineCanceled', {
                scanned: String(result.filesScanned),
                total: String(result.totalFiles),
              }),
            );
          } else if (result.errorMessage) {
            void vscode.window.showWarningMessage(
              l10n('notify.commands.scanOnSaveBaselineFailed', { details: result.errorMessage }),
            );
          } else {
            void vscode.window.showInformationMessage(
              l10n('notify.commands.scanOnSaveBaselineDone', {
                total: String(result.totalFiles),
                issues: String(result.diagnostics.length),
              }),
            );
          }
        },
      );
    } finally {
      this._baselineScanInFlight = false;
    }
  }

  dispose(): void {
    if (this._debounceTimer) clearTimeout(this._debounceTimer);
    // Kill any scan child still running at shutdown — an orphaned `dart`
    // process outliving the extension host keeps its resolved-analysis memory
    // (multiple GB on a large project) until the machine is rebooted.
    this._scanCancelSource?.cancel();
    this._scanCancelSource?.dispose();
    this._scanCancelSource = undefined;
    this._daemonManager.dispose();
    for (const d of this._disposables) d.dispose();
  }
}
