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
exports.findPubspecYaml = findPubspecYaml;
exports.buildVersionEdit = buildVersionEdit;
exports.readVersionConstraint = readVersionConstraint;
exports.findPackageLines = findPackageLines;
exports.buildBackupUri = buildBackupUri;
const vscode = __importStar(require("vscode"));
/**
 * Pubspec editing utilities.
 * Extracted from providers/tree-commands.ts to eliminate layer violations
 * (services should not import from providers).
 */
/** Find the first pubspec.yaml in the workspace. */
async function findPubspecYaml() {
    const files = await vscode.workspace.findFiles('**/pubspec.yaml', '**/.*/**', 1);
    return files[0] ?? null;
}
/** Build a workspace edit to replace a package's version constraint. */
function buildVersionEdit(doc, packageName, newConstraint) {
    const pattern = new RegExp(`^(\\s{2}${packageName}\\s*:\\s*)(.+)$`);
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
function readVersionConstraint(doc, packageName) {
    const pattern = new RegExp(`^\\s{2}${packageName}\\s*:\\s*(.+)$`);
    for (let i = 0; i < doc.lineCount; i++) {
        const match = doc.lineAt(i).text.match(pattern);
        if (match) {
            return match[1].trim();
        }
    }
    return null;
}
/**
 * Find the line range of a package entry in pubspec.yaml.
 * Includes the header line and any continuation lines (deeper indent).
 */
function findPackageLines(doc, packageName) {
    const header = new RegExp(`^\\s{2}${packageName}\\s*:`);
    for (let i = 0; i < doc.lineCount; i++) {
        if (!header.test(doc.lineAt(i).text)) {
            continue;
        }
        let end = i + 1;
        while (end < doc.lineCount) {
            const text = doc.lineAt(end).text;
            if (text.trim() === '' || /^\s{4,}\S/.test(text)) {
                end++;
            }
            else {
                break;
            }
        }
        return { start: i, end };
    }
    return null;
}
/** Build a backup URI for pubspec.yaml with timestamp. */
function buildBackupUri(yamlUri) {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const stamp = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}`
        + `_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
    return vscode.Uri.joinPath(yamlUri, '..', `pubspec.yaml.bak.${stamp}`);
}
//# sourceMappingURL=pubspec-editor.js.map