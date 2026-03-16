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
const pubspec_editor_1 = require("../../../vibrancy/services/pubspec-editor");
/** Create a minimal fake TextDocument from raw text. */
function makeFakeDoc(text) {
    const lines = text.split('\n');
    return {
        lineCount: lines.length,
        lineAt: (i) => ({ text: lines[i] ?? '' }),
    };
}
describe('pubspec-editor', () => {
    describe('buildVersionEdit', () => {
        it('should find and replace a caret constraint', () => {
            const doc = makeFakeDoc('dependencies:\n  http: ^1.2.0');
            const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, 'http', '^2.0.0');
            assert.ok(edit);
            assert.strictEqual(edit.newText, '^2.0.0');
        });
        it('should return null for unknown package', () => {
            const doc = makeFakeDoc('dependencies:\n  http: ^1.2.0');
            const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, 'missing', '^1.0.0');
            assert.strictEqual(edit, null);
        });
        it('should handle exact version constraints', () => {
            const doc = makeFakeDoc('  provider: 6.0.0');
            const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, 'provider', '^6.1.0');
            assert.ok(edit);
            assert.strictEqual(edit.newText, '^6.1.0');
        });
        it('should handle quoted version values', () => {
            const doc = makeFakeDoc('  intl: "^0.18.0"');
            const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, 'intl', '^0.19.0');
            assert.ok(edit);
            assert.strictEqual(edit.newText, '^0.19.0');
        });
    });
    describe('readVersionConstraint', () => {
        it('should read a caret constraint', () => {
            const doc = makeFakeDoc('  http: ^1.2.0');
            assert.strictEqual((0, pubspec_editor_1.readVersionConstraint)(doc, 'http'), '^1.2.0');
        });
        it('should trim whitespace from value', () => {
            const doc = makeFakeDoc('  http:   ^1.2.0  ');
            assert.strictEqual((0, pubspec_editor_1.readVersionConstraint)(doc, 'http'), '^1.2.0');
        });
        it('should return null for missing package', () => {
            const doc = makeFakeDoc('  http: ^1.2.0');
            assert.strictEqual((0, pubspec_editor_1.readVersionConstraint)(doc, 'missing'), null);
        });
        it('should read exact version', () => {
            const doc = makeFakeDoc('  meta: 1.11.0');
            assert.strictEqual((0, pubspec_editor_1.readVersionConstraint)(doc, 'meta'), '1.11.0');
        });
    });
    describe('findPackageLines', () => {
        it('should find a simple one-line entry', () => {
            const doc = makeFakeDoc('dependencies:\n  http: ^1.2.0\n  meta: ^1.11.0');
            const range = (0, pubspec_editor_1.findPackageLines)(doc, 'http');
            assert.deepStrictEqual(range, { start: 1, end: 2 });
        });
        it('should include continuation lines (deeper indent)', () => {
            const doc = makeFakeDoc([
                'dependencies:',
                '  http:',
                '    hosted: https://custom.pub',
                '    version: ^1.2.0',
                '  meta: ^1.11.0',
            ].join('\n'));
            const range = (0, pubspec_editor_1.findPackageLines)(doc, 'http');
            assert.deepStrictEqual(range, { start: 1, end: 4 });
        });
        it('should return null for missing package', () => {
            const doc = makeFakeDoc('  http: ^1.2.0');
            assert.strictEqual((0, pubspec_editor_1.findPackageLines)(doc, 'missing'), null);
        });
    });
    describe('buildBackupUri', () => {
        it('should produce a timestamped backup filename', () => {
            const fakeUri = { fsPath: '/project/pubspec.yaml' };
            const result = (0, pubspec_editor_1.buildBackupUri)(fakeUri);
            assert.ok(result);
            const path = result.path ?? result.fsPath ?? '';
            assert.ok(path.includes('pubspec.yaml.bak.'), `Expected backup pattern in: ${path}`);
        });
    });
});
//# sourceMappingURL=pubspec-editor.test.js.map