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
const diff_narrator_1 = require("../../../vibrancy/scoring/diff-narrator");
function makeDiff(overrides = {}) {
    return {
        added: [],
        removed: [],
        upgraded: [],
        downgraded: [],
        unchangedCount: 0,
        ...overrides,
    };
}
describe('diff-narrator', () => {
    describe('summarizeDiff', () => {
        it('should summarize upgrades', () => {
            const diff = makeDiff({
                upgraded: [{ name: 'http', from: '1.0.0', to: '1.1.0' }],
            });
            assert.strictEqual((0, diff_narrator_1.summarizeDiff)(diff), 'Lock file: 1 upgraded');
        });
        it('should summarize multiple change types', () => {
            const diff = makeDiff({
                upgraded: [{ name: 'http', from: '1.0.0', to: '1.1.0' }],
                added: [{ name: 'path', version: '1.8.0' }],
            });
            const result = (0, diff_narrator_1.summarizeDiff)(diff);
            assert.ok(result.includes('1 upgraded'));
            assert.ok(result.includes('1 added'));
        });
        it('should return no changes for empty diff', () => {
            assert.strictEqual((0, diff_narrator_1.summarizeDiff)(makeDiff()), 'Lock file: no changes');
        });
        it('should include removals', () => {
            const diff = makeDiff({
                removed: [{ name: 'old', version: '1.0.0' }],
            });
            assert.ok((0, diff_narrator_1.summarizeDiff)(diff).includes('1 removed'));
        });
        it('should include downgrades', () => {
            const diff = makeDiff({
                downgraded: [{ name: 'pkg', from: '2.0.0', to: '1.0.0' }],
            });
            assert.ok((0, diff_narrator_1.summarizeDiff)(diff).includes('1 downgraded'));
        });
    });
    describe('narrateDiff', () => {
        it('should include upgrade arrows', () => {
            const diff = makeDiff({
                upgraded: [{ name: 'http', from: '1.0.0', to: '1.1.0' }],
            });
            const text = (0, diff_narrator_1.narrateDiff)(diff);
            assert.ok(text.includes('⬆ http 1.0.0 → 1.1.0'));
        });
        it('should include added entries', () => {
            const diff = makeDiff({
                added: [{ name: 'path', version: '1.8.0' }],
            });
            const text = (0, diff_narrator_1.narrateDiff)(diff);
            assert.ok(text.includes('➕ path 1.8.0'));
        });
        it('should include removed entries', () => {
            const diff = makeDiff({
                removed: [{ name: 'old', version: '2.0.0' }],
            });
            const text = (0, diff_narrator_1.narrateDiff)(diff);
            assert.ok(text.includes('➖ old 2.0.0'));
        });
        it('should include downgrade arrows', () => {
            const diff = makeDiff({
                downgraded: [{ name: 'pkg', from: '3.0.0', to: '2.0.0' }],
            });
            const text = (0, diff_narrator_1.narrateDiff)(diff);
            assert.ok(text.includes('⬇ pkg 3.0.0 → 2.0.0'));
        });
        it('should start with summary line', () => {
            const diff = makeDiff({
                upgraded: [{ name: 'http', from: '1.0.0', to: '1.1.0' }],
            });
            const lines = (0, diff_narrator_1.narrateDiff)(diff).split('\n');
            assert.ok(lines[0].startsWith('Lock file:'));
        });
        it('should list all entries when multiple exist', () => {
            const diff = makeDiff({
                upgraded: [
                    { name: 'http', from: '1.0.0', to: '1.1.0' },
                    { name: 'path', from: '1.8.0', to: '1.9.0' },
                ],
            });
            const text = (0, diff_narrator_1.narrateDiff)(diff);
            assert.ok(text.includes('⬆ http'));
            assert.ok(text.includes('⬆ path'));
        });
        it('should handle empty diff gracefully', () => {
            const text = (0, diff_narrator_1.narrateDiff)(makeDiff());
            assert.ok(text.includes('no changes'));
        });
    });
});
//# sourceMappingURL=diff-narrator.test.js.map