import * as assert from 'assert';
import * as sinon from 'sinon';
import * as fs from 'fs';
import * as path from 'path';
import { extractGitHubRepo, fetchRepoMetrics, parseMarkdownImages } from '../../../vibrancy/services/github-api';

// From compiled out-test/test/vibrancy/services/ go up 4 levels to extension/,
// then into src/test/fixtures/.
const fixturesDir = path.join(__dirname, '..', '..', '..', '..', 'src', 'test', 'fixtures');

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

        /** Stub all 5 GitHub API endpoints (repo, closed issues, closed PRs, open issues, open PRs). */
        function stubAllEndpoints(openStatus = 200, openPrsStatus = 200): void {
            fetchStub.onCall(0).resolves(new Response(loadFixture('github-repo.json'), { status: 200 }));
            fetchStub.onCall(1).resolves(new Response(loadFixture('github-issues.json'), { status: 200 }));
            fetchStub.onCall(2).resolves(new Response(loadFixture('github-pulls.json'), { status: 200 }));
            const openBody = openStatus === 200
                ? loadFixture('github-open-issues.json') : '';
            fetchStub.onCall(3).resolves(new Response(openBody, { status: openStatus }));
            // 5th call: open PRs count
            const prsBody = openPrsStatus === 200 ? '[]' : '';
            fetchStub.onCall(4).resolves(new Response(prsBody, { status: openPrsStatus }));
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
            // Default stubAllEndpoints returns 0 open PRs, so trueOpenIssues = 42 - 0
            assert.strictEqual(metrics.openPullRequests, 0);
            assert.strictEqual(metrics.trueOpenIssues, 42);
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
            fetchStub.onCall(4).resolves(new Response('[]', { status: 200 }));
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

        it('should extract pushed_at and repoUrl from repo response', async () => {
            stubAllEndpoints();
            const metrics = await fetchRepoMetrics('dart-lang', 'http');
            assert.ok(metrics);
            // Fixture has pushed_at: "2024-06-10T08:00:00Z"
            assert.strictEqual(typeof metrics.daysSinceLastCommit, 'number');
            assert.ok(metrics.daysSinceLastCommit! >= 0);
            assert.strictEqual(metrics.repoUrl, 'https://github.com/dart-lang/http');
        });

        it('should omit isArchived for non-archived repos', async () => {
            // Fixture has archived: false → isArchived should be undefined (not false)
            stubAllEndpoints();
            const metrics = await fetchRepoMetrics('dart-lang', 'http');
            assert.ok(metrics);
            assert.strictEqual(metrics.isArchived, undefined);
        });

        it('should compute trueOpenIssues when open PRs available', async () => {
            // Build stubs inline to avoid double-setting onCall(4)
            fetchStub.onCall(0).resolves(new Response(loadFixture('github-repo.json'), { status: 200 }));
            fetchStub.onCall(1).resolves(new Response(loadFixture('github-issues.json'), { status: 200 }));
            fetchStub.onCall(2).resolves(new Response(loadFixture('github-pulls.json'), { status: 200 }));
            fetchStub.onCall(3).resolves(new Response(loadFixture('github-open-issues.json'), { status: 200 }));
            // 3 open PRs
            fetchStub.onCall(4).resolves(new Response(JSON.stringify([{}, {}, {}]), { status: 200 }));
            const metrics = await fetchRepoMetrics('dart-lang', 'http');
            assert.ok(metrics);
            assert.strictEqual(metrics.openPullRequests, 3);
            // trueOpenIssues = openIssues (42) minus open PRs (3) = 39
            assert.strictEqual(metrics.trueOpenIssues, 39);
        });

        it('should handle open PRs fetch failure gracefully', async () => {
            stubAllEndpoints(200, 403);
            const metrics = await fetchRepoMetrics('dart-lang', 'http');
            assert.ok(metrics);
            // When open PRs fetch fails, both fields stay undefined
            assert.strictEqual(metrics.openPullRequests, undefined);
            assert.strictEqual(metrics.trueOpenIssues, undefined);
        });

        it('should detect archived repository', async () => {
            const archivedRepo = JSON.stringify({
                full_name: 'org/old',
                html_url: 'https://github.com/org/old',
                stargazers_count: 50,
                open_issues_count: 10,
                updated_at: '2023-01-01T00:00:00Z',
                pushed_at: '2022-06-01T00:00:00Z',
                archived: true,
                license: null,
            });
            fetchStub.onCall(0).resolves(new Response(archivedRepo, { status: 200 }));
            fetchStub.onCall(1).resolves(new Response('[]', { status: 200 }));
            fetchStub.onCall(2).resolves(new Response('[]', { status: 200 }));
            fetchStub.onCall(3).resolves(new Response('[]', { status: 200 }));
            fetchStub.onCall(4).resolves(new Response('[]', { status: 200 }));
            const metrics = await fetchRepoMetrics('org', 'old');
            assert.ok(metrics);
            assert.strictEqual(metrics.isArchived, true);
        });
    });

    describe('parseMarkdownImages', () => {
        const owner = 'test-org';
        const repo = 'test-repo';
        const rawBase = `https://raw.githubusercontent.com/${owner}/${repo}/HEAD/`;

        it('should extract markdown image URLs', () => {
            const md = '# Title\n![Logo](logo.png)\nSome text\n![Screenshot](docs/screen.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls.length, 2);
            assert.strictEqual(result.imageUrls[0], `${rawBase}logo.png`);
            assert.strictEqual(result.imageUrls[1], `${rawBase}docs/screen.png`);
        });

        it('should extract HTML img tags', () => {
            const md = '# Title\n<img src="assets/logo.png" alt="logo" />';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls.length, 1);
            assert.strictEqual(result.imageUrls[0], `${rawBase}assets/logo.png`);
        });

        it('should resolve absolute URLs without modification', () => {
            const md = '![Logo](https://example.com/logo.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls[0], 'https://example.com/logo.png');
        });

        it('should resolve ../ relative paths correctly', () => {
            // URL constructor resolves ../ against the base
            const md = '![Logo](../assets/logo.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.ok(
                result.imageUrls[0].includes('assets/logo.png'),
                `Expected resolved URL, got: ${result.imageUrls[0]}`,
            );
            // Should NOT contain ../ in the final URL
            assert.ok(
                !result.imageUrls[0].includes('../'),
                `URL should not contain ../, got: ${result.imageUrls[0]}`,
            );
        });

        it('should resolve ./ relative paths', () => {
            const md = '![Logo](./assets/logo.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls[0], `${rawBase}assets/logo.png`);
        });

        it('should filter out badge images from shields.io', () => {
            const md = '![Badge](https://img.shields.io/badge/coverage-90-green)\n![Real](screenshot.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls.length, 1);
            assert.strictEqual(result.imageUrls[0], `${rawBase}screenshot.png`);
        });

        it('should filter out GitHub Actions workflow badges', () => {
            const md = '![CI](https://github.com/org/repo/workflows/CI/badge.svg)\n![Real](demo.gif)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls.length, 1);
            assert.strictEqual(result.imageUrls[0], `${rawBase}demo.gif`);
        });

        it('should handle URLs with parentheses', () => {
            const md = '![Screen](https://example.com/image(1).png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls.length, 1);
            assert.strictEqual(result.imageUrls[0], 'https://example.com/image(1).png');
        });

        it('should deduplicate identical image URLs', () => {
            const md = '![A](logo.png)\n![B](logo.png)\n![C](other.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls.length, 2);
        });

        it('should cap at 5 images', () => {
            const images = Array.from({ length: 10 }, (_, i) => `![img](img${i}.png)`).join('\n');
            const result = parseMarkdownImages(images, owner, repo);
            assert.strictEqual(result.imageUrls.length, 5);
        });

        it('should identify logo as first non-badge image before ## heading', () => {
            const md = '# My Package\n![Badge](https://img.shields.io/v1)\n![Logo](logo.png)\n## Installation\n![Screen](screen.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.logoUrl, `${rawBase}logo.png`);
        });

        it('should return null logo when no images before ## heading', () => {
            const md = '## Setup\n![Screen](screen.png)';
            const result = parseMarkdownImages(md, owner, repo);
            // No ## heading means entire doc is checked — screen.png appears after ## Setup
            // Actually the regex searches for ^##\s which matches "## Setup" at position 0
            // So preHeading is empty string
            assert.strictEqual(result.logoUrl, null);
        });

        it('should return null logo when only badges before ## heading', () => {
            const md = '# Title\n![Badge](https://img.shields.io/v1)\n## Docs\n![Real](real.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.logoUrl, null);
        });

        it('should return empty arrays for markdown with no images', () => {
            const md = '# Title\nJust text, no images here.';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls.length, 0);
            assert.strictEqual(result.logoUrl, null);
        });

        it('should not filter pub.dev package screenshot URLs', () => {
            // The badge filter should NOT block legitimate package screenshots
            // Only pub.dev/static/ paths (badge assets) should be filtered
            const md = '![Demo](https://pub.dev/packages/my_pkg/screenshot.png)';
            const result = parseMarkdownImages(md, owner, repo);
            assert.strictEqual(result.imageUrls.length, 1);
        });
    });
});
