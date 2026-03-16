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
exports.registerAnnotateCommand = registerAnnotateCommand;
const vscode = __importStar(require("vscode"));
const pubspec_parser_1 = require("../services/pubspec-parser");
const pub_dev_api_1 = require("../services/pub-dev-api");
const extension_activation_1 = require("../extension-activation");
const pubspec_editor_1 = require("../services/pubspec-editor");
const annotate_packages_1 = require("./annotate-packages");
const annotate_headers_1 = require("./annotate-headers");
const SDK_PACKAGES = new Set([
    'flutter', 'flutter_test', 'flutter_localizations',
    'flutter_web_plugins', 'flutter_driver',
]);
const FETCH_CONCURRENCY = 3;
let annotateInProgress = false;
/** Register the annotate-pubspec command. */
function registerAnnotateCommand(context) {
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.packageVibrancy.annotatePubspec', () => annotatePubspec()));
}
/** Add description comments above each dependency in pubspec.yaml. */
async function annotatePubspec() {
    if (annotateInProgress) {
        vscode.window.showWarningMessage('Annotation already in progress');
        return;
    }
    annotateInProgress = true;
    try {
        await annotatePubspecInner();
    }
    finally {
        annotateInProgress = false;
    }
}
async function annotatePubspecInner() {
    const yamlUri = await (0, pubspec_editor_1.findPubspecYaml)();
    if (!yamlUri) {
        vscode.window.showWarningMessage('No pubspec.yaml found in workspace');
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const content = doc.getText();
    const { directDeps, devDeps } = (0, pubspec_parser_1.parsePubspecYaml)(content);
    const overrides = (0, pubspec_parser_1.parseDependencyOverrides)(content);
    const allDeps = [...directDeps, ...devDeps]
        .filter(n => !SDK_PACKAGES.has(n));
    if (allDeps.length === 0) {
        vscode.window.showInformationMessage('No dependencies to annotate');
        return;
    }
    const descriptions = await fetchDescriptions(allDeps);
    const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, allDeps, descriptions);
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const insertSectionHeaders = config.get('annotateSectionHeaders', true);
    const allSectionEdits = [];
    if (insertSectionHeaders) {
        allSectionEdits.push(...(0, annotate_headers_1.buildSectionHeaderEdits)(doc));
        allSectionEdits.push(...(0, annotate_headers_1.buildSubSectionHeaderEdits)(doc));
        const overrideMarker = (0, annotate_headers_1.buildOverrideMarkerEdit)(doc, directDeps, overrides);
        if (overrideMarker) {
            allSectionEdits.push(overrideMarker);
        }
    }
    if (edits.length === 0 && allSectionEdits.length === 0) {
        return;
    }
    const wsEdit = new vscode.WorkspaceEdit();
    for (const edit of allSectionEdits) {
        if (edit.deleteRange) {
            wsEdit.delete(yamlUri, edit.deleteRange);
        }
        wsEdit.insert(yamlUri, edit.insertPos, edit.text);
    }
    for (const edit of edits) {
        for (const delRange of edit.deleteRanges) {
            wsEdit.delete(yamlUri, delRange);
        }
        wsEdit.insert(yamlUri, edit.insertPos, edit.text);
    }
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
    const parts = [];
    if (edits.length > 0) {
        parts.push(`${edits.length} dependencies`);
    }
    if (allSectionEdits.length > 0) {
        parts.push(`${allSectionEdits.length} section headers`);
    }
    vscode.window.showInformationMessage(`Annotated ${parts.join(' and ')} in pubspec.yaml`);
}
/** Fetch descriptions from cached scan results or pub.dev API. */
async function fetchDescriptions(names) {
    const map = new Map();
    const missing = [];
    for (const r of (0, extension_activation_1.getLatestResults)()) {
        if (r.pubDev?.description) {
            map.set(r.package.name, r.pubDev.description);
        }
    }
    for (const name of names) {
        if (!map.has(name)) {
            missing.push(name);
        }
    }
    if (missing.length === 0) {
        return map;
    }
    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: 'Fetching package descriptions...',
    }, async (progress) => {
        let completed = 0;
        let cursor = 0;
        async function next() {
            while (cursor < missing.length) {
                const name = missing[cursor++];
                progress.report({
                    message: `${name} (${++completed}/${missing.length})`,
                });
                const info = await (0, pub_dev_api_1.fetchPackageInfo)(name);
                if (info?.description) {
                    map.set(name, info.description);
                }
            }
        }
        const workers = Array.from({ length: Math.min(FETCH_CONCURRENCY, missing.length) }, () => next());
        await Promise.all(workers);
    });
    return map;
}
//# sourceMappingURL=annotate-command.js.map