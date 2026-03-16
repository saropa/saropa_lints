import * as vscode from 'vscode';

const IMPORT_PATTERN = /import\s+['"]package:(\w+)\//g;

/**
 * Scan Dart source files for package import statements.
 * Returns the set of package names that appear in any import.
 */
export async function scanDartImports(
    workspaceRoot: vscode.Uri,
): Promise<Set<string>> {
    const pattern = new vscode.RelativePattern(
        workspaceRoot, '{lib,bin,test}/**/*.dart',
    );
    const files = await vscode.workspace.findFiles(pattern);
    const imported = new Set<string>();

    const contents = await Promise.all(
        files.map(f => vscode.workspace.fs.readFile(f)),
    );
    for (const bytes of contents) {
        collectImports(Buffer.from(bytes).toString('utf8'), imported);
    }

    return imported;
}

function collectImports(content: string, out: Set<string>): void {
    const re = new RegExp(IMPORT_PATTERN.source, 'g');
    let match: RegExpExecArray | null;
    while ((match = re.exec(content)) !== null) {
        out.add(match[1]);
    }
}
