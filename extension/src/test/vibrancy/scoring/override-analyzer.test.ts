import * as assert from 'assert';
import {
    analyzeOverrides,
    isOldOverride,
    groupByStatus,
} from '../../../vibrancy/scoring/override-analyzer';
import { applyKnownOverrideReasons } from '../../../vibrancy/services/override-runner';
import { OverrideEntry, PackageDependency, OverrideAnalysis } from '../../../vibrancy/types';
import { DepGraphPackage } from '../../../vibrancy/services/dep-graph';

describe('override-analyzer', () => {
    describe('analyzeOverrides', () => {
        const makeOverride = (
            name: string,
            version: string,
            isPathDep = false,
            isGitDep = false,
        ): OverrideEntry => ({
            name,
            version,
            line: 10,
            isPathDep,
            isGitDep,
        });

        const makeDep = (
            name: string,
            version: string,
            constraint: string,
            isDirect = true,
        ): PackageDependency => ({
            name,
            version,
            constraint,
            source: 'hosted',
            isDirect,
            section: 'dependencies',
        });

        const makeGraphPkg = (
            name: string,
            dependencies: string[] = [],
            version = '1.0.0',
        ): DepGraphPackage => ({
            name,
            version,
            kind: 'direct',
            dependencies,
        });

        it('should mark path overrides as active', () => {
            const overrides = [makeOverride('local_pkg', 'path', true, false)];
            const result = analyzeOverrides(overrides, [], [], new Map());

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].status, 'active');
            assert.strictEqual(result[0].blocker, 'local path override');
        });

        it('should mark git overrides as active', () => {
            const overrides = [makeOverride('git_pkg', 'git', false, true)];
            const result = analyzeOverrides(overrides, [], [], new Map());

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].status, 'active');
            assert.strictEqual(result[0].blocker, 'git override');
        });

        it('should mark overrides without conflicts as stale', () => {
            const overrides = [makeOverride('intl', '0.18.5')];
            const deps = [makeDep('intl', '0.18.5', '^0.18.0')];
            // Graph resolved version matches override — no conflict
            const graph = [makeGraphPkg('intl', [], '0.18.5')];

            const result = analyzeOverrides(overrides, deps, graph, new Map());

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].status, 'stale');
            assert.strictEqual(result[0].blocker, null);
        });

        it('should include age information when provided', () => {
            const overrides = [makeOverride('intl', '0.19.0')];
            const addedDate = new Date('2024-01-01');
            const ages = new Map([['intl', addedDate]]);

            const result = analyzeOverrides(overrides, [], [], ages);

            assert.strictEqual(result.length, 1);
            assert.ok(result[0].addedDate);
            assert.ok(result[0].ageDays !== null);
            assert.ok(result[0].ageDays! > 0);
        });

        it('should handle missing age information', () => {
            const overrides = [makeOverride('intl', '0.19.0')];
            const result = analyzeOverrides(overrides, [], [], new Map());

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].addedDate, null);
            assert.strictEqual(result[0].ageDays, null);
        });

        it('should mark override as active when package is transitive dep of SDK package', () => {
            // Simulates: flutter_test (SDK package) depends on meta, and the
            // user overrides meta to 1.18.0 to resolve an SDK pin conflict.
            // dart pub deps --json shows meta at 1.18.0 (post-override), so
            // version comparison alone can't detect the conflict. Instead, we
            // detect that meta is a transitive dep of an SDK package.
            const overrides = [makeOverride('meta', '1.18.0')];
            const deps: PackageDependency[] = [
                // meta itself (hosted, transitive)
                makeDep('meta', '1.18.0', '1.18.0', false),
                // flutter_test is source: sdk in pubspec.lock
                {
                    name: 'flutter_test', version: '0.0.0',
                    constraint: 'sdk', source: 'sdk',
                    isDirect: true, section: 'dev_dependencies',
                },
            ];
            const graph = [
                makeGraphPkg('flutter_test', ['meta']),
                makeGraphPkg('meta', [], '1.18.0'),
            ];

            const result = analyzeOverrides(overrides, deps, graph, new Map());

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].status, 'active');
            assert.strictEqual(result[0].blocker, 'SDK transitive (flutter_test)');
        });

        it('should remain stale when override is not a transitive dep of any SDK package', () => {
            // Package is overridden but no SDK package depends on it — the
            // override has no detectable justification.
            const overrides = [makeOverride('http', '1.2.0')];
            const deps: PackageDependency[] = [
                makeDep('http', '1.2.0', '^1.0.0', false),
                // some_lib is hosted, not SDK
                {
                    name: 'some_lib', version: '2.0.0',
                    constraint: '^2.0.0', source: 'hosted',
                    isDirect: true, section: 'dependencies',
                },
            ];
            const graph = [
                makeGraphPkg('some_lib', ['http']),
                makeGraphPkg('http', [], '1.2.0'),
            ];

            const result = analyzeOverrides(overrides, deps, graph, new Map());

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].status, 'stale');
            assert.strictEqual(result[0].blocker, null);
        });
    });

    describe('isOldOverride', () => {
        const makeAnalysis = (ageDays: number | null): OverrideAnalysis => ({
            entry: { name: 'test', version: '1.0.0', line: 0, isPathDep: false, isGitDep: false },
            status: 'active',
            blocker: null,
            addedDate: null,
            ageDays,
        });

        it('should return true for overrides older than threshold', () => {
            const analysis = makeAnalysis(200);
            assert.strictEqual(isOldOverride(analysis, 180), true);
        });

        it('should return false for overrides newer than threshold', () => {
            const analysis = makeAnalysis(90);
            assert.strictEqual(isOldOverride(analysis, 180), false);
        });

        it('should return false for null age', () => {
            const analysis = makeAnalysis(null);
            assert.strictEqual(isOldOverride(analysis), false);
        });

        it('should use default threshold of 180 days', () => {
            const old = makeAnalysis(181);
            const recent = makeAnalysis(179);
            assert.strictEqual(isOldOverride(old), true);
            assert.strictEqual(isOldOverride(recent), false);
        });
    });

    describe('groupByStatus', () => {
        const makeAnalysis = (status: 'active' | 'stale'): OverrideAnalysis => ({
            entry: { name: 'test', version: '1.0.0', line: 0, isPathDep: false, isGitDep: false },
            status,
            blocker: null,
            addedDate: null,
            ageDays: null,
        });

        it('should group analyses by status', () => {
            const analyses = [
                makeAnalysis('active'),
                makeAnalysis('stale'),
                makeAnalysis('active'),
                makeAnalysis('stale'),
            ];

            const { active, stale } = groupByStatus(analyses);

            assert.strictEqual(active.length, 2);
            assert.strictEqual(stale.length, 2);
        });

        it('should handle empty array', () => {
            const { active, stale } = groupByStatus([]);
            assert.strictEqual(active.length, 0);
            assert.strictEqual(stale.length, 0);
        });

        it('should handle all active', () => {
            const analyses = [makeAnalysis('active'), makeAnalysis('active')];
            const { active, stale } = groupByStatus(analyses);
            assert.strictEqual(active.length, 2);
            assert.strictEqual(stale.length, 0);
        });

        it('should handle all stale', () => {
            const analyses = [makeAnalysis('stale'), makeAnalysis('stale')];
            const { active, stale } = groupByStatus(analyses);
            assert.strictEqual(active.length, 0);
            assert.strictEqual(stale.length, 2);
        });
    });

    describe('applyKnownOverrideReasons', () => {
        it('should flip stale to active when known override reason exists', () => {
            const analyses: OverrideAnalysis[] = [{
                entry: { name: 'path_provider_foundation', version: '2.4.0', line: 10, isPathDep: false, isGitDep: false },
                status: 'stale',
                blocker: null,
                addedDate: null,
                ageDays: null,
            }];
            const result = applyKnownOverrideReasons(analyses);
            assert.strictEqual(result[0].status, 'active');
            assert.ok(result[0].blocker);
        });

        it('should not change stale status when no known override reason', () => {
            const analyses: OverrideAnalysis[] = [{
                entry: { name: 'unknown_pkg', version: '1.0.0', line: 10, isPathDep: false, isGitDep: false },
                status: 'stale',
                blocker: null,
                addedDate: null,
                ageDays: null,
            }];
            const result = applyKnownOverrideReasons(analyses);
            assert.strictEqual(result[0].status, 'stale');
            assert.strictEqual(result[0].blocker, null);
        });

        it('should not change already-active overrides', () => {
            const analyses: OverrideAnalysis[] = [{
                entry: { name: 'path_provider_foundation', version: '2.4.0', line: 10, isPathDep: false, isGitDep: false },
                status: 'active',
                blocker: 'direct constraint',
                addedDate: null,
                ageDays: null,
            }];
            const result = applyKnownOverrideReasons(analyses);
            assert.strictEqual(result[0].status, 'active');
            assert.strictEqual(result[0].blocker, 'direct constraint');
        });
    });
});
