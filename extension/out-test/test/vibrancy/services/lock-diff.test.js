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
const lock_diff_1 = require("../../../vibrancy/services/lock-diff");
describe('lock-diff', () => {
    describe('diffVersionMaps', () => {
        it('should detect added packages', () => {
            const old = new Map();
            const next = new Map([['http', '1.0.0']]);
            const diff = (0, lock_diff_1.diffVersionMaps)(old, next);
            assert.strictEqual(diff.added.length, 1);
            assert.strictEqual(diff.added[0].name, 'http');
        });
        it('should detect removed packages', () => {
            const old = new Map([['http', '1.0.0']]);
            const next = new Map();
            const diff = (0, lock_diff_1.diffVersionMaps)(old, next);
            assert.strictEqual(diff.removed.length, 1);
            assert.strictEqual(diff.removed[0].name, 'http');
        });
        it('should detect upgraded packages', () => {
            const old = new Map([['http', '1.0.0']]);
            const next = new Map([['http', '1.1.0']]);
            const diff = (0, lock_diff_1.diffVersionMaps)(old, next);
            assert.strictEqual(diff.upgraded.length, 1);
            assert.strictEqual(diff.upgraded[0].from, '1.0.0');
            assert.strictEqual(diff.upgraded[0].to, '1.1.0');
        });
        it('should detect downgraded packages', () => {
            const old = new Map([['http', '2.0.0']]);
            const next = new Map([['http', '1.9.0']]);
            const diff = (0, lock_diff_1.diffVersionMaps)(old, next);
            assert.strictEqual(diff.downgraded.length, 1);
            assert.strictEqual(diff.downgraded[0].from, '2.0.0');
        });
        it('should count unchanged packages', () => {
            const old = new Map([['http', '1.0.0']]);
            const next = new Map([['http', '1.0.0']]);
            const diff = (0, lock_diff_1.diffVersionMaps)(old, next);
            assert.strictEqual(diff.unchangedCount, 1);
            assert.strictEqual(diff.upgraded.length, 0);
        });
        it('should handle empty maps', () => {
            const diff = (0, lock_diff_1.diffVersionMaps)(new Map(), new Map());
            assert.strictEqual(diff.added.length, 0);
            assert.strictEqual(diff.removed.length, 0);
            assert.strictEqual(diff.unchangedCount, 0);
        });
        it('should classify pre-release version upgrade correctly', () => {
            const old = new Map([['pkg', '1.0.0']]);
            const next = new Map([['pkg', '2.0.0-dev.1']]);
            const diff = (0, lock_diff_1.diffVersionMaps)(old, next);
            assert.strictEqual(diff.upgraded.length, 1);
            assert.strictEqual(diff.downgraded.length, 0);
        });
        it('should handle mixed changes', () => {
            const old = new Map([
                ['http', '1.0.0'],
                ['path', '1.8.0'],
                ['old_pkg', '2.0.0'],
            ]);
            const next = new Map([
                ['http', '1.1.0'],
                ['path', '1.8.0'],
                ['new_pkg', '3.0.0'],
            ]);
            const diff = (0, lock_diff_1.diffVersionMaps)(old, next);
            assert.strictEqual(diff.upgraded.length, 1);
            assert.strictEqual(diff.added.length, 1);
            assert.strictEqual(diff.removed.length, 1);
            assert.strictEqual(diff.unchangedCount, 1);
        });
    });
});
//# sourceMappingURL=lock-diff.test.js.map