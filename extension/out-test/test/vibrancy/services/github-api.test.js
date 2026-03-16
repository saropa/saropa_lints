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
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const github_api_1 = require("../../../vibrancy/services/github-api");
// From compiled out-test/test/vibrancy/services/ go up 4 levels to extension/,
// then into src/test/fixtures/.
const fixturesDir = path.join(__dirname, '..', '..', '..', '..', 'src', 'test', 'fixtures');
describe('github-api', () => {
    describe('extractGitHubRepo', () => {
        it('should parse standard GitHub URLs', () => {
            const result = (0, github_api_1.extractGitHubRepo)('https://github.com/dart-lang/http');
            assert.deepStrictEqual(result, { owner: 'dart-lang', repo: 'http' });
        });
        it('should parse URLs with trailing paths', () => {
            const result = (0, github_api_1.extractGitHubRepo)('https://github.com/org/repo/tree/main');
            assert.deepStrictEqual(result, { owner: 'org', repo: 'repo' });
        });
        it('should return null for non-GitHub URLs', () => {
            assert.strictEqual((0, github_api_1.extractGitHubRepo)('https://gitlab.com/a/b'), null);
        });
        it('should return null for invalid URLs', () => {
            assert.strictEqual((0, github_api_1.extractGitHubRepo)('not-a-url'), null);
        });
    });
    describe('repo URL override priority', () => {
        it('should prefer override URL over pub.dev URL', () => {
            const overrides = {
                'my_pkg': 'https://github.com/correct-org/my_pkg',
            };
            const pubDevUrl = 'https://github.com/wrong-org/old_repo';
            const repoUrl = overrides['my_pkg'] ?? pubDevUrl;
            const parsed = (0, github_api_1.extractGitHubRepo)(repoUrl);
            assert.deepStrictEqual(parsed, {
                owner: 'correct-org', repo: 'my_pkg',
            });
        });
        it('should fall back to pub.dev URL when no override', () => {
            const overrides = {};
            const pubDevUrl = 'https://github.com/dart-lang/http';
            const repoUrl = overrides['http'] ?? pubDevUrl;
            const parsed = (0, github_api_1.extractGitHubRepo)(repoUrl);
            assert.deepStrictEqual(parsed, {
                owner: 'dart-lang', repo: 'http',
            });
        });
        it('should handle null pub.dev URL with no override', () => {
            const overrides = {};
            const pubDevUrl = null;
            const repoUrl = overrides['pkg'] ?? pubDevUrl ?? null;
            assert.strictEqual(repoUrl, null);
        });
        it('should use override even when pub.dev URL is null', () => {
            const overrides = {
                'orphan_pkg': 'https://github.com/org/orphan_pkg',
            };
            const pubDevUrl = null;
            const repoUrl = overrides['orphan_pkg'] ?? pubDevUrl ?? null;
            const parsed = (0, github_api_1.extractGitHubRepo)(repoUrl);
            assert.deepStrictEqual(parsed, {
                owner: 'org', repo: 'orphan_pkg',
            });
        });
    });
    describe('fetchRepoMetrics', () => {
        let fetchStub;
        function loadFixture(name) {
            return fs.readFileSync(path.join(fixturesDir, name), 'utf8');
        }
        /** Stub all 5 GitHub API endpoints (repo, closed issues, closed PRs, open issues, open PRs). */
        function stubAllEndpoints(openStatus = 200, openPrsStatus = 200) {
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
            const metrics = await (0, github_api_1.fetchRepoMetrics)('dart-lang', 'http');
            assert.ok(metrics);
            assert.strictEqual(metrics.stars, 890);
            assert.strictEqual(metrics.openIssues, 42);
            // Default stubAllEndpoints returns 0 open PRs, so trueOpenIssues = 42 - 0
            assert.strictEqual(metrics.openPullRequests, 0);
            assert.strictEqual(metrics.trueOpenIssues, 42);
        });
        it('should extract license spdx_id from repo response', async () => {
            stubAllEndpoints();
            const metrics = await (0, github_api_1.fetchRepoMetrics)('dart-lang', 'http');
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
            const metrics = await (0, github_api_1.fetchRepoMetrics)('org', 'pkg');
            assert.ok(metrics);
            assert.strictEqual(metrics.license, null);
        });
        it('should include flagged issues from open issues', async () => {
            stubAllEndpoints();
            const metrics = await (0, github_api_1.fetchRepoMetrics)('dart-lang', 'http');
            assert.ok(metrics);
            assert.ok(metrics.flaggedIssues.length > 0);
            assert.ok(metrics.flaggedIssues.some(f => f.matchedSignals.includes('obsolete')));
        });
        it('should return empty flaggedIssues when open issues fetch fails', async () => {
            stubAllEndpoints(403);
            const metrics = await (0, github_api_1.fetchRepoMetrics)('dart-lang', 'http');
            assert.ok(metrics);
            assert.deepStrictEqual(metrics.flaggedIssues, []);
        });
        it('should return null when repo request fails', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));
            const metrics = await (0, github_api_1.fetchRepoMetrics)('no', 'repo');
            assert.strictEqual(metrics, null);
        });
        it('should include auth header when token provided', async () => {
            fetchStub.resolves(new Response('{}', { status: 404 }));
            await (0, github_api_1.fetchRepoMetrics)('a', 'b', { token: 'my-token' });
            const headers = fetchStub.firstCall.args[1]?.headers;
            assert.ok(headers?.Authorization?.includes('my-token'));
        });
        it('should extract pushed_at and repoUrl from repo response', async () => {
            stubAllEndpoints();
            const metrics = await (0, github_api_1.fetchRepoMetrics)('dart-lang', 'http');
            assert.ok(metrics);
            // Fixture has pushed_at: "2024-06-10T08:00:00Z"
            assert.strictEqual(typeof metrics.daysSinceLastCommit, 'number');
            assert.ok(metrics.daysSinceLastCommit >= 0);
            assert.strictEqual(metrics.repoUrl, 'https://github.com/dart-lang/http');
        });
        it('should omit isArchived for non-archived repos', async () => {
            // Fixture has archived: false → isArchived should be undefined (not false)
            stubAllEndpoints();
            const metrics = await (0, github_api_1.fetchRepoMetrics)('dart-lang', 'http');
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
            const metrics = await (0, github_api_1.fetchRepoMetrics)('dart-lang', 'http');
            assert.ok(metrics);
            assert.strictEqual(metrics.openPullRequests, 3);
            // trueOpenIssues = openIssues (42) minus open PRs (3) = 39
            assert.strictEqual(metrics.trueOpenIssues, 39);
        });
        it('should handle open PRs fetch failure gracefully', async () => {
            stubAllEndpoints(200, 403);
            const metrics = await (0, github_api_1.fetchRepoMetrics)('dart-lang', 'http');
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
            const metrics = await (0, github_api_1.fetchRepoMetrics)('org', 'old');
            assert.ok(metrics);
            assert.strictEqual(metrics.isArchived, true);
        });
    });
});
//# sourceMappingURL=github-api.test.js.map