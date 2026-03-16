import * as vscode from 'vscode';
import { ContextState } from './context-state';
import { VibrancyResult } from '../types';

/** Context key prefix for all vibrancy state. */
const PREFIX = 'saropaLints.packageVibrancy';

/** Context keys used by the extension. */
export const STATE_KEYS = {
    hasResults: `${PREFIX}.hasResults`,
    isScanning: `${PREFIX}.isScanning`,
    packageCount: `${PREFIX}.packageCount`,
    updatableCount: `${PREFIX}.updatableCount`,
    problemCount: `${PREFIX}.problemCount`,
    codeLensEnabled: `${PREFIX}.codeLensEnabled`,
    selectedPackage: `${PREFIX}.selectedPackage`,
    hasFilter: `${PREFIX}.hasFilter`,
} as const;

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
export class VibrancyStateManager implements vscode.Disposable {
    readonly hasResults: ContextState<boolean>;
    readonly isScanning: ContextState<boolean>;
    readonly packageCount: ContextState<number>;
    readonly updatableCount: ContextState<number>;
    readonly problemCount: ContextState<number>;
    readonly codeLensEnabled: ContextState<boolean>;
    readonly selectedPackage: ContextState<string | null>;
    readonly hasFilter: ContextState<boolean>;

    private readonly _onDidChangeScanning = new vscode.EventEmitter<boolean>();
    readonly onDidChangeScanning = this._onDidChangeScanning.event;

    private readonly _onDidChangeResults = new vscode.EventEmitter<void>();
    readonly onDidChangeResults = this._onDidChangeResults.event;

    constructor() {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const codeLensDefault = config.get<boolean>('enableCodeLens', true);

        this.hasResults = new ContextState(STATE_KEYS.hasResults, false);
        this.isScanning = new ContextState(STATE_KEYS.isScanning, false);
        this.packageCount = new ContextState(STATE_KEYS.packageCount, 0);
        this.updatableCount = new ContextState(STATE_KEYS.updatableCount, 0);
        this.problemCount = new ContextState(STATE_KEYS.problemCount, 0);
        this.codeLensEnabled = new ContextState(STATE_KEYS.codeLensEnabled, codeLensDefault);
        this.selectedPackage = new ContextState(STATE_KEYS.selectedPackage, null);
        this.hasFilter = new ContextState(STATE_KEYS.hasFilter, false);
    }

    /** Update state from scan results. Call after scan completes. */
    updateFromResults(results: readonly VibrancyResult[]): void {
        this.hasResults.value = results.length > 0;
        this.packageCount.value = results.length;
        this.updatableCount.value = results.filter(r => {
            const status = r.updateInfo?.updateStatus;
            return status && status !== 'up-to-date' && status !== 'unknown';
        }).length;
        // Stale packages are also problems — low maintenance activity
        this.problemCount.value = results.filter(
            r => r.category === 'end-of-life' || r.category === 'stale' || r.category === 'legacy-locked',
        ).length;
        this._onDidChangeResults.fire();
    }

    /** Mark scan as started. */
    startScanning(): void {
        this.isScanning.value = true;
        this._onDidChangeScanning.fire(true);
    }

    /** Mark scan as finished. */
    stopScanning(): void {
        this.isScanning.value = false;
        this._onDidChangeScanning.fire(false);
    }

    /** Toggle CodeLens visibility. */
    toggleCodeLens(): void {
        this.codeLensEnabled.value = !this.codeLensEnabled.value;
    }

    /** Show CodeLens. */
    showCodeLens(): void {
        this.codeLensEnabled.value = true;
    }

    /** Hide CodeLens. */
    hideCodeLens(): void {
        this.codeLensEnabled.value = false;
    }

    /** Reset all state to defaults. */
    reset(): void {
        this.hasResults.reset(false);
        this.isScanning.reset(false);
        this.packageCount.reset(0);
        this.updatableCount.reset(0);
        this.problemCount.reset(0);
        this.selectedPackage.reset(null);
        this.hasFilter.reset(false);
    }

    /** Re-sync all state to VS Code context (useful after activation). */
    syncAll(): void {
        this.hasResults.sync();
        this.isScanning.sync();
        this.packageCount.sync();
        this.updatableCount.sync();
        this.problemCount.sync();
        this.codeLensEnabled.sync();
        this.selectedPackage.sync();
        this.hasFilter.sync();
    }

    dispose(): void {
        this._onDidChangeScanning.dispose();
        this._onDidChangeResults.dispose();
    }
}
