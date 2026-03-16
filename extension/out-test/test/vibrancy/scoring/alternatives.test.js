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
const pub_dev_search_1 = require("../../../vibrancy/services/pub-dev-search");
describe('alternatives scoring', () => {
    describe('threshold logic', () => {
        it('should show curated replacement regardless of score', () => {
            const result = (0, pub_dev_search_1.buildAlternatives)('replacement_pkg', []);
            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].name, 'replacement_pkg');
            assert.strictEqual(result[0].source, 'curated');
        });
        it('should not include discovery alternatives when curated exists', () => {
            const discovery = [
                { name: 'alt1', source: 'discovery', score: 90, likes: 500 },
                { name: 'alt2', source: 'discovery', score: 85, likes: 300 },
            ];
            const result = (0, pub_dev_search_1.buildAlternatives)('curated_pkg', discovery);
            assert.strictEqual(result.length, 1);
            assert.ok(result.every(r => r.source === 'curated'));
        });
        it('should include all discovery alternatives when no curated', () => {
            const discovery = [
                { name: 'alt1', source: 'discovery', score: 90, likes: 500 },
                { name: 'alt2', source: 'discovery', score: 85, likes: 300 },
            ];
            const result = (0, pub_dev_search_1.buildAlternatives)(undefined, discovery);
            assert.strictEqual(result.length, 2);
            assert.ok(result.every(r => r.source === 'discovery'));
        });
    });
    describe('curated vs discovery priority', () => {
        it('should mark curated source correctly', () => {
            const result = (0, pub_dev_search_1.buildAlternatives)('http', []);
            assert.strictEqual(result[0].source, 'curated');
        });
        it('should mark discovery source correctly', () => {
            const discovery = [
                { name: 'dio', source: 'discovery', score: 80, likes: 1000 },
            ];
            const result = (0, pub_dev_search_1.buildAlternatives)(undefined, discovery);
            assert.strictEqual(result[0].source, 'discovery');
        });
        it('should preserve likes count from discovery', () => {
            const discovery = [
                { name: 'dio', source: 'discovery', score: 80, likes: 1500 },
            ];
            const result = (0, pub_dev_search_1.buildAlternatives)(undefined, discovery);
            assert.strictEqual(result[0].likes, 1500);
        });
        it('should set likes to 0 for curated', () => {
            const result = (0, pub_dev_search_1.buildAlternatives)('http', []);
            assert.strictEqual(result[0].likes, 0);
        });
    });
    describe('edge cases', () => {
        it('should handle empty discovery array', () => {
            const result = (0, pub_dev_search_1.buildAlternatives)(undefined, []);
            assert.deepStrictEqual(result, []);
        });
        it('should handle undefined curated with empty discovery', () => {
            const result = (0, pub_dev_search_1.buildAlternatives)(undefined, []);
            assert.strictEqual(result.length, 0);
        });
        it('should preserve score from discovery suggestions', () => {
            const discovery = [
                { name: 'package_a', source: 'discovery', score: 75, likes: 200 },
            ];
            const result = (0, pub_dev_search_1.buildAlternatives)(undefined, discovery);
            assert.strictEqual(result[0].score, 75);
        });
        it('should handle null score in discovery', () => {
            const discovery = [
                { name: 'package_a', source: 'discovery', score: null, likes: 200 },
            ];
            const result = (0, pub_dev_search_1.buildAlternatives)(undefined, discovery);
            assert.strictEqual(result[0].score, null);
        });
    });
});
//# sourceMappingURL=alternatives.test.js.map