import * as assert from 'assert';
import * as sinon from 'sinon';
import * as fs from 'fs';
import * as path from 'path';
import {
    fetchPackageInfo, fetchPackageMetrics, fetchPublisher,
    fetchArchiveSize,
} from '../../../vibrancy/services/pub-dev-api';

const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');

describe('pub-dev-api', () => {
    let fetchStub: sinon.SinonStub;

    beforeEach(() => {
        fetchStub = sinon.stub(globalThis, 'fetch');
    });

    afterEach(() => {
        fetchStub.restore();
    });

    describe('fetchPackageInfo', () => {
        it('should parse a valid response', async () => {
            const fixture = fs.readFileSync(
                path.join(fixturesDir, 'pub-dev-response.json'), 'utf8',
            );
            fetchStub.resolves(new Response(fixture, { status: 200 }));

            const info = await fetchPackageInfo('http');
            assert.ok(info);
            assert.strictEqual(info.name, 'http');
            assert.strictEqual(info.latestVersion, '1.2.0');
            assert.strictEqual(info.repositoryUrl, 'https://github.com/dart-lang/http');
            assert.strictEqual(info.description, 'A composable, multi-platform, Future-based API for HTTP requests.');
            assert.strictEqual(info.isDiscontinued, false);
            assert.deepStrictEqual(info.topics, ['networking', 'http']);
        });

        it('should return empty topics array when not present', async () => {
            const body = JSON.stringify({
                name: 'simple',
                latest: { version: '1.0.0', pubspec: {} },
            });
            fetchStub.resolves(new Response(body, { status: 200 }));

            const info = await fetchPackageInfo('simple');
            assert.ok(info);
            assert.deepStrictEqual(info.topics, []);
        });

        it('should return null for 404', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));
            const info = await fetchPackageInfo('nonexistent');
            assert.strictEqual(info, null);
        });

        it('should call the correct URL', async () => {
            fetchStub.resolves(new Response('{}', { status: 200 }));
            await fetchPackageInfo('provider');
            assert.ok(fetchStub.calledOnce);
            assert.ok(
                fetchStub.firstCall.args[0].includes('/packages/provider'),
            );
        });
    });

    describe('fetchPublisher', () => {
        it('should return publisher ID', async () => {
            const body = JSON.stringify({ publisherId: 'dart.dev' });
            fetchStub.resolves(new Response(body, { status: 200 }));

            const pub = await fetchPublisher('path');
            assert.strictEqual(pub, 'dart.dev');
        });

        it('should return null for 404', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));
            const pub = await fetchPublisher('no_publisher_pkg');
            assert.strictEqual(pub, null);
        });

        it('should return null when publisherId is missing', async () => {
            fetchStub.resolves(new Response('{}', { status: 200 }));
            const pub = await fetchPublisher('empty_response');
            assert.strictEqual(pub, null);
        });

        it('should call the correct URL', async () => {
            fetchStub.resolves(new Response('{}', { status: 200 }));
            await fetchPublisher('path');
            assert.ok(fetchStub.calledOnce);
            assert.ok(
                fetchStub.firstCall.args[0].includes('/packages/path/publisher'),
            );
        });
    });

    describe('fetchPackageMetrics', () => {
        it('should return points and platforms', async () => {
            const fixture = fs.readFileSync(
                path.join(fixturesDir, 'pub-dev-metrics.json'), 'utf8',
            );
            fetchStub.resolves(new Response(fixture, { status: 200 }));

            const metrics = await fetchPackageMetrics('http');
            assert.strictEqual(metrics.pubPoints, 140);
            assert.deepStrictEqual(
                metrics.platforms,
                ['android', 'ios', 'linux', 'macos', 'web', 'windows'],
            );
            assert.strictEqual(metrics.wasmReady, false);
        });

        it('should return fallback for failed requests', async () => {
            fetchStub.resolves(new Response('', { status: 400 }));
            const metrics = await fetchPackageMetrics('broken');
            assert.strictEqual(metrics.pubPoints, 0);
            assert.deepStrictEqual(metrics.platforms, []);
            assert.strictEqual(metrics.wasmReady, null);
        });

        it('should call the /metrics endpoint', async () => {
            fetchStub.resolves(new Response('{}', { status: 200 }));
            await fetchPackageMetrics('provider');
            assert.ok(fetchStub.calledOnce);
            assert.ok(
                fetchStub.firstCall.args[0].includes('/packages/provider/metrics'),
            );
        });

        it('should detect WASM readiness from tags', async () => {
            const body = JSON.stringify({
                score: {
                    grantedPoints: 100,
                    tags: ['platform:web', 'is:wasm-ready'],
                },
            });
            fetchStub.resolves(new Response(body, { status: 200 }));

            const metrics = await fetchPackageMetrics('wasm_pkg');
            assert.strictEqual(metrics.wasmReady, true);
            assert.deepStrictEqual(metrics.platforms, ['web']);
        });
    });

    describe('fetchArchiveSize', () => {
        it('should return size from HEAD Content-Length', async () => {
            const apiBody = JSON.stringify({
                latest: { archive_url: 'https://pub.dev/archive/test.tar.gz' },
            });
            fetchStub.onFirstCall().resolves(new Response(apiBody, { status: 200 }));
            fetchStub.onSecondCall().resolves(
                new Response(null, {
                    status: 200,
                    headers: { 'Content-Length': '1048576' },
                }),
            );

            const size = await fetchArchiveSize('test_pkg');
            assert.strictEqual(size, 1048576);
        });

        it('should return null when API returns 404', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));
            const size = await fetchArchiveSize('nonexistent');
            assert.strictEqual(size, null);
        });

        it('should return null when Content-Length header is missing', async () => {
            const apiBody = JSON.stringify({
                latest: { archive_url: 'https://pub.dev/archive/test.tar.gz' },
            });
            fetchStub.onFirstCall().resolves(new Response(apiBody, { status: 200 }));
            fetchStub.onSecondCall().resolves(
                new Response(null, { status: 200 }),
            );

            const size = await fetchArchiveSize('no_header_pkg');
            assert.strictEqual(size, null);
        });

        it('should return null when HEAD request throws', async () => {
            const apiBody = JSON.stringify({
                latest: { archive_url: 'https://pub.dev/archive/test.tar.gz' },
            });
            fetchStub.onFirstCall().resolves(new Response(apiBody, { status: 200 }));
            fetchStub.onSecondCall().rejects(new Error('network timeout'));

            const size = await fetchArchiveSize('timeout_pkg');
            assert.strictEqual(size, null);
        });

        it('should return null for non-numeric Content-Length', async () => {
            const apiBody = JSON.stringify({
                latest: { archive_url: 'https://pub.dev/archive/test.tar.gz' },
            });
            fetchStub.onFirstCall().resolves(new Response(apiBody, { status: 200 }));
            fetchStub.onSecondCall().resolves(
                new Response(null, {
                    status: 200,
                    headers: { 'Content-Length': 'abc' },
                }),
            );

            const size = await fetchArchiveSize('bad_header_pkg');
            assert.strictEqual(size, null);
        });
    });
});
