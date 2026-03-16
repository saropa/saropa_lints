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
const family_conflict_detector_1 = require("../../../vibrancy/scoring/family-conflict-detector");
function makeResult(name, version) {
    return {
        package: {
            name, version,
            constraint: `^${version}`,
            source: 'hosted',
            isDirect: true,
            section: 'dependencies',
        },
        pubDev: null,
        github: null,
        knownIssue: null,
        score: 70,
        category: 'vibrant',
        resolutionVelocity: 0,
        engagementLevel: 0,
        popularity: 0,
        publisherTrust: 0,
        updateInfo: null,
        license: null,
        drift: null,
        archiveSizeBytes: null,
        bloatRating: null,
        isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
    };
}
describe('family-conflict-detector', () => {
    describe('detectFamilySplits', () => {
        it('should return empty when no family packages exist', () => {
            const results = [
                makeResult('http', '1.2.0'),
                makeResult('path', '1.8.0'),
            ];
            assert.deepStrictEqual((0, family_conflict_detector_1.detectFamilySplits)(results), []);
        });
        it('should return empty when family is on same major', () => {
            const results = [
                makeResult('bloc', '8.1.0'),
                makeResult('flutter_bloc', '8.0.1'),
            ];
            assert.deepStrictEqual((0, family_conflict_detector_1.detectFamilySplits)(results), []);
        });
        it('should detect split when family spans two majors', () => {
            const results = [
                makeResult('bloc', '8.1.0'),
                makeResult('flutter_bloc', '7.3.0'),
            ];
            const splits = (0, family_conflict_detector_1.detectFamilySplits)(results);
            assert.strictEqual(splits.length, 1);
            assert.strictEqual(splits[0].familyId, 'bloc');
            assert.strictEqual(splits[0].familyLabel, 'Bloc');
            assert.strictEqual(splits[0].versionGroups.length, 2);
        });
        it('should sort version groups ascending', () => {
            const results = [
                makeResult('bloc', '8.1.0'),
                makeResult('flutter_bloc', '7.3.0'),
            ];
            const splits = (0, family_conflict_detector_1.detectFamilySplits)(results);
            assert.strictEqual(splits[0].versionGroups[0].majorVersion, 7);
            assert.strictEqual(splits[0].versionGroups[1].majorVersion, 8);
        });
        it('should list packages in each version group', () => {
            const results = [
                makeResult('bloc', '8.1.0'),
                makeResult('flutter_bloc', '7.3.0'),
                makeResult('hydrated_bloc', '8.0.0'),
            ];
            const splits = (0, family_conflict_detector_1.detectFamilySplits)(results);
            const v7 = splits[0].versionGroups.find(g => g.majorVersion === 7);
            const v8 = splits[0].versionGroups.find(g => g.majorVersion === 8);
            assert.deepStrictEqual(v7?.packages, ['flutter_bloc']);
            assert.ok(v8?.packages.includes('bloc'));
            assert.ok(v8?.packages.includes('hydrated_bloc'));
        });
        it('should generate upgrade suggestion', () => {
            const results = [
                makeResult('bloc', '8.1.0'),
                makeResult('flutter_bloc', '7.3.0'),
            ];
            const splits = (0, family_conflict_detector_1.detectFamilySplits)(results);
            assert.ok(splits[0].suggestion.includes('flutter_bloc'));
            assert.ok(splits[0].suggestion.includes('Bloc'));
        });
        it('should not split a single-package family', () => {
            const results = [makeResult('riverpod', '2.5.0')];
            assert.deepStrictEqual((0, family_conflict_detector_1.detectFamilySplits)(results), []);
        });
        it('should detect splits in multiple families', () => {
            const results = [
                makeResult('bloc', '8.1.0'),
                makeResult('flutter_bloc', '7.3.0'),
                makeResult('drift', '2.0.0'),
                makeResult('drift_dev', '1.5.0'),
            ];
            const splits = (0, family_conflict_detector_1.detectFamilySplits)(results);
            assert.strictEqual(splits.length, 2);
            const ids = splits.map(s => s.familyId).sort();
            assert.deepStrictEqual(ids, ['bloc', 'drift']);
        });
        it('should ignore non-family packages', () => {
            const results = [
                makeResult('http', '1.2.0'),
                makeResult('bloc', '8.1.0'),
                makeResult('flutter_bloc', '8.0.0'),
            ];
            assert.deepStrictEqual((0, family_conflict_detector_1.detectFamilySplits)(results), []);
        });
    });
});
//# sourceMappingURL=family-conflict-detector.test.js.map