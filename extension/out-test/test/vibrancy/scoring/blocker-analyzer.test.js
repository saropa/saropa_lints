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
const blocker_analyzer_1 = require("../../../vibrancy/scoring/blocker-analyzer");
function makeEntry(overrides) {
    return {
        current: '1.0.0',
        upgradable: '1.0.0',
        resolvable: '1.0.0',
        latest: '1.0.0',
        ...overrides,
    };
}
function makeResult(name, score) {
    return {
        package: {
            name, version: '1.0.0', constraint: '^1.0.0',
            source: 'hosted', isDirect: true, section: 'dependencies',
        },
        pubDev: null, github: null, knownIssue: null,
        score, category: score >= 70 ? 'vibrant' : 'end-of-life',
        resolutionVelocity: 0, engagementLevel: 0,
        popularity: 0, publisherTrust: 0,
        updateInfo: null, license: null, drift: null,
        archiveSizeBytes: null, bloatRating: null,
        isUnused: false, platforms: null,
        verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
    };
}
describe('blocker-analyzer', () => {
    describe('classifyUpgradeStatus', () => {
        it('should return up-to-date when current equals latest', () => {
            const entry = makeEntry({
                package: 'x', current: '2.0.0', latest: '2.0.0',
            });
            assert.strictEqual((0, blocker_analyzer_1.classifyUpgradeStatus)(entry), 'up-to-date');
        });
        it('should return blocked when resolvable < latest', () => {
            const entry = makeEntry({
                package: 'x',
                current: '1.0.0', upgradable: '1.0.0',
                resolvable: '1.0.0', latest: '2.0.0',
            });
            assert.strictEqual((0, blocker_analyzer_1.classifyUpgradeStatus)(entry), 'blocked');
        });
        it('should return constrained when upgradable < resolvable', () => {
            const entry = makeEntry({
                package: 'x',
                current: '1.0.0', upgradable: '1.1.0',
                resolvable: '2.0.0', latest: '2.0.0',
            });
            assert.strictEqual((0, blocker_analyzer_1.classifyUpgradeStatus)(entry), 'constrained');
        });
        it('should return upgradable when all versions match latest', () => {
            const entry = makeEntry({
                package: 'x',
                current: '1.0.0', upgradable: '2.0.0',
                resolvable: '2.0.0', latest: '2.0.0',
            });
            assert.strictEqual((0, blocker_analyzer_1.classifyUpgradeStatus)(entry), 'upgradable');
        });
        it('should return up-to-date when current is null', () => {
            const entry = makeEntry({
                package: 'x', current: null,
            });
            assert.strictEqual((0, blocker_analyzer_1.classifyUpgradeStatus)(entry), 'up-to-date');
        });
    });
    describe('findBlockers', () => {
        it('should find a single blocker', () => {
            const outdated = [
                makeEntry({
                    package: 'intl',
                    current: '0.17.0', upgradable: '0.17.0',
                    resolvable: '0.17.0', latest: '0.19.0',
                }),
            ];
            const reverseDeps = new Map([
                ['intl', [{ dependentPackage: 'date_picker_timeline' }]],
            ]);
            const results = [makeResult('date_picker_timeline', 12)];
            const directDeps = new Set(['intl', 'date_picker_timeline']);
            const blockers = (0, blocker_analyzer_1.findBlockers)(outdated, reverseDeps, results, directDeps);
            assert.strictEqual(blockers.length, 1);
            assert.strictEqual(blockers[0].blockedPackage, 'intl');
            assert.strictEqual(blockers[0].blockerPackage, 'date_picker_timeline');
            assert.strictEqual(blockers[0].blockerVibrancyScore, 12);
            assert.strictEqual(blockers[0].blockerCategory, 'end-of-life');
        });
        it('should prefer direct dependency as blocker', () => {
            const outdated = [
                makeEntry({
                    package: 'meta',
                    current: '1.0.0', resolvable: '1.0.0', latest: '2.0.0',
                }),
            ];
            const reverseDeps = new Map([
                ['meta', [
                        { dependentPackage: 'transitive_pkg' },
                        { dependentPackage: 'direct_pkg' },
                    ]],
            ]);
            const results = [makeResult('direct_pkg', 80)];
            const directDeps = new Set(['direct_pkg']);
            const blockers = (0, blocker_analyzer_1.findBlockers)(outdated, reverseDeps, results, directDeps);
            assert.strictEqual(blockers[0].blockerPackage, 'direct_pkg');
        });
        it('should return empty when no packages are blocked', () => {
            const outdated = [
                makeEntry({
                    package: 'http',
                    current: '1.0.0', upgradable: '2.0.0',
                    resolvable: '2.0.0', latest: '2.0.0',
                }),
            ];
            const blockers = (0, blocker_analyzer_1.findBlockers)(outdated, new Map(), [], new Set());
            assert.deepStrictEqual(blockers, []);
        });
        it('should handle blocked package with no reverse deps', () => {
            const outdated = [
                makeEntry({
                    package: 'orphan',
                    current: '1.0.0', resolvable: '1.0.0', latest: '2.0.0',
                }),
            ];
            const blockers = (0, blocker_analyzer_1.findBlockers)(outdated, new Map(), [], new Set());
            assert.deepStrictEqual(blockers, []);
        });
        it('should handle blocker without vibrancy result', () => {
            const outdated = [
                makeEntry({
                    package: 'pkg',
                    current: '1.0.0', resolvable: '1.0.0', latest: '2.0.0',
                }),
            ];
            const reverseDeps = new Map([
                ['pkg', [{ dependentPackage: 'unknown_blocker' }]],
            ]);
            const blockers = (0, blocker_analyzer_1.findBlockers)(outdated, reverseDeps, [], new Set());
            assert.strictEqual(blockers[0].blockerVibrancyScore, null);
            assert.strictEqual(blockers[0].blockerCategory, null);
        });
    });
});
//# sourceMappingURL=blocker-analyzer.test.js.map