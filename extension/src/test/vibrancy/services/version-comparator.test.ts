import * as assert from 'assert';
import * as sinon from 'sinon';
import { MockMemento } from '../vscode-mock';
import { CacheService } from '../../../vibrancy/services/cache-service';
import {
    buildWatchList, detectNewVersions, markVersionSeen, markAllSeen,
} from '../../../vibrancy/services/version-comparator';
import { VibrancyResult } from '../../../vibrancy/types';
import * as pubDevApi from '../../../vibrancy/services/pub-dev-api';

describe('version-comparator', () => {
    let memento: MockMemento;
    let cache: CacheService;
    let fetchStub: sinon.SinonStub;

    beforeEach(() => {
        memento = new MockMemento();
        cache = new CacheService(memento as any);
        fetchStub = sinon.stub(pubDevApi, 'fetchPackageInfo');
    });

    afterEach(() => {
        sinon.restore();
    });

    describe('buildWatchList', () => {
        const makeResult = (
            name: string,
            version: string,
            score: number,
            isDirect: boolean,
        ): VibrancyResult => ({
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

            const watchList = buildWatchList(results, 'all');

            assert.strictEqual(watchList.length, 2);
            assert.deepStrictEqual(watchList[0], { name: 'http', currentVersion: '1.0.0', blockedBy: null });
            assert.deepStrictEqual(watchList[1], { name: 'path', currentVersion: '2.0.0', blockedBy: null });
        });

        it('should filter unhealthy packages in "unhealthy" mode', () => {
            const results = [
                makeResult('healthy', '1.0.0', 80, true),
                makeResult('unhealthy', '2.0.0', 30, true),
            ];

            const watchList = buildWatchList(results, 'unhealthy');

            assert.strictEqual(watchList.length, 1);
            assert.strictEqual(watchList[0].name, 'unhealthy');
        });

        it('should filter by custom list in "custom" mode', () => {
            const results = [
                makeResult('http', '1.0.0', 80, true),
                makeResult('path', '2.0.0', 50, true),
                makeResult('json', '3.0.0', 60, true),
            ];

            const watchList = buildWatchList(results, 'custom', ['http', 'json']);

            assert.strictEqual(watchList.length, 2);
            assert.strictEqual(watchList[0].name, 'http');
            assert.strictEqual(watchList[1].name, 'json');
        });

        it('should exclude transitive dependencies', () => {
            const results = [
                makeResult('direct', '1.0.0', 80, true),
                makeResult('transitive', '2.0.0', 30, false),
            ];

            const watchList = buildWatchList(results, 'all');

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
            const notifications = await detectNewVersions(watchList, cache);

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
            const notifications = await detectNewVersions(watchList, cache);

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
            const notifications = await detectNewVersions(watchList, cache);

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
            const notifications = await detectNewVersions(watchList, cache);

            assert.strictEqual(notifications.length, 0);
        });

        it('should not re-notify for already seen versions', async () => {
            await markVersionSeen('http', '1.0.1', cache);

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
            const notifications = await detectNewVersions(watchList, cache);

            assert.strictEqual(notifications.length, 0);
        });

        it('should handle API failures gracefully', async () => {
            fetchStub.resolves(null);

            const watchList = [{ name: 'http', currentVersion: '1.0.0', blockedBy: null }];
            const notifications = await detectNewVersions(watchList, cache);

            assert.strictEqual(notifications.length, 0);
        });
    });

    describe('markAllSeen', () => {
        it('should mark all notifications as seen', async () => {
            const notifications = [
                { name: 'http', currentVersion: '1.0.0', newVersion: '1.0.1', updateType: 'patch' as const, blockedBy: null },
                { name: 'path', currentVersion: '2.0.0', newVersion: '2.1.0', updateType: 'minor' as const, blockedBy: null },
            ];

            await markAllSeen(notifications, cache);

            const httpSeen = cache.get<string>('freshness.seen.http');
            const pathSeen = cache.get<string>('freshness.seen.path');

            assert.strictEqual(httpSeen, '1.0.1');
            assert.strictEqual(pathSeen, '2.1.0');
        });
    });
});
