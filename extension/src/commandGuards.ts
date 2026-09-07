/**
 * Reusable concurrency guard for VS Code commands that must not run
 * simultaneously. Each guard instance tracks its own busy state,
 * so independent command groups don't block each other.
 */
import * as vscode from 'vscode';

/**
 * Creates a concurrency guard that serializes async command execution.
 * When a second invocation arrives while the first is still running,
 * the guard shows a brief status-bar message and drops the call —
 * satisfying the project's "no silent async" rule (every tap emits
 * visible outcome).
 *
 * Usage:
 * ```ts
 * const guard = createBusyGuard(() => l10n('staleIgnores.info.alreadyRunning'));
 * async function myCommand() {
 *   await guard(async () => { ... });
 * }
 * ```
 */
export function createBusyGuard(
  busyMessage: () => string,
  statusDurationMs = 3000,
): (fn: () => Promise<void>) => Promise<void> {
  let busy = false;
  return async (fn) => {
    // Show feedback and bail when already running.
    if (busy) {
      vscode.window.setStatusBarMessage(busyMessage(), statusDurationMs);
      return;
    }
    busy = true;
    try {
      await fn();
    } finally {
      busy = false;
    }
  };
}
