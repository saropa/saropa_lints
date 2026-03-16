import * as assert from 'assert';
import { ScanLogger } from '../../../vibrancy/services/scan-logger';

describe('ScanLogger', () => {
    let logger: ScanLogger;

    beforeEach(() => {
        logger = new ScanLogger();
    });

    it('should produce empty log with trailing newline when no entries', () => {
        assert.strictEqual(logger.toLogContent(), '\n');
    });

    it('should accumulate timestamped entries', () => {
        logger.info('hello');
        logger.info('world');
        const lines = logger.toLogContent().trim().split('\n');
        assert.strictEqual(lines.length, 2);
    });

    it('should format info entries with INFO level', () => {
        logger.info('test message');
        const content = logger.toLogContent();
        assert.ok(content.includes('[INFO ]'));
        assert.ok(content.includes('test message'));
    });

    it('should format error entries with ERROR level', () => {
        logger.error('something broke');
        const content = logger.toLogContent();
        assert.ok(content.includes('[ERROR]'));
        assert.ok(content.includes('something broke'));
    });

    it('should format cache hit entries', () => {
        logger.cacheHit('pub.info.provider');
        const content = logger.toLogContent();
        assert.ok(content.includes('[CACHE]'));
        assert.ok(content.includes('HIT  pub.info.provider'));
    });

    it('should format cache miss entries', () => {
        logger.cacheMiss('pub.info.provider');
        const content = logger.toLogContent();
        assert.ok(content.includes('MISS pub.info.provider'));
    });

    it('should format API request entries', () => {
        logger.apiRequest('GET', 'https://example.com/api');
        const content = logger.toLogContent();
        assert.ok(content.includes('[API  ]'));
        assert.ok(content.includes('GET https://example.com/api'));
    });

    it('should format API response entries with timing', () => {
        logger.apiResponse(200, 'OK', 150);
        const content = logger.toLogContent();
        assert.ok(content.includes('200 OK (150ms)'));
    });

    it('should format score entries with all components', () => {
        logger.score({
            name: 'provider', total: 78.5, category: 'vibrant',
            rv: 82, eg: 75, pop: 65,
        });
        const content = logger.toLogContent();
        assert.ok(content.includes('[SCORE]'));
        assert.ok(content.includes('provider'));
        assert.ok(content.includes('78.5'));
        assert.ok(content.includes('vibrant'));
        assert.ok(content.includes('rv=82'));
    });

    it('should include ISO timestamp in each entry', () => {
        logger.info('ts check');
        const content = logger.toLogContent();
        // ISO format: yyyy-mm-ddTHH:MM:SS.mmmZ
        assert.ok(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(content));
    });

    it('should track elapsed time', async () => {
        assert.ok(logger.elapsedMs >= 0);
        await new Promise(r => setTimeout(r, 5));
        assert.ok(logger.elapsedMs >= 4);
    });
});
