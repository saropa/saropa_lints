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
const version_increment_1 = require("../../../vibrancy/scoring/version-increment");
describe('version-increment', () => {
    describe('classifyIncrement', () => {
        it('detects major increment', () => {
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0', '2.0.0'), 'major');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.2.3', '2.0.0'), 'major');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('0.9.9', '1.0.0'), 'major');
        });
        it('detects minor increment', () => {
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0', '1.1.0'), 'minor');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.2.3', '1.3.0'), 'minor');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('2.5.1', '2.6.0'), 'minor');
        });
        it('detects patch increment', () => {
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0', '1.0.1'), 'patch');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.2.3', '1.2.4'), 'patch');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('2.5.1', '2.5.9'), 'patch');
        });
        it('detects prerelease changes', () => {
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0-alpha', '1.0.0-beta'), 'prerelease');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0-rc.1', '1.0.0-rc.2'), 'prerelease');
        });
        it('returns none for equal versions', () => {
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0', '1.0.0'), 'none');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('2.3.4', '2.3.4'), 'none');
        });
        it('returns none for downgrades', () => {
            assert.strictEqual((0, version_increment_1.classifyIncrement)('2.0.0', '1.0.0'), 'none');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.2.0', '1.1.0'), 'none');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.2', '1.0.1'), 'none');
        });
        it('returns none for invalid versions', () => {
            assert.strictEqual((0, version_increment_1.classifyIncrement)('invalid', '1.0.0'), 'none');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0', 'invalid'), 'none');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('', ''), 'none');
        });
        it('handles versions with build metadata', () => {
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0+1', '2.0.0+1'), 'major');
            assert.strictEqual((0, version_increment_1.classifyIncrement)('1.0.0+build', '1.1.0+build'), 'minor');
        });
    });
    describe('incrementMatchesFilter', () => {
        it('all filter matches all increment types', () => {
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('major', 'all'), true);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('minor', 'all'), true);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('patch', 'all'), true);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('prerelease', 'all'), true);
        });
        it('all filter excludes none', () => {
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('none', 'all'), false);
        });
        it('major filter only matches major', () => {
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('major', 'major'), true);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('minor', 'major'), false);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('patch', 'major'), false);
        });
        it('minor filter matches minor and major', () => {
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('major', 'minor'), true);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('minor', 'minor'), true);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('patch', 'minor'), false);
        });
        it('patch filter only matches patch', () => {
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('patch', 'patch'), true);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('minor', 'patch'), false);
            assert.strictEqual((0, version_increment_1.incrementMatchesFilter)('major', 'patch'), false);
        });
    });
    describe('filterByIncrement', () => {
        const makeResult = (name, current, latest) => ({
            package: {
                name,
                version: current,
                constraint: `^${current}`,
                source: 'hosted',
                isDirect: true,
                section: 'dependencies',
            },
            pubDev: null,
            github: null,
            knownIssue: null,
            score: 80,
            category: 'vibrant',
            resolutionVelocity: 0.8,
            engagementLevel: 0.7,
            popularity: 0.6,
            publisherTrust: 15,
            updateInfo: current === latest ? null : {
                currentVersion: current,
                latestVersion: latest,
                updateStatus: 'major',
                changelog: null,
            },
            license: 'MIT',
            drift: null,
            archiveSizeBytes: null,
            bloatRating: null,
            isUnused: false,
            platforms: null,
            verifiedPublisher: true,
            wasmReady: null,
            blocker: null,
            upgradeBlockStatus: 'upgradable',
            transitiveInfo: null,
            alternatives: [],
            latestPrerelease: null,
            prereleaseTag: null,
            vulnerabilities: [],
        });
        it('filters packages by all', () => {
            const packages = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];
            const filtered = (0, version_increment_1.filterByIncrement)(packages, 'all');
            assert.strictEqual(filtered.length, 3);
        });
        it('filters packages by major', () => {
            const packages = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];
            const filtered = (0, version_increment_1.filterByIncrement)(packages, 'major');
            assert.strictEqual(filtered.length, 1);
            assert.strictEqual(filtered[0].package.name, 'pkg-major');
        });
        it('filters packages by minor (includes major)', () => {
            const packages = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];
            const filtered = (0, version_increment_1.filterByIncrement)(packages, 'minor');
            assert.strictEqual(filtered.length, 2);
            const names = filtered.map(p => p.package.name);
            assert.ok(names.includes('pkg-major'));
            assert.ok(names.includes('pkg-minor'));
        });
        it('filters packages by patch', () => {
            const packages = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];
            const filtered = (0, version_increment_1.filterByIncrement)(packages, 'patch');
            assert.strictEqual(filtered.length, 1);
            assert.strictEqual(filtered[0].package.name, 'pkg-patch');
        });
        it('excludes packages without update info', () => {
            const packages = [
                makeResult('pkg-no-update', '1.0.0', '1.0.0'),
            ];
            const filtered = (0, version_increment_1.filterByIncrement)(packages, 'all');
            assert.strictEqual(filtered.length, 0);
        });
    });
    describe('formatIncrement', () => {
        it('formats all increment types', () => {
            assert.strictEqual((0, version_increment_1.formatIncrement)('major'), 'major');
            assert.strictEqual((0, version_increment_1.formatIncrement)('minor'), 'minor');
            assert.strictEqual((0, version_increment_1.formatIncrement)('patch'), 'patch');
            assert.strictEqual((0, version_increment_1.formatIncrement)('prerelease'), 'prerelease');
            assert.strictEqual((0, version_increment_1.formatIncrement)('none'), 'up-to-date');
        });
    });
});
//# sourceMappingURL=version-increment.test.js.map