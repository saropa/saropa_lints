import * as vscode from 'vscode';
import { escapeRegExp } from './annotate-headers';

const MAX_DESC_LENGTH = 80;
const PUB_URL_PREFIX = '# https://pub.dev/packages/';

/** An edit to insert or replace an annotation block above a package. */
export interface AnnotationEdit {
    readonly insertPos: vscode.Position;
    readonly text: string;
    readonly deleteRanges: vscode.Range[];
}

/** Format annotation comment lines for a package. */
export function formatAnnotation(
    name: string,
    description: string | null,
): string {
    const url = `  ${PUB_URL_PREFIX}${name}`;
    if (!description) { return `${url}\n`; }

    const truncated = description.length > MAX_DESC_LENGTH
        ? description.slice(0, MAX_DESC_LENGTH - 3) + '...'
        : description;
    return `  # ${truncated}\n${url}\n`;
}

/** Build edits to insert or replace annotations above each package. */
export function buildAnnotationEdits(
    doc: vscode.TextDocument,
    packageNames: string[],
    descriptions: Map<string, string>,
): AnnotationEdit[] {
    const edits: AnnotationEdit[] = [];

    for (const name of packageNames) {
        const lineIdx = findPackageLine(doc, name);
        if (lineIdx === null) { continue; }

        const existing = findExistingAnnotations(doc, lineIdx, name);
        const text = formatAnnotation(name, descriptions.get(name) ?? null);

        const deleteRanges = existing.map(r => new vscode.Range(
            new vscode.Position(r.start, 0),
            new vscode.Position(r.end, 0),
        ));

        const insertLine = existing.length > 0
            ? Math.min(...existing.map(r => r.start))
            : lineIdx;

        edits.push({
            insertPos: new vscode.Position(insertLine, 0),
            text,
            deleteRanges,
        });
    }

    return edits;
}

/** Find the line number of a package entry in a pubspec document. */
function findPackageLine(
    doc: vscode.TextDocument,
    packageName: string,
): number | null {
    const pattern = new RegExp(`^\\s{2}${packageName}\\s*:`);
    for (let i = 0; i < doc.lineCount; i++) {
        if (pattern.test(doc.lineAt(i).text)) { return i; }
    }
    return null;
}

/**
 * Find all auto-generated annotation blocks above a package entry.
 * Scans consecutive comment lines and identifies URL + description pairs.
 * Returns an array of ranges to delete, preserving user comments.
 */
function findExistingAnnotations(
    doc: vscode.TextDocument,
    packageLine: number,
    packageName: string,
): Array<{ start: number; end: number }> {
    const urlPattern = new RegExp(
        `^\\s*#\\s*https://pub\\.dev/packages/${escapeRegExp(packageName)}(?:/[\\w-]*)?\\s*$`,
    );

    let cursor = packageLine - 1;
    if (cursor < 0) { return []; }

    const ranges: Array<{ start: number; end: number }> = [];
    const processedLines = new Set<number>();

    while (cursor >= 0) {
        const lineText = doc.lineAt(cursor).text;

        if (!lineText.match(/^\s*#/) && lineText.trim() !== '') {
            break;
        }

        if (lineText.trim() === '' || lineText.trim() === '#') {
            cursor--;
            continue;
        }

        if (urlPattern.test(lineText) && !processedLines.has(cursor)) {
            const urlLine = cursor;
            processedLines.add(urlLine);

            const descLine = cursor - 1;
            if (
                descLine >= 0
                && !processedLines.has(descLine)
                && isAutoDescription(doc.lineAt(descLine).text)
            ) {
                processedLines.add(descLine);
                ranges.push({ start: descLine, end: urlLine + 1 });
                cursor = descLine - 1;
            } else {
                ranges.push({ start: urlLine, end: urlLine + 1 });
                cursor--;
            }
        } else {
            cursor--;
        }
    }

    return ranges;
}

/**
 * Check if a line looks like an auto-generated description comment.
 * Auto descriptions are indented comment lines that don't look like user notes.
 */
function isAutoDescription(lineText: string): boolean {
    const trimmed = lineText.trim();

    if (!trimmed.startsWith('#')) { return false; }
    if (trimmed.startsWith(PUB_URL_PREFIX.trim())) { return false; }

    const content = trimmed.replace(/^#\s*/, '');

    if (content.startsWith('NOTE:')) { return false; }
    if (content.startsWith('TODO:')) { return false; }
    if (content.startsWith('FIXME:')) { return false; }
    if (content.startsWith('IMPORTANT')) { return false; }
    if (content.startsWith('CRITICAL')) { return false; }
    if (content.startsWith('WARNING')) { return false; }
    if (/^#+\s/.test(content)) { return false; }
    if (/^Because\s/.test(content)) { return false; }

    const sentencePattern = /^[A-Z][^.]*\.\.\.$|^[A-Z][a-z].*[a-z]\.?$/;
    if (sentencePattern.test(content)) { return true; }

    return false;
}
