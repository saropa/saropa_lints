import * as vscode from 'vscode';

export const PREVIEW_SCHEME = 'saropa-analyzer-exclude-preview';

// Virtual document provider so the "proposed exclusions" diff can be shown
// against the real file without ever writing the proposed content to disk
// (VS Code's diff editor only reads registered TextDocumentContentProviders
// for non-file URI schemes).
class AnalyzerExcludePreviewProvider implements vscode.TextDocumentContentProvider {
  private readonly _content = new Map<string, string>();
  private readonly _onDidChange = new vscode.EventEmitter<vscode.Uri>();
  readonly onDidChange = this._onDidChange.event;

  set(uri: vscode.Uri, content: string): void {
    this._content.set(uri.toString(), content);
    this._onDidChange.fire(uri);
  }

  provideTextDocumentContent(uri: vscode.Uri): string {
    return this._content.get(uri.toString()) ?? '';
  }
}

let _provider: AnalyzerExcludePreviewProvider | undefined;

export function registerAnalyzerExcludeDiffProvider(
  context: vscode.ExtensionContext,
): void {
  _provider = new AnalyzerExcludePreviewProvider();
  context.subscriptions.push(
    vscode.workspace.registerTextDocumentContentProvider(PREVIEW_SCHEME, _provider),
  );
}

/** Opens a read-only diff between the on-disk file and proposed new content. */
export async function showAnalyzerExcludeDiff(
  filePath: string,
  proposedContent: string,
  title: string,
): Promise<void> {
  if (!_provider) return;
  // Query string uniquifies the URI per call so VS Code doesn't reuse a
  // cached editor for a stale previous proposal when this is invoked twice.
  const previewUri = vscode.Uri.parse(`${PREVIEW_SCHEME}:/analysis_options.yaml?${Date.now()}`);
  _provider.set(previewUri, proposedContent);
  const fileUri = vscode.Uri.file(filePath);
  await vscode.commands.executeCommand('vscode.diff', fileUri, previewUri, title, {
    preview: true,
  });
}
