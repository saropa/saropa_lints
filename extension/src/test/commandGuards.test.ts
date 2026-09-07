/**
 * Unit tests for the createBusyGuard concurrency utility.
 * Verifies serialization, visible feedback on blocked calls,
 * and proper cleanup after both success and error paths.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'assert';
import * as vscode from 'vscode';
import { createBusyGuard } from '../commandGuards';

describe('createBusyGuard', () => {
  // Track status bar messages — re-patched in beforeEach to survive
  // other test suites that also stub setStatusBarMessage.
  let statusBarMessages: string[];

  beforeEach(() => {
    statusBarMessages = [];
    (vscode.window as unknown as { setStatusBarMessage: (...args: unknown[]) => void })
      .setStatusBarMessage = (msg: unknown) => { statusBarMessages.push(String(msg)); };
  });

  it('runs the function when not busy', async () => {
    const guard = createBusyGuard(() => 'busy');
    let ran = false;
    await guard(async () => { ran = true; });
    assert.strictEqual(ran, true, 'function should have run');
  });

  it('resets busy flag after success so the next call runs', async () => {
    const guard = createBusyGuard(() => 'busy');
    let count = 0;
    await guard(async () => { count++; });
    await guard(async () => { count++; });
    assert.strictEqual(count, 2, 'both calls should have run sequentially');
  });

  it('resets busy flag after an error so the next call still runs', async () => {
    const guard = createBusyGuard(() => 'busy');
    let secondRan = false;
    try {
      await guard(async () => { throw new Error('boom'); });
    } catch { /* expected */ }
    await guard(async () => { secondRan = true; });
    assert.strictEqual(secondRan, true, 'guard should have cleared after error');
  });

  it('shows status bar message and skips when already busy', async () => {
    const guard = createBusyGuard(() => 'scan running');
    // Hold the first call open via a deferred promise.
    let resolveFirst!: () => void;
    const firstDone = new Promise<void>((r) => { resolveFirst = r; });

    // Launch the first call (stays in-flight).
    const firstPromise = guard(async () => { await firstDone; });

    // Second call should be blocked — status bar message fires.
    await guard(async () => { assert.fail('should not run'); });
    assert.strictEqual(statusBarMessages.length, 1, 'one status bar message');
    assert.strictEqual(statusBarMessages[0], 'scan running');

    // Clean up: let the first call complete.
    resolveFirst();
    await firstPromise;
  });

  it('allows the next call after the first finishes even if one was blocked', async () => {
    const guard = createBusyGuard(() => 'busy');
    let resolveFirst!: () => void;
    const firstDone = new Promise<void>((r) => { resolveFirst = r; });

    // First call holds the lock.
    const firstPromise = guard(async () => { await firstDone; });
    // Second call is blocked.
    await guard(async () => { assert.fail('should not run'); });

    // Release the first call.
    resolveFirst();
    await firstPromise;

    // Third call should succeed — the lock is free.
    let thirdRan = false;
    await guard(async () => { thirdRan = true; });
    assert.strictEqual(thirdRan, true, 'third call should run after first completed');
  });
});
