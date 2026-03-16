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
exports.sortDependencies = sortDependencies;
const vscode = __importStar(require("vscode"));
const SDK_PACKAGES = new Set(['flutter', 'flutter_test', 'flutter_localizations', 'flutter_web_plugins']);
const DEPENDENCY_SECTIONS = ['dependencies', 'dev_dependencies', 'dependency_overrides'];
/**
 * Sort dependencies alphabetically in pubspec.yaml.
 * Preserves comments and multi-line dependency specs.
 */
async function sortDependencies(pubspecUri, options = { sdkFirst: true }) {
    const doc = await vscode.workspace.openTextDocument(pubspecUri);
    const content = doc.getText();
    const lines = content.split('\n');
    const edits = [];
    const sectionsModified = [];
    let totalMoved = 0;
    for (const section of DEPENDENCY_SECTIONS) {
        const sectionInfo = findSection(lines, section);
        if (!sectionInfo) {
            continue;
        }
        const entries = parseEntries(lines, sectionInfo.start, sectionInfo.end);
        if (entries.length < 2) {
            continue;
        }
        const sorted = sortEntries(entries, options.sdkFirst);
        const moved = countMoved(entries, sorted);
        if (moved === 0) {
            continue;
        }
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
function findSection(lines, sectionName) {
    const headerPattern = new RegExp(`^${sectionName}:\\s*$`);
    let headerLine = -1;
    for (let i = 0; i < lines.length; i++) {
        if (headerPattern.test(lines[i])) {
            headerLine = i;
            break;
        }
    }
    if (headerLine === -1) {
        return null;
    }
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
        }
        else {
            break;
        }
    }
    while (end > start && lines[end - 1].trim() === '') {
        end--;
    }
    return start < end ? { start, end } : null;
}
function parseEntries(lines, start, end) {
    const entries = [];
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
        const entryLines = [line];
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
            }
            else {
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
function sortEntries(entries, sdkFirst) {
    return [...entries].sort((a, b) => {
        if (sdkFirst) {
            if (a.isSdk && !b.isSdk) {
                return -1;
            }
            if (!a.isSdk && b.isSdk) {
                return 1;
            }
        }
        return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
    });
}
function countMoved(original, sorted) {
    let moved = 0;
    for (let i = 0; i < original.length; i++) {
        if (original[i].name !== sorted[i].name) {
            moved++;
        }
    }
    return moved;
}
//# sourceMappingURL=pubspec-sorter.js.map