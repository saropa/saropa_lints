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
exports.ComparisonPanel = void 0;
const vscode = __importStar(require("vscode"));
const comparison_html_1 = require("./comparison-html");
const comparison_ranker_1 = require("../scoring/comparison-ranker");
const pubspec_editor_1 = require("../services/pubspec-editor");
/** Singleton webview panel for package comparison. */
class ComparisonPanel {
    static currentPanel;
    _panel;
    _disposables = [];
    /** Create or reveal the comparison panel. */
    static createOrShow(packages) {
        if (ComparisonPanel.currentPanel) {
            ComparisonPanel.currentPanel._panel.reveal();
            ComparisonPanel.currentPanel._updateContent(packages);
            return;
        }
        const panel = vscode.window.createWebviewPanel('saropaPackageComparison', 'Package Comparison', vscode.ViewColumn.One, { enableScripts: true, retainContextWhenHidden: true });
        ComparisonPanel.currentPanel = new ComparisonPanel(panel, packages);
    }
    constructor(panel, packages) {
        this._panel = panel;
        this._updateContent(packages);
        this._panel.onDidDispose(() => this._dispose(), null, this._disposables);
        this._panel.webview.onDidReceiveMessage(message => this._handleMessage(message), null, this._disposables);
    }
    _updateContent(packages) {
        const ranked = (0, comparison_ranker_1.rankPackages)(packages);
        this._panel.webview.html = (0, comparison_html_1.buildComparisonHtml)(ranked);
    }
    async _handleMessage(message) {
        if (message.type !== 'addPackage') {
            return;
        }
        const { name, version } = message;
        await addPackageToPubspec(name, version);
    }
    _dispose() {
        ComparisonPanel.currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}
exports.ComparisonPanel = ComparisonPanel;
async function addPackageToPubspec(name, version) {
    const yamlUri = await (0, pubspec_editor_1.findPubspecYaml)();
    if (!yamlUri) {
        vscode.window.showWarningMessage('No pubspec.yaml found');
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const text = doc.getText();
    const lines = text.split('\n');
    let depSectionIndex = -1;
    for (let i = 0; i < lines.length; i++) {
        if (/^dependencies:\s*$/.test(lines[i])) {
            depSectionIndex = i;
            break;
        }
    }
    if (depSectionIndex < 0) {
        vscode.window.showWarningMessage('Could not find dependencies section');
        return;
    }
    let insertIndex = depSectionIndex + 1;
    while (insertIndex < lines.length) {
        const line = lines[insertIndex];
        if (/^\S/.test(line) && !line.trim().startsWith('#')) {
            break;
        }
        insertIndex++;
    }
    const constraint = version ? `^${version}` : 'any';
    const newLine = `  ${name}: ${constraint}\n`;
    const edit = new vscode.WorkspaceEdit();
    const position = new vscode.Position(insertIndex, 0);
    edit.insert(yamlUri, position, newLine);
    const applied = await vscode.workspace.applyEdit(edit);
    if (applied) {
        await doc.save();
        vscode.window.showInformationMessage(`Added ${name}: ${constraint} to pubspec.yaml`);
    }
    else {
        vscode.window.showWarningMessage(`Failed to add ${name} to pubspec.yaml`);
    }
}
//# sourceMappingURL=comparison-webview.js.map