import * as vscode from 'vscode';

export interface SortOptions {
    readonly sdkFirst: boolean;
}

export interface SortResult {
    readonly sorted: boolean;
    readonly sectionsModified: string[];
    readonly entriesMoved: number;
}

const SDK_PACKAGES = new Set(['flutter', 'flutter_test', 'flutter_localizations', 'flutter_web_plugins']);
const DEPENDENCY_SECTIONS = ['dependencies', 'dev_dependencies', 'dependency_overrides'];

interface DependencyEntry {
    name: string;
    startLine: number;
    endLine: number;
    lines: string[];
    isSdk: boolean;
}

/**
 * Sort dependencies alphabetically in pubspec.yaml.
 * Preserves comments and multi-line dependency specs.
 */
export async function sortDependencies(
    pubspecUri: vscode.Uri,
    options: SortOptions = { sdkFirst: true },
): Promise<SortResult> {
    const doc = await vscode.workspace.openTextDocument(pubspecUri);
    const content = doc.getText();
    const lines = content.split('\n');

    const edits: { start: number; end: number; newLines: string[] }[] = [];
    const sectionsModified: string[] = [];
    let totalMoved = 0;

    for (const section of DEPENDENCY_SECTIONS) {
        const sectionInfo = findSection(lines, section);
        if (!sectionInfo) { continue; }

        const entries = parseEntries(lines, sectionInfo.start, sectionInfo.end);
        if (entries.length < 2) { continue; }

        const sorted = sortEntries(entries, options.sdkFirst);
        const moved = countMoved(entries, sorted);
        if (moved === 0) { continue; }

        const newLines = sorted.flatMap(e => e.lines);
        edits.push({
            start: sectionInfo.start,
            end: sectionInfo.end,
            newLines,
        });
        sectionsModified.push(section);
        totalMoved += moved;
    }

    if (edits.length === 0) {
        return { sorted: false, sectionsModified: [], entriesMoved: 0 };
    }

    const edit = new vscode.WorkspaceEdit();
    for (const e of edits.reverse()) {
        const range = new vscode.Range(e.start, 0, e.end, lines[e.end - 1]?.length ?? 0);
        edit.replace(pubspecUri, range, e.newLines.join('\n'));
    }

    await vscode.workspace.applyEdit(edit);
    return { sorted: true, sectionsModified, entriesMoved: totalMoved };
}

function findSection(lines: string[], sectionName: string): { start: number; end: number } | null {
    const headerPattern = new RegExp(`^${sectionName}:\\s*$`);
    let headerLine = -1;

    for (let i = 0; i < lines.length; i++) {
        if (headerPattern.test(lines[i])) {
            headerLine = i;
            break;
        }
    }

    if (headerLine === -1) { return null; }

    const start = headerLine + 1;
    let end = start;

    while (end < lines.length) {
        const line = lines[end];
        if (line.trim() === '') {
            end++;
            continue;
        }
        if (/^\s{2}\S/.test(line) || /^\s{4,}\S/.test(line)) {
            end++;
        } else {
            break;
        }
    }

    while (end > start && lines[end - 1].trim() === '') {
        end--;
    }

    return start < end ? { start, end } : null;
}

function parseEntries(lines: string[], start: number, end: number): DependencyEntry[] {
    const entries: DependencyEntry[] = [];
    let i = start;

    while (i < end) {
        const line = lines[i];

        if (line.trim() === '' || !/^\s{2}\S/.test(line)) {
            i++;
            continue;
        }

        const match = line.match(/^\s{2}(\w[\w_-]*)\s*:/);
        if (!match) {
            i++;
            continue;
        }

        const name = match[1];
        const startLine = i;
        const entryLines: string[] = [line];
        i++;

        while (i < end) {
            const nextLine = lines[i];
            if (nextLine.trim() === '') {
                i++;
                continue;
            }
            if (/^\s{4,}\S/.test(nextLine)) {
                entryLines.push(nextLine);
                i++;
            } else {
                break;
            }
        }

        entries.push({
            name,
            startLine,
            endLine: i,
            lines: entryLines,
            isSdk: SDK_PACKAGES.has(name),
        });
    }

    return entries;
}

function sortEntries(entries: DependencyEntry[], sdkFirst: boolean): DependencyEntry[] {
    return [...entries].sort((a, b) => {
        if (sdkFirst) {
            if (a.isSdk && !b.isSdk) { return -1; }
            if (!a.isSdk && b.isSdk) { return 1; }
        }
        return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
    });
}

function countMoved(original: DependencyEntry[], sorted: DependencyEntry[]): number {
    let moved = 0;
    for (let i = 0; i < original.length; i++) {
        if (original[i].name !== sorted[i].name) {
            moved++;
        }
    }
    return moved;
}
