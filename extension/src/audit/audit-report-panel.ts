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
 * Opens (or reveals) the audit report panel and renders the audit JSON.
 * The `root` param is the scanned project root — used for relative path
 * display and file-open commands.
 */
export function openAuditReport(
  context: vscode.ExtensionContext,
  auditJson: Record<string, unknown>,
  root: string,
): void {
  if (panel) {
    // Reuse existing panel — update content and reveal.
    panel.webview.html = buildAuditReportHtml(auditJson, panel.webview, root);
    panel.reveal(vscode.ViewColumn.One);
    return;
  }

  panel = vscode.window.createWebviewPanel(
    'saropaAuditReport',
    l10n('audit.report.title'),
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      retainContextWhenHidden: true,
      localResourceRoots: [],
    },
  );

  panel.webview.html = buildAuditReportHtml(auditJson, panel.webview, root);

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
