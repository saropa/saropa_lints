/**
 * Manages a standalone Saropa Lints LSP server process from the VS Code
 * extension. Spawns `dart run saropa_lints:lsp_server` as a
 * `LanguageClient`, wiring its diagnostics into VS Code's Problems panel
 * and its logs into a dedicated output channel.
 *
 * Lifecycle mirrors `ScanDaemonManager` — start/stop/restart/dispose — but
 * delegates the wire protocol to `vscode-languageclient` instead of raw
 * NDJSON, because the server speaks LSP.
 *
 * `vscode-languageclient` is listed in extension/package.json dependencies.
 */

import * as vscode from 'vscode';
import {
  LanguageClient,
  type LanguageClientOptions,
  type ServerOptions,
} from 'vscode-languageclient/node';
import { HealthPanel } from '../systemHealth/healthPanel';

// CVE-2024-27980 / PATHEXT: on Windows, `dart` resolves to `dart.bat` which
// needs a shell to execute. Without this, spawn() returns ENOENT.
// Same rationale as scanOnSaveRunner.ts SPAWN_USE_SHELL.
const SPAWN_USE_SHELL = process.platform === 'win32';

/** Output channel name surfaced in VS Code's "Output" dropdown. */
const OUTPUT_CHANNEL_NAME = 'Saropa Lints LSP';

/**
 * WP4 (`plans/PLAN_ext_ui_dart_deferred.md`): payload shape of the server's
 * custom `saropa/scanProgress` notification — see
 * `lib/src/lsp/scan_progress_notification.dart` (the Dart side's pinned
 * builder) for the authoritative schema this mirrors.
 */
export interface LspScanProgress {
  readonly filesScanned: number;
  readonly totalFiles: number;
  readonly diagnosticsPublished: number;
  /**
   * True when the scan has terminated (completed or canceled). Without this,
   * a canceled scan whose `filesScanned < totalFiles` leaves the engine card
   * stuck on "scanning" forever. Optional: older servers that don't send the
   * field fall back to the filesScanned < totalFiles ratio.
   */
  readonly done?: boolean;
}

/**
 * Wraps a single `LanguageClient` instance that talks to
 * `bin/lsp_server.dart`. The extension creates one per project root and
 * disposes it on deactivation.
 */
export class SaropaLspClient implements vscode.Disposable {
  /** The active language client, or undefined when stopped. */
  private _client: LanguageClient | undefined;

  /** Dedicated output channel for server logs and lifecycle messages. */
  private readonly _outputChannel: vscode.OutputChannel;

  /** Subscriptions pushed during start(); cleared on stop(). */
  private readonly _disposables: vscode.Disposable[] = [];

  /**
   * WP4: most recent `saropa/scanProgress` tick, or undefined before the
   * server's first workspace scan has emitted one (e.g. workspace scan
   * disabled, or an older engine that predates this notification entirely —
   * absence here is exactly how the Health Panel tells "no progress data"
   * from "0/0 scanned").
   */
  private _lastScanProgress: LspScanProgress | undefined;

  /** Read-only snapshot of the latest workspace-scan progress (see [_lastScanProgress]). */
  get lastScanProgress(): LspScanProgress | undefined {
    return this._lastScanProgress;
  }

