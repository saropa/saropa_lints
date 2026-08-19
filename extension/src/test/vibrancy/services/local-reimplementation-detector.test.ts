/**
 * Tests **local-reimplementation-detector**: extracting top-level and
 * extension-member declarations from Dart source, and matching a project's
 * own declared symbols against a dependency's exported symbol names.
 */
import * as assert from 'assert';
import {
    extractDeclaredSymbols, detectLocalReimplementations,
} from '../../../vibrancy/services/local-reimplementation-detector';
import { DartSource } from '../../../vibrancy/services/import-scanner';

function source(path: string, text: string): DartSource {
    return { path, text };
}

describe('local-reimplementation-detector', () => {
    describe('extractDeclaredSymbols', () => {
        it('extracts a top-level function declaration', () => {
            const src = source('lib/utils/retry_utils.dart', [
                'Future<T> retryWithBackoff<T>(Future<T> Function() action) async {',
                '  return action();',
                '}',
            ].join('\n'));
            const symbols = extractDeclaredSymbols(src);
            assert.deepStrictEqual(
                symbols.map(s => [s.name, s.kind]),
                [['retryWithBackoff', 'function']],
            );
            assert.strictEqual(symbols[0].line, 1);
        });

        it('extracts a top-level class declaration', () => {
            const src = source('lib/models/foo.dart', 'class Foo {\n  int x = 1;\n}\n');
            const symbols = extractDeclaredSymbols(src);
            assert.deepStrictEqual(symbols.map(s => [s.name, s.kind]), [['Foo', 'class']]);
        });

        it('extracts a top-level mixin declaration', () => {
            const src = source('lib/mixins/loggable.dart', 'mixin Loggable {\n  void log() {}\n}\n');
            const symbols = extractDeclaredSymbols(src);
            assert.deepStrictEqual(symbols.map(s => [s.name, s.kind]), [['Loggable', 'mixin']]);
        });

        it('extracts a named extension and its members separately', () => {
            const src = source('lib/extensions/list_nullable_extensions.dart', [
                'extension ListNullableExtensions on List? {',
                '  bool get isListNullOrEmpty => this == null || this!.isEmpty;',
                '  void doSomething() {}',
                '}',
            ].join('\n'));
            const symbols = extractDeclaredSymbols(src);
            const names = symbols.map(s => [s.name, s.kind]);
            assert.deepStrictEqual(names, [
                ['ListNullableExtensions', 'extension'],
                ['isListNullOrEmpty', 'extensionMember'],
                ['doSomething', 'extensionMember'],
            ]);
        });

        it('does not descend into a method body inside an extension as more members', () => {
            const src = source('lib/extensions/x.dart', [
                'extension X on int {',
                '  int compute() {',
                '    if (this > 0) { return this; }',
                '    return 0;',
                '  }',
                '}',
            ].join('\n'));
            const symbols = extractDeclaredSymbols(src);
            assert.deepStrictEqual(symbols.map(s => s.name), ['X', 'compute']);
        });

        it('does not mistake control-flow lines for top-level functions', () => {
            const src = source('lib/util.dart', [
                'void run() {',
                '  if (true) {',
                '    for (var i = 0; i < 1; i++) {}',
                '  }',
                '}',
            ].join('\n'));
            const symbols = extractDeclaredSymbols(src);
            assert.deepStrictEqual(symbols.map(s => s.name), ['run']);
        });

        it('handles an anonymous extension by tracking members with no extension name', () => {
            const src = source('lib/anon.dart', [
                'extension on String {',
                '  bool get isBlank => trim().isEmpty;',
                '}',
            ].join('\n'));
            const symbols = extractDeclaredSymbols(src);
            assert.deepStrictEqual(symbols.map(s => [s.name, s.kind]), [
                ['isBlank', 'extensionMember'],
            ]);
        });

        it('returns an empty array for a file with no top-level declarations', () => {
            const src = source('lib/constants.dart', "const kFoo = 'bar';\n");
            assert.deepStrictEqual(extractDeclaredSymbols(src), []);
        });
    });

    describe('detectLocalReimplementations', () => {
        it('matches project declarations whose name appears in the package symbol set', () => {
            const declared = extractDeclaredSymbols(source('lib/utils/retry_utils.dart', [
                'Future<T> retryWithBackoff<T>(Future<T> Function() action) async {',
                '  return action();',
                '}',
            ].join('\n')));
            const matches = detectLocalReimplementations(
                declared, new Set(['retryWithBackoff', 'exponentialBackoff']),
            );
            assert.strictEqual(matches.length, 1);
            assert.strictEqual(matches[0].name, 'retryWithBackoff');
            assert.strictEqual(matches[0].filePath, 'lib/utils/retry_utils.dart');
        });

        it('returns nothing when no project declaration matches', () => {
            const declared = extractDeclaredSymbols(source('lib/a.dart', 'class Unrelated {}\n'));
            const matches = detectLocalReimplementations(declared, new Set(['SomethingElse']));
            assert.strictEqual(matches.length, 0);
        });

        it('returns nothing for an empty package symbol set', () => {
            const declared = extractDeclaredSymbols(source('lib/a.dart', 'class Foo {}\n'));
            const matches = detectLocalReimplementations(declared, new Set());
            assert.strictEqual(matches.length, 0);
        });
    });
});
