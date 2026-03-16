import * as assert from 'assert';
import { hasDependencyChanges, getDependencyChangeSummary } from '../../../vibrancy/services/dependency-differ';

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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), true);
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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), true);
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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), true);
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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), false);
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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), true);
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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), true);
        });

        it('should handle empty content gracefully', () => {
            assert.strictEqual(hasDependencyChanges('', ''), false);
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
            const result = hasDependencyChanges(malformed, good);
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
            assert.strictEqual(hasDependencyChanges(content, content), false);
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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), true);
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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), true);
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
            assert.strictEqual(hasDependencyChanges(oldContent, newContent), false);
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
            const summary = getDependencyChangeSummary(oldContent, newContent);
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
            const summary = getDependencyChangeSummary(oldContent, newContent);
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
            const summary = getDependencyChangeSummary(oldContent, newContent);
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
            const summary = getDependencyChangeSummary(oldContent, newContent);
            assert.deepStrictEqual(summary.added, ['dio']);
            assert.deepStrictEqual(summary.removed, ['provider']);
            assert.deepStrictEqual(summary.changed, ['http']);
        });

        it('should return empty arrays when no changes', () => {
            const content = `
dependencies:
  http: ^1.0.0
`;
            const summary = getDependencyChangeSummary(content, content);
            assert.deepStrictEqual(summary.added, []);
            assert.deepStrictEqual(summary.removed, []);
            assert.deepStrictEqual(summary.changed, []);
        });

        it('should handle empty content', () => {
            const summary = getDependencyChangeSummary('', '');
            assert.deepStrictEqual(summary.added, []);
            assert.deepStrictEqual(summary.removed, []);
            assert.deepStrictEqual(summary.changed, []);
        });
    });
});
