import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { buildDebugPanelHtml } from './debugPanel-html';

// ────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────

/** Runtime snapshot of a single diagnostic engine (analyzer, scan daemon, LSP). */
export interface EngineStatus {
  /** Stable machine key for toggle messages and data-attributes.
   *  Must match the DebugPanelMessage engine union: 'analyzer' | 'scanDaemon' | 'lspServer'. */
  key: 'analyzer' | 'scanDaemon' | 'lspServer';
  /** Display name shown in the panel header row — must come from l10n(). */
  name: string;
  /** Whether the user has toggled this engine on. */
  enabled: boolean;
  /** Freeform lifecycle label: "active", "idle", "running", "stopped", "starting", etc. */
  status: string;
  /** OS process ID when the engine is running. */
  pid?: number;
  /** Number of lint rules loaded by this engine. */
  ruleCount?: number;
  /** Resident set size in bytes. */
  rssBytes?: number;
  /** Explanatory note when RSS cannot be measured (e.g. in-process engines). */
  rssNote?: string;
}

/** Message shapes the webview can post back to the extension host. */
type DebugPanelMessage =
  | { command: 'toggle'; engine: 'analyzer' | 'scanDaemon' | 'lspServer'; enabled: boolean }
  | { command: 'killAll' }
  | { command: 'restartAll' };

// ────────────────────────────────────────────────────────────────
// Engine-status callbacks — the extension wires these at activation time
// ────────────────────────────────────────────────────────────────

/** Callback signatures the host supplies so the panel can read engine state. */
export interface DebugPanelDeps {
  getAnalyzerPluginStatus: () => EngineStatus;
  getScanDaemonStatus: () => EngineStatus;
  getLspServerStatus: () => EngineStatus;
}

// ────────────────────────────────────────────────────────────────
// Provider
// ────────────────────────────────────────────────────────────────

/** Maximum number of log entries retained in the scrollback buffer. */
const MAX_LOG_ENTRIES = 100;

/**
 * Sidebar webview provider for the Debug Panel.
 *
 * Shows live status of the three diagnostic engines (Analyzer Plugin,
 * Scan Daemon, LSP Server), toggle controls, and a timestamped log.
 * Follows the same provider/HTML-builder split used by
 * `DetailViewProvider` and `HealthPanel`.
 */
export class DebugPanelProvider implements vscode.WebviewViewProvider {
  /** View type registered in package.json `contributes.views`. */
  static readonly viewType = 'saropaLints.debugPanel';

  private _view: vscode.WebviewView | undefined;

  /** Rolling log buffer — newest entry at the end. */
  private readonly _logEntries: string[] = [];

  /** Fires when the webview requests an engine toggle. */
  private readonly _onToggle = new vscode.EventEmitter<{
    engine: 'analyzer' | 'scanDaemon' | 'lspServer';
    enabled: boolean;
  }>();
  /** Fires when the webview requests a kill-all. */
  private readonly _onKillAll = new vscode.EventEmitter<void>();
  /** Fires when the webview requests a restart-all. */
  private readonly _onRestartAll = new vscode.EventEmitter<void>();

  /** Subscribe to engine toggle requests from the panel UI. */
  readonly onToggle = this._onToggle.event;
  /** Subscribe to kill-all requests from the panel UI. */
  readonly onKillAll = this._onKillAll.event;
  /** Subscribe to restart-all requests from the panel UI. */
  readonly onRestartAll = this._onRestartAll.event;

  constructor(
    private readonly _extensionUri: vscode.Uri,
    private readonly _deps: DebugPanelDeps,
  ) {}

  // ── WebviewViewProvider ───────────────────────────────────────

  /** Called by VS Code when the sidebar view becomes visible. */
  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken,
  ): void {
    this._view = webviewView;

    // Allow scripts so the inline <script> block can postMessage back.
    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this._extensionUri],
    };

    // Initial render with current engine snapshots.
    this._renderHtml();

    // Route messages from the webview script to the appropriate emitter.
    webviewView.webview.onDidReceiveMessage(
      (msg: DebugPanelMessage) => this._handleMessage(msg),
    );

    // When the view is disposed (user collapses the panel, etc.) clear
    // the reference so we stop trying to push HTML into a dead webview.
    webviewView.onDidDispose(() => {
      this._view = undefined;
    });
  }

  // ── Public API ────────────────────────────────────────────────

  /** Re-render the panel HTML with fresh engine status. */
  refresh(): void {
    this._renderHtml();
  }

  /**
   * Append a timestamped entry to the log buffer and re-render.
   * Oldest entries are evicted when the buffer exceeds MAX_LOG_ENTRIES.
   */
  addLogEntry(message: string): void {
    const timestamp = new Date().toLocaleTimeString();
    this._logEntries.push(`[${timestamp}] ${message}`);

    // Evict oldest entries when the buffer is full.
    while (this._logEntries.length > MAX_LOG_ENTRIES) {
      this._logEntries.shift();
    }

    this._renderHtml();
  }

  // ── Internals ─────────────────────────────────────────────────

  /** Gather engine snapshots and push rendered HTML into the webview. */
  private _renderHtml(): void {
    if (!this._view) {
      return;
    }

    const engines: EngineStatus[] = [
      this._deps.getAnalyzerPluginStatus(),
      this._deps.getScanDaemonStatus(),
      this._deps.getLspServerStatus(),
    ];

    this._view.webview.html = buildDebugPanelHtml(
      this._view.webview,
      this._extensionUri,
      engines,
      this._logEntries,
    );
  }

  /** Dispatch a webview message to the matching event emitter. */
  private _handleMessage(msg: DebugPanelMessage): void {
    switch (msg.command) {
      case 'toggle':
        this._onToggle.fire({ engine: msg.engine, enabled: msg.enabled });
        break;
      case 'killAll':
        this._onKillAll.fire();
        break;
      case 'restartAll':
        this._onRestartAll.fire();
        break;
    }
  }
}
