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
exports.CodeLensToggle = void 0;
const vscode = __importStar(require("vscode"));
/**
 * Manages CodeLens visibility state.
 * Provides session-level toggle that overrides the setting.
 * Toggle is accessible via command palette and editor context menus.
 */
class CodeLensToggle {
    _enabled;
    _onDidChange = new vscode.EventEmitter();
    onDidChange = this._onDidChange.event;
    constructor() {
        this._enabled = this.readSettingDefault();
        this.updateContext();
    }
    get isEnabled() {
        return this._enabled;
    }
    toggle() {
        this._enabled = !this._enabled;
        this.updateContext();
        this._onDidChange.fire(this._enabled);
    }
    show() {
        if (!this._enabled) {
            this._enabled = true;
            this.updateContext();
            this._onDidChange.fire(this._enabled);
        }
    }
    hide() {
        if (this._enabled) {
            this._enabled = false;
            this.updateContext();
            this._onDidChange.fire(this._enabled);
        }
    }
    readSettingDefault() {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return config.get('enableCodeLens', true);
    }
    updateContext() {
        vscode.commands.executeCommand('setContext', 'saropaLints.packageVibrancy.codeLensEnabled', this._enabled);
    }
    dispose() {
        this._onDidChange.dispose();
    }
}
exports.CodeLensToggle = CodeLensToggle;
//# sourceMappingURL=codelens-toggle.js.map