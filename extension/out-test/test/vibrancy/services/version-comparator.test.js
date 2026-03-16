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
const sinon = __importStar(require("sinon"));
const vscode_mock_1 = require("../vscode-mock");
const cache_service_1 = require("../../../vibrancy/services/cache-service");
const version_comparator_1 = require("../../../vibrancy/services/version-comparator");
const pubDevApi = __importStar(require("../../../vibrancy/services/pub-dev-api"));
describe('version-comparator', () => {
    let memento;
    let cache;
    let fetchStub;
    beforeEach(() => {
        memento = new vscode_mock_1.MockMemento();
        cache = new cache_service_1.CacheService(memento);
        fetchStub = sinon.stub(pubDevApi, 'fetchPackageInfo');
    });
    afterEach(() => {
        sinon.restore();
    });
    describe('buildWatchList', () => {
        const makeResult = (name, version, score, isDirect) => ({
            package: { name, version, constraint: `^${version}`, source: 'hosted', isDirect, section: 'dependencies' },
            pubDev: null,
            github: null,
            knownIssue: null,
            score,
            category: score >= 60 ? 'vibrant' : score >= 40 ? 'quiet' : 'legacy-locked',
            resolutionVelocity: 0,
            engagementLevel: 0,
            popularity: 0,
            publisherTrust: 0,
            updateInfo: null,
            license: null,
            drift: null,
            archiveSizeBytes: null,
            bloatRating: null,
            isUnused: false,
            platforms: null,
            verifiedPublisher: false,
            wasmReady: null,
            blocker: null,
            upgradeBlockStatus: 'up-to-date',
            transitiveInfo: null,
            alternatives: [],
            latestPrerelease: null,
            prereleaseTag: null,
            vulnerabilities: [],
        });
        it('should include all direct dependencies in "all" mode', () => {
            const results = [
                makeResult('http', '1.0.0', 80, true),
                makeResult('path', '2.0.0', 50, true),
                makeResult('transitive', '1.0.0', 90, false),
            ];
            const watchList = (0, version_comparator_1.buildWatchList)(results, 'all');
            assert.strictEqual(watchList.length, 2);
            assert.deepStrictEqual(watchList[0], { name: 'http', currentVersion: '1.0.0', blockedBy: null });
            assert.deepStrictEqual(watchList[1], { name: 'path', currentVersion: '2.0.0', blockedBy: null });
        });
        it('should filter unhealthy packages in "unhealthy" mode', () => {
            const results = [
                makeResult('healthy', '1.0.0', 80, true),
                makeResult('unhealthy', '2.0.0', 30, true),
            ];
            const watchList = (0, version_comparator_1.buildWatchList)(results, 'unhealthy');
            assert.strictEqual(watchList.length, 1);
            assert.strictEqual(watchList[0].name, 'unhealthy');
        });
        it('should filter by custom list in "custom" mode', () => {
            const results = [
                makeResult('http', '1.0.0', 80, true),
                makeResult('path', '2.0.0', 50, true),
                makeResult('json', '3.0.0', 60, true),
            ];
            const watchList = (0, version_comparator_1.buildWatchList)(results, 'custom', ['http', 'json']);
            assert.strictEqual(watchList.length, 2);
            assert.strictEqual(watchList[0].name, 'http');
            assert.strictEqual(watchList[1].name, 'json');
        });
        it('should exclude transitive dependencies', () => {
            const results = [
                makeResult('direct', '1.0.0', 80, true),
                makeResult('transitive', '2.0.0', 30, false),
            ];
            const watchList = (0, version_comparator_1.buildWatchList)(results, 'all');
            assert.strictEqual(watchList.length, 1);
            assert.strictEqual(watchList[0].name, 'direct');
        });
    });
    describe('detectNewVersions', () => {
        it('should detect new patch version', async () => {
            fetchStub.resolves({
                name: 'http',
                latestVersion: '1.0.1',
                publishedDate: '',
                repositoryUrl: null,
                isDiscontinued: false,
                isUnlisted: false,
                pubPoints: 0,
                publisher: null,
                license: null,
                description: null,
            });
            const watchList = [{ name: 'http', currentVersion: '1.0.0', blockedBy: null }];
            const notifications = await (0, version_comparator_1.detectNewVersions)(watchList, cache);
            assert.strictEqual(notifications.length, 1);
            assert.strictEqual(notifications[0].name, 'http');
            assert.strictEqual(notifications[0].currentVersion, '1.0.0');
            assert.strictEqual(notifications[0].newVersion, '1.0.1');
            assert.strictEqual(notifications[0].updateType, 'patch');
        });
        it('should detect new minor version', async () => {
            fetchStub.resolves({
                name: 'http',
                latestVersion: '1.1.0',
                publishedDate: '',
                repositoryUrl: null,
                isDiscontinued: false,
                isUnlisted: false,
                pubPoints: 0,
                publisher: null,
                license: null,
                description: null,
            });
            const watchList = [{ name: 'http', currentVersion: '1.0.0', blockedBy: null }];
            const notifications = await (0, version_comparator_1.detectNewVersions)(watchList, cache);
            assert.strictEqual(notifications.length, 1);
            assert.strictEqual(notifications[0].updateType, 'minor');
        });
        it('should detect new major version', async () => {
            fetchStub.resolves({
                name: 'http',
                latestVersion: '2.0.0',
                publishedDate: '',
                repositoryUrl: null,
                isDiscontinued: false,
                isUnlisted: false,
                pubPoints: 0,
                publisher: null,
                license: null,
                description: null,
            });
            const watchList = [{ name: 'http', currentVersion: '1.0.0', blockedBy: null }];
            const notifications = await (0, version_comparator_1.detectNewVersions)(watchList, cache);
            assert.strictEqual(notifications.length, 1);
            assert.strictEqual(notifications[0].updateType, 'major');
        });
        it('should not notify for up-to-date packages', async () => {
            fetchStub.resolves({
                name: 'http',
                latestVersion: '1.0.0',
                publishedDate: '',
                repositoryUrl: null,
                isDiscontinued: false,
                isUnlisted: false,
                pubPoints: 0,
                publisher: null,
                license: null,
                description: null,
            });
            const watchList = [{ name: 'http', currentVersion: '1.0.0', blockedBy: null }];
            const notifications = await (0, version_comparator_1.detectNewVersions)(watchList, cache);
            assert.strictEqual(notifications.length, 0);
        });
        it('should not re-notify for already seen versions', async () => {
            await (0, version_comparator_1.markVersionSeen)('http', '1.0.1', cache);
            fetchStub.resolves({
                name: 'http',
                latestVersion: '1.0.1',
                publishedDate: '',
                repositoryUrl: null,
                isDiscontinued: false,
                isUnlisted: false,
                pubPoints: 0,
                publisher: null,
                license: null,
                description: null,
            });
            const watchList = [{ name: 'http', currentVersion: '1.0.0', blockedBy: null }];
            const notifications = await (0, version_comparator_1.detectNewVersions)(watchList, cache);
            assert.strictEqual(notifications.length, 0);
        });
        it('should handle API failures gracefully', async () => {
            fetchStub.resolves(null);
            const watchList = [{ name: 'http', currentVersion: '1.0.0', blockedBy: null }];
            const notifications = await (0, version_comparator_1.detectNewVersions)(watchList, cache);
            assert.strictEqual(notifications.length, 0);
        });
    });
    describe('markAllSeen', () => {
        it('should mark all notifications as seen', async () => {
            const notifications = [
                { name: 'http', currentVersion: '1.0.0', newVersion: '1.0.1', updateType: 'patch', blockedBy: null },
                { name: 'path', currentVersion: '2.0.0', newVersion: '2.1.0', updateType: 'minor', blockedBy: null },
            ];
            await (0, version_comparator_1.markAllSeen)(notifications, cache);
            const httpSeen = cache.get('freshness.seen.http');
            const pathSeen = cache.get('freshness.seen.path');
            assert.strictEqual(httpSeen, '1.0.1');
            assert.strictEqual(pathSeen, '2.1.0');
        });
    });
});
//# sourceMappingURL=version-comparator.test.js.map