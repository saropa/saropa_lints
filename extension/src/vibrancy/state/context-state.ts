import * as vscode from 'vscode';

/**
 * Syncs a typed value with VS Code's context system for `when` clause evaluation.
 * 
 * When the value changes, it automatically calls `setContext` to update VS Code's
 * context, enabling reactive UI updates via `when` clauses in package.json.
 * 
 * @example
 * const isScanning = new ContextState('myExt.isScanning', false);
 * isScanning.value = true;  // Automatically syncs to VS Code context
 * 
 * // In package.json:
 * // "when": "!myExt.isScanning"
 */
export class ContextState<T> {
    private _value: T;

    constructor(
        private readonly key: string,
        defaultValue: T,
    ) {
        this._value = defaultValue;
        this.sync();
    }

    get value(): T {
        return this._value;
    }

    set value(newValue: T) {
        if (this._value !== newValue) {
            this._value = newValue;
            this.sync();
        }
    }

    /** Re-sync current value to VS Code context (useful after activation). */
    sync(): void {
        vscode.commands.executeCommand('setContext', this.key, this._value);
    }

    /** Reset to a new value and sync. */
    reset(newValue: T): void {
        this._value = newValue;
        this.sync();
    }
}
