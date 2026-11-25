/**
 * Pure decision for the `pubspec.lock` file-watcher scan. Extracted from
 * `registerFileWatcher` so the gate is unit-testable without a watcher.
 */

/** What the lock watcher should do when its debounce fires. */
export type LockWatcherAction = 'skip-disabled' | 'skip-unchanged' | 'scan';

/**
 * Order matters: the master switch comes first, so with
 * `saropaLints.enabled: false` no work happens at all (not even the hash
 * comparison); only then is the cheap "bytes unchanged since last scan" skip
 * applied.
 */
export function decideLockWatcherAction(
    extensionEnabled: boolean,
    lockUnchangedSinceLastScan: boolean,
): LockWatcherAction {
    if (!extensionEnabled) { return 'skip-disabled'; }
    if (lockUnchangedSinceLastScan) { return 'skip-unchanged'; }
    return 'scan';
}
