import * as vscode from 'vscode';

/**
 * Manages CodeLens visibility state.
 * Provides session-level toggle that overrides the setting.
 * Toggle is accessible via command palette and editor context menus.
 */
export class CodeLensToggle implements vscode.Disposable {
    private _enabled: boolean;
    private readonly _onDidChange = new vscode.EventEmitter<boolean>();
    readonly onDidChange = this._onDidChange.event;

    constructor() {
        this._enabled = this.readSettingDefault();
        this.updateContext();
    }

    get isEnabled(): boolean {
        return this._enabled;
    }

    toggle(): void {
        this._enabled = !this._enabled;
        this.updateContext();
        this._onDidChange.fire(this._enabled);
    }

    show(): void {
        if (!this._enabled) {
            this._enabled = true;
            this.updateContext();
            this._onDidChange.fire(this._enabled);
        }
    }

    hide(): void {
        if (this._enabled) {
            this._enabled = false;
            this.updateContext();
            this._onDidChange.fire(this._enabled);
        }
    }

    private readSettingDefault(): boolean {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return config.get<boolean>('enableCodeLens', true);
    }

    private updateContext(): void {
        vscode.commands.executeCommand(
            'setContext',
            'saropaLints.packageVibrancy.codeLensEnabled',
            this._enabled,
        );
    }

    dispose(): void {
        this._onDidChange.dispose();
    }
}
