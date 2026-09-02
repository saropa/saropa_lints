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
 * TODO: `vscode-languageclient` is not yet listed in extension/package.json
 *       dependencies. Add it before this module is imported:
 *         npm i vscode-languageclient
 *       (The `@types/vscode` peer is already satisfied by the extension.)
 */

import * as vscode from 'vscode';
import {
  LanguageClient,
  type LanguageClientOptions,
  type ServerOptions,
} from 'vscode-languageclient/node';

/** Output channel name surfaced in VS Code's "Output" dropdown. */
const OUTPUT_CHANNEL_NAME = 'Saropa Lints LSP';

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
    const serverOptions: ServerOptions = {
      run: {
        command: 'dart',
        args: ['run', 'saropa_lints:lsp_server'],
        options: { cwd: this._projectRoot },
      },
      debug: {
        command: 'dart',
        args: ['run', 'saropa_lints:lsp_server'],
        options: { cwd: this._projectRoot },
      },
    };

    // Client configuration — route Dart files through this server and
    // send log output to the dedicated channel.
    const clientOptions: LanguageClientOptions = {
      documentSelector: [{ scheme: 'file', language: 'dart' }],
      outputChannel: this._outputChannel,
      outputChannelName: OUTPUT_CHANNEL_NAME,
    };

    const client = new LanguageClient(
      'saropaLintsLsp',           // Internal client id (unique per extension).
      OUTPUT_CHANNEL_NAME,        // Human-readable name shown in status bar.
      serverOptions,
      clientOptions,
    );

    // Push the client itself as a disposable so VS Code can tear it down
    // if the extension deactivates before we call stop() explicitly.
    this._context.subscriptions.push(client);
    this._disposables.push(client);

    try {
      await client.start();
      this._client = client;
      this._outputChannel.appendLine('[SaropaLspClient] LSP server started successfully.');
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
    // await. The LanguageClient's own dispose (registered in
    // _context.subscriptions above) is the final backstop.
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
