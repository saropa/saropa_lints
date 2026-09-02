/**
 * Singleton webview panel for the full audit report.
 *
 * Receives the parsed JSON payload from the audit CLI and renders a
 * filterable, searchable diagnostic table with tier/severity/impact
 * filter chips and a summary header.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { buildAuditErrorHtml, buildAuditReportHtml } from './audit-report-html';

let panel: vscode.WebviewPanel | undefined;

// The message handler closes over this rather than a value captured at
// registration time, so "Save as baseline" (fired from a reused panel)
// always targets the most recently audited root — even when the panel was
// first created by openAuditError() before any successful run existed.
let currentRoot = '';

/**
 * Payloads larger than this are not inlined into the webview HTML/script —
 * doing so for a 100k-diagnostic audit (~50MB of JSON, per the plan's
 * "Verified hardening" section) risks hitting webview message/HTML size
 * limits and freezing the renderer while it parses one giant string.
 * Instead the full array is written to a temp file under the extension's
 * storage dir and the client fetches it lazily via a webview resource URI.
 */
/** @internal Exported for testing only — not part of the public API. */
export const MAX_INLINE_BYTES = 10 * 1024 * 1024;

/**
 * Opens (or reveals) the audit report panel and renders the audit JSON.
 * The `root` param is the scanned project root — used for relative path
 * display and file-open commands.
 */
export function openAuditReport(
  context: vscode.ExtensionContext,
  auditJson: Record<string, unknown>,
  root: string,
): void {
  currentRoot = root;
  const storageDir = vscode.Uri.joinPath(context.globalStorageUri, 'audit-tmp');
  const deferredFileUri = maybeWriteDeferredPayload(auditJson, storageDir);

  const p = ensurePanel(context, webviewOptions(storageDir));
  // Widen localResourceRoots on an already-existing panel so a *new*
  // deferred temp file is reachable even if the previous render didn't
  // need one (e.g. panel was first opened via openAuditError, which sets
  // an empty localResourceRoots).
  p.webview.options = webviewOptions(storageDir);

  const deferredUri = deferredFileUri ? p.webview.asWebviewUri(deferredFileUri).toString() : null;
  p.webview.html = buildAuditReportHtml(auditJson, p.webview, root, deferredUri);
  p.reveal(vscode.ViewColumn.One);
}

/**
 * Opens (or reveals) the audit report panel showing a failure/cancel state
 * instead of a table — used whenever the audit CLI errors out or the user
 * cancels it, so the panel never sits blank or shows a stale prior run's
 * results with no explanation of what happened (project hard rule: no
 * silent async, every action gets a visible outcome).
 */
export function openAuditError(
  context: vscode.ExtensionContext,
  root: string,
  message: string,
  canceled: boolean,
): void {
  currentRoot = root;
  // No scripts and no filesystem access needed for a static error state.
  const p = ensurePanel(context, { enableScripts: false, localResourceRoots: [] });
  p.webview.html = buildAuditErrorHtml(message, canceled);
  p.reveal(vscode.ViewColumn.One);
}

/**
 * Returns the singleton panel, creating it (and wiring its one-time
 * message handler) on first use. Reused across openAuditReport and
 * openAuditError so a panel first created by either entry point still
 * responds to "Copy JSON" / "Save as baseline" once a real report loads
 * into it later — the handler reads `currentRoot` at call time rather than
 * closing over the root available when the panel happened to be created.
 */
function ensurePanel(
  context: vscode.ExtensionContext,
  options: vscode.WebviewOptions,
): vscode.WebviewPanel {
  if (panel) {
    panel.webview.options = options;
    return panel;
  }

  panel = vscode.window.createWebviewPanel(
    'saropaAuditReport',
    l10n('audit.report.title'),
    vscode.ViewColumn.One,
    // retainContextWhenHidden is panel-level (fixed at creation, unlike
    // webview.options which can be widened later) so it's merged in only
    // at creation time.
    { retainContextWhenHidden: true, ...options },
  );

  // Handle messages from the webview (file open, copy JSON, save baseline).
  // Registered once per panel instance regardless of which entry point
  // created it.
  panel.webview.onDidReceiveMessage(
    (msg: { type: string; path?: string; json?: string }) => {
      if (msg.type === 'openFile' && msg.path) {
        // Open the file at the diagnostic location.
        const uri = vscode.Uri.file(msg.path);
        void vscode.window.showTextDocument(uri);
      }
      if (msg.type === 'copyJson' && msg.json) {
        void vscode.env.clipboard.writeText(msg.json);
        void vscode.window.showInformationMessage(
          l10n('audit.report.copiedJson'),
        );
      }
      if (msg.type === 'saveBaseline' && msg.json) {
        // Save the audit JSON as the project baseline via the CLI.
        saveAuditBaseline(currentRoot, msg.json);
      }
    },
    undefined,
    context.subscriptions,
  );

  panel.onDidDispose(() => {
    panel = undefined;
  });

  return panel;
}

