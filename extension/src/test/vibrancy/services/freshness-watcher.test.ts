import * as assert from 'assert';
import * as sinon from 'sinon';
import { MockMemento } from '../vscode-mock';
import { CacheService } from '../../../vibrancy/services/cache-service';
import {
    FreshnessWatcher, formatNotificationMessage, createNotificationActions,
} from '../../../vibrancy/services/freshness-watcher';
import { NewVersionNotification, VibrancyResult } from '../../../vibrancy/types';
import * as versionComparator from '../../../vibrancy/services/version-comparator';

describe('FreshnessWatcher', () => {
    let memento: MockMemento;
    let cache: CacheService;
    let clock: sinon.SinonFakeTimers;
    let detectStub: sinon.SinonStub;

    const makeResult = (
        name: string,
        version: string,
        score: number = 80,
    ): VibrancyResult => ({
        package: { name, version, constraint: `^${version}`, source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score,
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

    beforeEach(() => {
        memento = new MockMemento();
        cache = new CacheService(memento as any);
        clock = sinon.useFakeTimers();
        detectStub = sinon.stub(versionComparator, 'detectNewVersions');
        detectStub.resolves([]);
        sinon.stub(versionComparator, 'markAllSeen').resolves();
    });

    afterEach(() => {
        clock.restore();
        sinon.restore();
    });

    describe('start/stop lifecycle', () => {
        it('should start with results', () => {
            const watcher = new FreshnessWatcher(cache);
            const results = [makeResult('http', '1.0.0')];

            watcher.start(results);

            assert.strictEqual(watcher.isRunning(), true);
            assert.strictEqual(watcher.getWatchListSize(), 1);

            watcher.stop();
        });

        it('should stop cleanly', () => {
            const watcher = new FreshnessWatcher(cache);
            const results = [makeResult('http', '1.0.0')];

            watcher.start(results);
            watcher.stop();

            assert.strictEqual(watcher.isRunning(), false);
            assert.strictEqual(watcher.getWatchListSize(), 0);
        });

        it('should restart with new results', () => {
            const watcher = new FreshnessWatcher(cache);

            watcher.start([makeResult('http', '1.0.0')]);
            assert.strictEqual(watcher.getWatchListSize(), 1);

            watcher.start([makeResult('http', '1.0.0'), makeResult('path', '2.0.0')]);
            assert.strictEqual(watcher.getWatchListSize(), 2);

            watcher.stop();
        });

        it('should not start with empty watch list', () => {
            const watcher = new FreshnessWatcher(cache);

            watcher.start([]);

            assert.strictEqual(watcher.isRunning(), false);
        });
    });

    describe('polling behavior', () => {
        it('should not poll immediately on start', () => {
            const watcher = new FreshnessWatcher(cache);
            const results = [makeResult('http', '1.0.0')];

            watcher.start(results);

            assert.strictEqual(detectStub.callCount, 0);

            watcher.stop();
        });

        it('should call handler when new versions detected', async () => {
            const notification: NewVersionNotification = {
                name: 'http',
                currentVersion: '1.0.0',
                newVersion: '1.0.1',
                updateType: 'patch',
                blockedBy: null,
            };
            detectStub.resolves([notification]);

            const watcher = new FreshnessWatcher(cache);
            const handler = sinon.stub();
            watcher.setOnNewVersions(handler);

            const results = [makeResult('http', '1.0.0')];
            watcher.start(results);

            await watcher.pollNow();

            assert.strictEqual(handler.callCount, 1);
            assert.deepStrictEqual(handler.firstCall.args[0], [notification]);

            watcher.stop();
        });

        it('should not call handler when no new versions', async () => {
            detectStub.resolves([]);

            const watcher = new FreshnessWatcher(cache);
            const handler = sinon.stub();
            watcher.setOnNewVersions(handler);

            const results = [makeResult('http', '1.0.0')];
            watcher.start(results);

            await watcher.pollNow();

            assert.strictEqual(handler.callCount, 0);

            watcher.stop();
        });

        it('should return empty when watch list is empty', async () => {
            const watcher = new FreshnessWatcher(cache);
            watcher.start([]);

            const notifications = await watcher.pollNow();

            assert.strictEqual(notifications.length, 0);
        });

        it('should prevent concurrent polls (race condition guard)', async () => {
            let resolveFirst: () => void;
            const firstPollPromise = new Promise<void>(r => { resolveFirst = r; });

            detectStub.callsFake(async () => {
                await firstPollPromise;
                return [];
            });

            const watcher = new FreshnessWatcher(cache);
            watcher.start([makeResult('http', '1.0.0')]);

            const poll1 = watcher.pollNow();
            const poll2 = watcher.pollNow();

            resolveFirst!();
            await poll1;
            await poll2;

            assert.strictEqual(detectStub.callCount, 1);

            watcher.stop();
        });
    });

    describe('updateResults', () => {
        it('should update watch list', () => {
            const watcher = new FreshnessWatcher(cache);

            watcher.start([makeResult('http', '1.0.0')]);
            assert.strictEqual(watcher.getWatchListSize(), 1);

            watcher.updateResults([
                makeResult('http', '1.0.0'),
                makeResult('path', '2.0.0'),
            ]);
            assert.strictEqual(watcher.getWatchListSize(), 2);

            watcher.stop();
        });
    });
});

describe('formatNotificationMessage', () => {
    it('should format single notification concisely', () => {
        const notifications: NewVersionNotification[] = [{
            name: 'http',
            currentVersion: '1.0.0',
            newVersion: '1.0.1',
            updateType: 'patch',
            blockedBy: null,
        }];

        const message = formatNotificationMessage(notifications);

        assert.ok(message.includes('http'));
        assert.ok(message.includes('1.0.0 → 1.0.1'));
        assert.ok(message.includes('patch'));
    });

    it('should format multiple notifications with count', () => {
        const notifications: NewVersionNotification[] = [
            { name: 'http', currentVersion: '1.0.0', newVersion: '1.0.1', updateType: 'patch', blockedBy: null },
            { name: 'path', currentVersion: '2.0.0', newVersion: '3.0.0', updateType: 'major', blockedBy: null },
        ];

        const message = formatNotificationMessage(notifications);

        assert.ok(message.includes('2 new versions'));
        assert.ok(message.includes('http'));
        assert.ok(message.includes('path'));
        assert.ok(message.includes('1 major'));
    });

    it('should truncate long lists with "+N more"', () => {
        const notifications: NewVersionNotification[] = [
            { name: 'a', currentVersion: '1.0.0', newVersion: '1.0.1', updateType: 'patch', blockedBy: null },
            { name: 'b', currentVersion: '1.0.0', newVersion: '1.0.1', updateType: 'patch', blockedBy: null },
            { name: 'c', currentVersion: '1.0.0', newVersion: '1.0.1', updateType: 'patch', blockedBy: null },
            { name: 'd', currentVersion: '1.0.0', newVersion: '1.0.1', updateType: 'patch', blockedBy: null },
            { name: 'e', currentVersion: '1.0.0', newVersion: '1.0.1', updateType: 'patch', blockedBy: null },
        ];

        const message = formatNotificationMessage(notifications);

        assert.ok(message.includes('5 new versions'));
        assert.ok(message.includes('+2 more'));
    });

    it('should return empty string for no notifications', () => {
        const message = formatNotificationMessage([]);

        assert.strictEqual(message, '');
    });
});

describe('createNotificationActions', () => {
    it('should return expected actions', () => {
        const actions = createNotificationActions();

        assert.ok(actions.includes('View Details'));
        assert.ok(actions.includes('Update All'));
        assert.ok(actions.includes('Dismiss'));
    });
});
