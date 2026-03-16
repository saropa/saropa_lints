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
const indicator_config_1 = require("../../../vibrancy/services/indicator-config");
describe('indicator-config', () => {
    beforeEach(() => {
        (0, indicator_config_1.clearIndicatorCache)();
    });
    describe('loadIndicatorConfig', () => {
        it('should return default indicators', () => {
            const config = (0, indicator_config_1.loadIndicatorConfig)();
            assert.strictEqual(config.vibrant, '🟢');
            assert.strictEqual(config.quiet, '🟡');
            assert.strictEqual(config.legacyLocked, '🟠');
            assert.strictEqual(config.stale, '🟠');
            assert.strictEqual(config.endOfLife, '🔴');
        });
        it('should include all indicator types', () => {
            const config = (0, indicator_config_1.loadIndicatorConfig)();
            assert.ok('updateAvailable' in config);
            assert.ok('warning' in config);
            assert.ok('unused' in config);
            assert.ok('upToDate' in config);
        });
        it('should cache the config', () => {
            const config1 = (0, indicator_config_1.loadIndicatorConfig)();
            const config2 = (0, indicator_config_1.loadIndicatorConfig)();
            assert.strictEqual(config1, config2);
        });
    });
    describe('loadIndicatorStyle', () => {
        it('should return default style', () => {
            const style = (0, indicator_config_1.loadIndicatorStyle)();
            assert.strictEqual(style, 'emoji');
        });
        it('should cache the style', () => {
            const style1 = (0, indicator_config_1.loadIndicatorStyle)();
            const style2 = (0, indicator_config_1.loadIndicatorStyle)();
            assert.strictEqual(style1, style2);
        });
    });
    describe('clearIndicatorCache', () => {
        it('should clear cached config', () => {
            const config1 = (0, indicator_config_1.loadIndicatorConfig)();
            (0, indicator_config_1.clearIndicatorCache)();
            const config2 = (0, indicator_config_1.loadIndicatorConfig)();
            assert.notStrictEqual(config1, config2);
            assert.deepStrictEqual(config1, config2);
        });
    });
    describe('getCategoryIndicator', () => {
        it('should return emoji for vibrant', () => {
            const indicator = (0, indicator_config_1.getCategoryIndicator)('vibrant');
            assert.strictEqual(indicator, '🟢');
        });
        it('should return emoji for quiet', () => {
            const indicator = (0, indicator_config_1.getCategoryIndicator)('quiet');
            assert.strictEqual(indicator, '🟡');
        });
        it('should return emoji for legacy-locked', () => {
            const indicator = (0, indicator_config_1.getCategoryIndicator)('legacy-locked');
            assert.strictEqual(indicator, '🟠');
        });
        it('should return emoji for stale', () => {
            const indicator = (0, indicator_config_1.getCategoryIndicator)('stale');
            assert.strictEqual(indicator, '🟠');
        });
        it('should return emoji for end-of-life', () => {
            const indicator = (0, indicator_config_1.getCategoryIndicator)('end-of-life');
            assert.strictEqual(indicator, '🔴');
        });
    });
    describe('getIndicator', () => {
        it('should return update available indicator', () => {
            const indicator = (0, indicator_config_1.getIndicator)('updateAvailable');
            assert.strictEqual(indicator, '⬆');
        });
        it('should return warning indicator', () => {
            const indicator = (0, indicator_config_1.getIndicator)('warning');
            assert.strictEqual(indicator, '⚠');
        });
        it('should return unused indicator', () => {
            const indicator = (0, indicator_config_1.getIndicator)('unused');
            assert.strictEqual(indicator, '👻');
        });
        it('should return up to date indicator', () => {
            const indicator = (0, indicator_config_1.getIndicator)('upToDate');
            assert.strictEqual(indicator, '✓');
        });
    });
    describe('formatIndicator', () => {
        it('should return emoji in emoji style', () => {
            const formatted = (0, indicator_config_1.formatIndicator)('warning', 'Warning');
            assert.strictEqual(formatted, '⚠');
        });
    });
});
//# sourceMappingURL=indicator-config.test.js.map