import * as assert from 'assert';
import { buildUpgradeOrder } from '../../../vibrancy/scoring/upgrade-sequencer';
import { VibrancyResult, DepEdge, UpdateStatus } from '../../../vibrancy/types';

function makeResult(
    name: string,
    opts: {
        updateStatus?: UpdateStatus;
        currentVersion?: string;
        latestVersion?: string;
        score?: number;
        blocked?: boolean;
    } = {},
): VibrancyResult {
    const status = opts.updateStatus ?? 'minor';
    return {
        package: {
            name, version: opts.currentVersion ?? '1.0.0',
            constraint: `^${opts.currentVersion ?? '1.0.0'}`,
            source: 'hosted', isDirect: true, section: 'dependencies',
        },
        pubDev: null, github: null, knownIssue: null,
        score: opts.score ?? 70, category: 'vibrant',
        resolutionVelocity: 0, engagementLevel: 0,
        popularity: 0, publisherTrust: 0,
        updateInfo: status === 'up-to-date' ? null : {
            currentVersion: opts.currentVersion ?? '1.0.0',
            latestVersion: opts.latestVersion ?? '2.0.0',
            updateStatus: status,
            changelog: null,
        },
        archiveSizeBytes: null, bloatRating: null,
        isUnused: false, platforms: null,
        verifiedPublisher: false, wasmReady: null,
        blocker: null,
        upgradeBlockStatus: opts.blocked ? 'blocked' : 'upgradable',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
    };
}

describe('upgrade-sequencer', () => {
    describe('buildUpgradeOrder', () => {
        it('should return empty for up-to-date packages', () => {
            const results = [
                makeResult('http', { updateStatus: 'up-to-date' }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.deepStrictEqual(steps, []);
        });

        it('should return empty when all are blocked', () => {
            const results = [
                makeResult('intl', { blocked: true }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.deepStrictEqual(steps, []);
        });

        it('should order independent packages by risk', () => {
            const results = [
                makeResult('major_pkg', {
                    updateStatus: 'major', score: 80,
                }),
                makeResult('patch_pkg', {
                    updateStatus: 'patch', score: 60,
                }),
                makeResult('minor_pkg', {
                    updateStatus: 'minor', score: 70,
                }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.strictEqual(steps[0].packageName, 'patch_pkg');
            assert.strictEqual(steps[1].packageName, 'minor_pkg');
            assert.strictEqual(steps[2].packageName, 'major_pkg');
        });

        it('should break risk ties by higher vibrancy first', () => {
            const results = [
                makeResult('low', { updateStatus: 'minor', score: 40 }),
                makeResult('high', { updateStatus: 'minor', score: 90 }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.strictEqual(steps[0].packageName, 'high');
            assert.strictEqual(steps[1].packageName, 'low');
        });

        it('should respect dependency order', () => {
            // b depends on a — so a should be upgraded first
            const results = [
                makeResult('b', { updateStatus: 'minor' }),
                makeResult('a', { updateStatus: 'minor' }),
            ];
            const reverseDeps = new Map<string, DepEdge[]>([
                ['a', [{ dependentPackage: 'b' }]],
            ]);
            const steps = buildUpgradeOrder(results, reverseDeps);
            assert.strictEqual(steps[0].packageName, 'a');
            assert.strictEqual(steps[1].packageName, 'b');
        });

        it('should handle diamond dependency', () => {
            // c depends on a and b; b depends on a
            const results = [
                makeResult('c', { updateStatus: 'minor' }),
                makeResult('b', { updateStatus: 'minor' }),
                makeResult('a', { updateStatus: 'minor' }),
            ];
            const reverseDeps = new Map<string, DepEdge[]>([
                ['a', [
                    { dependentPackage: 'b' },
                    { dependentPackage: 'c' },
                ]],
                ['b', [{ dependentPackage: 'c' }]],
            ]);
            const steps = buildUpgradeOrder(results, reverseDeps);
            const names = steps.map(s => s.packageName);
            assert.ok(names.indexOf('a') < names.indexOf('b'));
            assert.ok(names.indexOf('b') < names.indexOf('c'));
        });

        it('should group family packages together', () => {
            const results = [
                makeResult('http', { updateStatus: 'patch' }),
                makeResult('riverpod', { updateStatus: 'minor' }),
                makeResult('path', { updateStatus: 'patch' }),
                makeResult('flutter_riverpod', { updateStatus: 'minor' }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            const names = steps.map(s => s.packageName);
            const rpIdx = names.indexOf('riverpod');
            const frpIdx = names.indexOf('flutter_riverpod');
            assert.strictEqual(
                Math.abs(rpIdx - frpIdx), 1,
                'Riverpod packages should be adjacent',
            );
        });

        it('should assign sequential order numbers', () => {
            const results = [
                makeResult('a', { updateStatus: 'patch' }),
                makeResult('b', { updateStatus: 'minor' }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.strictEqual(steps[0].order, 1);
            assert.strictEqual(steps[1].order, 2);
        });

        it('should set familyId for family packages', () => {
            const results = [
                makeResult('riverpod', { updateStatus: 'minor' }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.strictEqual(steps[0].familyId, 'riverpod');
        });

        it('should set null familyId for non-family packages', () => {
            const results = [
                makeResult('http', { updateStatus: 'minor' }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.strictEqual(steps[0].familyId, null);
        });

        it('should skip blocked packages', () => {
            const results = [
                makeResult('blocked_pkg', { blocked: true }),
                makeResult('ok_pkg', { updateStatus: 'patch' }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.strictEqual(steps.length, 1);
            assert.strictEqual(steps[0].packageName, 'ok_pkg');
        });

        it('should exclude git-sourced packages', () => {
            // Git deps cannot be upgraded via version constraint bump
            const gitResult = makeResult('device_calendar', {
                updateStatus: 'patch',
            });
            // Override source to simulate a git dependency
            (gitResult.package as { source: string }).source = 'git';
            const results = [
                gitResult,
                makeResult('http', { updateStatus: 'patch' }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.strictEqual(steps.length, 1);
            assert.strictEqual(steps[0].packageName, 'http');
        });

        it('should exclude path-sourced packages', () => {
            const pathResult = makeResult('my_local_pkg', {
                updateStatus: 'minor',
            });
            (pathResult.package as { source: string }).source = 'path';
            const results = [
                pathResult,
                makeResult('meta', { updateStatus: 'patch' }),
            ];
            const steps = buildUpgradeOrder(results, new Map());
            assert.strictEqual(steps.length, 1);
            assert.strictEqual(steps[0].packageName, 'meta');
        });
    });
});
