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
exports.VibrancyStateManager = exports.STATE_KEYS = void 0;
const vscode = __importStar(require("vscode"));
const context_state_1 = require("./context-state");
/** Context key prefix for all vibrancy state. */
const PREFIX = 'saropaLints.packageVibrancy';
/** Context keys used by the extension. */
exports.STATE_KEYS = {
    hasResults: `${PREFIX}.hasResults`,
    isScanning: `${PREFIX}.isScanning`,
    packageCount: `${PREFIX}.packageCount`,
    updatableCount: `${PREFIX}.updatableCount`,
    problemCount: `${PREFIX}.problemCount`,
    codeLensEnabled: `${PREFIX}.codeLensEnabled`,
    selectedPackage: `${PREFIX}.selectedPackage`,
    hasFilter: `${PREFIX}.hasFilter`,
};
/**
 * Centralized state manager that syncs extension state with VS Code's context API.
 *
 * This enables fine-grained UI control via `when` clauses in package.json:
 * - Menu items appear/disappear based on actual state
 * - Commands are enabled/disabled reactively
 * - State is shared across all components
 *
 * @example
 * // In package.json:
 * // "when": "saropaLints.packageVibrancy.hasResults && saropaLints.packageVibrancy.updatableCount > 0"
 */
class VibrancyStateManager {
    hasResults;
    isScanning;
    packageCount;
    updatableCount;
    problemCount;
    codeLensEnabled;
    selectedPackage;
    hasFilter;
    _onDidChangeScanning = new vscode.EventEmitter();
    onDidChangeScanning = this._onDidChangeScanning.event;
    _onDidChangeResults = new vscode.EventEmitter();
    onDidChangeResults = this._onDidChangeResults.event;
    constructor() {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const codeLensDefault = config.get('enableCodeLens', true);
        this.hasResults = new context_state_1.ContextState(exports.STATE_KEYS.hasResults, false);
        this.isScanning = new context_state_1.ContextState(exports.STATE_KEYS.isScanning, false);
        this.packageCount = new context_state_1.ContextState(exports.STATE_KEYS.packageCount, 0);
        this.updatableCount = new context_state_1.ContextState(exports.STATE_KEYS.updatableCount, 0);
        this.problemCount = new context_state_1.ContextState(exports.STATE_KEYS.problemCount, 0);
        this.codeLensEnabled = new context_state_1.ContextState(exports.STATE_KEYS.codeLensEnabled, codeLensDefault);
        this.selectedPackage = new context_state_1.ContextState(exports.STATE_KEYS.selectedPackage, null);
        this.hasFilter = new context_state_1.ContextState(exports.STATE_KEYS.hasFilter, false);
    }
    /** Update state from scan results. Call after scan completes. */
    updateFromResults(results) {
        this.hasResults.value = results.length > 0;
        this.packageCount.value = results.length;
        this.updatableCount.value = results.filter(r => {
            const status = r.updateInfo?.updateStatus;
            return status && status !== 'up-to-date' && status !== 'unknown';
        }).length;
        // End-of-life, stale, and legacy-locked packages are all counted as problems
        this.problemCount.value = results.filter(r => r.category === 'end-of-life' || r.category === 'stale' || r.category === 'legacy-locked').length;
        this._onDidChangeResults.fire();
    }
    /** Mark scan as started. */
    startScanning() {
        this.isScanning.value = true;
        this._onDidChangeScanning.fire(true);
    }
    /** Mark scan as finished. */
    stopScanning() {
        this.isScanning.value = false;
        this._onDidChangeScanning.fire(false);
    }
    /** Toggle CodeLens visibility. */
    toggleCodeLens() {
        this.codeLensEnabled.value = !this.codeLensEnabled.value;
    }
    /** Show CodeLens. */
    showCodeLens() {
        this.codeLensEnabled.value = true;
    }
    /** Hide CodeLens. */
    hideCodeLens() {
        this.codeLensEnabled.value = false;
    }
    /** Reset all state to defaults. */
    reset() {
        this.hasResults.reset(false);
        this.isScanning.reset(false);
        this.packageCount.reset(0);
        this.updatableCount.reset(0);
        this.problemCount.reset(0);
        this.selectedPackage.reset(null);
        this.hasFilter.reset(false);
    }
    /** Re-sync all state to VS Code context (useful after activation). */
    syncAll() {
        this.hasResults.sync();
        this.isScanning.sync();
        this.packageCount.sync();
        this.updatableCount.sync();
        this.problemCount.sync();
        this.codeLensEnabled.sync();
        this.selectedPackage.sync();
        this.hasFilter.sync();
    }
    dispose() {
        this._onDidChangeScanning.dispose();
        this._onDidChangeResults.dispose();
    }
}
exports.VibrancyStateManager = VibrancyStateManager;
//# sourceMappingURL=vibrancy-state.js.map