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
exports.readVersionConstraint = exports.findPackageLines = exports.buildVersionEdit = exports.findPubspecYaml = void 0;
exports.registerTreeCommands = registerTreeCommands;
const vscode = __importStar(require("vscode"));
const pubspec_parser_1 = require("../services/pubspec-parser");
const pubspec_editor_1 = require("../services/pubspec-editor");
Object.defineProperty(exports, "findPubspecYaml", { enumerable: true, get: function () { return pubspec_editor_1.findPubspecYaml; } });
Object.defineProperty(exports, "buildVersionEdit", { enumerable: true, get: function () { return pubspec_editor_1.buildVersionEdit; } });
Object.defineProperty(exports, "findPackageLines", { enumerable: true, get: function () { return pubspec_editor_1.findPackageLines; } });
Object.defineProperty(exports, "readVersionConstraint", { enumerable: true, get: function () { return pubspec_editor_1.readVersionConstraint; } });
const config_service_1 = require("../services/config-service");
const copyTreeAsJson_1 = require("../../copyTreeAsJson");
const treeSerializers_1 = require("../../treeSerializers");
const extension_activation_1 = require("../extension-activation");
const comparison_webview_1 = require("../views/comparison-webview");
const comparison_ranker_1 = require("../scoring/comparison-ranker");
let _detailViewProvider = null;
let _detailLogger = null;
/**
 * Guard for commands that require a PackageItem from the Packages view.
 * Returns true if item has result.package.name; otherwise shows a warning and returns false.
 */
function requirePackageItem(item, actionLabel) {
    if (item?.result?.package?.name) {
        return true;
    }
    vscode.window.showWarningMessage(`${actionLabel} is only available for package items in the Packages view.`);
    return false;
}
/** Register tree-item commands (navigate, open, update, copy, suppress). */
function registerTreeCommands(context, treeProvider, detailViewProvider, detailLogger) {
    _detailViewProvider = detailViewProvider ?? null;
    _detailLogger = detailLogger ?? null;
    // Bind getChildren for the copy command to use for recursive serialization.
    const getChildren = (n) => treeProvider.getChildren(n);
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.packageVibrancy.goToPackage', goToPackage), vscode.commands.registerCommand('saropaLints.packageVibrancy.goToLine', goToLine), vscode.commands.registerCommand('saropaLints.packageVibrancy.openOnPubDev', openOnPubDev), vscode.commands.registerCommand('saropaLints.packageVibrancy.showChangelog', showChangelog), vscode.commands.registerCommand('saropaLints.packageVibrancy.updateToLatest', updateToLatest), vscode.commands.registerCommand('saropaLints.packageVibrancy.copyAsJson', (item, selected) => (0, copyTreeAsJson_1.copyTreeNodesToClipboard)(item, selected, treeSerializers_1.serializeVibrancyNode, getChildren, 'Vibrancy')), vscode.commands.registerCommand('saropaLints.packageVibrancy.suppressPackage', suppressPackage), vscode.commands.registerCommand('saropaLints.packageVibrancy.unsuppressPackage', unsuppressPackage), vscode.commands.registerCommand('saropaLints.packageVibrancy.openUrl', openUrl), vscode.commands.registerCommand('saropaLints.packageVibrancy.commentOutUnused', commentOutUnused), vscode.commands.registerCommand('saropaLints.packageVibrancy.deleteUnused', deleteUnused), vscode.commands.registerCommand('saropaLints.packageVibrancy.focusDetails', focusDetails), vscode.commands.registerCommand('saropaLints.packageVibrancy.logDetails', logDetails), vscode.commands.registerCommand('saropaLints.packageVibrancy.logAllDetails', logAllDetails), vscode.commands.registerCommand('saropaLints.packageVibrancy.updateFromCodeLens', updateFromCodeLens), vscode.commands.registerCommand('saropaLints.packageVibrancy.focusPackageInTree', focusPackageInTree), vscode.commands.registerCommand('saropaLints.packageVibrancy.compareSelected', compareSelected));
}
/**
 * Resolve the pubspec.yaml URI, preferring the scanned URI from the last scan
 * over a workspace-wide glob (which can return a wrong file in multi-root workspaces).
 */
