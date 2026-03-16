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
exports.AboutPanel = void 0;
const vscode = __importStar(require("vscode"));
const about_html_1 = require("./about-html");
/** Singleton webview panel showing extension info and links. */
class AboutPanel {
    static currentPanel;
    _panel;
    _disposables = [];
    static createOrShow(version) {
        if (AboutPanel.currentPanel) {
            AboutPanel.currentPanel._panel.reveal();
            return;
        }
        const panel = vscode.window.createWebviewPanel('saropaAbout', 'About Saropa Package Vibrancy', vscode.ViewColumn.One, { enableScripts: false });
        AboutPanel.currentPanel = new AboutPanel(panel, version);
    }
    constructor(panel, version) {
        this._panel = panel;
        this._panel.webview.html = (0, about_html_1.buildAboutHtml)(version);
        this._panel.onDidDispose(() => this._dispose(), null, this._disposables);
    }
    _dispose() {
        AboutPanel.currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}
exports.AboutPanel = AboutPanel;
//# sourceMappingURL=about-webview.js.map