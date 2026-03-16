import * as assert from 'assert';
import * as sinon from 'sinon';
import * as fs from 'fs';
import * as path from 'path';
import {
    compareVersions,
    constraintAllowsVersion,
    extractRepoSubpath,
    parseChangelog,
    fetchChangelog,
    buildUpdateInfo,
} from '../../../vibrancy/services/changelog-service';

const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');

describe('changelog-service', () => {
    describe('compareVersions', () => {
        it('should return up-to-date for equal versions', () => {
            assert.strictEqual(compareVersions('1.2.3', '1.2.3'), 'up-to-date');
        });

        it('should return major for major bump', () => {
            assert.strictEqual(compareVersions('1.2.3', '2.0.0'), 'major');
        });

        it('should return minor for minor bump', () => {
            assert.strictEqual(compareVersions('1.2.3', '1.3.0'), 'minor');
        });

        it('should return patch for patch bump', () => {
            assert.strictEqual(compareVersions('1.2.3', '1.2.4'), 'patch');
        });

        it('should return unknown for unparseable version', () => {
            assert.strictEqual(compareVersions('not-a-version', '1.0.0'), 'unknown');
        });

        it('should return up-to-date when current > latest', () => {
            assert.strictEqual(compareVersions('2.0.0', '1.9.9'), 'up-to-date');
        });

        it('should handle versions with pre-release suffixes', () => {
            assert.strictEqual(compareVersions('1.0.0-beta.1', '1.0.0'), 'up-to-date');
        });
    });

    describe('constraintAllowsVersion', () => {
        it('should allow minor bump within caret range', () => {
            assert.strictEqual(constraintAllowsVersion('^1.2.3', '1.3.0'), true);
        });

        it('should allow patch bump within caret range', () => {
            assert.strictEqual(constraintAllowsVersion('^1.2.3', '1.2.4'), true);
        });

        it('should allow exact version match', () => {
            assert.strictEqual(constraintAllowsVersion('^1.2.3', '1.2.3'), true);
        });

        it('should reject next major version', () => {
            assert.strictEqual(constraintAllowsVersion('^1.2.3', '2.0.0'), false);
        });

        it('should reject version below constraint', () => {
            assert.strictEqual(constraintAllowsVersion('^1.2.3', '1.2.2'), false);
        });

        it('should handle ^0.x.y caret (minor is ceiling)', () => {
            assert.strictEqual(constraintAllowsVersion('^0.5.0', '0.5.1'), true);
            assert.strictEqual(constraintAllowsVersion('^0.5.0', '0.6.0'), false);
        });

        it('should allow any version for "any" constraint', () => {
            assert.strictEqual(constraintAllowsVersion('any', '99.0.0'), true);
        });

        it('should return false for unparseable constraint', () => {
            assert.strictEqual(constraintAllowsVersion('>=1.0.0 <2.0.0', '1.5.0'), false);
        });

        it('should return false for unparseable version', () => {
            assert.strictEqual(constraintAllowsVersion('^1.0.0', 'not-a-version'), false);
        });

        it('should handle real-world constraint like ^8.0.11 with 8.1.0', () => {
            assert.strictEqual(constraintAllowsVersion('^8.0.11', '8.1.0'), true);
        });
    });

    describe('extractRepoSubpath', () => {
        it('should extract subpath from monorepo URL', () => {
            const url = 'https://github.com/firebase/flutterfire/tree/master/packages/firebase_core';
            assert.strictEqual(extractRepoSubpath(url), 'packages/firebase_core');
        });

        it('should return null for simple repo URL', () => {
            assert.strictEqual(
                extractRepoSubpath('https://github.com/dart-lang/http'),
                null,
            );
        });

        it('should handle nested subpaths', () => {
            const url = 'https://github.com/org/repo/tree/main/packages/sub/pkg';
            assert.strictEqual(extractRepoSubpath(url), 'packages/sub/pkg');
        });

        it('should strip trailing slash', () => {
            const url = 'https://github.com/org/repo/tree/main/packages/pkg/';
            assert.strictEqual(extractRepoSubpath(url), 'packages/pkg');
        });

        it('should return null for non-GitHub URLs', () => {
            assert.strictEqual(
                extractRepoSubpath('https://gitlab.com/org/repo'),
                null,
            );
        });
    });

    describe('parseChangelog', () => {
        it('should parse fixture changelog', () => {
            const content = fs.readFileSync(
                path.join(fixturesDir, 'changelog-sample.md'), 'utf8',
            );
            const result = parseChangelog(content, '1.0.0', '2.0.0');
            assert.strictEqual(result.entries.length, 3);
            assert.strictEqual(result.entries[0].version, '2.0.0');
            assert.strictEqual(result.entries[0].date, '2024-06-15');
            assert.strictEqual(result.entries[2].version, '1.1.0');
        });

        it('should parse ## X.Y.Z format without brackets', () => {
            const content = '## 2.0.0\n\nBreaking\n\n## 1.1.0\n\nFeature\n\n## 1.0.0\n\nInit\n';
            const result = parseChangelog(content, '1.0.0', '2.0.0');
            assert.strictEqual(result.entries.length, 2);
            assert.strictEqual(result.entries[0].version, '2.0.0');
        });

        it('should parse ## [X.Y.Z] - YYYY-MM-DD format', () => {
            const content = '## [1.2.0] - 2024-06-15\n\nStuff\n';
            const result = parseChangelog(content, '1.1.0', '1.2.0');
            assert.strictEqual(result.entries.length, 1);
            assert.strictEqual(result.entries[0].date, '2024-06-15');
        });

        it('should return empty for no matching entries', () => {
            const content = '## 3.0.0\n\nFuture\n';
            const result = parseChangelog(content, '1.0.0', '2.0.0');
            assert.strictEqual(result.entries.length, 0);
        });

        it('should return unavailableReason for empty changelog', () => {
            const result = parseChangelog('No versions here', '1.0.0', '2.0.0');
            assert.ok(result.unavailableReason);
        });

        it('should truncate when too many entries', () => {
            let content = '';
            for (let i = 25; i >= 1; i--) {
                content += `## 1.0.${i}\n\nEntry ${i}\n\n`;
            }
            const result = parseChangelog(content, '1.0.0', '1.0.25');
            assert.strictEqual(result.truncated, true);
            assert.strictEqual(result.entries.length, 20);
        });

        it('should exclude current version entry', () => {
            const content = '## 1.1.0\n\nNew\n\n## 1.0.0\n\nInit\n';
            const result = parseChangelog(content, '1.0.0', '1.1.0');
            assert.strictEqual(result.entries.length, 1);
            assert.strictEqual(result.entries[0].version, '1.1.0');
        });

        it('should include latest version entry', () => {
            const content = '## 2.0.0\n\nLatest\n\n## 1.5.0\n\nMid\n\n## 1.0.0\n\nInit\n';
            const result = parseChangelog(content, '1.0.0', '2.0.0');
            assert.ok(result.entries.some(e => e.version === '2.0.0'));
        });
    });

    describe('fetchChangelog', () => {
        let fetchStub: sinon.SinonStub;

        beforeEach(() => {
            fetchStub = sinon.stub(globalThis, 'fetch');
        });

        afterEach(() => {
            fetchStub.restore();
        });

        it('should fetch CHANGELOG.md from root', async () => {
            fetchStub.resolves(new Response('## 1.0.0\nChange', { status: 200 }));
            const result = await fetchChangelog('dart-lang', 'http');
            assert.ok(result);
            assert.ok(result!.includes('1.0.0'));
            assert.ok(
                fetchStub.firstCall.args[0].includes('/contents/CHANGELOG.md'),
            );
        });

        it('should try subpath first for monorepo', async () => {
            fetchStub.onCall(0).resolves(
                new Response('## 1.0.0\nSubpath', { status: 200 }),
            );
            const result = await fetchChangelog('firebase', 'flutterfire', {
                subpath: 'packages/firebase_core',
            });
            assert.ok(result);
            assert.ok(
                fetchStub.firstCall.args[0].includes(
                    'packages/firebase_core/CHANGELOG.md',
                ),
            );
        });

        it('should fall back to root when subpath not found', async () => {
            fetchStub.onCall(0).resolves(new Response('', { status: 404 }));
            fetchStub.onCall(1).resolves(
                new Response('## 1.0.0\nRoot', { status: 200 }),
            );
            const result = await fetchChangelog('org', 'repo', {
                subpath: 'packages/pkg',
            });
            assert.ok(result);
            assert.strictEqual(fetchStub.callCount, 2);
        });

        it('should return null when not found anywhere', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));
            const result = await fetchChangelog('org', 'repo');
            assert.strictEqual(result, null);
        });

        it('should use raw Accept header', async () => {
            fetchStub.resolves(new Response('content', { status: 200 }));
            await fetchChangelog('o', 'r');
            const opts = fetchStub.firstCall.args[1];
            assert.ok(opts.headers.Accept.includes('raw'));
        });

        it('should include auth token when provided', async () => {
            fetchStub.resolves(new Response('content', { status: 200 }));
            await fetchChangelog('o', 'r', { token: 'ghp_test123' });
            const opts = fetchStub.firstCall.args[1];
            assert.ok(opts.headers.Authorization.includes('ghp_test123'));
        });
    });

    describe('buildUpdateInfo', () => {
        let fetchStub: sinon.SinonStub;

        beforeEach(() => {
            fetchStub = sinon.stub(globalThis, 'fetch');
        });

        afterEach(() => {
            fetchStub.restore();
        });

        it('should return up-to-date with no changelog when current', async () => {
            const info = await buildUpdateInfo({ current: '1.0.0', latest: '1.0.0', constraint: '^1.0.0' }, null);
            assert.strictEqual(info.updateStatus, 'up-to-date');
            assert.strictEqual(info.changelog, null);
            assert.strictEqual(fetchStub.callCount, 0);
        });

        it('should return up-to-date when constraint covers latest', async () => {
            const info = await buildUpdateInfo({ current: '8.0.11', latest: '8.1.0', constraint: '^8.0.11' }, null);
            assert.strictEqual(info.updateStatus, 'up-to-date');
            assert.strictEqual(info.changelog, null);
            assert.strictEqual(fetchStub.callCount, 0);
        });

        it('should set unavailableReason when no repo and no packageName', async () => {
            const info = await buildUpdateInfo({ current: '1.0.0', latest: '2.0.0', constraint: '^1.0.0' }, null);
            assert.strictEqual(info.updateStatus, 'major');
            assert.ok(info.changelog?.unavailableReason);
        });

        it('should fetch and parse changelog when update available', async () => {
            const changelog = '## 2.0.0\n\nBreaking change\n\n## 1.0.0\n\nInit\n';
            fetchStub.resolves(new Response(changelog, { status: 200 }));

            const info = await buildUpdateInfo(
                { current: '1.0.0', latest: '2.0.0', constraint: '^1.0.0' },
                { owner: 'org', repo: 'pkg', subpath: null },
            );
            assert.strictEqual(info.updateStatus, 'major');
            assert.strictEqual(info.changelog?.entries.length, 1);
            assert.strictEqual(info.changelog?.entries[0].version, '2.0.0');
        });

        it('should set unavailableReason when changelog not found', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));

            const info = await buildUpdateInfo(
                { current: '1.0.0', latest: '2.0.0', constraint: '^1.0.0' },
                { owner: 'org', repo: 'pkg', subpath: null },
            );
            assert.strictEqual(info.updateStatus, 'major');
            assert.ok(info.changelog?.unavailableReason);
        });

        it('should fall back to pub.dev when GitHub fails', async () => {
            const html = fs.readFileSync(
                path.join(fixturesDir, 'pub-dev-changelog.html'), 'utf8',
            );
            // GitHub 404, then pub.dev HTML success
            fetchStub.onCall(0).resolves(new Response('', { status: 404 }));
            fetchStub.onCall(1).resolves(new Response(html, { status: 200 }));

            const info = await buildUpdateInfo(
                { current: '1.0.0', latest: '2.0.0', constraint: '^1.0.0' },
                { owner: 'org', repo: 'pkg', subpath: null },
                { packageName: 'http' },
            );
            assert.strictEqual(info.changelog?.entries.length, 2);
            assert.strictEqual(info.changelog?.entries[0].version, '2.0.0');
        });

        it('should fall back to pub.dev when no repo info', async () => {
            const html = fs.readFileSync(
                path.join(fixturesDir, 'pub-dev-changelog.html'), 'utf8',
            );
            fetchStub.resolves(new Response(html, { status: 200 }));

            const info = await buildUpdateInfo(
                { current: '1.0.0', latest: '2.0.0', constraint: '^1.0.0' },
                null,
                { packageName: 'http' },
            );
            assert.strictEqual(info.changelog?.entries.length, 2);
        });
    });
});
