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
const drift_calculator_1 = require("../../../vibrancy/scoring/drift-calculator");
const RELEASES = [
    { version: '3.27.0', releaseDate: '2025-02-01' },
    { version: '3.24.0', releaseDate: '2024-08-01' },
    { version: '3.22.0', releaseDate: '2024-05-01' },
    { version: '3.19.0', releaseDate: '2024-02-01' },
    { version: '3.16.0', releaseDate: '2023-11-01' },
    { version: '3.13.0', releaseDate: '2023-08-01' },
    { version: '3.10.0', releaseDate: '2023-05-01' },
    { version: '3.7.0', releaseDate: '2023-02-01' },
];
describe('drift-calculator', () => {
    describe('calcDrift', () => {
        it('should return 0 behind for recent publish', () => {
            const result = (0, drift_calculator_1.calcDrift)('2025-03-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 0);
            assert.strictEqual(result?.label, 'current');
            assert.strictEqual(result?.driftScore, 10);
        });
        it('should count releases after publish date', () => {
            const result = (0, drift_calculator_1.calcDrift)('2024-06-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 2);
            assert.strictEqual(result?.label, 'recent');
        });
        it('should return drifting for 3-5 releases behind', () => {
            const result = (0, drift_calculator_1.calcDrift)('2024-01-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 4);
            assert.strictEqual(result?.label, 'drifting');
            assert.strictEqual(result?.driftScore, 4);
        });
        it('should return stale for 6 releases behind', () => {
            const result = (0, drift_calculator_1.calcDrift)('2023-07-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 6);
            assert.strictEqual(result?.label, 'stale');
            assert.strictEqual(result?.driftScore, 2);
        });
        it('should return abandoned for 7+ releases behind', () => {
            const result = (0, drift_calculator_1.calcDrift)('2022-01-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 8);
            assert.strictEqual(result?.label, 'abandoned');
            assert.strictEqual(result?.driftScore, 0);
        });
        it('should return null for null publish date', () => {
            assert.strictEqual((0, drift_calculator_1.calcDrift)(null, RELEASES), null);
        });
        it('should return null for empty releases', () => {
            assert.strictEqual((0, drift_calculator_1.calcDrift)('2025-01-01', []), null);
        });
        it('should return null for invalid date', () => {
            assert.strictEqual((0, drift_calculator_1.calcDrift)('not-a-date', RELEASES), null);
        });
        it('should include latest flutter version', () => {
            const result = (0, drift_calculator_1.calcDrift)('2025-03-01', RELEASES);
            assert.strictEqual(result?.latestFlutterVersion, '3.27.0');
        });
        it('should handle publish on same day as release', () => {
            const result = (0, drift_calculator_1.calcDrift)('2025-02-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 0);
        });
    });
    describe('driftLabel', () => {
        it('should return current for 0', () => {
            assert.strictEqual((0, drift_calculator_1.driftLabel)(0), 'current');
        });
        it('should return recent for 1-2', () => {
            assert.strictEqual((0, drift_calculator_1.driftLabel)(1), 'recent');
            assert.strictEqual((0, drift_calculator_1.driftLabel)(2), 'recent');
        });
        it('should return drifting for 3-5', () => {
            assert.strictEqual((0, drift_calculator_1.driftLabel)(3), 'drifting');
            assert.strictEqual((0, drift_calculator_1.driftLabel)(5), 'drifting');
        });
        it('should return stale for 6', () => {
            assert.strictEqual((0, drift_calculator_1.driftLabel)(6), 'stale');
        });
        it('should return abandoned for 7+', () => {
            assert.strictEqual((0, drift_calculator_1.driftLabel)(7), 'abandoned');
            assert.strictEqual((0, drift_calculator_1.driftLabel)(10), 'abandoned');
        });
    });
});
//# sourceMappingURL=drift-calculator.test.js.map