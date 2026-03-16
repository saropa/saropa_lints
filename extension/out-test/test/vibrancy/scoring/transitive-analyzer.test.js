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
const assert = __importStar(require("assert"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const dep_graph_1 = require("../../../vibrancy/services/dep-graph");
const transitive_analyzer_1 = require("../../../vibrancy/scoring/transitive-analyzer");
const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');
const FIXTURE_PATH = path.join(fixturesDir, 'pub-deps.json');
describe('transitive-analyzer', () => {
    describe('buildAdjacencyMap', () => {
        it('should build map from packages', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['b', 'c'] },
                { name: 'b', version: '1.0.0', kind: 'transitive', dependencies: ['c'] },
                { name: 'c', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const map = (0, transitive_analyzer_1.buildAdjacencyMap)(packages);
            assert.deepStrictEqual([...map.get('a')], ['b', 'c']);
            assert.deepStrictEqual([...map.get('b')], ['c']);
            assert.deepStrictEqual([...map.get('c')], []);
        });
    });
    describe('collectTransitives', () => {
        it('should collect all transitive deps', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['b'] },
                { name: 'b', version: '1.0.0', kind: 'transitive', dependencies: ['c'] },
                { name: 'c', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const adjacency = (0, transitive_analyzer_1.buildAdjacencyMap)(packages);
            const result = (0, transitive_analyzer_1.collectTransitives)('a', adjacency);
            assert.strictEqual(result.size, 2);
            assert.ok(result.has('b'));
            assert.ok(result.has('c'));
        });
        it('should handle cycles', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['b'] },
                { name: 'b', version: '1.0.0', kind: 'transitive', dependencies: ['c'] },
                { name: 'c', version: '1.0.0', kind: 'transitive', dependencies: ['a'] },
            ];
            const adjacency = (0, transitive_analyzer_1.buildAdjacencyMap)(packages);
            const result = (0, transitive_analyzer_1.collectTransitives)('a', adjacency);
            assert.strictEqual(result.size, 2);
        });
        it('should return empty set for package with no deps', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: [] },
            ];
            const adjacency = (0, transitive_analyzer_1.buildAdjacencyMap)(packages);
            const result = (0, transitive_analyzer_1.collectTransitives)('a', adjacency);
            assert.strictEqual(result.size, 0);
        });
    });
    describe('countTransitives', () => {
        it('should count transitives from fixture', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = (0, dep_graph_1.parseDepGraphJson)(json);
            const directDeps = ['http', 'intl', 'firebase_core'];
            const result = (0, transitive_analyzer_1.countTransitives)(directDeps, packages);
            assert.strictEqual(result.length, 3);
            const httpInfo = result.find((r) => r.directDep === 'http');
            assert.ok(httpInfo);
            assert.ok(httpInfo.transitiveCount >= 2);
        });
        it('should return empty transitives for leaf packages', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: [] },
            ];
            const result = (0, transitive_analyzer_1.countTransitives)(['a'], packages);
            assert.strictEqual(result[0].transitiveCount, 0);
        });
    });
    describe('findSharedDeps', () => {
        it('should find deps used by multiple direct deps', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'b', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'shared', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const shared = (0, transitive_analyzer_1.findSharedDeps)(['a', 'b'], packages);
            assert.strictEqual(shared.length, 1);
            assert.strictEqual(shared[0].name, 'shared');
            assert.strictEqual(shared[0].usedBy.length, 2);
        });
        it('should not include deps used by only one direct dep', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['unique'] },
                { name: 'unique', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const shared = (0, transitive_analyzer_1.findSharedDeps)(['a'], packages);
            assert.strictEqual(shared.length, 0);
        });
        it('should sort by usage count descending', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['x', 'y'] },
                { name: 'b', version: '1.0.0', kind: 'direct', dependencies: ['x', 'y'] },
                { name: 'c', version: '1.0.0', kind: 'direct', dependencies: ['x'] },
                { name: 'x', version: '1.0.0', kind: 'transitive', dependencies: [] },
                { name: 'y', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const shared = (0, transitive_analyzer_1.findSharedDeps)(['a', 'b', 'c'], packages);
            assert.strictEqual(shared[0].name, 'x');
            assert.strictEqual(shared[0].usedBy.length, 3);
        });
        it('should find meta as shared dep in fixture', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = (0, dep_graph_1.parseDepGraphJson)(json);
            const directDeps = ['http', 'intl', 'firebase_core'];
            const shared = (0, transitive_analyzer_1.findSharedDeps)(directDeps, packages);
            const meta = shared.find((s) => s.name === 'meta');
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
            const knownIssues = new Map([
                ['bad_pkg', [{ name: 'bad_pkg', status: 'discontinued', reason: 'No longer maintained' }]],
            ]);
            const flagged = (0, transitive_analyzer_1.flagRiskyTransitives)(infos, knownIssues);
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
            const knownIssues = new Map();
            const flagged = (0, transitive_analyzer_1.flagRiskyTransitives)(infos, knownIssues);
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
            const knownIssues = new Map([
                ['bad_pkg', [{ name: 'bad_pkg', status: 'end-of-life' }]],
            ]);
            const enriched = (0, transitive_analyzer_1.enrichTransitiveInfo)(infos, sharedDeps, knownIssues);
            assert.strictEqual(enriched[0].flaggedCount, 1);
            assert.deepStrictEqual(enriched[0].sharedDeps, ['shared_pkg']);
        });
    });
    describe('buildDepGraphSummary', () => {
        it('should compute summary from fixture', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = (0, dep_graph_1.parseDepGraphJson)(json);
            const directDeps = ['http', 'intl', 'firebase_core', 'date_picker_timeline'];
            const summary = (0, transitive_analyzer_1.buildDepGraphSummary)(directDeps, packages, 1);
            assert.strictEqual(summary.directCount, 4);
            assert.ok(summary.transitiveCount > 0);
            assert.strictEqual(summary.totalUnique, summary.directCount + summary.transitiveCount);
            assert.strictEqual(summary.overrideCount, 1);
        });
        it('should find high blast radius shared deps', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'b', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'c', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'd', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'e', version: '1.0.0', kind: 'direct', dependencies: ['shared'] },
                { name: 'shared', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const summary = (0, transitive_analyzer_1.buildDepGraphSummary)(['a', 'b', 'c', 'd', 'e'], packages, 0);
            assert.strictEqual(summary.sharedDeps.length, 1);
            assert.strictEqual(summary.sharedDeps[0].name, 'shared');
            assert.strictEqual(summary.sharedDeps[0].usedBy.length, 5);
        });
    });
});
//# sourceMappingURL=transitive-analyzer.test.js.map