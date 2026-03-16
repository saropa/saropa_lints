import * as assert from 'assert';
import * as sinon from 'sinon';
import * as fs from 'fs';
import * as path from 'path';
import { extractGitHubRepo, fetchRepoMetrics } from '../../../vibrancy/services/github-api';

const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');

describe('github-api', () => {
    describe('extractGitHubRepo', () => {
        it('should parse standard GitHub URLs', () => {
            const result = extractGitHubRepo('https://github.com/dart-lang/http');
            assert.deepStrictEqual(result, { owner: 'dart-lang', repo: 'http' });
        });

        it('should parse URLs with trailing paths', () => {
            const result = extractGitHubRepo('https://github.com/org/repo/tree/main');
            assert.deepStrictEqual(result, { owner: 'org', repo: 'repo' });
        });

        it('should return null for non-GitHub URLs', () => {
            assert.strictEqual(extractGitHubRepo('https://gitlab.com/a/b'), null);
        });

        it('should return null for invalid URLs', () => {
            assert.strictEqual(extractGitHubRepo('not-a-url'), null);
        });
    });

    describe('repo URL override priority', () => {
        it('should prefer override URL over pub.dev URL', () => {
            const overrides: Record<string, string> = {
                'my_pkg': 'https://github.com/correct-org/my_pkg',
            };
            const pubDevUrl = 'https://github.com/wrong-org/old_repo';
            const repoUrl = overrides['my_pkg'] ?? pubDevUrl;
            const parsed = extractGitHubRepo(repoUrl);
            assert.deepStrictEqual(parsed, {
                owner: 'correct-org', repo: 'my_pkg',
            });
        });

        it('should fall back to pub.dev URL when no override', () => {
            const overrides: Record<string, string> = {};
            const pubDevUrl = 'https://github.com/dart-lang/http';
            const repoUrl = overrides['http'] ?? pubDevUrl;
            const parsed = extractGitHubRepo(repoUrl);
            assert.deepStrictEqual(parsed, {
                owner: 'dart-lang', repo: 'http',
            });
        });

        it('should handle null pub.dev URL with no override', () => {
            const overrides: Record<string, string> = {};
            const pubDevUrl: string | null = null;
            const repoUrl = overrides['pkg'] ?? pubDevUrl ?? null;
            assert.strictEqual(repoUrl, null);
        });

        it('should use override even when pub.dev URL is null', () => {
            const overrides: Record<string, string> = {
                'orphan_pkg': 'https://github.com/org/orphan_pkg',
            };
            const pubDevUrl: string | null = null;
            const repoUrl = overrides['orphan_pkg'] ?? pubDevUrl ?? null;
            const parsed = extractGitHubRepo(repoUrl!);
            assert.deepStrictEqual(parsed, {
                owner: 'org', repo: 'orphan_pkg',
            });
        });
    });

    describe('fetchRepoMetrics', () => {
        let fetchStub: sinon.SinonStub;

        function loadFixture(name: string): string {
            return fs.readFileSync(path.join(fixturesDir, name), 'utf8');
        }

        function stubAllEndpoints(openStatus = 200): void {
            fetchStub.onCall(0).resolves(new Response(loadFixture('github-repo.json'), { status: 200 }));
            fetchStub.onCall(1).resolves(new Response(loadFixture('github-issues.json'), { status: 200 }));
            fetchStub.onCall(2).resolves(new Response(loadFixture('github-pulls.json'), { status: 200 }));
            const openBody = openStatus === 200
                ? loadFixture('github-open-issues.json') : '';
            fetchStub.onCall(3).resolves(new Response(openBody, { status: openStatus }));
        }

        beforeEach(() => {
            fetchStub = sinon.stub(globalThis, 'fetch');
        });

        afterEach(() => {
            fetchStub.restore();
        });

        it('should parse fixture responses into metrics', async () => {
            stubAllEndpoints();
            const metrics = await fetchRepoMetrics('dart-lang', 'http');
            assert.ok(metrics);
            assert.strictEqual(metrics.stars, 890);
            assert.strictEqual(metrics.openIssues, 42);
        });

        it('should extract license spdx_id from repo response', async () => {
            stubAllEndpoints();
            const metrics = await fetchRepoMetrics('dart-lang', 'http');
            assert.ok(metrics);
            assert.strictEqual(metrics.license, 'BSD-3-Clause');
        });

        it('should return null license when repo has no license field', async () => {
            const noLicense = JSON.stringify({
                full_name: 'org/pkg', stargazers_count: 10,
                open_issues_count: 0, updated_at: '2024-01-01T00:00:00Z',
            });
            fetchStub.onCall(0).resolves(new Response(noLicense, { status: 200 }));
            fetchStub.onCall(1).resolves(new Response('[]', { status: 200 }));
            fetchStub.onCall(2).resolves(new Response('[]', { status: 200 }));
            fetchStub.onCall(3).resolves(new Response('[]', { status: 200 }));
            const metrics = await fetchRepoMetrics('org', 'pkg');
            assert.ok(metrics);
            assert.strictEqual(metrics.license, null);
        });

        it('should include flagged issues from open issues', async () => {
            stubAllEndpoints();
            const metrics = await fetchRepoMetrics('dart-lang', 'http');
            assert.ok(metrics);
            assert.ok(metrics.flaggedIssues.length > 0);
            assert.ok(metrics.flaggedIssues.some(
                f => f.matchedSignals.includes('obsolete'),
            ));
        });

        it('should return empty flaggedIssues when open issues fetch fails', async () => {
            stubAllEndpoints(403);
            const metrics = await fetchRepoMetrics('dart-lang', 'http');
            assert.ok(metrics);
            assert.deepStrictEqual(metrics.flaggedIssues, []);
        });

        it('should return null when repo request fails', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));
            const metrics = await fetchRepoMetrics('no', 'repo');
            assert.strictEqual(metrics, null);
        });

        it('should include auth header when token provided', async () => {
            fetchStub.resolves(new Response('{}', { status: 404 }));
            await fetchRepoMetrics('a', 'b', { token: 'my-token' });
            const headers = fetchStub.firstCall.args[1]?.headers;
            assert.ok(headers?.Authorization?.includes('my-token'));
        });
    });
});
