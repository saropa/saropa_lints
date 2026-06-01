import * as assert from 'assert';
import {
    parsePubspecYaml,
    parseDependencyOverrides,
} from '../../../vibrancy/services/pubspec-parser';

/**
 * Regression suite for the section-exit guard in pubspec-parser.
 *
 * Bug: the original parser used `/^\S/.test(trimmed)` to detect a new
 * top-level YAML key and exit the active dependency section. Because `#`
 * is not whitespace, a zero-indent comment like `# cspell:ignore bardram`
 * was treated as a section terminator. Observed on saropa/contacts
 * pubspec, where two such comments inside `dependencies:` silently
 * dropped ~14 direct deps (device_info_plus, image, share_plus, …) from
 * the Package Dashboard.
 *
 * These tests are self-contained (no fixture files) so they exercise the
 * fix without depending on the broader pubspec-parser.test.ts setup.
 */
describe('pubspec-parser comment resilience', () => {
    describe('parsePubspecYaml', () => {
        it('keeps collecting deps after a zero-indent comment', () => {
            const content = [
                'dependencies:',
                '  before_comment: ^1.0.0',
                '# cspell:ignore bardram',
                '  after_comment: ^2.0.0',
                '',
                '# cspell:ignore javac',
                '  after_blank_and_comment: ^3.0.0',
                'dev_dependencies:',
                '  dev_pkg: ^4.0.0',
            ].join('\n');
            const { directDeps, devDeps } = parsePubspecYaml(content);
            assert.deepStrictEqual(
                directDeps,
                ['before_comment', 'after_comment', 'after_blank_and_comment'],
            );
            assert.deepStrictEqual(devDeps, ['dev_pkg']);
        });

        it('still treats a real top-level key as a section terminator', () => {
            const content = [
                'dependencies:',
                '  in_section: ^1.0.0',
                'flutter:',
                '  uses-material-design: true',
                '  in_flutter_block: ^9.9.9',
            ].join('\n');
            const { directDeps } = parsePubspecYaml(content);
            assert.deepStrictEqual(directDeps, ['in_section']);
        });
    });

    describe('parseDependencyOverrides', () => {
        it('keeps collecting overrides after a zero-indent comment', () => {
            const content = [
                'dependency_overrides:',
                '  before_comment: ^1.0.0',
                '# cspell:ignore bardram',
                '  after_comment: ^2.0.0',
                'dev_dependencies:',
                '  test_pkg: ^3.0.0',
            ].join('\n');
            const overrides = parseDependencyOverrides(content);
            assert.deepStrictEqual(overrides, ['before_comment', 'after_comment']);
        });

        it('still exits on a real top-level key', () => {
            const content = [
                'dependency_overrides:',
                '  in_overrides: ^1.0.0',
                'flutter:',
                '  uses-material-design: true',
            ].join('\n');
            const overrides = parseDependencyOverrides(content);
            assert.deepStrictEqual(overrides, ['in_overrides']);
        });
    });
});
