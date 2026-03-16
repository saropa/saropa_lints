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
const vscode_mock_1 = require("../vscode-mock");
const cache_service_1 = require("../../../vibrancy/services/cache-service");
describe('CacheService', () => {
    let memento;
    let cache;
    beforeEach(() => {
        memento = new vscode_mock_1.MockMemento();
        cache = new cache_service_1.CacheService(memento);
    });
    it('should return null for missing keys', () => {
        assert.strictEqual(cache.get('missing'), null);
    });
    it('should store and retrieve values', async () => {
        await cache.set('key1', { foo: 'bar' });
        const result = cache.get('key1');
        assert.deepStrictEqual(result, { foo: 'bar' });
    });
    it('should return null for expired entries', async () => {
        const shortCache = new cache_service_1.CacheService(memento, 1);
        await shortCache.set('key2', 'value');
        await new Promise(r => setTimeout(r, 5));
        assert.strictEqual(shortCache.get('key2'), null);
    });
    it('should clear all prefixed keys', async () => {
        await cache.set('a', 1);
        await cache.set('b', 2);
        await cache.clear();
        assert.strictEqual(cache.get('a'), null);
        assert.strictEqual(cache.get('b'), null);
    });
});
//# sourceMappingURL=cache-service.test.js.map