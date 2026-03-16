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
const prerelease_classifier_1 = require("../../../vibrancy/scoring/prerelease-classifier");
describe('prerelease-classifier', () => {
    describe('isPrerelease', () => {
        it('should detect dev prereleases', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('2.0.0-dev.1'), true);
        });
        it('should detect beta prereleases', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('2.0.0-beta.1'), true);
        });
        it('should detect rc prereleases', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('2.0.0-rc.1'), true);
        });
        it('should detect alpha prereleases', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('2.0.0-alpha'), true);
        });
        it('should detect nullsafety prereleases', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('2.0.0-nullsafety.0'), true);
        });
        it('should return false for stable versions', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('2.0.0'), false);
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('1.0.0'), false);
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('0.1.0'), false);
        });
        it('should handle invalid versions', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrerelease)('not-a-version'), false);
        });
    });
    describe('getPrereleaseTag', () => {
        it('should extract dev tag', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTag)('2.0.0-dev.1'), 'dev');
        });
        it('should extract beta tag', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTag)('2.0.0-beta.2'), 'beta');
        });
        it('should extract rc tag', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTag)('2.0.0-rc.1'), 'rc');
        });
        it('should extract alpha tag', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTag)('2.0.0-alpha'), 'alpha');
        });
        it('should return null for stable versions', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTag)('2.0.0'), null);
        });
    });
    describe('findLatestPrerelease', () => {
        it('should find the latest prerelease', () => {
            const versions = [
                '1.0.0',
                '2.0.0-dev.1',
                '2.0.0-dev.2',
                '2.0.0-beta.1',
            ];
            // semver sorts alphabetically: dev > beta because d > b
            assert.strictEqual((0, prerelease_classifier_1.findLatestPrerelease)(versions), '2.0.0-dev.2');
        });
        it('should return null if no prereleases', () => {
            const versions = ['1.0.0', '2.0.0'];
            assert.strictEqual((0, prerelease_classifier_1.findLatestPrerelease)(versions), null);
        });
        it('should handle empty list', () => {
            assert.strictEqual((0, prerelease_classifier_1.findLatestPrerelease)([]), null);
        });
    });
    describe('findLatestStable', () => {
        it('should find the latest stable version', () => {
            const versions = [
                '1.0.0',
                '2.0.0',
                '2.1.0-dev.1',
            ];
            assert.strictEqual((0, prerelease_classifier_1.findLatestStable)(versions), '2.0.0');
        });
        it('should return null if only prereleases', () => {
            const versions = ['1.0.0-dev.1', '2.0.0-beta.1'];
            assert.strictEqual((0, prerelease_classifier_1.findLatestStable)(versions), null);
        });
    });
    describe('filterByTags', () => {
        const versions = [
            '2.0.0-dev.1',
            '2.0.0-beta.1',
            '2.0.0-rc.1',
            '2.0.0-alpha.1',
        ];
        it('should filter by single tag', () => {
            const filtered = (0, prerelease_classifier_1.filterByTags)(versions, ['beta']);
            assert.deepStrictEqual(filtered, ['2.0.0-beta.1']);
        });
        it('should filter by multiple tags', () => {
            const filtered = (0, prerelease_classifier_1.filterByTags)(versions, ['beta', 'rc']);
            assert.deepStrictEqual(filtered, ['2.0.0-beta.1', '2.0.0-rc.1']);
        });
        it('should return all prereleases if tags empty', () => {
            const filtered = (0, prerelease_classifier_1.filterByTags)(versions, []);
            assert.deepStrictEqual(filtered, versions);
        });
        it('should be case-insensitive', () => {
            const filtered = (0, prerelease_classifier_1.filterByTags)(versions, ['BETA', 'RC']);
            assert.deepStrictEqual(filtered, ['2.0.0-beta.1', '2.0.0-rc.1']);
        });
    });
    describe('isPrereleaseNewerThanStable', () => {
        it('should return true when prerelease is newer', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrereleaseNewerThanStable)('2.1.0-dev.1', '2.0.0'), true);
        });
        it('should return false when prerelease is older', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrereleaseNewerThanStable)('2.0.0-dev.1', '2.0.0'), false);
        });
        it('should return true for prerelease of same base version', () => {
            assert.strictEqual((0, prerelease_classifier_1.isPrereleaseNewerThanStable)('3.0.0-rc.1', '2.0.0'), true);
        });
    });
    describe('getPrereleaseTier', () => {
        it('should classify alpha', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTier)('alpha'), 'alpha');
        });
        it('should classify dev', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTier)('dev'), 'dev');
        });
        it('should classify beta', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTier)('beta'), 'beta');
        });
        it('should classify rc', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTier)('rc'), 'rc');
        });
        it('should classify rc variants', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTier)('rc1'), 'rc');
        });
        it('should classify nullsafety as beta', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTier)('nullsafety'), 'beta');
        });
        it('should classify unknown as other', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTier)('custom'), 'other');
        });
        it('should handle null', () => {
            assert.strictEqual((0, prerelease_classifier_1.getPrereleaseTier)(null), 'other');
        });
    });
    describe('formatPrereleaseTag', () => {
        it('should format alpha', () => {
            assert.strictEqual((0, prerelease_classifier_1.formatPrereleaseTag)('alpha'), 'Alpha');
        });
        it('should format dev', () => {
            assert.strictEqual((0, prerelease_classifier_1.formatPrereleaseTag)('dev'), 'Dev');
        });
        it('should format beta', () => {
            assert.strictEqual((0, prerelease_classifier_1.formatPrereleaseTag)('beta'), 'Beta');
        });
        it('should format rc', () => {
            assert.strictEqual((0, prerelease_classifier_1.formatPrereleaseTag)('rc'), 'RC');
        });
        it('should return original for unknown tags', () => {
            assert.strictEqual((0, prerelease_classifier_1.formatPrereleaseTag)('custom'), 'custom');
        });
        it('should handle null', () => {
            assert.strictEqual((0, prerelease_classifier_1.formatPrereleaseTag)(null), 'prerelease');
        });
    });
    describe('extractPrereleaseInfo', () => {
        it('should extract prerelease info when newer than stable', () => {
            const versions = [
                '1.0.0',
                '2.0.0',
                '2.1.0-dev.1',
            ];
            const info = (0, prerelease_classifier_1.extractPrereleaseInfo)(versions);
            assert.strictEqual(info.latestStable, '2.0.0');
            assert.strictEqual(info.latestPrerelease, '2.1.0-dev.1');
            assert.strictEqual(info.prereleaseTag, 'dev');
            assert.strictEqual(info.hasNewerPrerelease, true);
        });
        it('should return null prerelease when stable is newer', () => {
            const versions = [
                '1.0.0',
                '2.0.0',
                '1.5.0-dev.1',
            ];
            const info = (0, prerelease_classifier_1.extractPrereleaseInfo)(versions);
            assert.strictEqual(info.latestStable, '2.0.0');
            assert.strictEqual(info.latestPrerelease, null);
            assert.strictEqual(info.prereleaseTag, null);
            assert.strictEqual(info.hasNewerPrerelease, false);
        });
        it('should handle only prereleases', () => {
            const versions = [
                '1.0.0-dev.1',
                '1.0.0-beta.1',
            ];
            const info = (0, prerelease_classifier_1.extractPrereleaseInfo)(versions);
            assert.strictEqual(info.latestStable, null);
            // semver sorts alphabetically: dev > beta because d > b
            assert.strictEqual(info.latestPrerelease, '1.0.0-dev.1');
            assert.strictEqual(info.prereleaseTag, 'dev');
            assert.strictEqual(info.hasNewerPrerelease, true);
        });
        it('should handle empty list', () => {
            const info = (0, prerelease_classifier_1.extractPrereleaseInfo)([]);
            assert.strictEqual(info.latestStable, null);
            assert.strictEqual(info.latestPrerelease, null);
            assert.strictEqual(info.prereleaseTag, null);
            assert.strictEqual(info.hasNewerPrerelease, false);
        });
        it('should filter invalid versions', () => {
            const versions = [
                '2.0.0',
                'not-a-version',
                '3.0.0-dev.1',
            ];
            const info = (0, prerelease_classifier_1.extractPrereleaseInfo)(versions);
            assert.strictEqual(info.latestStable, '2.0.0');
            assert.strictEqual(info.latestPrerelease, '3.0.0-dev.1');
        });
    });
});
//# sourceMappingURL=prerelease-classifier.test.js.map