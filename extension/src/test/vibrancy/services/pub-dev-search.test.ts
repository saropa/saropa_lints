import * as assert from 'assert';
import * as sinon from 'sinon';
import { searchAlternatives, buildAlternatives } from '../../../vibrancy/services/pub-dev-search';

describe('pub-dev-search', () => {
    let fetchStub: sinon.SinonStub;

    beforeEach(() => {
        fetchStub = sinon.stub(globalThis, 'fetch');
    });

    afterEach(() => {
        fetchStub.restore();
    });

    describe('searchAlternatives', () => {
        it('should return empty array when no topics provided', async () => {
            const result = await searchAlternatives([], ['existing_pkg']);
            assert.deepStrictEqual(result, []);
            assert.ok(fetchStub.notCalled);
        });

        it('should search pub.dev with topic query', async () => {
            const searchResponse = {
                packages: [
                    { package: 'http' },
                    { package: 'dio' },
                ],
            };
            const scoreResponse = { grantedPoints: 140, likeCount: 500 };

            fetchStub.onCall(0).resolves(
                new Response(JSON.stringify(searchResponse), { status: 200 }),
            );
            fetchStub.onCall(1).resolves(
                new Response(JSON.stringify(scoreResponse), { status: 200 }),
            );
            fetchStub.onCall(2).resolves(
                new Response(JSON.stringify(scoreResponse), { status: 200 }),
            );

            await searchAlternatives(['networking'], ['other_pkg']);

            assert.ok(fetchStub.called);
            const searchUrl = fetchStub.firstCall.args[0];
            assert.ok(
                searchUrl.includes('topic:networking') ||
                searchUrl.includes('topic%3Anetworking'),
                `Expected URL to contain topic:networking, got: ${searchUrl}`,
            );
            assert.ok(searchUrl.includes('sort=popularity'));
        });

        it('should exclude packages in the exclude list', async () => {
            const searchResponse = {
                packages: [
                    { package: 'http' },
                    { package: 'excluded_pkg' },
                    { package: 'dio' },
                ],
            };
            const scoreResponse = { grantedPoints: 140, likeCount: 500 };

            fetchStub.onCall(0).resolves(
                new Response(JSON.stringify(searchResponse), { status: 200 }),
            );
            fetchStub.resolves(
                new Response(JSON.stringify(scoreResponse), { status: 200 }),
            );

            const result = await searchAlternatives(
                ['networking'], ['excluded_pkg'],
            );

            const names = result.map(r => r.name);
            assert.ok(!names.includes('excluded_pkg'));
        });

        it('should return max 3 suggestions', async () => {
            const searchResponse = {
                packages: [
                    { package: 'pkg1' },
                    { package: 'pkg2' },
                    { package: 'pkg3' },
                    { package: 'pkg4' },
                    { package: 'pkg5' },
                ],
            };
            const scoreResponse = { grantedPoints: 140, likeCount: 100 };

            fetchStub.onCall(0).resolves(
                new Response(JSON.stringify(searchResponse), { status: 200 }),
            );
            fetchStub.resolves(
                new Response(JSON.stringify(scoreResponse), { status: 200 }),
            );

            const result = await searchAlternatives(['topic'], []);

            assert.ok(result.length <= 3);
        });

        it('should return empty array on API error', async () => {
            fetchStub.resolves(new Response('', { status: 500 }));

            const result = await searchAlternatives(['networking'], []);

            assert.deepStrictEqual(result, []);
        });

        it('should handle multiple topics in search query', async () => {
            const searchResponse = { packages: [] };
            fetchStub.resolves(
                new Response(JSON.stringify(searchResponse), { status: 200 }),
            );

            await searchAlternatives(['networking', 'http'], []);

            const searchUrl = fetchStub.firstCall.args[0];
            assert.ok(
                searchUrl.includes('topic:networking') ||
                searchUrl.includes('topic%3Anetworking'),
                `Expected URL to contain topic:networking`,
            );
            assert.ok(
                searchUrl.includes('topic:http') ||
                searchUrl.includes('topic%3Ahttp'),
                `Expected URL to contain topic:http`,
            );
        });

        it('should mark all results as discovery source', async () => {
            const searchResponse = {
                packages: [{ package: 'dio' }],
            };
            const scoreResponse = { grantedPoints: 140, likeCount: 500 };

            fetchStub.onCall(0).resolves(
                new Response(JSON.stringify(searchResponse), { status: 200 }),
            );
            fetchStub.onCall(1).resolves(
                new Response(JSON.stringify(scoreResponse), { status: 200 }),
            );

            const result = await searchAlternatives(['networking'], []);

            assert.ok(result.every(r => r.source === 'discovery'));
        });
    });

    describe('buildAlternatives', () => {
        it('should prioritize curated replacement', () => {
            const discovery = [
                { name: 'alt1', source: 'discovery' as const, score: 80, likes: 100 },
                { name: 'alt2', source: 'discovery' as const, score: 70, likes: 50 },
            ];

            const result = buildAlternatives('curated_pkg', discovery);

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].name, 'curated_pkg');
            assert.strictEqual(result[0].source, 'curated');
        });

        it('should return discovery when no curated replacement', () => {
            const discovery = [
                { name: 'alt1', source: 'discovery' as const, score: 80, likes: 100 },
            ];

            const result = buildAlternatives(undefined, discovery);

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].name, 'alt1');
            assert.strictEqual(result[0].source, 'discovery');
        });

        it('should return empty array when no alternatives', () => {
            const result = buildAlternatives(undefined, []);
            assert.deepStrictEqual(result, []);
        });

        it('should set score to null for curated replacements', () => {
            const result = buildAlternatives('curated_pkg', []);

            assert.strictEqual(result[0].score, null);
            assert.strictEqual(result[0].likes, 0);
        });
    });
});
