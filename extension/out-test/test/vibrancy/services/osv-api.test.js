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
const osv_api_1 = require("../../../vibrancy/services/osv-api");
describe('osv-api', () => {
    let fetchStub;
    beforeEach(() => {
        fetchStub = sinon.stub(globalThis, 'fetch');
    });
    afterEach(() => {
        fetchStub.restore();
    });
    it('should return empty array for empty package list', async () => {
        const results = await (0, osv_api_1.queryVulnerabilities)([]);
        assert.deepStrictEqual(results, []);
        assert.strictEqual(fetchStub.callCount, 0);
    });
    it('should query OSV batch endpoint', async () => {
        const mockResponse = {
            results: [
                { vulns: [] },
            ],
        };
        fetchStub.resolves(new Response(JSON.stringify(mockResponse), { status: 200 }));
        await (0, osv_api_1.queryVulnerabilities)([
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
        fetchStub.resolves(new Response(JSON.stringify(mockResponse), { status: 200 }));
        const results = await (0, osv_api_1.queryVulnerabilities)([
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
        fetchStub.resolves(new Response(JSON.stringify(mockResponse), { status: 200 }));
        const results = await (0, osv_api_1.queryVulnerabilities)([
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
        fetchStub.resolves(new Response(JSON.stringify(mockResponse), { status: 200 }));
        const results = await (0, osv_api_1.queryVulnerabilities)([
            { name: 'multi_vuln', version: '1.0.0' },
        ]);
        assert.strictEqual(results[0].vulnerabilities.length, 3);
    });
    it('should return empty results on API error', async () => {
        fetchStub.resolves(new Response('', { status: 500 }));
        const results = await (0, osv_api_1.queryVulnerabilities)([
            { name: 'pkg', version: '1.0.0' },
        ]);
        assert.strictEqual(results.length, 1);
        assert.deepStrictEqual(results[0].vulnerabilities, []);
    });
    it('should return empty results on network error', async () => {
        fetchStub.rejects(new Error('Network error'));
        const results = await (0, osv_api_1.queryVulnerabilities)([
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
        fetchStub.resolves(new Response(JSON.stringify(mockResponse), { status: 200 }));
        const results = await (0, osv_api_1.queryVulnerabilities)([
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
        fetchStub.resolves(new Response(JSON.stringify(mockResponse), { status: 200 }));
        const results = await (0, osv_api_1.queryVulnerabilities)([
            { name: 'pkg', version: '1.0.0' },
        ]);
        assert.strictEqual(results[0].vulnerabilities[0].url, 'https://osv.dev/vulnerability/OSV-2023-123');
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
        fetchStub.resolves(new Response(JSON.stringify(mockResponse), { status: 200 }));
        const results = await (0, osv_api_1.queryVulnerabilities)([
            { name: 'pkg', version: '1.0.0' },
        ]);
        assert.strictEqual(results[0].vulnerabilities[0].url, 'https://github.com/advisories/GHSA-abcd-1234-efgh');
    });
});
//# sourceMappingURL=osv-api.test.js.map