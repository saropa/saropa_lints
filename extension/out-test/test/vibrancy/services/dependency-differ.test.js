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
const dependency_differ_1 = require("../../../vibrancy/services/dependency-differ");
describe('dependency-differ', () => {
    describe('hasDependencyChanges', () => {
        it('should detect added dependency', () => {
            const oldContent = `
name: my_app
dependencies:
  http: ^1.0.0
`;
            const newContent = `
name: my_app
dependencies:
  http: ^1.0.0
  provider: ^6.0.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), true);
        });
        it('should detect removed dependency', () => {
            const oldContent = `
name: my_app
dependencies:
  http: ^1.0.0
  provider: ^6.0.0
`;
            const newContent = `
name: my_app
dependencies:
  http: ^1.0.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), true);
        });
        it('should detect version change', () => {
            const oldContent = `
name: my_app
dependencies:
  http: ^1.0.0
`;
            const newContent = `
name: my_app
dependencies:
  http: ^2.0.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), true);
        });
        it('should ignore non-dependency changes', () => {
            const oldContent = `
name: my_app
description: Old description
dependencies:
  http: ^1.0.0
`;
            const newContent = `
name: my_app
description: New description
dependencies:
  http: ^1.0.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), false);
        });
        it('should detect dev_dependencies changes', () => {
            const oldContent = `
name: my_app
dev_dependencies:
  test: ^1.0.0
`;
            const newContent = `
name: my_app
dev_dependencies:
  test: ^1.0.0
  mockito: ^5.0.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), true);
        });
        it('should detect dependency_overrides changes', () => {
            const oldContent = `
name: my_app
dependency_overrides:
  path: ^1.8.0
`;
            const newContent = `
name: my_app
dependency_overrides:
  path: ^1.9.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), true);
        });
        it('should handle empty content gracefully', () => {
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)('', ''), false);
        });
        it('should handle malformed YAML gracefully', () => {
            const malformed = `
name: my_app
dependencies:
  http: ^1.0.0
    bad_indent: this is wrong
`;
            const good = `
name: my_app
dependencies:
  http: ^1.0.0
`;
            const result = (0, dependency_differ_1.hasDependencyChanges)(malformed, good);
            assert.strictEqual(typeof result, 'boolean');
        });
        it('should return false when dependencies are identical', () => {
            const content = `
name: my_app
dependencies:
  http: ^1.0.0
  provider: ^6.0.0
dev_dependencies:
  test: ^1.0.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(content, content), false);
        });
        it('should handle multi-line dependency specs', () => {
            const oldContent = `
name: my_app
dependencies:
  my_pkg:
    path: ../my_pkg
`;
            const newContent = `
name: my_app
dependencies:
  my_pkg:
    path: ../other_pkg
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), true);
        });
        it('should detect adding override section', () => {
            const oldContent = `
name: my_app
dependencies:
  http: ^1.0.0
`;
            const newContent = `
name: my_app
dependencies:
  http: ^1.0.0
dependency_overrides:
  path: ^1.8.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), true);
        });
        it('should not detect order changes', () => {
            const oldContent = `
name: my_app
dependencies:
  http: ^1.0.0
  provider: ^6.0.0
`;
            const newContent = `
name: my_app
dependencies:
  provider: ^6.0.0
  http: ^1.0.0
`;
            assert.strictEqual((0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent), false);
        });
    });
    describe('getDependencyChangeSummary', () => {
        it('should list added packages', () => {
            const oldContent = `
dependencies:
  http: ^1.0.0
`;
            const newContent = `
dependencies:
  http: ^1.0.0
  provider: ^6.0.0
`;
            const summary = (0, dependency_differ_1.getDependencyChangeSummary)(oldContent, newContent);
            assert.deepStrictEqual(summary.added, ['provider']);
            assert.deepStrictEqual(summary.removed, []);
            assert.deepStrictEqual(summary.changed, []);
        });
        it('should list removed packages', () => {
            const oldContent = `
dependencies:
  http: ^1.0.0
  provider: ^6.0.0
`;
            const newContent = `
dependencies:
  http: ^1.0.0
`;
            const summary = (0, dependency_differ_1.getDependencyChangeSummary)(oldContent, newContent);
            assert.deepStrictEqual(summary.added, []);
            assert.deepStrictEqual(summary.removed, ['provider']);
            assert.deepStrictEqual(summary.changed, []);
        });
        it('should list changed packages', () => {
            const oldContent = `
dependencies:
  http: ^1.0.0
`;
            const newContent = `
dependencies:
  http: ^2.0.0
`;
            const summary = (0, dependency_differ_1.getDependencyChangeSummary)(oldContent, newContent);
            assert.deepStrictEqual(summary.added, []);
            assert.deepStrictEqual(summary.removed, []);
            assert.deepStrictEqual(summary.changed, ['http']);
        });
        it('should handle multiple changes at once', () => {
            const oldContent = `
dependencies:
  http: ^1.0.0
  provider: ^6.0.0
`;
            const newContent = `
dependencies:
  http: ^2.0.0
  dio: ^5.0.0
`;
            const summary = (0, dependency_differ_1.getDependencyChangeSummary)(oldContent, newContent);
            assert.deepStrictEqual(summary.added, ['dio']);
            assert.deepStrictEqual(summary.removed, ['provider']);
            assert.deepStrictEqual(summary.changed, ['http']);
        });
        it('should return empty arrays when no changes', () => {
            const content = `
dependencies:
  http: ^1.0.0
`;
            const summary = (0, dependency_differ_1.getDependencyChangeSummary)(content, content);
            assert.deepStrictEqual(summary.added, []);
            assert.deepStrictEqual(summary.removed, []);
            assert.deepStrictEqual(summary.changed, []);
        });
        it('should handle empty content', () => {
            const summary = (0, dependency_differ_1.getDependencyChangeSummary)('', '');
            assert.deepStrictEqual(summary.added, []);
            assert.deepStrictEqual(summary.removed, []);
            assert.deepStrictEqual(summary.changed, []);
        });
    });
});
//# sourceMappingURL=dependency-differ.test.js.map