import * as assert from 'assert';
import * as sinon from 'sinon';
import { fetchWithRetry } from '../../../vibrancy/services/fetch-retry';

describe('fetch-retry', () => {
    let fetchStub: sinon.SinonStub;

    beforeEach(() => {
        fetchStub = sinon.stub(globalThis, 'fetch');
    });

    afterEach(() => {
        fetchStub.restore();
    });

    it('should return immediately on success', async () => {
        fetchStub.resolves(new Response('ok', { status: 200 }));

        const resp = await fetchWithRetry('https://example.com');

        assert.strictEqual(resp.status, 200);
        assert.strictEqual(fetchStub.callCount, 1);
    });

    it('should return immediately on 404 (non-retryable)', async () => {
        fetchStub.resolves(new Response('', { status: 404 }));

        const resp = await fetchWithRetry('https://example.com');

        assert.strictEqual(resp.status, 404);
        assert.strictEqual(fetchStub.callCount, 1);
    });

    it('should retry on 429 and succeed', async () => {
        const retryHeaders = new Headers({ 'Retry-After': '0' });
        fetchStub
            .onCall(0).resolves(
                new Response('', { status: 429, headers: retryHeaders }),
            )
            .onCall(1).resolves(new Response('ok', { status: 200 }));

        const resp = await fetchWithRetry('https://example.com');

        assert.strictEqual(resp.status, 200);
        assert.strictEqual(fetchStub.callCount, 2);
    });

    it('should retry on 500 and succeed', async () => {
        const retryHeaders = new Headers({ 'Retry-After': '0' });
        fetchStub
            .onCall(0).resolves(
                new Response('', { status: 500, headers: retryHeaders }),
            )
            .onCall(1).resolves(new Response('ok', { status: 200 }));

        const resp = await fetchWithRetry('https://example.com');

        assert.strictEqual(resp.status, 200);
        assert.strictEqual(fetchStub.callCount, 2);
    });

    it('should return last response after max retries exhausted', async () => {
        const retryHeaders = new Headers({ 'Retry-After': '0' });
        fetchStub.resolves(
            new Response('', { status: 503, headers: retryHeaders }),
        );

        const resp = await fetchWithRetry('https://example.com');

        assert.strictEqual(resp.status, 503);
        assert.strictEqual(fetchStub.callCount, 3);
    });

    it('should respect Retry-After header', async () => {
        const headers = new Headers({ 'Retry-After': '0' });
        fetchStub
            .onCall(0).resolves(
                new Response('', { status: 429, headers }),
            )
            .onCall(1).resolves(new Response('ok', { status: 200 }));

        const resp = await fetchWithRetry('https://example.com');

        assert.strictEqual(resp.status, 200);
        assert.strictEqual(fetchStub.callCount, 2);
    });

    it('should pass through request init options', async () => {
        fetchStub.resolves(new Response('ok', { status: 200 }));
        const init = { headers: { 'Authorization': 'token abc' } };

        await fetchWithRetry('https://example.com', init);

        const calledInit = fetchStub.firstCall.args[1];
        assert.deepStrictEqual(calledInit, init);
    });
});
