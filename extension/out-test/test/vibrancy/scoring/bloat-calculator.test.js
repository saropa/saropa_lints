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
const bloat_calculator_1 = require("../../../vibrancy/scoring/bloat-calculator");
describe('bloat-calculator', () => {
    describe('calcBloatRating', () => {
        it('should return 0 for zero bytes', () => {
            assert.strictEqual((0, bloat_calculator_1.calcBloatRating)(0), 0);
        });
        it('should return 0 for negative bytes', () => {
            assert.strictEqual((0, bloat_calculator_1.calcBloatRating)(-100), 0);
        });
        it('should return 0 for tiny packages under 50 KB', () => {
            assert.strictEqual((0, bloat_calculator_1.calcBloatRating)(10_000), 0);
        });
        it('should return low rating for small packages around 100 KB', () => {
            const rating = (0, bloat_calculator_1.calcBloatRating)(100_000);
            assert.ok(rating >= 1 && rating <= 2, `expected 1-2, got ${rating}`);
        });
        it('should return medium rating for ~1 MB packages', () => {
            const rating = (0, bloat_calculator_1.calcBloatRating)(1_048_576);
            assert.ok(rating >= 4 && rating <= 5, `expected 4-5, got ${rating}`);
        });
        it('should return high rating for ~10 MB packages', () => {
            const rating = (0, bloat_calculator_1.calcBloatRating)(10_485_760);
            assert.ok(rating >= 7 && rating <= 8, `expected 7-8, got ${rating}`);
        });
        it('should return 10 for very large packages over 50 MB', () => {
            assert.strictEqual((0, bloat_calculator_1.calcBloatRating)(52_428_800), 10);
        });
        it('should clamp at 10 for extremely large packages', () => {
            assert.strictEqual((0, bloat_calculator_1.calcBloatRating)(500_000_000), 10);
        });
        it('should return 0 for a 1-byte archive', () => {
            assert.strictEqual((0, bloat_calculator_1.calcBloatRating)(1), 0);
        });
    });
    describe('formatSizeMB', () => {
        it('should show <0.01 MB for very small sizes', () => {
            assert.strictEqual((0, bloat_calculator_1.formatSizeMB)(5_000), '<0.01 MB');
        });
        it('should show one decimal place at exactly 1 MB', () => {
            assert.strictEqual((0, bloat_calculator_1.formatSizeMB)(1_048_576), '1.0 MB');
        });
        it('should show two decimal places for sub-MB sizes', () => {
            assert.strictEqual((0, bloat_calculator_1.formatSizeMB)(317_440), '0.30 MB');
        });
        it('should show one decimal place for MB+ sizes', () => {
            assert.strictEqual((0, bloat_calculator_1.formatSizeMB)(2_621_440), '2.5 MB');
        });
        it('should show one decimal place for large sizes', () => {
            assert.strictEqual((0, bloat_calculator_1.formatSizeMB)(52_428_800), '50.0 MB');
        });
    });
});
//# sourceMappingURL=bloat-calculator.test.js.map