  /**
   * @param _context  Extension context — used to register disposables so
   *                  VS Code tears them down on deactivation.
   * @param _projectRoot  Absolute path to the Dart project root whose
   *                      `pubspec.yaml` depends on `saropa_lints`. The
   *                      LSP server is spawned with this as its `cwd`.
   */
  constructor(
    private readonly _context: vscode.ExtensionContext,
    private readonly _projectRoot: string,
  ) {
    // Create the output channel once — it survives stop/start cycles so
    // the user doesn't lose earlier log lines when the server restarts.
    this._outputChannel = vscode.window.createOutputChannel(OUTPUT_CHANNEL_NAME);

    // Register for VS Code deactivation teardown exactly once per instance,
    // so the spawned dart process is stopped even if dispose() is never
    // called explicitly. Done in the constructor (not at each call site)
    // to prevent duplicate pushes across toggle/restart/config-change paths.
    this._context.subscriptions.push(this);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────

  /**
   * Spawns the LSP server and connects the language client. If the client
   * is already running this is a no-op — call `restart()` to cycle it.
   */
  async start(): Promise<void> {
    if (this._client) {
      // Already running — avoid double-spawning.
      this._outputChannel.appendLine('[SaropaLspClient] start() called but client already running — skipping.');
      return;
    }

    this._outputChannel.appendLine(
      `[SaropaLspClient] Starting LSP server for project: ${this._projectRoot}`,
    );

    // Server spawn configuration — identical for run and debug because
    // the Dart VM doesn't need a separate debug launch profile here.
    // shell: true on Windows so `dart.bat` resolves via PATHEXT.
    const serverOptions: ServerOptions = {
      run: {
        command: 'dart',
        args: ['run', 'saropa_lints:lsp_server'],
        options: { cwd: this._projectRoot, shell: SPAWN_USE_SHELL },
      },
      debug: {
        command: 'dart',
        args: ['run', 'saropa_lints:lsp_server'],
        options: { cwd: this._projectRoot, shell: SPAWN_USE_SHELL },
      },
    };

    // Client configuration — route Dart files through this server and
    // send log output to the dedicated channel. The middleware filter
    // prevents the 200+-file didOpen flood VS Code sends on activation —
    // only files in visible editors get forwarded, so the server only
    // analyzes what the user is actually looking at.
    // Pass user-configurable LSP settings as initialization options so the
    // server knows which directories to scan and whether to run a startup
    // workspace scan at all. These mirror the saropaLints.lspServer.*
    // settings in package.json.
    const lspConfig = vscode.workspace.getConfiguration('saropaLints.lspServer');
    const clientOptions: LanguageClientOptions = {
      documentSelector: [{ scheme: 'file', language: 'dart' }],
      outputChannel: this._outputChannel,
      outputChannelName: OUTPUT_CHANNEL_NAME,
      initializationOptions: {
        workspaceScan: lspConfig.get<boolean>('workspaceScan', true),
        scanDirectories: lspConfig.get<string[]>('scanDirectories', ['lib', 'bin', 'test']),
      },
      middleware: {
        didOpen: (document, next) => {
          // Only forward didOpen for files the user has in a visible editor
          // tab. VS Code's LanguageClient sends didOpen for ALL matching
          // documents on connect (~200+ Dart files in a real workspace),
          // each of which triggers a full ScanRunner pass in the LSP server.
          // This filter reduces that to ~1-3 files (the visible tabs).
          const isVisible = vscode.window.visibleTextEditors.some(
            (editor) => editor.document.uri.toString() === document.uri.toString(),
          );
          if (isVisible) {
            return next(document);
          }
          // Silently drop — the server will analyze on didSave when the
          // user actually edits this file.
          return Promise.resolve();
        },
      },
    };

    const client = new LanguageClient(
      'saropaLintsLsp',           // Internal client id (unique per extension).
      OUTPUT_CHANNEL_NAME,        // Human-readable name shown in status bar.
      serverOptions,
      clientOptions,
    );

    // Track the client in local disposables only — pushing to
    // _context.subscriptions on every start() grows unbounded across
    // restart cycles. The class's own dispose() is the teardown path.
    this._disposables.push(client);

    try {
      await client.start();
      this._client = client;
      this._outputChannel.appendLine('[SaropaLspClient] LSP server started successfully.');
      // WP4: listen for the server's custom scan-progress notification. Not
      // part of the LSP spec (see bin/lsp_server.dart's `_sendScanProgress`
      // doc comment for why this is a plain notification rather than the
      // standard `$/progress`), so `onNotification` is given the raw method
      // name string rather than a typed request descriptor.
      this._disposables.push(
        client.onNotification('saropa/scanProgress', (params: LspScanProgress) => {
          this._lastScanProgress = params;
          // Live-refresh the Health Panel's engine card if it's open. Uses
          // refreshIfOpen (not addLogEntry) so a long scan's many ticks
          // don't spam the Activity log — only the server's own "scan
          // complete" log line does that.
          HealthPanel.refreshIfOpen();
        }),
      );
    } catch (err) {
      // Surface the spawn failure so it's visible in the output channel
      // and doesn't silently vanish.
      const message = err instanceof Error ? err.message : String(err);
      this._outputChannel.appendLine(`[SaropaLspClient] Failed to start LSP server: ${message}`);
      // Don't hold a half-started client reference.
      this._client = undefined;
    }
  }

  /**
   * Gracefully stops the language client and clears any diagnostics it
   * published. Safe to call when already stopped.
   */
  async stop(): Promise<void> {
    if (!this._client) {
      return;
    }

    this._outputChannel.appendLine('[SaropaLspClient] Stopping LSP server…');

    try {
      await this._client.stop();
    } catch (err) {
      // The server may have already exited — log but don't propagate.
      const message = err instanceof Error ? err.message : String(err);
      this._outputChannel.appendLine(`[SaropaLspClient] Error during stop: ${message}`);
    }

    // Clear diagnostics so stale squigglies don't linger after shutdown.
    this._client.diagnostics?.clear();
    this._client = undefined;
    // A stopped server cannot still be "scanning 812/1900" — stale progress
    // from before the stop would otherwise linger and mislead the card.
    this._lastScanProgress = undefined;

    this._outputChannel.appendLine('[SaropaLspClient] LSP server stopped.');
  }

  /**
   * Full stop-then-start cycle. Useful after config changes that require
   * the server to re-read its analysis context.
   */
  async restart(): Promise<void> {
    this._outputChannel.appendLine('[SaropaLspClient] Restarting LSP server…');
    await this.stop();
    await this.start();
  }

  /** Whether the language client is currently running and connected. */
  get isRunning(): boolean {
    return this._client?.isRunning() ?? false;
  }

  // ── Disposable ─────────────────────────────────────────────────────

  /**
   * Clean shutdown for extension deactivation. Stops the server, disposes
   * the output channel, and releases all held subscriptions.
   */
  dispose(): void {
    // Best-effort synchronous teardown — `stop()` is async but
    // `dispose()` is called during extension deactivation which may not
    // await. The SaropaLspClient is registered in context.subscriptions
    // at each creation site in extension.ts as the deactivation backstop.
    if (this._client) {
      // Fire-and-forget — deactivation doesn't await promises.
      void this.stop();
    }

    // Dispose everything registered during start() cycles.
    for (const d of this._disposables) {
      d.dispose();
    }
    this._disposables.length = 0;

    this._outputChannel.dispose();
  }
}
