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
const treeCommands = __importStar(require("../../../vibrancy/providers/tree-commands"));
/** Create a minimal fake TextDocument from lines of text. */
function makeFakeDoc(line) {
    const lines = line.split('\n');
    return {
        lineCount: lines.length,
        lineAt: (i) => ({ text: lines[i] ?? '' }),
    };
}
describe('upgrade-command helpers', () => {
    describe('buildVersionEdit', () => {
        it('should build edit with the exact constraint passed', () => {
            const doc = makeFakeDoc('  http: ^1.0.0');
            const edit = treeCommands.buildVersionEdit(doc, 'http', '^2.0.0');
            assert.strictEqual(edit?.newText, '^2.0.0');
        });
        it('should return null for unknown package', () => {
            const doc = makeFakeDoc('  http: ^1.0.0');
            const edit = treeCommands.buildVersionEdit(doc, 'missing', '^1.0.0');
            assert.strictEqual(edit, null);
        });
        it('should preserve non-caret constraints', () => {
            const doc = makeFakeDoc('  http: >=1.0.0 <2.0.0');
            const edit = treeCommands.buildVersionEdit(doc, 'http', '>=2.0.0 <3.0.0');
            assert.strictEqual(edit?.newText, '>=2.0.0 <3.0.0');
        });
    });
    describe('readVersionConstraint', () => {
        it('should read existing constraint', () => {
            const doc = makeFakeDoc('  http: ^1.0.0');
            const constraint = treeCommands.readVersionConstraint(doc, 'http');
            assert.strictEqual(constraint, '^1.0.0');
        });
        it('should return null for missing package', () => {
            const doc = makeFakeDoc('  http: ^1.0.0');
            const constraint = treeCommands.readVersionConstraint(doc, 'missing');
            assert.strictEqual(constraint, null);
        });
        it('should trim whitespace from constraint', () => {
            const doc = makeFakeDoc('  http:   ^1.0.0  ');
            const constraint = treeCommands.readVersionConstraint(doc, 'http');
            assert.strictEqual(constraint, '^1.0.0');
        });
        it('should handle range constraints', () => {
            const doc = makeFakeDoc('  http: >=1.0.0 <2.0.0');
            const constraint = treeCommands.readVersionConstraint(doc, 'http');
            assert.strictEqual(constraint, '>=1.0.0 <2.0.0');
        });
    });
});
//# sourceMappingURL=upgrade-command.test.js.map