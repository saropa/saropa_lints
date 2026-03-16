import * as vscode from 'vscode';
import { NewVersionNotification, VibrancyResult, WatchFilterMode } from '../types';
import { CacheService } from './cache-service';
import {
    buildWatchList, detectNewVersions, markAllSeen, WatchEntry,
} from './version-comparator';

const HOURS_TO_MS = 60 * 60 * 1000;

export interface FreshnessWatcherConfig {
    readonly enabled: boolean;
    readonly intervalHours: number;
    readonly filterMode: WatchFilterMode;
    readonly customWatchList: readonly string[];
}

export type NewVersionsHandler = (notifications: NewVersionNotification[]) => void;

/**
 * Background watcher that polls for new package versions and notifies the user.
 * Respects VS Code window focus state to avoid polling when the IDE is in the background.
 */
export class FreshnessWatcher {
    private _timer: ReturnType<typeof setInterval> | null = null;
    private _watchList: WatchEntry[] = [];
    private _onNewVersions: NewVersionsHandler | null = null;
    private _config: FreshnessWatcherConfig;
    private _focusDisposable: vscode.Disposable | null = null;
    private _isPaused = false;
    private _pollPending = false;
    private _pollInProgress = false;

    constructor(private readonly _cache: CacheService) {
        this._config = this._readConfig();
    }

    setOnNewVersions(handler: NewVersionsHandler): void {
        this._onNewVersions = handler;
    }

    start(results: readonly VibrancyResult[]): void {
        this.stop();

        this._config = this._readConfig();
        if (!this._config.enabled) { return; }

        this._watchList = buildWatchList(
            results,
            this._config.filterMode,
            this._config.customWatchList,
        );

        if (this._watchList.length === 0) { return; }

        this._setupFocusTracking();
        this._startTimer();
    }

    stop(): void {
        if (this._timer) {
            clearInterval(this._timer);
            this._timer = null;
        }
        if (this._focusDisposable) {
            this._focusDisposable.dispose();
            this._focusDisposable = null;
        }
        this._watchList = [];
        this._isPaused = false;
        this._pollPending = false;
        this._pollInProgress = false;
    }

    updateResults(results: readonly VibrancyResult[]): void {
        if (!this._config.enabled) { return; }

        this._watchList = buildWatchList(
            results,
            this._config.filterMode,
            this._config.customWatchList,
        );
    }

    isRunning(): boolean {
        return this._timer !== null;
    }

    getWatchListSize(): number {
        return this._watchList.length;
    }

    async pollNow(): Promise<NewVersionNotification[]> {
        if (this._watchList.length === 0) { return []; }
        if (this._pollInProgress) { return []; }

        this._pollInProgress = true;
        try {
            const notifications = await detectNewVersions(
                this._watchList, this._cache,
            );

            if (notifications.length > 0) {
                await markAllSeen(notifications, this._cache);
                this._onNewVersions?.(notifications);
            }

            return notifications;
        } finally {
            this._pollInProgress = false;
        }
    }

    private _readConfig(): FreshnessWatcherConfig {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return {
            enabled: config.get<boolean>('watchEnabled', true),
            intervalHours: config.get<number>('watchIntervalHours', 6),
            filterMode: config.get<WatchFilterMode>('watchFilter', 'all'),
            customWatchList: config.get<string[]>('watchList', []),
        };
    }

    private _setupFocusTracking(): void {
        this._focusDisposable = vscode.window.onDidChangeWindowState(state => {
            if (state.focused) {
                this._isPaused = false;
                if (this._pollPending) {
                    this._pollPending = false;
                    this._poll();
                }
            } else {
                this._isPaused = true;
            }
        });
    }

    private _startTimer(): void {
        const intervalMs = this._config.intervalHours * HOURS_TO_MS;
        this._timer = setInterval(() => this._onInterval(), intervalMs);
    }

    private _onInterval(): void {
        if (this._isPaused) {
            this._pollPending = true;
            return;
        }
        this._poll();
    }

    private _poll(): void {
        this.pollNow().catch(() => {
            // Polling errors are non-fatal — next interval will retry
        });
    }
}

/**
 * Format notifications into a user-friendly message for VS Code toast.
 * Keeps message concise for better display in notification area.
 * Includes blocker info when upgrades are blocked.
 */
export function formatNotificationMessage(
    notifications: readonly NewVersionNotification[],
): string {
    if (notifications.length === 0) { return ''; }

    if (notifications.length === 1) {
        const n = notifications[0];
        const blockerNote = n.blockedBy ? ` [blocked by ${n.blockedBy}]` : '';
        return `📦 ${n.name} ${n.currentVersion} → ${n.newVersion} (${n.updateType})${blockerNote}`;
    }

    const majorCount = notifications.filter(n => n.updateType === 'major').length;
    const blockedCount = notifications.filter(n => n.blockedBy !== null).length;
    const names = notifications.slice(0, 3).map(n => n.name).join(', ');
    const suffix = notifications.length > 3
        ? ` +${notifications.length - 3} more`
        : '';
    const majorNote = majorCount > 0 ? ` (${majorCount} major)` : '';
    const blockedNote = blockedCount > 0 ? ` (${blockedCount} blocked)` : '';

    return `📦 ${notifications.length} new versions available: ${names}${suffix}${majorNote}${blockedNote}`;
}

export function createNotificationActions(): readonly string[] {
    return ['View Details', 'Update All', 'Dismiss'];
}
