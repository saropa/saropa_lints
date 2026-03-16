import * as assert from 'assert';
import {
    loadIndicatorConfig, loadIndicatorStyle, clearIndicatorCache,
    getCategoryIndicator, getIndicator, formatIndicator,
} from '../../../vibrancy/services/indicator-config';

describe('indicator-config', () => {
    beforeEach(() => {
        clearIndicatorCache();
    });

    describe('loadIndicatorConfig', () => {
        it('should return default indicators', () => {
            const config = loadIndicatorConfig();
            assert.strictEqual(config.vibrant, '🟢');
            assert.strictEqual(config.quiet, '🟡');
            assert.strictEqual(config.legacyLocked, '🟠');
            assert.strictEqual(config.stale, '🟠');
            assert.strictEqual(config.endOfLife, '🔴');
        });

        it('should include all indicator types', () => {
            const config = loadIndicatorConfig();
            assert.ok('updateAvailable' in config);
            assert.ok('warning' in config);
            assert.ok('unused' in config);
            assert.ok('upToDate' in config);
        });

        it('should cache the config', () => {
            const config1 = loadIndicatorConfig();
            const config2 = loadIndicatorConfig();
            assert.strictEqual(config1, config2);
        });
    });

    describe('loadIndicatorStyle', () => {
        it('should return default style', () => {
            const style = loadIndicatorStyle();
            assert.strictEqual(style, 'emoji');
        });

        it('should cache the style', () => {
            const style1 = loadIndicatorStyle();
            const style2 = loadIndicatorStyle();
            assert.strictEqual(style1, style2);
        });
    });

    describe('clearIndicatorCache', () => {
        it('should clear cached config', () => {
            const config1 = loadIndicatorConfig();
            clearIndicatorCache();
            const config2 = loadIndicatorConfig();
            assert.notStrictEqual(config1, config2);
            assert.deepStrictEqual(config1, config2);
        });
    });

    describe('getCategoryIndicator', () => {
        it('should return emoji for vibrant', () => {
            const indicator = getCategoryIndicator('vibrant');
            assert.strictEqual(indicator, '🟢');
        });

        it('should return emoji for quiet', () => {
            const indicator = getCategoryIndicator('quiet');
            assert.strictEqual(indicator, '🟡');
        });

        it('should return emoji for legacy-locked', () => {
            const indicator = getCategoryIndicator('legacy-locked');
            assert.strictEqual(indicator, '🟠');
        });

        it('should return emoji for stale', () => {
            const indicator = getCategoryIndicator('stale');
            assert.strictEqual(indicator, '🟠');
        });

        it('should return emoji for end-of-life', () => {
            const indicator = getCategoryIndicator('end-of-life');
            assert.strictEqual(indicator, '🔴');
        });
    });

    describe('getIndicator', () => {
        it('should return update available indicator', () => {
            const indicator = getIndicator('updateAvailable');
            assert.strictEqual(indicator, '⬆');
        });

        it('should return warning indicator', () => {
            const indicator = getIndicator('warning');
            assert.strictEqual(indicator, '⚠');
        });

        it('should return unused indicator', () => {
            const indicator = getIndicator('unused');
            assert.strictEqual(indicator, '👻');
        });

        it('should return up to date indicator', () => {
            const indicator = getIndicator('upToDate');
            assert.strictEqual(indicator, '✓');
        });
    });

    describe('formatIndicator', () => {
        it('should return emoji in emoji style', () => {
            const formatted = formatIndicator('warning', 'Warning');
            assert.strictEqual(formatted, '⚠');
        });
    });
});
