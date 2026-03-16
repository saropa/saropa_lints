import * as vscode from 'vscode';

const CONFIG_SECTION = 'saropaLints.packageVibrancy';
const SHOW_PRERELEASES_KEY = 'showPrereleases';
const TAG_FILTER_KEY = 'prereleaseTagFilter';

/** Context key evaluated by when-clauses in package.json menus. */
const CONTEXT_KEY = `${CONFIG_SECTION}.${SHOW_PRERELEASES_KEY}`;

/** Manages prerelease visibility toggle state. */
export class PrereleaseToggle implements vscode.Disposable {
    private _enabled: boolean;
    private readonly _onDidChange = new vscode.EventEmitter<boolean>();
    readonly onDidChange = this._onDidChange.event;

    constructor() {
        this._enabled = this.readFromConfig();
        // Sync context key on startup so when-clauses reflect persisted state
        this.syncContextKey();
    }

    /** Current toggle state. */
    get isEnabled(): boolean {
        return this._enabled;
    }

    /** Show prerelease versions. */
    show(): void {
        if (this._enabled) { return; }
        this._enabled = true;
        this.saveToConfig(true);
        this.syncContextKey();
        this._onDidChange.fire(true);
    }

    /** Hide prerelease versions. */
    hide(): void {
        if (!this._enabled) { return; }
        this._enabled = false;
        this.saveToConfig(false);
        this.syncContextKey();
        this._onDidChange.fire(false);
    }

    /** Refresh state from configuration. */
    refresh(): void {
        const newState = this.readFromConfig();
        if (newState !== this._enabled) {
            this._enabled = newState;
            this.syncContextKey();
            this._onDidChange.fire(newState);
        }
    }

    dispose(): void {
        this._onDidChange.dispose();
    }

    /** Push current state to VS Code context so when-clauses update. */
    private syncContextKey(): void {
        vscode.commands.executeCommand('setContext', CONTEXT_KEY, this._enabled)
            .then(undefined, (err: unknown) => {
                console.warn('[PrereleaseToggle] setContext failed:', err);
            });
    }

    private readFromConfig(): boolean {
        const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
        return config.get<boolean>(SHOW_PRERELEASES_KEY, false);
    }

    private saveToConfig(enabled: boolean): void {
        const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
        // Fire-and-forget: onDidChangeConfiguration listener handles
        // re-sync if external config edits race with this write
        void config.update(
            SHOW_PRERELEASES_KEY, enabled,
            vscode.ConfigurationTarget.Global,
        );
    }
}

/** Get allowed prerelease tags from configuration. */
export function getPrereleaseTagFilter(): string[] {
    const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
    return config.get<string[]>(TAG_FILTER_KEY, []);
}

/** Check if prereleases are enabled via configuration. */
export function arePrereleasesEnabled(): boolean {
    const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
    return config.get<boolean>(SHOW_PRERELEASES_KEY, false);
}
