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
  // scan CLI lines/columns are 1-based; VS Code Positions are 0-based. Column
  // can be absent/0 for file-level findings — clamp to a valid non-negative.
  const line = Math.max(0, d.line - 1);
  const column = Math.max(0, (d.column || 1) - 1);
  const range = new vscode.Range(line, column, line, column + 1);
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

export class ScanOnSaveController implements vscode.Disposable {
  private readonly _disposables: vscode.Disposable[] = [];
  private readonly _statusBarItem: vscode.StatusBarItem;
  /** Absolute file paths saved since the last scan started, keyed by uniqueness. */
  private _pendingFiles = new Set<string>();
  private _debounceTimer: NodeJS.Timeout | undefined;
  private _scanInFlight = false;
  /** Set when saves arrive while a scan is already running — triggers one more pass after it finishes. */
  private _rescanQueued = false;
  private readonly _daemonManager = new ScanDaemonManager();
  /** True while a Lane 3 baseline scan is running — guards against a second concurrent invocation. */
  private _baselineScanInFlight = false;

  constructor(
    private readonly _collection: vscode.DiagnosticCollection,
    private readonly _getProjectRoot: () => string | undefined,
  ) {
    this._statusBarItem = vscode.window.createStatusBarItem(
      'saropaLints.scanOnSave',
      vscode.StatusBarAlignment.Right,
      99,
    );
    this._statusBarItem.name = l10n('scanOnSave.statusBar.name');
    this._disposables.push(this._statusBarItem);
    this._disposables.push(
      vscode.workspace.onDidSaveTextDocument((doc) => this._onSave(doc)),
    );
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
            this._statusBarItem.hide();
          }
        }
      }),
    );
  }

  /** Reads the master toggle from config and applies {@link scanOnSaveIsEnabled}. */
  private _isEnabled(): boolean {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    return scanOnSaveIsEnabled(cfg.get<boolean>('enabled', true) ?? true);
  }

  private _onSave(doc: vscode.TextDocument): void {
    if (!this._isEnabled()) return;
    if (doc.languageId !== 'dart') return;
    const root = this._getProjectRoot();
    if (!root) return;
    // Only queue files under the resolved Dart project root — a save in an
    // unrelated open file (e.g. a sibling non-Dart workspace folder) must
    // not trigger or pollute this project's scan.
    const relative = path.relative(root, doc.uri.fsPath);
    if (relative.startsWith('..') || path.isAbsolute(relative)) return;

    this._pendingFiles.add(doc.uri.fsPath);
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
      return;
    }
    const files = [...this._pendingFiles];
    this._pendingFiles.clear();
    if (files.length === 0) return;
    void this._scan(root, files);
  }

  private async _scan(root: string, files: string[]): Promise<void> {
    this._scanInFlight = true;
    this._statusBarItem.text = l10n('scanOnSave.statusBar.scanning', { count: String(files.length) });
    this._statusBarItem.show();
    const start = Date.now();
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const tier = resolveEffectiveTier(root);
    const resolveTypes = cfg.get<boolean>('scanOnSave.resolveTypes', true) ?? true;

    try {
      // Resolved scans go through the persistent daemon — spawn-per-save
      // `scan --resolve` pays a fixed ~80s warmup per invocation. The
      // syntactic path stays spawn-per-save (fast, no warm state to keep).
      const result = resolveTypes
        ? await this._scanViaDaemon(root, files, tier)
        : await runScanOnSave(root, files, tier, false);
      if (result.errorMessage) {
        this._statusBarItem.text = l10n('scanOnSave.statusBar.failed');
        void vscode.window.showWarningMessage(
          l10n('notify.commands.scanOnSaveFailedDetails', { details: result.errorMessage }),
        );
        return;
      }
      const diagnostics = result.payload?.diagnostics ?? [];
      this._applyDiagnostics(files, diagnostics);
      const elapsedS = ((Date.now() - start) / 1000).toFixed(1);
      this._statusBarItem.text = l10n('scanOnSave.statusBar.done', {
        count: String(diagnostics.length),
        elapsed: elapsedS,
      });
    } finally {
      this._scanInFlight = false;
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
   */
  private _applyDiagnostics(files: readonly string[], diagnostics: readonly ScanOnSaveDiagnostic[]): void {
    const byFile = groupDiagnosticsByFile(diagnostics);
    for (const filePath of files) {
      const fileDiagnostics = byFile.get(filePath) ?? [];
      this._collection.set(
        vscode.Uri.file(filePath),
        fileDiagnostics.map(toVscodeDiagnostic),
      );
    }
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
    this._daemonManager.dispose();
    for (const d of this._disposables) d.dispose();
  }
}
