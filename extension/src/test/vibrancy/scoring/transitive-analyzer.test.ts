import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import { DepGraphPackage, parseDepGraphJson } from '../../../vibrancy/services/dep-graph';
import {
    collectTransitives, buildAdjacencyMap, countTransitives,
    findSharedDeps, flagRiskyTransitives, enrichTransitiveInfo,
    buildDepGraphSummary,
} from '../../../vibrancy/scoring/transitive-analyzer';
import { KnownIssue } from '../../../vibrancy/types';

const fixturesDir = path.join(
    __dirname, '..', '..', '..', 'src', 'test', 'fixtures',
);
const FIXTURE_PATH = path.join(fixturesDir, 'pub-deps.json');

describe('transitive-analyzer', () => {
    describe('buildAdjacencyMap', () => {
        it('should build map from packages', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['b', 'c'] },
                { name: 'b', version: '1.0.0', kind: 'transitive', dependencies: ['c'] },
                { name: 'c', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const map = buildAdjacencyMap(packages);
            assert.deepStrictEqual([...map.get('a')!], ['b', 'c']);
            assert.deepStrictEqual([...map.get('b')!], ['c']);
            assert.deepStrictEqual([...map.get('c')!], []);
        });
    });

    describe('collectTransitives', () => {
        it('should collect all transitive deps', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['b'] },
                { name: 'b', version: '1.0.0', kind: 'transitive', dependencies: ['c'] },
                { name: 'c', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const adjacency = buildAdjacencyMap(packages);
            const result = collectTransitives('a', adjacency);
            assert.strictEqual(result.size, 2);
            assert.ok(result.has('b'));
            assert.ok(result.has('c'));
        });

        it('should handle cycles', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['b'] },
                { name: 'b', version: '1.0.0', kind: 'transitive', dependencies: ['c'] },
                { name: 'c', version: '1.0.0', kind: 'transitive', dependencies: ['a'] },
            ];
            const adjacency = buildAdjacencyMap(packages);
            const result = collectTransitives('a', adjacency);
            assert.strictEqual(result.size, 2);
        });

        it('should return empty set for package with no deps', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: [] },
            ];
            const adjacency = buildAdjacencyMap(packages);
            const result = collectTransitives('a', adjacency);
            assert.strictEqual(result.size, 0);
        });
    });

    describe('countTransitives', () => {
        it('should count transitives from fixture', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = parseDepGraphJson(json);
            const directDeps = ['http', 'intl', 'firebase_core'];
            const result = countTransitives(directDeps, packages);

            assert.strictEqual(result.length, 3);

            const httpInfo = result.find((r: import('../../../vibrancy/types').TransitiveInfo) => r.directDep === 'http');
            assert.ok(httpInfo);
            assert.ok(httpInfo.transitiveCount >= 2);
        });

        it('should return empty transitives for leaf packages', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: [] },
            ];
            const result = countTransitives(['a'], packages);
            assert.strictEqual(result[0].transitiveCount, 0);
        });
    });

    describe('findSharedDeps', () => {
        it('should find deps used by multiple direct deps', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'b', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'shared', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const shared = findSharedDeps(['a', 'b'], packages);
            assert.strictEqual(shared.length, 1);
            assert.strictEqual(shared[0].name, 'shared');
            assert.strictEqual(shared[0].usedBy.length, 2);
        });

        it('should not include deps used by only one direct dep', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['unique'] },
                { name: 'unique', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const shared = findSharedDeps(['a'], packages);
            assert.strictEqual(shared.length, 0);
        });

        it('should sort by usage count descending', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['x', 'y'] },
                { name: 'b', version: '1.0.0', kind: 'direct', dependencies: ['x', 'y'] },
                { name: 'c', version: '1.0.0', kind: 'direct', dependencies: ['x'] },
                { name: 'x', version: '1.0.0', kind: 'transitive', dependencies: [] },
                { name: 'y', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const shared = findSharedDeps(['a', 'b', 'c'], packages);
            assert.strictEqual(shared[0].name, 'x');
            assert.strictEqual(shared[0].usedBy.length, 3);
        });

        it('should find meta as shared dep in fixture', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = parseDepGraphJson(json);
            const directDeps = ['http', 'intl', 'firebase_core'];
            const shared = findSharedDeps(directDeps, packages);

            const meta = shared.find((s: import('../../../vibrancy/types').SharedDep) => s.name === 'meta');
            assert.ok(meta);
            assert.ok(meta.usedBy.length >= 2);
        });
    });

    describe('flagRiskyTransitives', () => {
        it('should flag discontinued transitives', () => {
            const infos = [{
                directDep: 'a',
                transitiveCount: 1,
                flaggedCount: 0,
                transitives: ['bad_pkg'],
                sharedDeps: [],
            }];
            const knownIssues = new Map<string, readonly KnownIssue[]>([
                ['bad_pkg', [{ name: 'bad_pkg', status: 'discontinued', reason: 'No longer maintained' }]],
            ]);
            const flagged = flagRiskyTransitives(infos, knownIssues);
            assert.strictEqual(flagged.length, 1);
            assert.strictEqual(flagged[0].name, 'bad_pkg');
            assert.strictEqual(flagged[0].directDep, 'a');
        });

        it('should not flag healthy transitives', () => {
            const infos = [{
                directDep: 'a',
                transitiveCount: 1,
                flaggedCount: 0,
                transitives: ['good_pkg'],
                sharedDeps: [],
            }];
            const knownIssues = new Map<string, readonly KnownIssue[]>();
            const flagged = flagRiskyTransitives(infos, knownIssues);
            assert.strictEqual(flagged.length, 0);
        });
    });

    describe('enrichTransitiveInfo', () => {
        it('should add flagged counts and shared deps', () => {
            const infos = [{
                directDep: 'a',
                transitiveCount: 2,
                flaggedCount: 0,
                transitives: ['bad_pkg', 'shared_pkg'],
                sharedDeps: [],
            }];
            const sharedDeps = [{ name: 'shared_pkg', usedBy: ['a', 'b'] }];
            const knownIssues = new Map<string, readonly KnownIssue[]>([
                ['bad_pkg', [{ name: 'bad_pkg', status: 'end-of-life' }]],
            ]);
            const enriched = enrichTransitiveInfo(infos, sharedDeps, knownIssues);

            assert.strictEqual(enriched[0].flaggedCount, 1);
            assert.deepStrictEqual(enriched[0].sharedDeps, ['shared_pkg']);
        });
    });

    describe('buildDepGraphSummary', () => {
        it('should compute summary from fixture', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = parseDepGraphJson(json);
            const directDeps = ['http', 'intl', 'firebase_core', 'date_picker_timeline'];
            const summary = buildDepGraphSummary(directDeps, packages, 1);

            assert.strictEqual(summary.directCount, 4);
            assert.ok(summary.transitiveCount > 0);
            assert.strictEqual(summary.totalUnique, summary.directCount + summary.transitiveCount);
            assert.strictEqual(summary.overrideCount, 1);
        });

        it('should find high blast radius shared deps', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'b', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'c', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'd', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'e', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'shared', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const summary = buildDepGraphSummary(['a', 'b', 'c', 'd', 'e'], packages, 0);

            assert.strictEqual(summary.sharedDeps.length, 1);
            assert.strictEqual(summary.sharedDeps[0].name, 'shared');
            assert.strictEqual(summary.sharedDeps[0].usedBy.length, 5);
        });
    });
});
