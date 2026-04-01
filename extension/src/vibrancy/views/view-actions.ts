import * as vscode from 'vscode';

/**
 * Open a workspace-relative file at a specific line in the editor.
 * Silently returns if the workspace folder is missing or the file cannot be opened
 * (e.g. deleted after the scan completed).
 */
export async function openFileAtLine(relativePath: string, line: number): Promise<void> {
    const folder = vscode.workspace.workspaceFolders?.[0];
    if (!folder) { return; }
    try {
        const fileUri = vscode.Uri.joinPath(folder.uri, relativePath);
        const doc = await vscode.workspace.openTextDocument(fileUri);
        const position = new vscode.Position(Math.max(0, line - 1), 0);
        await vscode.window.showTextDocument(doc, {
            selection: new vscode.Range(position, position),
        });
    } catch {
        // File may have been deleted or renamed since the scan — ignore silently
    }
}
