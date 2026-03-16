import * as assert from 'assert';
import * as sinon from 'sinon';
import { queryVulnerabilities } from '../../../vibrancy/services/osv-api';

describe('osv-api', () => {
    let fetchStub: sinon.SinonStub;

    beforeEach(() => {
        fetchStub = sinon.stub(globalThis, 'fetch');
    });

    afterEach(() => {
        fetchStub.restore();
    });

    it('should return empty array for empty package list', async () => {
        const results = await queryVulnerabilities([]);

        assert.deepStrictEqual(results, []);
        assert.strictEqual(fetchStub.callCount, 0);
    });

    it('should query OSV batch endpoint', async () => {
        const mockResponse = {
            results: [
                { vulns: [] },
            ],
        };
        fetchStub.resolves(new Response(
            JSON.stringify(mockResponse),
            { status: 200 },
        ));

        await queryVulnerabilities([
            { name: 'http', version: '1.0.0' },
        ]);

        assert.strictEqual(fetchStub.callCount, 1);
        const [url, init] = fetchStub.firstCall.args;
        assert.strictEqual(url, 'https://api.osv.dev/v1/querybatch');
        assert.strictEqual(init.method, 'POST');
    });

    it('should return empty vulns for packages with no vulnerabilities', async () => {
        const mockResponse = {
            results: [
                { vulns: [] },
                {},
            ],
        };
        fetchStub.resolves(new Response(
            JSON.stringify(mockResponse),
            { status: 200 },
        ));

        const results = await queryVulnerabilities([
            { name: 'http', version: '1.0.0' },
            { name: 'path', version: '2.0.0' },
        ]);

        assert.strictEqual(results.length, 2);
        assert.deepStrictEqual(results[0].vulnerabilities, []);
        assert.deepStrictEqual(results[1].vulnerabilities, []);
    });

    it('should parse vulnerabilities from response', async () => {
        const mockResponse = {
            results: [
                {
                    vulns: [
                        {
                            id: 'GHSA-test-1234',
                            summary: 'Test vulnerability',
                            severity: [
                                { type: 'CVSS_V3', score: '7.5' },
                            ],
                            affected: [
                                {
                                    ranges: [
                                        {
                                            type: 'SEMVER',
                                            events: [
                                                { introduced: '0' },
                                                { fixed: '2.0.0' },
                                            ],
                                        },
                                    ],
                                },
                            ],
                            references: [
                                { type: 'ADVISORY', url: 'https://github.com/advisories/GHSA-test-1234' },
                            ],
                        },
                    ],
                },
            ],
        };
        fetchStub.resolves(new Response(
            JSON.stringify(mockResponse),
            { status: 200 },
        ));

        const results = await queryVulnerabilities([
            { name: 'vuln_pkg', version: '1.0.0' },
        ]);

        assert.strictEqual(results.length, 1);
        assert.strictEqual(results[0].name, 'vuln_pkg');
        assert.strictEqual(results[0].vulnerabilities.length, 1);

        const vuln = results[0].vulnerabilities[0];
        assert.strictEqual(vuln.id, 'GHSA-test-1234');
        assert.strictEqual(vuln.summary, 'Test vulnerability');
        assert.strictEqual(vuln.severity, 'high');
        assert.strictEqual(vuln.cvssScore, 7.5);
        assert.strictEqual(vuln.fixedVersion, '2.0.0');
        assert.strictEqual(vuln.url, 'https://github.com/advisories/GHSA-test-1234');
    });

    it('should handle multiple vulnerabilities per package', async () => {
        const mockResponse = {
            results: [
                {
                    vulns: [
                        { id: 'VULN-001', summary: 'First' },
                        { id: 'VULN-002', summary: 'Second' },
                        { id: 'VULN-003', summary: 'Third' },
                    ],
                },
            ],
        };
        fetchStub.resolves(new Response(
            JSON.stringify(mockResponse),
            { status: 200 },
        ));

        const results = await queryVulnerabilities([
            { name: 'multi_vuln', version: '1.0.0' },
        ]);

        assert.strictEqual(results[0].vulnerabilities.length, 3);
    });

    it('should return empty results on API error', async () => {
        fetchStub.resolves(new Response('', { status: 500 }));

        const results = await queryVulnerabilities([
            { name: 'pkg', version: '1.0.0' },
        ]);

        assert.strictEqual(results.length, 1);
        assert.deepStrictEqual(results[0].vulnerabilities, []);
    });

    it('should return empty results on network error', async () => {
        fetchStub.rejects(new Error('Network error'));

        const results = await queryVulnerabilities([
            { name: 'pkg', version: '1.0.0' },
        ]);

        assert.strictEqual(results.length, 1);
        assert.deepStrictEqual(results[0].vulnerabilities, []);
    });

    it('should classify severity without CVSS as medium', async () => {
        const mockResponse = {
            results: [
                {
                    vulns: [
                        { id: 'VULN-001', summary: 'No CVSS' },
                    ],
                },
            ],
        };
        fetchStub.resolves(new Response(
            JSON.stringify(mockResponse),
            { status: 200 },
        ));

        const results = await queryVulnerabilities([
            { name: 'pkg', version: '1.0.0' },
        ]);

        assert.strictEqual(results[0].vulnerabilities[0].severity, 'medium');
    });

    it('should generate OSV URL for non-GHSA IDs', async () => {
        const mockResponse = {
            results: [
                {
                    vulns: [
                        { id: 'OSV-2023-123', summary: 'OSV vuln' },
                    ],
                },
            ],
        };
        fetchStub.resolves(new Response(
            JSON.stringify(mockResponse),
            { status: 200 },
        ));

        const results = await queryVulnerabilities([
            { name: 'pkg', version: '1.0.0' },
        ]);

        assert.strictEqual(
            results[0].vulnerabilities[0].url,
            'https://osv.dev/vulnerability/OSV-2023-123',
        );
    });

    it('should generate GitHub advisory URL for GHSA IDs', async () => {
        const mockResponse = {
            results: [
                {
                    vulns: [
                        { id: 'GHSA-abcd-1234-efgh', summary: 'GHSA vuln' },
                    ],
                },
            ],
        };
        fetchStub.resolves(new Response(
            JSON.stringify(mockResponse),
            { status: 200 },
        ));

        const results = await queryVulnerabilities([
            { name: 'pkg', version: '1.0.0' },
        ]);

        assert.strictEqual(
            results[0].vulnerabilities[0].url,
            'https://github.com/advisories/GHSA-abcd-1234-efgh',
        );
    });
});
