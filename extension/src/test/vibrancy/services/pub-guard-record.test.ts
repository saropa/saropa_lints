/**
 * Tests for decision recording / explain formatting of the Vibrancy pub guard,
 * the lock-watcher gate decision, and guard -> record wiring.
 */

import * as assert from 'assert';
import {
    GuardDecision, recordGuardOutcome, getSkips, clearSkips, onGuardOutcome,
    formatDecision, buildExplainModel, buildFolderPickItems, ruleName,
} from '../../../vibrancy/services/pub-guard-record';
import { guardPubCommand, GuardIo } from '../../../vibrancy/services/sdk-toolchain';

const decision = (over: Partial<GuardDecision> = {}): GuardDecision => ({
    at: 1_700_000_000_000, cwd: '/proj', sdkCommand: '/sdk/bin/dart', sdkSource: 'fvm',
    projectVersion: '3.8.1', projectVersionSource: 'dartToolVersion', toolVersion: '3.14.0',
    reasonKey: 'pubGuard.sdkMismatch', reasonParams: { project: '3.8.1', tool: '3.14.0' },
    ...over,
});

describe('pub-guard-record', () => {
    beforeEach(() => clearSkips());

    it('records refused decisions only, and notifies listeners of both outcomes', () => {
        const seen: boolean[] = [];
        const off = onGuardOutcome((safe) => seen.push(safe));
        recordGuardOutcome(true, decision({ reasonKey: '' }));
        assert.strictEqual(getSkips().length, 0);
        recordGuardOutcome(false, decision());
        assert.strictEqual(getSkips()[0]?.reasonKey, 'pubGuard.sdkMismatch');
        // An allowed pass for the SAME folder clears its skip; another folder's skip survives.
        recordGuardOutcome(false, decision({ cwd: '/other' }));
        recordGuardOutcome(true, decision({ reasonKey: '' }));
        assert.deepStrictEqual(getSkips().map((d) => d.cwd), ['/other']);
        off();
        recordGuardOutcome(false, decision());
        assert.deepStrictEqual(seen, [true, false, false, true]);
    });

    it('a throwing listener does not break recording', () => {
        const off = onGuardOutcome(() => { throw new Error('ui'); });
        recordGuardOutcome(false, decision());
        off();
        assert.ok(getSkips()[0]);
    });

    it('keeps one skip per folder; an allowed pass clears only its own folder', () => {
        recordGuardOutcome(false, decision({ cwd: '/a', at: 1 }));
        recordGuardOutcome(false, decision({ cwd: '/b', at: 2 }));
        assert.deepStrictEqual(getSkips().map((d) => d.cwd), ['/b', '/a']);
        recordGuardOutcome(true, decision({ cwd: '/b', reasonKey: '' }));
        assert.deepStrictEqual(getSkips().map((d) => d.cwd), ['/a']);
        recordGuardOutcome(false, decision({ cwd: '/a', at: 5, reasonKey: 'pubGuard.staleLock' }));
        assert.strictEqual(getSkips().length, 1);
        assert.strictEqual(getSkips()[0].reasonKey, 'pubGuard.staleLock');
    });

    it('shows a localized rule name, never the raw key', () => {
        assert.strictEqual(ruleName('pubGuard.sdkMismatch'), 'SDK version mismatch');
        assert.ok(!formatDecision(decision(), () => 'T').includes('pubGuard.'));
        assert.strictEqual(ruleName(''), 'unknown');
    });

    it('builds QuickPick rows with folder name, path and reason', () => {
        const items = buildFolderPickItems([decision({ cwd: '/work/app' })]);
        assert.strictEqual(items[0].label, 'app');
        assert.strictEqual(items[0].description, '/work/app');
        assert.ok(items[0].detail.includes('3.14.0'));
    });

    it('formats every field of the decision', () => {
        const text = formatDecision(decision(), () => 'T');
        for (const needle of ['3.8.1', '3.14.0', '/sdk/bin/dart', 'FVM', '.dart_tool/version',
            '/proj', 'SDK version mismatch', 'T']) {
            assert.ok(text.includes(needle), `missing ${needle} in:\n${text}`);
        }
        assert.strictEqual(text.split('\n').length, 7);
    });

    it('formats unknown evidence instead of printing undefined', () => {
        const text = formatDecision(decision({
            projectVersion: undefined, projectVersionSource: 'none', toolVersion: undefined,
            reasonKey: 'pubGuard.unknownPathSdk', sdkSource: 'path',
        }), () => 'T');
        assert.ok(!text.includes('undefined'));
        assert.ok(text.includes('unknown'));
    });

    it('builds the "none" model when nothing was skipped', () => {
        const m = buildExplainModel(undefined);
        assert.strictEqual(m.kind, 'none');
        assert.ok(m.kind === 'none' && m.message.length > 0 && !m.message.includes('pubGuard.'));
    });

    it('builds the skip model with title, detail and action label', () => {
        const m = buildExplainModel(decision(), () => 'T');
        assert.ok(m.kind === 'skip' && m.title && m.detail.includes('3.14.0') && m.actionLabel);
    });

    describe('guardPubCommand records its outcome', () => {
        const io = (probe: string): GuardIo => ({
            readFile: (p) => {
                if (p.includes('.dart_tool') && p.endsWith('version')) { return '3.8.1'; }
                if (p.endsWith('pubspec.yaml') || p.endsWith('pubspec.lock')) { return ''; }
                throw new Error('ENOENT');
            },
            mtimeMs: (p) => (p.endsWith('pubspec.yaml') ? 1 : p.endsWith('pubspec.lock') ? 2 : p.endsWith('package_config.json') ? 3 : undefined),
            probe: async () => probe,
        });

        it('records a mismatch with SDK source and versions', async () => {
            await guardPubCommand('/proj', { command: 'dart', useShell: false, source: 'path' }, { io: io('3.14.0'), now: () => 42 });
            const d = getSkips()[0];
            assert.strictEqual(d?.sdkSource, 'path');
            assert.strictEqual(d?.projectVersion, '3.8.1');
            assert.strictEqual(d?.projectVersionSource, 'dartToolVersion');
            assert.strictEqual(d?.toolVersion, '3.14.0');
            assert.strictEqual(d?.at, 42);
            assert.strictEqual(d?.reasonKey, 'pubGuard.sdkMismatch');
        });

        it('does not record a skip when allowed', async () => {
            await guardPubCommand('/proj', { command: 'dart', useShell: false, source: 'path' }, { io: io('3.8.1') });
            assert.strictEqual(getSkips().length, 0);
        });
    });
});
