// Must be the first import — registers vscode mock before source modules load
import './register-vscode-mock';

import * as assert from 'assert';
import * as sinon from 'sinon';
import * as scanOrchestrator from '../../vibrancy/scan-orchestrator';
import { scanPackages, ScanConfig } from '../../vibrancy/scan-helpers';
import { PackageDependency } from '../../vibrancy/types';
import { makeMinimalResult } from './test-helpers';

/** Create a minimal PackageDependency stub for testing. */
function makeDep(name: string): PackageDependency {
    return {
        name,
        version: '1.0.0',
        constraint: '^1.0.0',
        source: 'hosted',
        isDirect: true,
        section: 'dependencies',
    };
}

/** No-op progress reporter matching VS Code's progress API shape. */
const noopProgress = { report: () => { /* no-op */ } };

/** Minimal ScanConfig with no tokens or overrides. */
const stubConfig: ScanConfig = {
    token: '',
    allowSet: new Set(),
    weights: {} as ScanConfig['weights'],
    repoOverrides: {},
    publisherTrustBonus: 0,
};

describe('scanPackages', () => {
    let analyzeStub: sinon.SinonStub;

    beforeEach(() => {
        analyzeStub = sinon.stub(scanOrchestrator, 'analyzePackage')
            .callsFake(async (dep) => makeMinimalResult({ name: dep.name }));
    });

    afterEach(() => {
        sinon.restore();
    });

    it('should process all packages when no signal is provided', async () => {
        const deps = [makeDep('a'), makeDep('b'), makeDep('c')];

        const results = await scanPackages(
            deps, null as any, stubConfig, noopProgress,
        );

        assert.strictEqual(results.length, 3);
        assert.strictEqual(analyzeStub.callCount, 3);
        assert.strictEqual(results[0].package.name, 'a');
        assert.strictEqual(results[1].package.name, 'b');
        assert.strictEqual(results[2].package.name, 'c');
    });

    it('should skip all packages when signal is pre-aborted', async () => {
        const deps = [makeDep('a'), makeDep('b')];
        const controller = new AbortController();
        // Abort before scan starts — no packages should be analyzed
        controller.abort();

        const results = await scanPackages(
            deps, null as any, stubConfig, noopProgress, controller.signal,
        );

        assert.strictEqual(analyzeStub.callCount, 0);
        // Array is allocated but contains no analyzed results
        assert.strictEqual(results.length, 2);
    });

    it('should stop workers when signal is aborted mid-scan', async () => {
        const deps = [
            makeDep('a'), makeDep('b'), makeDep('c'),
            makeDep('d'), makeDep('e'), makeDep('f'),
        ];
        const controller = new AbortController();

        // Abort after the second package completes analysis
        let callCount = 0;
        analyzeStub.callsFake(async (dep: PackageDependency) => {
            callCount++;
            if (callCount >= 2) { controller.abort(); }
            return makeMinimalResult({ name: dep.name });
        });

        await scanPackages(
            deps, null as any, stubConfig, noopProgress, controller.signal,
        );

        // Workers check signal before each iteration, so at most CONCURRENCY(3)
        // workers may each complete one package before seeing the abort.
        assert.ok(
            analyzeStub.callCount < deps.length,
            `Expected fewer than ${deps.length} packages analyzed, ` +
            `got ${analyzeStub.callCount}`,
        );
    });

    it('should report progress for each completed package', async () => {
        const deps = [makeDep('a'), makeDep('b')];
        const reports: Array<{ message?: string; increment?: number }> = [];
        const trackingProgress = {
            report: (value: { message?: string; increment?: number }) => {
                reports.push(value);
            },
        };

        await scanPackages(
            deps, null as any, stubConfig, trackingProgress,
        );

        assert.strictEqual(reports.length, 2);
        assert.ok(reports[0].message?.includes('a'));
        assert.ok(reports[1].message?.includes('b'));
        // Each increment should be 100 / numDeps = 50
        assert.strictEqual(reports[0].increment, 50);
        assert.strictEqual(reports[1].increment, 50);
    });
});
