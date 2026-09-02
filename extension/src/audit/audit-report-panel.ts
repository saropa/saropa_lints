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
import { buildAuditReportHtml } from './audit-report-html';

let panel: vscode.WebviewPanel | undefined;

/**
 * Payloads larger than this are not inlined into the webview HTML/script —
 * doing so for a 100k-diagnostic audit (~50MB of JSON, per the plan's
 * "Verified hardening" section) risks hitting webview message/HTML size
 * limits and freezing the renderer while it parses one giant string.
 * Instead the full array is written to a temp file under the extension's
 * storage dir and the client fetches it lazily via a webview resource URI.
 */
const MAX_INLINE_BYTES = 10 * 1024 * 1024;

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
  const storageDir = vscode.Uri.joinPath(context.globalStorageUri, 'audit-tmp');
  const deferredFileUri = maybeWriteDeferredPayload(auditJson, storageDir);

  if (panel) {
    // Reuse existing panel — update content and reveal. Widen
    // localResourceRoots first so a *new* deferred temp file is
    // reachable even if the previous render didn't need one.
    panel.webview.options = webviewOptions(storageDir);
    const deferredUri = deferredFileUri ? panel.webview.asWebviewUri(deferredFileUri).toString() : null;
    panel.webview.html = buildAuditReportHtml(auditJson, panel.webview, root, deferredUri);
    panel.reveal(vscode.ViewColumn.One);
    return;
  }

  panel = vscode.window.createWebviewPanel(
    'saropaAuditReport',
    l10n('audit.report.title'),
    vscode.ViewColumn.One,
    // retainContextWhenHidden is panel-level (fixed at creation, unlike
    // webview.options which can be widened later) so it's merged in only
    // here, not in the shared webviewOptions() helper used for updates too.
    { retainContextWhenHidden: true, ...webviewOptions(storageDir) },
  );

  const deferredUri = deferredFileUri ? panel.webview.asWebviewUri(deferredFileUri).toString() : null;
  panel.webview.html = buildAuditReportHtml(auditJson, panel.webview, root, deferredUri);

  // Handle messages from the webview (file open, copy JSON, save baseline).
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
        saveAuditBaseline(root, msg.json);
      }
    },
    undefined,
    context.subscriptions,
  );

  panel.onDidDispose(() => {
    panel = undefined;
  });
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
 * served if a write fails partway through a previous run.
 */
function maybeWriteDeferredPayload(
  auditJson: Record<string, unknown>,
  storageDir: vscode.Uri,
): vscode.Uri | null {
  const diagnostics = auditJson['diagnostics'];
  if (!Array.isArray(diagnostics)) return null;

  const serialized = JSON.stringify(diagnostics);
  if (Buffer.byteLength(serialized, 'utf-8') <= MAX_INLINE_BYTES) return null;

  try {
    fs.mkdirSync(storageDir.fsPath, { recursive: true });
    const filePath = path.join(storageDir.fsPath, `diagnostics-${Date.now()}.json`);
    fs.writeFileSync(filePath, serialized, 'utf-8');
    return vscode.Uri.file(filePath);
  } catch {
    // Fall back to the inline path (large, but still correct) rather than
    // showing an empty report when the temp dir isn't writable.
    return null;
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
