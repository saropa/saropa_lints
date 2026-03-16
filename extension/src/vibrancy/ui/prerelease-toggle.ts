import * as vscode from 'vscode';

const CONFIG_SECTION = 'saropaLints.packageVibrancy';
const SHOW_PRERELEASES_KEY = 'showPrereleases';
const TAG_FILTER_KEY = 'prereleaseTagFilter';

/** Manages prerelease visibility toggle state. */
export class PrereleaseToggle implements vscode.Disposable {
    private _enabled: boolean;
    private readonly _onDidChange = new vscode.EventEmitter<boolean>();
    readonly onDidChange = this._onDidChange.event;

    constructor() {
        this._enabled = this.readFromConfig();
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
        this._onDidChange.fire(true);
    }

    /** Hide prerelease versions. */
    hide(): void {
        if (!this._enabled) { return; }
        this._enabled = false;
        this.saveToConfig(false);
        this._onDidChange.fire(false);
    }

    /** Toggle prerelease visibility. */
    toggle(): void {
        if (this._enabled) {
            this.hide();
        } else {
            this.show();
        }
    }

    /** Refresh state from configuration. */
    refresh(): void {
        const newState = this.readFromConfig();
        if (newState !== this._enabled) {
            this._enabled = newState;
            this._onDidChange.fire(newState);
        }
    }

    dispose(): void {
        this._onDidChange.dispose();
    }

    private readFromConfig(): boolean {
        const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
        return config.get<boolean>(SHOW_PRERELEASES_KEY, false);
    }

    private saveToConfig(enabled: boolean): void {
        const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
        config.update(
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