async function resolveScannedPubspec() {
    return (0, extension_activation_1.getScannedPubspecUri)() ?? await (0, pubspec_editor_1.findPubspecYaml)();
}
/** Navigate to a package's entry in pubspec.yaml. */
async function goToPackage(packageName) {
    if (!packageName || typeof packageName !== 'string') {
        return;
    }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) {
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const range = (0, pubspec_parser_1.findPackageRange)(doc.getText(), packageName);
    if (!range) {
        return;
    }
    const pos = new vscode.Position(range.line, range.startChar);
    const sel = new vscode.Selection(pos, pos);
    await vscode.window.showTextDocument(doc, { selection: sel });
}
/** Open pubspec.yaml at a given 0-based line. Used when clicking a problem in the Problems view. */
async function goToLine(line) {
    if (line == null || typeof line !== 'number' || line < 0) {
        return;
    }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) {
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const pos = new vscode.Position(line, 0);
    const sel = new vscode.Selection(pos, pos);
    await vscode.window.showTextDocument(doc, { selection: sel });
}
/** Open a package's pub.dev page in the browser. */
async function openOnPubDev(item) {
    if (!requirePackageItem(item, 'Open on pub.dev')) {
        return;
    }
    const url = `https://pub.dev/packages/${item.result.package.name}`;
    await vscode.env.openExternal(vscode.Uri.parse(url));
}
/** Open a package's changelog on pub.dev (used by detail view). */
async function showChangelog(packageName) {
    if (!packageName || typeof packageName !== 'string') {
        return;
    }
    const url = `https://pub.dev/packages/${packageName}/changelog`;
    await vscode.env.openExternal(vscode.Uri.parse(url));
}
/** Open a URL in the default browser (from click or inline action). */
async function openUrl(urlOrItem) {
    if (!urlOrItem) {
        return;
    }
    const url = typeof urlOrItem === 'string' ? urlOrItem : urlOrItem.url;
    if (!url) {
        return;
    }
    await vscode.env.openExternal(vscode.Uri.parse(url));
}
/** Replace the version constraint in pubspec.yaml with ^latest. */
async function updateToLatest(item) {
    if (!requirePackageItem(item, 'Update to Latest')) {
        return;
    }
    const latest = item.result.updateInfo?.latestVersion;
    if (!latest) {
        return;
    }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) {
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, item.result.package.name, `^${latest}`);
    if (!edit) {
        vscode.window.showWarningMessage(`Could not locate version constraint for ${item.result.package.name}`);
        return;
    }
    const wsEdit = new vscode.WorkspaceEdit();
    wsEdit.replace(yamlUri, edit.range, edit.newText);
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
}
// copyAsJson is now handled inline by copyTreeNodesToClipboard in registerTreeCommands.
/** Add a package to the suppressed list in workspace settings. */
async function suppressPackage(item) {
    if (!requirePackageItem(item, 'Suppress')) {
        return;
    }
    await (0, config_service_1.addSuppressedPackage)(item.result.package.name);
}
/** Remove a package from the suppressed list in workspace settings. */
async function unsuppressPackage(item) {
    if (!requirePackageItem(item, 'Unsuppress')) {
        return;
    }
    await (0, config_service_1.removeSuppressedPackage)(item.result.package.name);
}
/** Comment out an unused dependency in pubspec.yaml. */
async function commentOutUnused(item) {
    if (!requirePackageItem(item, 'Comment Out Unused')) {
        return;
    }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) {
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const lines = (0, pubspec_editor_1.findPackageLines)(doc, item.result.package.name);
    if (!lines) {
        return;
    }
    const wsEdit = new vscode.WorkspaceEdit();
    for (let i = lines.start; i < lines.end; i++) {
        wsEdit.insert(yamlUri, new vscode.Position(i, 0), '# ');
    }
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
}
/** Delete an unused dependency from pubspec.yaml, creating a backup. */
async function deleteUnused(item) {
    if (!requirePackageItem(item, 'Delete Unused')) {
        return;
    }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) {
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const lines = (0, pubspec_editor_1.findPackageLines)(doc, item.result.package.name);
    if (!lines) {
        return;
    }
    const backupUri = (0, pubspec_editor_1.buildBackupUri)(yamlUri);
    const content = new TextEncoder().encode(doc.getText());
    await vscode.workspace.fs.writeFile(backupUri, content);
    const wsEdit = new vscode.WorkspaceEdit();
    const range = new vscode.Range(new vscode.Position(lines.start, 0), new vscode.Position(lines.end, 0));
    wsEdit.delete(yamlUri, range);
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
    const backupName = backupUri.path.split('/').pop();
    vscode.window.showInformationMessage(`Deleted ${item.result.package.name} from pubspec.yaml (backup: ${backupName})`);
}
/** Focus the package details view in the sidebar. */
function focusDetails() {
    if (_detailViewProvider) {
        _detailViewProvider.focus();
    }
}
/** Log a package's details to the output channel. */
function logDetails(item) {
    if (!requirePackageItem(item, 'Log to Output')) {
        return;
    }
    if (!_detailLogger) {
        return;
    }
    _detailLogger.logPackage(item.result);
    _detailLogger.show();
}
/** Log all package details to the output channel. */
function logAllDetails() {
    if (!_detailLogger) {
        return;
    }
    const results = (0, extension_activation_1.getLatestResults)();
    if (results.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }
    _detailLogger.clear();
    _detailLogger.logAllPackages(results);
    _detailLogger.show();
}
/** Update a package version directly from CodeLens click. */
async function updateFromCodeLens(args) {
    if (!args || !args.packageName || !args.targetVersion) {
        return;
    }
    const yamlUri = args.pubspecPath
        ? vscode.Uri.file(args.pubspecPath)
        : await resolveScannedPubspec();
    if (!yamlUri) {
        vscode.window.showWarningMessage('Could not find pubspec.yaml');
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const newConstraint = `^${args.targetVersion}`;
    const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, args.packageName, newConstraint);
    if (!edit) {
        vscode.window.showWarningMessage(`Could not locate version constraint for ${args.packageName}`);
        return;
    }
    const wsEdit = new vscode.WorkspaceEdit();
    wsEdit.replace(yamlUri, edit.range, edit.newText);
    const applied = await vscode.workspace.applyEdit(wsEdit);
    if (applied) {
        await doc.save();
        vscode.window.showInformationMessage(`Updated ${args.packageName} to ${newConstraint}`);
    }
    else {
        vscode.window.showWarningMessage(`Failed to update ${args.packageName}`);
    }
}
/** Focus a package in the tree view and show its details. */
async function focusPackageInTree(packageName) {
    if (!packageName) {
        return;
    }
    await vscode.commands.executeCommand('saropaLints.packageVibrancy.packages.focus');
    const results = (0, extension_activation_1.getLatestResults)();
    const result = results.find(r => r.package.name === packageName);
    if (result && _detailViewProvider) {
        _detailViewProvider.update(result);
    }
}
/** Compare selected packages in a side-by-side view. */
function compareSelected(_item, selectedItems) {
    const raw = Array.isArray(selectedItems) ? selectedItems : [];
    const items = raw.filter((i) => !!i?.result);
    if (items.length < 2) {
        vscode.window.showWarningMessage('Select 2-3 packages to compare');
        return;
    }
    if (items.length > 3) {
        vscode.window.showWarningMessage('Maximum 3 packages for comparison');
        return;
    }
    const comparisonData = items.map(item => (0, comparison_ranker_1.resultToComparisonData)(item.result, true));
    comparison_webview_1.ComparisonPanel.createOrShow(comparisonData);
}
//# sourceMappingURL=tree-commands.js.map