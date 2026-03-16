import * as assert from 'assert';
import { MockMemento } from '../vscode-mock';
import { CacheService } from '../../../vibrancy/services/cache-service';

describe('CacheService', () => {
    let memento: MockMemento;
    let cache: CacheService;

    beforeEach(() => {
        memento = new MockMemento();
        cache = new CacheService(memento as any);
    });

    it('should return null for missing keys', () => {
        assert.strictEqual(cache.get('missing'), null);
    });

    it('should store and retrieve values', async () => {
        await cache.set('key1', { foo: 'bar' });
        const result = cache.get<{ foo: string }>('key1');
        assert.deepStrictEqual(result, { foo: 'bar' });
    });

    it('should return null for expired entries', async () => {
        const shortCache = new CacheService(memento as any, 1);
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
