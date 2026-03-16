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
exports.DetailViewProvider = exports.DETAIL_VIEW_ID = void 0;
const vscode = __importStar(require("vscode"));
const detail_view_html_1 = require("./detail-view-html");
const tree_commands_1 = require("../providers/tree-commands");
/** View ID for the package details webview in the sidebar. */
exports.DETAIL_VIEW_ID = 'saropaLints.packageVibrancy.details';
/** Provides the Package Details webview in the sidebar. */
class DetailViewProvider {
    _extensionUri;
    _view;
    _currentResult = null;
    constructor(_extensionUri) {
        this._extensionUri = _extensionUri;
    }
    /** Called by VS Code when the webview view becomes visible. */
    resolveWebviewView(webviewView, _context, _token) {
        this._view = webviewView;
        webviewView.webview.options = {
            enableScripts: true,
            localResourceRoots: [this._extensionUri],
        };
        webviewView.webview.html = (0, detail_view_html_1.buildDetailViewHtml)(this._currentResult);
        webviewView.webview.onDidReceiveMessage(message => this._handleMessage(message));
    }
    /** Update the detail view with a new package result. */
    update(result) {
        this._currentResult = result;
        if (this._view) {
            this._view.webview.html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        }
    }
    /** Clear the detail view to show the placeholder state. */
    clear() {
        this._currentResult = null;
        if (this._view) {
            this._view.webview.html = (0, detail_view_html_1.buildDetailViewHtml)(null);
        }
    }
    /** Reveal and focus the detail view. */
    focus() {
        if (this._view) {
            this._view.show(true);
        }
    }
    /** Get the currently displayed package result. */
    getCurrentResult() {
        return this._currentResult;
    }
    async _handleMessage(message) {
        switch (message.type) {
            case 'upgrade':
                if (message.package) {
                    await this._handleUpgrade(message.package);
                }
                break;
            case 'changelog':
                if (message.package) {
                    await vscode.commands.executeCommand('saropaLints.packageVibrancy.showChangelog', message.package);
                }
                break;
            case 'openUrl':
                if (message.url) {
                    await vscode.env.openExternal(vscode.Uri.parse(message.url));
                }
                break;
        }
    }
    async _handleUpgrade(packageName) {
        const result = this._currentResult;
        if (!result || result.package.name !== packageName) {
            return;
        }
        const latest = result.updateInfo?.latestVersion;
        if (!latest) {
            return;
        }
        const targetVersion = `^${latest}`;
        const yamlUri = await (0, tree_commands_1.findPubspecYaml)();
        if (!yamlUri) {
            return;
        }
        const doc = await vscode.workspace.openTextDocument(yamlUri);
        const edit = (0, tree_commands_1.buildVersionEdit)(doc, packageName, targetVersion);
        if (!edit) {
            vscode.window.showWarningMessage(`Could not locate version constraint for ${packageName}`);
            return;
        }
        const wsEdit = new vscode.WorkspaceEdit();
        wsEdit.replace(yamlUri, edit.range, edit.newText);
        await vscode.workspace.applyEdit(wsEdit);
        await doc.save();
        vscode.window.showInformationMessage(`Updated ${packageName} to ${targetVersion}`);
    }
}
exports.DetailViewProvider = DetailViewProvider;
//# sourceMappingURL=detail-view-provider.js.map