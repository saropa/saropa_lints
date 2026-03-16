import * as vscode from 'vscode';

/**
 * Manages CodeLens visibility state with status bar indicator.
 * Provides session-level toggle that overrides the setting.
 */
export class CodeLensToggle implements vscode.Disposable {
    private _enabled: boolean;
    private readonly _statusBarItem: vscode.StatusBarItem;
    private readonly _onDidChange = new vscode.EventEmitter<boolean>();
    readonly onDidChange = this._onDidChange.event;

    constructor() {
        this._enabled = this.readSettingDefault();

        this._statusBarItem = vscode.window.createStatusBarItem(
            vscode.StatusBarAlignment.Right,
            100,
        );
        this._statusBarItem.command = 'saropaLints.packageVibrancy.toggleCodeLens';
        this.updateStatusBar();
        this._statusBarItem.show();

        this.updateContext();
    }

    get isEnabled(): boolean {
        return this._enabled;
    }

    toggle(): void {
        this._enabled = !this._enabled;
        this.updateStatusBar();
        this.updateContext();
        this._onDidChange.fire(this._enabled);
    }

    show(): void {
        if (!this._enabled) {
            this._enabled = true;
            this.updateStatusBar();
            this.updateContext();
            this._onDidChange.fire(this._enabled);
        }
    }

    hide(): void {
        if (this._enabled) {
            this._enabled = false;
            this.updateStatusBar();
            this.updateContext();
            this._onDidChange.fire(this._enabled);
        }
    }

    private readSettingDefault(): boolean {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return config.get<boolean>('enableCodeLens', true);
    }

    private updateStatusBar(): void {
        if (this._enabled) {
            this._statusBarItem.text = '$(eye) Vibrancy';
            this._statusBarItem.tooltip = 'Vibrancy badges visible (click to hide)';
        } else {
            this._statusBarItem.text = '$(eye-closed) Vibrancy';
            this._statusBarItem.tooltip = 'Vibrancy badges hidden (click to show)';
        }
    }

    private updateContext(): void {
        vscode.commands.executeCommand(
            'setContext',
            'saropaLints.packageVibrancy.codeLensEnabled',
            this._enabled,
        );
    }

    dispose(): void {
        this._statusBarItem.dispose();
        this._onDidChange.dispose();
    }
}
