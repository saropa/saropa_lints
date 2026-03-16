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
const fetch_retry_1 = require("../../../vibrancy/services/fetch-retry");
describe('fetch-retry', () => {
    let fetchStub;
    beforeEach(() => {
        fetchStub = sinon.stub(globalThis, 'fetch');
    });
    afterEach(() => {
        fetchStub.restore();
    });
    it('should return immediately on success', async () => {
        fetchStub.resolves(new Response('ok', { status: 200 }));
        const resp = await (0, fetch_retry_1.fetchWithRetry)('https://example.com');
        assert.strictEqual(resp.status, 200);
        assert.strictEqual(fetchStub.callCount, 1);
    });
    it('should return immediately on 404 (non-retryable)', async () => {
        fetchStub.resolves(new Response('', { status: 404 }));
        const resp = await (0, fetch_retry_1.fetchWithRetry)('https://example.com');
        assert.strictEqual(resp.status, 404);
        assert.strictEqual(fetchStub.callCount, 1);
    });
    it('should retry on 429 and succeed', async () => {
        const retryHeaders = new Headers({ 'Retry-After': '0' });
        fetchStub
            .onCall(0).resolves(new Response('', { status: 429, headers: retryHeaders }))
            .onCall(1).resolves(new Response('ok', { status: 200 }));
        const resp = await (0, fetch_retry_1.fetchWithRetry)('https://example.com');
        assert.strictEqual(resp.status, 200);
        assert.strictEqual(fetchStub.callCount, 2);
    });
    it('should retry on 500 and succeed', async () => {
        const retryHeaders = new Headers({ 'Retry-After': '0' });
        fetchStub
            .onCall(0).resolves(new Response('', { status: 500, headers: retryHeaders }))
            .onCall(1).resolves(new Response('ok', { status: 200 }));
        const resp = await (0, fetch_retry_1.fetchWithRetry)('https://example.com');
        assert.strictEqual(resp.status, 200);
        assert.strictEqual(fetchStub.callCount, 2);
    });
    it('should return last response after max retries exhausted', async () => {
        const retryHeaders = new Headers({ 'Retry-After': '0' });
        fetchStub.resolves(new Response('', { status: 503, headers: retryHeaders }));
        const resp = await (0, fetch_retry_1.fetchWithRetry)('https://example.com');
        assert.strictEqual(resp.status, 503);
        assert.strictEqual(fetchStub.callCount, 3);
    });
    it('should respect Retry-After header', async () => {
        const headers = new Headers({ 'Retry-After': '0' });
        fetchStub
            .onCall(0).resolves(new Response('', { status: 429, headers }))
            .onCall(1).resolves(new Response('ok', { status: 200 }));
        const resp = await (0, fetch_retry_1.fetchWithRetry)('https://example.com');
        assert.strictEqual(resp.status, 200);
        assert.strictEqual(fetchStub.callCount, 2);
    });
    it('should pass through request init options', async () => {
        fetchStub.resolves(new Response('ok', { status: 200 }));
        const init = { headers: { 'Authorization': 'token abc' } };
        await (0, fetch_retry_1.fetchWithRetry)('https://example.com', init);
        const calledInit = fetchStub.firstCall.args[1];
        assert.deepStrictEqual(calledInit, init);
    });
});
//# sourceMappingURL=fetch-retry.test.js.map