/** Webview creation/update options — scripts on, and the deferred-payload temp dir readable. */
function webviewOptions(storageDir: vscode.Uri): vscode.WebviewOptions {
  return {
    enableScripts: true,
    // Only the audit temp dir is reachable — never the workspace or
    // filesystem root — so a malicious diagnostic message/path can't be
    // used to pull arbitrary local files into the webview.
    localResourceRoots: [storageDir],
  };
}

/**
 * When the diagnostics array is too large to inline safely (see
 * MAX_INLINE_BYTES), writes it to a fresh temp file under `storageDir` and
 * returns that file's URI. Returns null for the normal (small payload)
 * path, where the array is embedded directly in the generated HTML.
 *
 * A fresh filename per call (timestamped) avoids a stale temp file being
 * served if a write fails partway through a previous run. Any leftover
 * files from PRIOR audit runs are deleted first — without this, every
 * >10MB audit (each easily tens of MB) accumulates in global storage
 * forever, since nothing else in the panel's lifecycle ever removes them
 * (the panel is a singleton reused across many runs, not disposed per-run).
 */
/** @internal Exported for testing only — not part of the public API. */
export function maybeWriteDeferredPayload(
  auditJson: Record<string, unknown>,
  storageDir: vscode.Uri,
): vscode.Uri | null {
  const diagnostics = auditJson['diagnostics'];
  if (!Array.isArray(diagnostics)) return null;

  const serialized = JSON.stringify(diagnostics);
  if (Buffer.byteLength(serialized, 'utf-8') <= MAX_INLINE_BYTES) return null;

  try {
    fs.mkdirSync(storageDir.fsPath, { recursive: true });
    cleanupDeferredPayloads(storageDir);
    const filePath = path.join(storageDir.fsPath, `diagnostics-${Date.now()}.json`);
    fs.writeFileSync(filePath, serialized, 'utf-8');
    return vscode.Uri.file(filePath);
  } catch (e: unknown) {
    // Fall back to the inline path (large, but still correct) rather than
    // showing an empty report when the temp dir isn't writable (disk full,
    // permissions, etc). Still surface the failure — silently degrading to
    // a multi-tens-of-MB inline render with no explanation would violate
    // the project's "no silent async" rule if that render then stalls.
    //
    // KNOWN RISK (circular fallback): the payload exceeded MAX_INLINE_BYTES,
    // which is WHY we tried the temp-file path. Inlining it back into the
    // webview HTML may hang/crash the renderer for very large payloads
    // (100k+ diagnostics, ~50MB+). Accepted trade-off: a degraded but
    // visible report is better than no report at all, and the warning toast
    // above tells the user what happened. A future mitigation could truncate
    // the inlined array to a safe size and show a "results truncated" banner.
    const message = e instanceof Error ? e.message : String(e);
    void vscode.window.showWarningMessage(
      l10n('audit.report.deferredWriteFailed', { message }),
    );
    return null;
  }
}

/**
 * Deletes every previously-written deferred-payload temp file under
 * `storageDir`. Called right before writing a new one so at most one
 * lingers on disk at a time — the webview never reads a file mid-delete
 * here since this runs strictly before the new file is written and served.
 * Best-effort: a locked/already-gone file is skipped rather than failing
 * the whole audit render over stale-temp-file housekeeping.
 */
/** @internal Exported for testing only — not part of the public API. */
export function cleanupDeferredPayloads(storageDir: vscode.Uri): void {
  let entries: string[];
  try {
    entries = fs.readdirSync(storageDir.fsPath);
  } catch {
    return;
  }
  for (const name of entries) {
    if (!name.startsWith('diagnostics-') || !name.endsWith('.json')) continue;
    try {
      fs.unlinkSync(path.join(storageDir.fsPath, name));
    } catch {
      // Ignore: e.g. still open by the webview from a prior render, or
      // already removed by another process.
    }
  }
}

/** Saves the audit JSON as the project baseline at `.saropa/audit_baseline.json`. */
function saveAuditBaseline(root: string, jsonString: string): void {
  try {
    const dir = path.join(root, '.saropa');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(
      path.join(dir, 'audit_baseline.json'),
      jsonString,
      'utf-8',
    );
    void vscode.window.showInformationMessage(
      l10n('audit.report.baselineSaved'),
    );
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    void vscode.window.showErrorMessage(
      l10n('audit.report.baselineSaveFailed', { message }),
    );
  }
}
