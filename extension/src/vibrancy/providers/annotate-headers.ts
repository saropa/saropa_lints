import * as vscode from 'vscode';

const SECTION_HEADERS: ReadonlyMap<string, string> = new Map([
    ['dependencies:', 'DEPENDENCIES'], ['dev_dependencies:', 'DEV DEPENDENCIES'],
    ['dependency_overrides:', 'DEP OVERRIDES'], ['flutter:', 'FLUTTER'],
    ['flutter_launcher_icons:', 'APP ICONS'], ['flutter_native_splash:', 'NATIVE SPLASH'],
]);

const SUB_SECTION_HEADERS: ReadonlyMap<string, { parent: string; title: string }> = new Map([
    ['assets:', { parent: 'flutter:', title: 'ASSETS' }],
    ['fonts:', { parent: 'flutter:', title: 'FONTS' }],
]);

const OVERRIDE_MARKER_TITLE = 'DEP OVERRIDDEN BELOW';

/** An edit to insert or replace a decorative section header. */
export interface SectionHeaderEdit {
    readonly insertPos: vscode.Position;
    readonly text: string;
    readonly deleteRange?: vscode.Range;
}

/** Escape special regex characters in a string. */
export function escapeRegExp(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Build an edit that inserts a header, optionally replacing an existing one. */
function buildHeaderEdit(
    lineIdx: number,
    title: string,
    existing: { start: number; end: number } | null,
): SectionHeaderEdit {
    const text = formatSectionHeader(title);
    if (existing) {
        return {
            insertPos: new vscode.Position(existing.start, 0),
            text,
            deleteRange: new vscode.Range(
                new vscode.Position(existing.start, 0),
                new vscode.Position(existing.end, 0),
            ),
        };
    }
    return { insertPos: new vscode.Position(lineIdx, 0), text };
}

/** Build edits to insert section headers above major pubspec sections. */
export function buildSectionHeaderEdits(doc: vscode.TextDocument): SectionHeaderEdit[] {
    const edits: SectionHeaderEdit[] = [];
    for (const [sectionKey, title] of SECTION_HEADERS) {
        const lineIdx = findSectionLine(doc, sectionKey);
        if (lineIdx === null) { continue; }
        edits.push(buildHeaderEdit(lineIdx, title, findExistingSectionHeader(doc, lineIdx)));
    }
    return edits;
}

/** Find the line number of a top-level section in pubspec. */
function findSectionLine(doc: vscode.TextDocument, sectionKey: string): number | null {
    const pattern = new RegExp(`^${escapeRegExp(sectionKey)}\\s*$`);
    for (let i = 0; i < doc.lineCount; i++) {
        if (pattern.test(doc.lineAt(i).text)) { return i; }
    }
    return null;
}

/**
 * Detect existing section header block above a section.
 * Looks for the decorative comment pattern with hash borders.
 */
function findExistingSectionHeader(
    doc: vscode.TextDocument,
    sectionLine: number,
): { start: number; end: number } | null {
    let cursor = sectionLine - 1;
    if (cursor < 0) { return null; }

    while (cursor >= 0 && doc.lineAt(cursor).text.trim() === '') {
        cursor--;
    }
    if (cursor < 0) { return null; }

    const bottomBorder = doc.lineAt(cursor).text;
    if (!bottomBorder.match(/^\s*#{30,}/)) { return null; }

    const endLine = cursor + 1;
    cursor--;

    while (cursor >= 0) {
        const line = doc.lineAt(cursor).text;
        if (line.trim() === '' || line.trim() === '#') {
            cursor--;
            continue;
        }
        if (line.match(/^\s*#{30,}/)) {
            return { start: cursor, end: endLine };
        }
        if (!line.match(/^\s*#/)) {
            break;
        }
        cursor--;
    }

    return null;
}

/** Format a decorative section header block. */
export function formatSectionHeader(title: string): string {
    const hashLine = '#'.repeat(98);
    const leftHashes = '##########################';
    const rightHashes = '#####################################';
    const middleWidth = 35;
    const spacerLine = leftHashes + ' '.repeat(middleWidth) + rightHashes;
    const paddedTitle = title.padStart(
        Math.floor((middleWidth + title.length) / 2),
    ).padEnd(middleWidth);
    const titleLine = leftHashes + paddedTitle + rightHashes;
    const blankLines = Array(9).fill('#').join('\n  ');

    return [
        '',
        `  ${blankLines}`,
        `  ${hashLine}`,
        `  ${spacerLine}`,
        `  ${titleLine}`,
        `  ${spacerLine}`,
        `  ${hashLine}`,
        '',
    ].join('\n');
}

/** Build edits for sub-section headers (e.g. assets: within flutter:). */
export function buildSubSectionHeaderEdits(doc: vscode.TextDocument): SectionHeaderEdit[] {
    const edits: SectionHeaderEdit[] = [];
    for (const [subKey, { parent, title }] of SUB_SECTION_HEADERS) {
        const lineIdx = findSubSectionLine(doc, parent, subKey);
        if (lineIdx === null) { continue; }
        edits.push(buildHeaderEdit(lineIdx, title, findExistingSectionHeader(doc, lineIdx)));
    }
    return edits;
}

/** Find a sub-section line within a parent section. */
function findSubSectionLine(
    doc: vscode.TextDocument, parentKey: string, subKey: string,
): number | null {
    const parentPattern = new RegExp(`^${escapeRegExp(parentKey)}\\s*$`);
    const subPattern = new RegExp(`^\\s{2}${escapeRegExp(subKey)}\\s*$`);

    let inParent = false;
    for (let i = 0; i < doc.lineCount; i++) {
        const line = doc.lineAt(i).text;
        if (parentPattern.test(line)) {
            inParent = true;
            continue;
        }
        if (inParent) {
            if (/^\S/.test(line) && !line.trim().startsWith('#')) {
                inParent = false;
                continue;
            }
            if (subPattern.test(line)) { return i; }
        }
    }
    return null;
}

/**
 * Build edit to insert "DEP OVERRIDDEN BELOW" marker above the first
 * dependency that has a corresponding override.
 */
export function buildOverrideMarkerEdit(
    doc: vscode.TextDocument,
    directDeps: string[],
    overrides: string[],
): SectionHeaderEdit | null {
    if (overrides.length === 0) { return null; }

    const overrideSet = new Set(overrides);
    const overriddenDeps = directDeps.filter(d => overrideSet.has(d));
    if (overriddenDeps.length === 0) { return null; }

    const firstOverriddenLine = findFirstOverriddenLine(doc, overrideSet);
    if (firstOverriddenLine === null) { return null; }

    const existing = findExistingOverrideMarker(doc, firstOverriddenLine);
    return buildHeaderEdit(firstOverriddenLine, OVERRIDE_MARKER_TITLE, existing);
}

/** Find the first dependency line in the dependencies: section that has an override. */
function findFirstOverriddenLine(
    doc: vscode.TextDocument, overrideSet: Set<string>,
): number | null {
    const depPattern = /^\s{2}(\w[\w_]*)\s*:/;
    let inDeps = false;
    for (let i = 0; i < doc.lineCount; i++) {
        const line = doc.lineAt(i).text;
        if (/^dependencies\s*:/.test(line)) { inDeps = true; continue; }
        if (inDeps && /^\S/.test(line) && !line.trim().startsWith('#')) { break; }
        if (!inDeps) { continue; }
        const match = line.match(depPattern);
        if (match && overrideSet.has(match[1])) { return i; }
    }
    return null;
}

/**
 * Find existing override marker above a line.
 * Looks for the decorative header pattern containing "OVERRID".
 */
function findExistingOverrideMarker(
    doc: vscode.TextDocument, belowLine: number,
): { start: number; end: number } | null {
    let cursor = belowLine - 1;
    if (cursor < 0) { return null; }

    while (cursor >= 0 && doc.lineAt(cursor).text.trim() === '') { cursor--; }
    if (cursor < 0) { return null; }

    if (!doc.lineAt(cursor).text.match(/^\s*#{30,}/)) { return null; }

    const endLine = cursor + 1;
    cursor--;

    let foundOverrideText = false;
    while (cursor >= 0) {
        const line = doc.lineAt(cursor).text;
        if (line.includes('OVERRID')) { foundOverrideText = true; }
        if (line.trim() === '' || line.trim() === '#') { cursor--; continue; }
        if (line.match(/^\s*#{30,}/)) {
            return foundOverrideText ? { start: cursor, end: endLine } : null;
        }
        if (!line.match(/^\s*#/)) { break; }
        cursor--;
    }
    return null;
}
