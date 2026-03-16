"use strict";
/**
 * D3: Inline annotations — Error Lens style line-end decorations.
 *
 * Shows violation messages at the end of affected lines in the editor.
 * One decoration type per severity (error, warning, info) for performance.
 * Respects the `saropaLints.inlineAnnotations` toggle setting.
 *
 * Known limitation: decorations are line-number-based and do not shift when
 * the user edits a file. They refresh on the next violations.json write
 * (via the file watcher) or on editor switch.
 */
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
exports.invalidateAnnotationCache = invalidateAnnotationCache;
exports.updateAnnotationsForEditor = updateAnnotationsForEditor;
exports.updateAnnotationsForAllEditors = updateAnnotationsForAllEditors;
exports.registerInlineAnnotations = registerInlineAnnotations;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const violationsReader_1 = require("./violationsReader");
const projectRoot_1 = require("./projectRoot");
// --- Decoration types (one per severity for VS Code perf) ---
const errorDecorationType = vscode.window.createTextEditorDecorationType({
    after: {
        margin: '0 0 0 2em',
        color: new vscode.ThemeColor('editorError.foreground'),
        fontStyle: 'italic',
    },
    isWholeLine: true,
});
const warningDecorationType = vscode.window.createTextEditorDecorationType({
    after: {
        margin: '0 0 0 2em',
        color: new vscode.ThemeColor('editorWarning.foreground'),
        fontStyle: 'italic',
    },
    isWholeLine: true,
});
const infoDecorationType = vscode.window.createTextEditorDecorationType({
    after: {
        margin: '0 0 0 2em',
        color: new vscode.ThemeColor('editorInfo.foreground'),
        fontStyle: 'italic',
    },
    isWholeLine: true,
});
const MAX_MESSAGE_LENGTH = 80;
// --- Violations cache ---
// Avoids re-reading violations.json from disk on every editor switch.
// Invalidated by `invalidateAnnotationCache()` (called from refreshAll).
let cachedData = null;
function getCachedViolations(root) {
    if (cachedData?.root === root)
        return cachedData.data;
    const data = (0, violationsReader_1.readViolations)(root);
    cachedData = { root, data };
    return data;
}
/** Invalidate the violations cache. Call when violations.json changes. */
function invalidateAnnotationCache() {
    cachedData = null;
}
// --- Formatting helpers ---
/** Truncate message to MAX_MESSAGE_LENGTH, appending rule name. */
function formatAnnotation(v) {
    const msg = v.message.length > MAX_MESSAGE_LENGTH
        ? v.message.slice(0, MAX_MESSAGE_LENGTH) + '…'
        : v.message;
    return `${msg} (${v.rule})`;
}
function clearAllDecorations(editor) {
    editor.setDecorations(errorDecorationType, []);
    editor.setDecorations(warningDecorationType, []);
    editor.setDecorations(infoDecorationType, []);
}
/**
 * Update inline annotations for a single editor.
 * Clears existing decorations and re-applies from cached violations data.
 */
function updateAnnotationsForEditor(editor) {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const annotationsEnabled = cfg.get('inlineAnnotations', true) ?? true;
    // Clear all decorations first — whether enabled or not.
    clearAllDecorations(editor);
    if (!annotationsEnabled)
        return;
    const root = (0, projectRoot_1.getProjectRoot)();
    if (!root)
        return;
    // Use cached data to avoid disk I/O on every editor switch.
    const data = getCachedViolations(root);
    if (!data?.violations)
        return;
    // Compute path relative to project root (where violations.json lives),
    // not workspace root — these differ when pubspec is in a subdirectory.
    const editorRelative = path.relative(root, editor.document.uri.fsPath).replace(/\\/g, '/');
    // Filter violations for this file.
    const fileViolations = data.violations.filter((v) => {
        return v.file.replace(/\\/g, '/') === editorRelative;
    });
    if (fileViolations.length === 0)
        return;
    // Group by severity, keeping only the first violation per line per severity
    // to avoid clutter.
    const errorDecos = [];
    const warningDecos = [];
    const infoDecos = [];
    const seenLines = new Map();
    for (const v of fileViolations) {
        const severity = v.severity ?? 'info';
        const lineSet = seenLines.get(severity) ?? new Set();
        seenLines.set(severity, lineSet);
        // violations.json uses 1-based lines; VS Code uses 0-based.
        const lineIndex = Math.max(0, v.line - 1);
        if (lineSet.has(lineIndex))
            continue;
        lineSet.add(lineIndex);
        // Column values are irrelevant for isWholeLine decorations — the `after`
        // pseudo-element always renders at the line end regardless of range.
        const range = new vscode.Range(lineIndex, 0, lineIndex, 0);
        const deco = {
            range,
            renderOptions: {
                after: { contentText: formatAnnotation(v) },
            },
        };
        switch (severity) {
            case 'error':
                errorDecos.push(deco);
                break;
            case 'warning':
                warningDecos.push(deco);
                break;
            default:
                infoDecos.push(deco);
        }
    }
    editor.setDecorations(errorDecorationType, errorDecos);
    editor.setDecorations(warningDecorationType, warningDecos);
    editor.setDecorations(infoDecorationType, infoDecos);
}
/** Update annotations for all visible text editors. */
function updateAnnotationsForAllEditors() {
    for (const editor of vscode.window.visibleTextEditors) {
        updateAnnotationsForEditor(editor);
    }
}
/** Register event listeners and toggle command. Returns disposables. */
function registerInlineAnnotations(context) {
    // Update when the active editor changes.
    context.subscriptions.push(vscode.window.onDidChangeActiveTextEditor((editor) => {
        if (editor)
            updateAnnotationsForEditor(editor);
    }));
    // Update when visible editors change (e.g. split view).
    context.subscriptions.push(vscode.window.onDidChangeVisibleTextEditors(() => {
        updateAnnotationsForAllEditors();
    }));
    // Toggle command.
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.toggleInlineAnnotations', async () => {
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const current = cfg.get('inlineAnnotations', true) ?? true;
        await cfg.update('inlineAnnotations', !current, vscode.ConfigurationTarget.Workspace);
        updateAnnotationsForAllEditors();
        const state = !current ? 'on' : 'off';
        void vscode.window.setStatusBarMessage(`Saropa Lints: Inline annotations ${state}`, 3000);
    }));
    // Dispose decoration types on deactivation.
    context.subscriptions.push(errorDecorationType, warningDecorationType, infoDecorationType);
}
//# sourceMappingURL=inlineAnnotations.js.map