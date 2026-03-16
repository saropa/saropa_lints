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
exports.FreshnessWatcher = void 0;
exports.formatNotificationMessage = formatNotificationMessage;
exports.createNotificationActions = createNotificationActions;
const vscode = __importStar(require("vscode"));
const version_comparator_1 = require("./version-comparator");
const HOURS_TO_MS = 60 * 60 * 1000;
/**
 * Background watcher that polls for new package versions and notifies the user.
 * Respects VS Code window focus state to avoid polling when the IDE is in the background.
 */
class FreshnessWatcher {
    _cache;
    _timer = null;
    _watchList = [];
    _onNewVersions = null;
    _config;
    _focusDisposable = null;
    _isPaused = false;
    _pollPending = false;
    _pollInProgress = false;
    constructor(_cache) {
        this._cache = _cache;
        this._config = this._readConfig();
    }
    setOnNewVersions(handler) {
        this._onNewVersions = handler;
    }
    start(results) {
        this.stop();
        this._config = this._readConfig();
        if (!this._config.enabled) {
            return;
        }
        this._watchList = (0, version_comparator_1.buildWatchList)(results, this._config.filterMode, this._config.customWatchList);
        if (this._watchList.length === 0) {
            return;
        }
        this._setupFocusTracking();
        this._startTimer();
    }
    stop() {
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
    updateResults(results) {
        if (!this._config.enabled) {
            return;
        }
        this._watchList = (0, version_comparator_1.buildWatchList)(results, this._config.filterMode, this._config.customWatchList);
    }
    isRunning() {
        return this._timer !== null;
    }
    getWatchListSize() {
        return this._watchList.length;
    }
    async pollNow() {
        if (this._watchList.length === 0) {
            return [];
        }
        if (this._pollInProgress) {
            return [];
        }
        this._pollInProgress = true;
        try {
            const notifications = await (0, version_comparator_1.detectNewVersions)(this._watchList, this._cache);
            if (notifications.length > 0) {
                await (0, version_comparator_1.markAllSeen)(notifications, this._cache);
                this._onNewVersions?.(notifications);
            }
            return notifications;
        }
        finally {
            this._pollInProgress = false;
        }
    }
    _readConfig() {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return {
            enabled: config.get('watchEnabled', true),
            intervalHours: config.get('watchIntervalHours', 6),
            filterMode: config.get('watchFilter', 'all'),
            customWatchList: config.get('watchList', []),
        };
    }
    _setupFocusTracking() {
        this._focusDisposable = vscode.window.onDidChangeWindowState(state => {
            if (state.focused) {
                this._isPaused = false;
                if (this._pollPending) {
                    this._pollPending = false;
                    this._poll();
                }
            }
            else {
                this._isPaused = true;
            }
        });
    }
    _startTimer() {
        const intervalMs = this._config.intervalHours * HOURS_TO_MS;
        this._timer = setInterval(() => this._onInterval(), intervalMs);
    }
    _onInterval() {
        if (this._isPaused) {
            this._pollPending = true;
            return;
        }
        this._poll();
    }
    _poll() {
        this.pollNow().catch(() => {
            // Polling errors are non-fatal — next interval will retry
        });
    }
}
exports.FreshnessWatcher = FreshnessWatcher;
/**
 * Format notifications into a user-friendly message for VS Code toast.
 * Keeps message concise for better display in notification area.
 * Includes blocker info when upgrades are blocked.
 */
function formatNotificationMessage(notifications) {
    if (notifications.length === 0) {
        return '';
    }
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
function createNotificationActions() {
    return ['View Details', 'Update All', 'Dismiss'];
}
//# sourceMappingURL=freshness-watcher.js.map