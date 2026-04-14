import * as vscode from 'vscode';
import { SDK_PACKAGES } from '../sdk-packages';

export interface SortOptions {
    readonly sdkFirst: boolean;
}

export interface SortResult {
    readonly sorted: boolean;
    readonly sectionsModified: string[];
    readonly entriesMoved: number;
}

const DEPENDENCY_SECTIONS = ['dependencies', 'dev_dependencies', 'dependency_overrides'];

interface DependencyEntry {
    name: string;
    startLine: number;
    endLine: number;
    lines: string[];
    /** Comment lines that precede this entry and travel with it during sort. */
    leadingComments: string[];
    isSdk: boolean;
}

interface ParseResult {
    entries: DependencyEntry[];
    /** Trailing lines after the last entry (decorators, section dividers). */
    tail: string[];
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

        const { entries, tail } = parseEntries(lines, sectionInfo.start, sectionInfo.end);
        if (entries.length < 2) { continue; }

        const sorted = sortEntries(entries, options.sdkFirst);
        const newLines = buildSortedLines(sorted, options.sdkFirst);
        // Append trailing lines (decorators, section dividers) that follow
        // the last entry but are still inside the section range
        if (tail.length > 0) {
            newLines.push(...tail);
        }

        // Check if anything actually changed (order or formatting)
        const originalLines = lines.slice(sectionInfo.start, sectionInfo.end);
        const newContent = newLines.join('\n');
        const originalContent = originalLines.join('\n');
        if (newContent === originalContent) { continue; }

        const moved = countMoved(entries, sorted);
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

/**
 * Parse dependency entries from a section, collecting comment lines that
 * precede each entry so they travel with it during sorting. Blank lines
 * between entries are treated as group separators (rebuilt by
 * buildSortedLines) rather than entry-specific content.
 */
function parseEntries(lines: string[], start: number, end: number): ParseResult {
    const entries: DependencyEntry[] = [];
    // Buffer for comment/blank lines seen between entries
    let pending: string[] = [];
    let i = start;

    while (i < end) {
        const line = lines[i];

        // Blank lines go into the pending buffer
        if (line.trim() === '') {
            pending.push(line);
            i++;
            continue;
        }

        // Lines that aren't 2-space indented (shouldn't happen inside a
        // section, but guard against it)
        if (!/^\s{2}\S/.test(line)) {
            pending.push(line);
            i++;
            continue;
        }

        // 2-space indented line — either a dependency name or a comment
        const match = line.match(/^\s{2}(\w[\w_-]*)\s*:/);
        if (!match) {
            // Comment or decorator line (e.g. `  # description`)
            pending.push(line);
            i++;
            continue;
        }

        // Found a dependency entry — collect continuation lines (4+ indent)
        const name = match[1];
        const startLine = i;
        const entryLines: string[] = [line];
        i++;

        while (i < end) {
            const nextLine = lines[i];
            // Break on blank lines so they go into the pending buffer for
            // the next entry instead of being silently consumed
            if (nextLine.trim() === '') { break; }
            if (/^\s{4,}\S/.test(nextLine)) {
                entryLines.push(nextLine);
                i++;
            } else {
                break;
            }
        }

        // Trim leading blank lines from pending — blank lines are group
        // separators rebuilt by buildSortedLines, not entry-specific
        while (pending.length > 0 && pending[0].trim() === '') {
            pending.shift();
        }

        entries.push({
            name,
            startLine,
            endLine: i,
            lines: entryLines,
            leadingComments: pending,
            isSdk: SDK_PACKAGES.has(name),
        });
        pending = [];
    }

    return { entries, tail: pending };
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

/**
 * Find the group key for a package — the shortest other package name in the
 * section that is a prefix of this name at a '_' boundary. Packages sharing
 * a group key stay adjacent without blank line separators.
 *
 * Example: if both 'drift' and 'drift_flutter' are in the section,
 * drift_flutter's group key is 'drift', so they stay together.
 */
function getGroupKey(name: string, allNames: Set<string>): string {
    const parts = name.split('_');
    // Check progressively longer prefixes: 'drift' before 'drift_flutter'
    for (let i = 1; i < parts.length; i++) {
        const prefix = parts.slice(0, i).join('_');
        if (allNames.has(prefix) && prefix !== name) {
            return prefix;
        }
    }
    return name;
}

/**
 * Build output lines from sorted entries, inserting blank lines between
 * package groups. Packages are grouped when one name is a prefix of another
 * at a '_' boundary (e.g. drift + drift_flutter + drift_dev). SDK packages
 * are always separated from non-SDK packages by a blank line.
 */
function buildSortedLines(
    entries: DependencyEntry[],
    sdkFirst: boolean,
): string[] {
    if (entries.length === 0) { return []; }

    // Collect non-SDK names for group-key computation
    const nonSdkNames = new Set(
        entries.filter(e => !e.isSdk).map(e => e.name),
    );

    // First entry: emit its leading comments (e.g. "# SDK deps first")
    // and its dependency lines
    const result: string[] = [
        ...entries[0].leadingComments,
        ...entries[0].lines,
    ];

    for (let i = 1; i < entries.length; i++) {
        const prev = entries[i - 1];
        const curr = entries[i];

        let needsBlankLine: boolean;

        if (sdkFirst && prev.isSdk !== curr.isSdk) {
            // Always separate SDK block from non-SDK block
            needsBlankLine = true;
        } else if (prev.isSdk && curr.isSdk) {
            // SDK packages stay together — but still add a blank line if
            // the entry has its own leading comments (e.g. a doc block)
            needsBlankLine = curr.leadingComments.length > 0;
        } else {
            // Both non-SDK: separate unless they share a group key
            const prevKey = getGroupKey(prev.name, nonSdkNames);
            const currKey = getGroupKey(curr.name, nonSdkNames);
            needsBlankLine = prevKey !== currKey;
        }

        if (needsBlankLine) {
            result.push('');
        }
        // Emit leading comments, then the dependency lines
        result.push(...curr.leadingComments, ...curr.lines);
    }

    return result;
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
