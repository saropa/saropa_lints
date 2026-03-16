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
exports.formatAnnotation = formatAnnotation;
exports.buildAnnotationEdits = buildAnnotationEdits;
const vscode = __importStar(require("vscode"));
const annotate_headers_1 = require("./annotate-headers");
const MAX_DESC_LENGTH = 80;
const PUB_URL_PREFIX = '# https://pub.dev/packages/';
/** Format annotation comment lines for a package. */
function formatAnnotation(name, description) {
    const url = `  ${PUB_URL_PREFIX}${name}`;
    if (!description) {
        return `${url}\n`;
    }
    const truncated = description.length > MAX_DESC_LENGTH
        ? description.slice(0, MAX_DESC_LENGTH - 3) + '...'
        : description;
    return `  # ${truncated}\n${url}\n`;
}
/** Build edits to insert or replace annotations above each package. */
function buildAnnotationEdits(doc, packageNames, descriptions) {
    const edits = [];
    for (const name of packageNames) {
        const lineIdx = findPackageLine(doc, name);
        if (lineIdx === null) {
            continue;
        }
        const existing = findExistingAnnotations(doc, lineIdx, name);
        const text = formatAnnotation(name, descriptions.get(name) ?? null);
        const deleteRanges = existing.map(r => new vscode.Range(new vscode.Position(r.start, 0), new vscode.Position(r.end, 0)));
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
function findPackageLine(doc, packageName) {
    const pattern = new RegExp(`^\\s{2}${packageName}\\s*:`);
    for (let i = 0; i < doc.lineCount; i++) {
        if (pattern.test(doc.lineAt(i).text)) {
            return i;
        }
    }
    return null;
}
/**
 * Find all auto-generated annotation blocks above a package entry.
 * Scans consecutive comment lines and identifies URL + description pairs.
 * Returns an array of ranges to delete, preserving user comments.
 */
function findExistingAnnotations(doc, packageLine, packageName) {
    const urlPattern = new RegExp(`^\\s*#\\s*https://pub\\.dev/packages/${(0, annotate_headers_1.escapeRegExp)(packageName)}(?:/[\\w-]*)?\\s*$`);
    let cursor = packageLine - 1;
    if (cursor < 0) {
        return [];
    }
    const ranges = [];
    const processedLines = new Set();
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
            if (descLine >= 0
                && !processedLines.has(descLine)
                && isAutoDescription(doc.lineAt(descLine).text)) {
                processedLines.add(descLine);
                ranges.push({ start: descLine, end: urlLine + 1 });
                cursor = descLine - 1;
            }
            else {
                ranges.push({ start: urlLine, end: urlLine + 1 });
                cursor--;
            }
        }
        else {
            cursor--;
        }
    }
    return ranges;
}
/**
 * Check if a line looks like an auto-generated description comment.
 * Auto descriptions are indented comment lines that don't look like user notes.
 */
function isAutoDescription(lineText) {
    const trimmed = lineText.trim();
    if (!trimmed.startsWith('#')) {
        return false;
    }
    if (trimmed.startsWith(PUB_URL_PREFIX.trim())) {
        return false;
    }
    const content = trimmed.replace(/^#\s*/, '');
    if (content.startsWith('NOTE:')) {
        return false;
    }
    if (content.startsWith('TODO:')) {
        return false;
    }
    if (content.startsWith('FIXME:')) {
        return false;
    }
    if (content.startsWith('IMPORTANT')) {
        return false;
    }
    if (content.startsWith('CRITICAL')) {
        return false;
    }
    if (content.startsWith('WARNING')) {
        return false;
    }
    if (/^#+\s/.test(content)) {
        return false;
    }
    if (/^Because\s/.test(content)) {
        return false;
    }
    const sentencePattern = /^[A-Z][^.]*\.\.\.$|^[A-Z][a-z].*[a-z]\.?$/;
    if (sentencePattern.test(content)) {
        return true;
    }
    return false;
}
//# sourceMappingURL=annotate-packages.js.map