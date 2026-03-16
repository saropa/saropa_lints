import * as assert from 'assert';
import * as sinon from 'sinon';
import {
    queryGitHubAdvisories,
    mergeVulnerabilities,
} from '../../../vibrancy/services/github-advisory-api';
import { Vulnerability } from '../../../vibrancy/types';

describe('github-advisory-api', () => {
    let fetchStub: sinon.SinonStub;

    beforeEach(() => {
        fetchStub = sinon.stub(globalThis, 'fetch');
    });

    afterEach(() => {
        sinon.restore();
    });

    describe('queryGitHubAdvisories', () => {
        it('should return empty array for empty package list', async () => {
            const results = await queryGitHubAdvisories([]);

            assert.deepStrictEqual(results, []);
            assert.strictEqual(fetchStub.callCount, 0);
        });

        it('should query GitHub API for each package', async () => {
            fetchStub.resolves(new Response(JSON.stringify([]), { status: 200 }));

            await queryGitHubAdvisories([
                { name: 'http', version: '1.0.0' },
                { name: 'path', version: '2.0.0' },
            ]);

            assert.strictEqual(fetchStub.callCount, 2);
        });

        it('should parse advisory response correctly', async () => {
            const mockAdvisory = {
                ghsa_id: 'GHSA-xxxx-yyyy-zzzz',
                cve_id: 'CVE-2024-1234',
                summary: 'Test vulnerability',
                description: 'A test vulnerability description',
                severity: 'high',
                cvss: { score: 8.5, vector_string: 'CVSS:3.1/AV:N/AC:L' },
                vulnerabilities: [{
                    package: { ecosystem: 'pub', name: 'test_pkg' },
                    vulnerable_version_range: '< 1.0.0',
                    first_patched_version: '1.0.0',
                }],
                html_url: 'https://github.com/advisories/GHSA-xxxx-yyyy-zzzz',
            };

            fetchStub.resolves(new Response(
                JSON.stringify([mockAdvisory]),
                { status: 200 },
            ));

            const results = await queryGitHubAdvisories([
                { name: 'test_pkg', version: '0.9.0' },
            ]);

            assert.strictEqual(results.length, 1);
            assert.strictEqual(results[0].name, 'test_pkg');
            assert.strictEqual(results[0].vulnerabilities.length, 1);
            assert.strictEqual(results[0].vulnerabilities[0].id, 'GHSA-xxxx-yyyy-zzzz');
            assert.strictEqual(results[0].vulnerabilities[0].severity, 'high');
            assert.strictEqual(results[0].vulnerabilities[0].cvssScore, 8.5);
            assert.strictEqual(results[0].vulnerabilities[0].fixedVersion, '1.0.0');
        });

        it('should return empty results on 404', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));

            const results = await queryGitHubAdvisories([
                { name: 'nonexistent', version: '1.0.0' },
            ]);

            assert.strictEqual(results.length, 1);
            assert.deepStrictEqual(results[0].vulnerabilities, []);
        });

        it('should return empty results on API error', async () => {
            fetchStub.resolves(new Response('', { status: 500 }));

            const results = await queryGitHubAdvisories([
                { name: 'pkg', version: '1.0.0' },
            ]);

            assert.strictEqual(results.length, 1);
            assert.deepStrictEqual(results[0].vulnerabilities, []);
        });

        it('should include authorization header when token provided', async () => {
            fetchStub.resolves(new Response(JSON.stringify([]), { status: 200 }));

            await queryGitHubAdvisories(
                [{ name: 'pkg', version: '1.0.0' }],
                'test-token',
            );

            const callArgs = fetchStub.firstCall.args;
            const headers = callArgs[1]?.headers as Record<string, string>;
            assert.strictEqual(headers['Authorization'], 'Bearer test-token');
        });

        it('should use cache for repeated queries', async () => {
            fetchStub.resolves(new Response(JSON.stringify([]), { status: 200 }));

            const mockCache = {
                get: sinon.stub(),
                set: sinon.stub(),
            };

            // First call - cache miss
            mockCache.get.returns(undefined);
            await queryGitHubAdvisories(
                [{ name: 'cached_pkg', version: '1.0.0' }],
                undefined,
                mockCache as any,
            );
            assert.strictEqual(fetchStub.callCount, 1);

            // Second call - cache hit
            mockCache.get.returns([]);
            await queryGitHubAdvisories(
                [{ name: 'cached_pkg', version: '1.0.0' }],
                undefined,
                mockCache as any,
            );
            // fetch should not be called again
            assert.strictEqual(fetchStub.callCount, 1);
        });

        it('should handle network errors gracefully', async () => {
            fetchStub.rejects(new Error('Network error'));

            const results = await queryGitHubAdvisories([
                { name: 'pkg', version: '1.0.0' },
            ]);

            assert.strictEqual(results.length, 1);
            assert.deepStrictEqual(results[0].vulnerabilities, []);
        });

        it('should process packages in parallel batches', async () => {
            fetchStub.resolves(new Response(JSON.stringify([]), { status: 200 }));

            const packages = Array.from({ length: 10 }, (_, i) => ({
                name: `pkg${i}`,
                version: '1.0.0',
            }));

            await queryGitHubAdvisories(packages);

            assert.strictEqual(fetchStub.callCount, 10);
        });
    });

    describe('mergeVulnerabilities', () => {
        it('should return empty array for empty sources', () => {
            const result = mergeVulnerabilities([], []);
            assert.deepStrictEqual(result, []);
        });

        it('should combine vulnerabilities from multiple sources', () => {
            const osv: Vulnerability[] = [{
                id: 'OSV-2024-001',
                summary: 'OSV vuln',
                severity: 'medium',
                cvssScore: 5.0,
                fixedVersion: '1.0.1',
                url: 'https://osv.dev/OSV-2024-001',
            }];
            const ghsa: Vulnerability[] = [{
                id: 'GHSA-aaaa-bbbb-cccc',
                summary: 'GHSA vuln',
                severity: 'high',
                cvssScore: 8.0,
                fixedVersion: '1.0.2',
                url: 'https://github.com/advisories/GHSA-aaaa-bbbb-cccc',
            }];

            const result = mergeVulnerabilities(osv, ghsa);

            assert.strictEqual(result.length, 2);
            assert.ok(result.some(v => v.id === 'OSV-2024-001'));
            assert.ok(result.some(v => v.id === 'GHSA-aaaa-bbbb-cccc'));
        });

        it('should deduplicate by ID', () => {
            const source1: Vulnerability[] = [{
                id: 'GHSA-xxxx-yyyy-zzzz',
                summary: 'Same vuln source 1',
                severity: 'high',
                cvssScore: 8.0,
                fixedVersion: '1.0.0',
                url: 'https://github.com/advisories/GHSA-xxxx-yyyy-zzzz',
            }];
            const source2: Vulnerability[] = [{
                id: 'GHSA-xxxx-yyyy-zzzz',
                summary: 'Same vuln source 2',
                severity: 'high',
                cvssScore: 8.0,
                fixedVersion: '1.0.0',
                url: 'https://github.com/advisories/GHSA-xxxx-yyyy-zzzz',
            }];

            const result = mergeVulnerabilities(source1, source2);

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].id, 'GHSA-xxxx-yyyy-zzzz');
        });
    });
});
