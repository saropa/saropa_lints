"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.escapeRegExp = escapeRegExp;
exports.buildSectionHeaderEdits = buildSectionHeaderEdits;
exports.formatSectionHeader = formatSectionHeader;
exports.buildSubSectionHeaderEdits = buildSubSectionHeaderEdits;
exports.buildOverrideMarkerEdit = buildOverrideMarkerEdit;
const vscode = __importStar(require("vscode"));
const SECTION_HEADERS = new Map([
    ['dependencies:', 'DEPENDENCIES'], ['dev_dependencies:', 'DEV DEPENDENCIES'],
    ['dependency_overrides:', 'DEP OVERRIDES'], ['flutter:', 'FLUTTER'],
    ['flutter_launcher_icons:', 'APP ICONS'], ['flutter_native_splash:', 'NATIVE SPLASH'],
]);
const SUB_SECTION_HEADERS = new Map([
    ['assets:', { parent: 'flutter:', title: 'ASSETS' }],
    ['fonts:', { parent: 'flutter:', title: 'FONTS' }],
]);
const OVERRIDE_MARKER_TITLE = 'DEP OVERRIDDEN BELOW';
/** Escape special regex characters in a string. */
function escapeRegExp(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
/** Build an edit that inserts a header, optionally replacing an existing one. */
function buildHeaderEdit(lineIdx, title, existing) {
    const text = formatSectionHeader(title);
    if (existing) {
        return {
            insertPos: new vscode.Position(existing.start, 0),
            text,
            deleteRange: new vscode.Range(new vscode.Position(existing.start, 0), new vscode.Position(existing.end, 0)),
        };
    }
    return { insertPos: new vscode.Position(lineIdx, 0), text };
}
/** Build edits to insert section headers above major pubspec sections. */
function buildSectionHeaderEdits(doc) {
    const edits = [];
    for (const [sectionKey, title] of SECTION_HEADERS) {
        const lineIdx = findSectionLine(doc, sectionKey);
        if (lineIdx === null) {
            continue;
        }
        edits.push(buildHeaderEdit(lineIdx, title, findExistingSectionHeader(doc, lineIdx)));
    }
    return edits;
}
/** Find the line number of a top-level section in pubspec. */
function findSectionLine(doc, sectionKey) {
    const pattern = new RegExp(`^${escapeRegExp(sectionKey)}\\s*$`);
    for (let i = 0; i < doc.lineCount; i++) {
        if (pattern.test(doc.lineAt(i).text)) {
            return i;
        }
    }
    return null;
}
/**
 * Detect existing section header block above a section.
 * Looks for the decorative comment pattern with hash borders.
 */
function findExistingSectionHeader(doc, sectionLine) {
    let cursor = sectionLine - 1;
    if (cursor < 0) {
        return null;
    }
    while (cursor >= 0 && doc.lineAt(cursor).text.trim() === '') {
        cursor--;
    }
    if (cursor < 0) {
        return null;
    }
    const bottomBorder = doc.lineAt(cursor).text;
    if (!bottomBorder.match(/^\s*#{30,}/)) {
        return null;
    }
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
function formatSectionHeader(title) {
    const hashLine = '#'.repeat(98);
    const leftHashes = '##########################';
    const rightHashes = '#####################################';
    const middleWidth = 35;
    const spacerLine = leftHashes + ' '.repeat(middleWidth) + rightHashes;
    const paddedTitle = title.padStart(Math.floor((middleWidth + title.length) / 2)).padEnd(middleWidth);
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
function buildSubSectionHeaderEdits(doc) {
    const edits = [];
    for (const [subKey, { parent, title }] of SUB_SECTION_HEADERS) {
        const lineIdx = findSubSectionLine(doc, parent, subKey);
        if (lineIdx === null) {
            continue;
        }
        edits.push(buildHeaderEdit(lineIdx, title, findExistingSectionHeader(doc, lineIdx)));
    }
    return edits;
}
/** Find a sub-section line within a parent section. */
function findSubSectionLine(doc, parentKey, subKey) {
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
            if (subPattern.test(line)) {
                return i;
            }
        }
    }
    return null;
}
/**
 * Build edit to insert "DEP OVERRIDDEN BELOW" marker above the first
 * dependency that has a corresponding override.
 */
function buildOverrideMarkerEdit(doc, directDeps, overrides) {
    if (overrides.length === 0) {
        return null;
    }
    const overrideSet = new Set(overrides);
    const overriddenDeps = directDeps.filter(d => overrideSet.has(d));
    if (overriddenDeps.length === 0) {
        return null;
    }
    const firstOverriddenLine = findFirstOverriddenLine(doc, overrideSet);
    if (firstOverriddenLine === null) {
        return null;
    }
    const existing = findExistingOverrideMarker(doc, firstOverriddenLine);
    return buildHeaderEdit(firstOverriddenLine, OVERRIDE_MARKER_TITLE, existing);
}
/** Find the first dependency line in the dependencies: section that has an override. */
function findFirstOverriddenLine(doc, overrideSet) {
    const depPattern = /^\s{2}(\w[\w_]*)\s*:/;
    let inDeps = false;
    for (let i = 0; i < doc.lineCount; i++) {
        const line = doc.lineAt(i).text;
        if (/^dependencies\s*:/.test(line)) {
            inDeps = true;
            continue;
        }
        if (inDeps && /^\S/.test(line) && !line.trim().startsWith('#')) {
            break;
        }
        if (!inDeps) {
            continue;
        }
        const match = line.match(depPattern);
        if (match && overrideSet.has(match[1])) {
            return i;
        }
    }
    return null;
}
/**
 * Find existing override marker above a line.
 * Looks for the decorative header pattern containing "OVERRID".
 */
function findExistingOverrideMarker(doc, belowLine) {
    let cursor = belowLine - 1;
    if (cursor < 0) {
        return null;
    }
    while (cursor >= 0 && doc.lineAt(cursor).text.trim() === '') {
        cursor--;
    }
    if (cursor < 0) {
        return null;
    }
    if (!doc.lineAt(cursor).text.match(/^\s*#{30,}/)) {
        return null;
    }
    const endLine = cursor + 1;
    cursor--;
    let foundOverrideText = false;
    while (cursor >= 0) {
        const line = doc.lineAt(cursor).text;
        if (line.includes('OVERRID')) {
            foundOverrideText = true;
        }
        if (line.trim() === '' || line.trim() === '#') {
            cursor--;
            continue;
        }
        if (line.match(/^\s*#{30,}/)) {
            return foundOverrideText ? { start: cursor, end: endLine } : null;
        }
        if (!line.match(/^\s*#/)) {
            break;
        }
        cursor--;
    }
    return null;
}
//# sourceMappingURL=annotate-headers.js.map