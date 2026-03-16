import * as vscode from 'vscode';

/** Resolve the report/ directory in the first workspace folder. */
export async function resolveReportFolder(): Promise<vscode.Uri | null> {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) { return null; }
    const reportDir = vscode.Uri.joinPath(folders[0].uri, 'report');
    await vscode.workspace.fs.createDirectory(reportDir);
    return reportDir;
}

/** Format a date as YYYY-MM-DD_HH-mm-ss for report filenames. */
export function formatTimestamp(date: Date): string {
    const pad = (n: number) => String(n).padStart(2, '0');
    return [
        date.getFullYear(),
        '-', pad(date.getMonth() + 1),
        '-', pad(date.getDate()),
        '_', pad(date.getHours()),
        '-', pad(date.getMinutes()),
        '-', pad(date.getSeconds()),
    ].join('');
}
