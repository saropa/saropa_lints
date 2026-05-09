/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'assert';
import * as sinon from 'sinon';
import { MockMemento } from '../vscode-mock';
import { CacheService } from '../../../vibrancy/services/cache-service';
import {
    applyNewVersionNotificationsToResults,
    buildWatchList, detectNewVersions, markVersionSeen, markAllSeen,
} from '../../../vibrancy/services/version-comparator';
import { VibrancyResult } from '../../../vibrancy/types';
import * as pubDevApi from '../../../vibrancy/services/pub-dev-api';
import { makeMinimalResult } from '../test-helpers';

/**
 * Tests **version-comparator**: `buildWatchList`, semver detection vs memento, `markVersionSeen` / `markAllSeen`,
 * and stubbed [pubDevApi] fetches so tests stay offline.
 */

describe('version-comparator', () => {
    let memento: MockMemento;
    let cache: CacheService;
    let fetchStub: sinon.SinonStub;

    const makeResult = (
        name: string,
        version: string,
        score: number,
        isDirect: boolean,
    ): VibrancyResult => {
        const category = score >= 60 ? 'vibrant' : score >= 40 ? 'stable' : 'outdated';
        return {
            ...makeMinimalResult({ name, version, score, category }),
            package: {
                name,
                version,
                constraint: `^${version}`,
                source: 'hosted',
                isDirect,
                section: 'dependencies',
            },
        };
    };

    beforeEach(() => {
        memento = new MockMemento();
        cache = new CacheService(memento as any);
        fetchStub = sinon.stub(pubDevApi, 'fetchPackageInfo');
    });

    afterEach(() => {
        sinon.restore();
    });

    describe('buildWatchList', () => {
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

    describe('applyNewVersionNotificationsToResults', () => {
        it('should patch updateInfo for packages in the notification list', () => {
            const http = {
                ...makeResult('http', '1.0.0', 80, true),
                updateInfo: {
                    currentVersion: '1.0.0',
                    latestVersion: '1.0.0',
                    updateStatus: 'up-to-date' as const,
                    changelog: null,
                },
            };
            const pathR = makeResult('path', '2.0.0', 80, true);
            const merged = applyNewVersionNotificationsToResults(
                [http, pathR],
                [{
                    name: 'http',
                    currentVersion: '1.0.0',
                    newVersion: '1.0.2',
                    updateType: 'patch',
                    blockedBy: null,
                }],
            );
            assert.strictEqual(merged[0].updateInfo?.latestVersion, '1.0.2');
            assert.strictEqual(merged[0].updateInfo?.updateStatus, 'patch');
            assert.strictEqual(merged[1], pathR);
        });

        it('should return a new results array when there are no notifications', () => {
            const r = makeResult('http', '1.0.0', 80, true);
            const results = [r];
            const merged = applyNewVersionNotificationsToResults(results, []);
            assert.notStrictEqual(merged, results);
            assert.strictEqual(merged[0], r);
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
