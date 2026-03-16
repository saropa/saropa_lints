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
exports.PrereleaseToggle = void 0;
exports.getPrereleaseTagFilter = getPrereleaseTagFilter;
exports.arePrereleasesEnabled = arePrereleasesEnabled;
const vscode = __importStar(require("vscode"));
const CONFIG_SECTION = 'saropaLints.packageVibrancy';
const SHOW_PRERELEASES_KEY = 'showPrereleases';
const TAG_FILTER_KEY = 'prereleaseTagFilter';
/** Context key evaluated by when-clauses in package.json menus. */
const CONTEXT_KEY = `${CONFIG_SECTION}.${SHOW_PRERELEASES_KEY}`;
/** Manages prerelease visibility toggle state. */
class PrereleaseToggle {
    _enabled;
    _onDidChange = new vscode.EventEmitter();
    onDidChange = this._onDidChange.event;
    constructor() {
        this._enabled = this.readFromConfig();
        // Sync context key on startup so when-clauses reflect persisted state
        this.syncContextKey();
    }
    /** Current toggle state. */
    get isEnabled() {
        return this._enabled;
    }
    /** Show prerelease versions. */
    show() {
        if (this._enabled) {
            return;
        }
        this._enabled = true;
        this.saveToConfig(true);
        this.syncContextKey();
        this._onDidChange.fire(true);
    }
    /** Hide prerelease versions. */
    hide() {
        if (!this._enabled) {
            return;
        }
        this._enabled = false;
        this.saveToConfig(false);
        this.syncContextKey();
        this._onDidChange.fire(false);
    }
    /** Refresh state from configuration. */
    refresh() {
        const newState = this.readFromConfig();
        if (newState !== this._enabled) {
            this._enabled = newState;
            this.syncContextKey();
            this._onDidChange.fire(newState);
        }
    }
    dispose() {
        this._onDidChange.dispose();
    }
    /** Push current state to VS Code context so when-clauses update. */
    syncContextKey() {
        vscode.commands.executeCommand('setContext', CONTEXT_KEY, this._enabled)
            .then(undefined, (err) => {
            console.warn('[PrereleaseToggle] setContext failed:', err);
        });
    }
    readFromConfig() {
        const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
        return config.get(SHOW_PRERELEASES_KEY, false);
    }
    saveToConfig(enabled) {
        const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
        // Fire-and-forget: onDidChangeConfiguration listener handles
        // re-sync if external config edits race with this write
        void config.update(SHOW_PRERELEASES_KEY, enabled, vscode.ConfigurationTarget.Global);
    }
}
exports.PrereleaseToggle = PrereleaseToggle;
/** Get allowed prerelease tags from configuration. */
function getPrereleaseTagFilter() {
    const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
    return config.get(TAG_FILTER_KEY, []);
}
/** Check if prereleases are enabled via configuration. */
function arePrereleasesEnabled() {
    const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
    return config.get(SHOW_PRERELEASES_KEY, false);
}
//# sourceMappingURL=prerelease-toggle.js.map