/**
 * Tests for the pubspec.lock watcher gate decision (saropaLints.enabled master switch).
 */

import * as assert from 'assert';
import { decideLockWatcherAction } from '../../../vibrancy/services/scan-gate';

describe('decideLockWatcherAction (enabled gate)', () => {
    it('skips everything when saropaLints.enabled is false, even if the lock changed', () => {
        assert.strictEqual(decideLockWatcherAction(false, false), 'skip-disabled');
        assert.strictEqual(decideLockWatcherAction(false, true), 'skip-disabled');
    });

    it('skips an unchanged lock when enabled', () => {
        assert.strictEqual(decideLockWatcherAction(true, true), 'skip-unchanged');
    });

    it('scans a changed lock when enabled', () => {
        assert.strictEqual(decideLockWatcherAction(true, false), 'scan');
    });
});
