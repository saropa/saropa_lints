import * as vscode from 'vscode';

/**
 * Pubspec editing utilities.
 * Extracted from providers/tree-commands.ts to eliminate layer violations
 * (services should not import from providers).
 */

/** Find the first pubspec.yaml in the workspace. */
export async function findPubspecYaml(): Promise<vscode.Uri | null> {
    const files = await vscode.workspace.findFiles(
        '**/pubspec.yaml', '**/.*/**', 1,
    );
    return files[0] ?? null;
}

/** Build a workspace edit to replace a package's version constraint. */
export function buildVersionEdit(
    doc: vscode.TextDocument,
    packageName: string,
    newConstraint: string,
): { range: vscode.Range; newText: string } | null {
    const pattern = new RegExp(
        `^(\\s{2}${packageName}\\s*:\\s*)(.+)$`,
    );
    for (let i = 0; i < doc.lineCount; i++) {
        const line = doc.lineAt(i);
        const match = line.text.match(pattern);
        if (match) {
            const start = new vscode.Position(i, match[1].length);
            const end = new vscode.Position(i, line.text.length);
            return { range: new vscode.Range(start, end), newText: newConstraint };
        }
    }
    return null;
}

/** Read the current version constraint for a package from pubspec.yaml. */
export function readVersionConstraint(
    doc: vscode.TextDocument,
    packageName: string,
): string | null {
    const pattern = new RegExp(
        `^\\s{2}${packageName}\\s*:\\s*(.+)$`,
    );
    for (let i = 0; i < doc.lineCount; i++) {
        const match = doc.lineAt(i).text.match(pattern);
        if (match) { return match[1].trim(); }
    }
    return null;
}

/**
 * Find the line range of a package entry in pubspec.yaml.
 * Includes the header line and any continuation lines (deeper indent).
 */
export function findPackageLines(
    doc: vscode.TextDocument,
    packageName: string,
): { start: number; end: number } | null {
    const header = new RegExp(`^\\s{2}${packageName}\\s*:`);
    for (let i = 0; i < doc.lineCount; i++) {
        if (!header.test(doc.lineAt(i).text)) { continue; }
        let end = i + 1;
        while (end < doc.lineCount) {
            const text = doc.lineAt(end).text;
            if (text.trim() === '' || /^\s{4,}\S/.test(text)) {
                end++;
            } else {
                break;
            }
        }
        return { start: i, end };
    }
    return null;
}

/** Build a backup URI for pubspec.yaml with timestamp. */
export function buildBackupUri(yamlUri: vscode.Uri): vscode.Uri {
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    const stamp = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}`
        + `_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
    return vscode.Uri.joinPath(yamlUri, '..', `pubspec.yaml.bak.${stamp}`);
}
