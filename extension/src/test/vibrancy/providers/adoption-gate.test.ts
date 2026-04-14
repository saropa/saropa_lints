import '../register-vscode-mock';
import * as assert from 'assert';
import { findCandidates } from '../../../vibrancy/providers/adoption-gate';

// Note: getLatestResults() returns [] in test context (no scan has run),
// so all parsed dependency names are treated as candidates.

const PUBSPEC_WITH_DEPS = `
name: my_app
dependencies:
  http: ^1.2.0
  bloc: ^8.1.0
  path: ^1.9.0

dev_dependencies:
  test: ^1.25.0
`;

const PUBSPEC_EMPTY_DEPS = `
name: my_app
dependencies:
`;

const PUBSPEC_NO_DEPS = `
name: my_app
version: 1.0.0
`;

describe('adoption-gate', () => {
    describe('findCandidates', () => {
        it('should find all deps as candidates when no scan results exist', () => {
            const candidates = findCandidates(PUBSPEC_WITH_DEPS);
            assert.ok(candidates.includes('http'));
            assert.ok(candidates.includes('bloc'));
            assert.ok(candidates.includes('path'));
            assert.ok(candidates.includes('test'));
            assert.strictEqual(candidates.length, 4);
        });

        it('should return empty for empty dependency section', () => {
            const candidates = findCandidates(PUBSPEC_EMPTY_DEPS);
            assert.strictEqual(candidates.length, 0);
        });

        it('should return empty when no dependency section exists', () => {
            const candidates = findCandidates(PUBSPEC_NO_DEPS);
            assert.strictEqual(candidates.length, 0);
        });

        it('should handle both direct and dev dependencies', () => {
            const candidates = findCandidates(PUBSPEC_WITH_DEPS);
            // http, bloc, path are direct; test is dev
            assert.ok(candidates.includes('http'));
            assert.ok(candidates.includes('test'));
        });

        it('should not include non-dependency lines', () => {
            const yaml = `
name: my_app
version: 1.0.0
dependencies:
  http: ^1.0.0
environment:
  sdk: ">=3.0.0 <4.0.0"
`;
            const candidates = findCandidates(yaml);
            assert.deepStrictEqual(candidates, ['http']);
        });

        it('should exclude SDK packages (flutter, flutter_test, etc.)', () => {
            // SDK packages use `sdk: flutter` in pubspec.yaml and are not
            // hosted on pub.dev. Looking them up produces false "Discontinued"
            // warnings because the pub.dev `flutter` package is discontinued.
            const yaml = `
name: my_app
environment:
  sdk: ">=3.10.7 <4.0.0"
  flutter: ">=3.41.2"
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  http: ^1.2.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  test: ^1.25.0
`;
            const candidates = findCandidates(yaml);
            // Only hosted packages should appear; SDK deps should be filtered
            assert.ok(candidates.includes('http'), 'hosted dep http should be a candidate');
            assert.ok(candidates.includes('test'), 'hosted dep test should be a candidate');
            assert.ok(!candidates.includes('flutter'), 'SDK dep flutter should be excluded');
            assert.ok(!candidates.includes('flutter_localizations'), 'SDK dep flutter_localizations should be excluded');
            assert.ok(!candidates.includes('flutter_test'), 'SDK dep flutter_test should be excluded');
            assert.ok(!candidates.includes('integration_test'), 'SDK dep integration_test should be excluded');
            assert.strictEqual(candidates.length, 2);
        });

        it('should exclude flutter_web_plugins and flutter_driver', () => {
            const yaml = `
name: my_app
dependencies:
  flutter:
    sdk: flutter
  flutter_web_plugins:
    sdk: flutter
  http: ^1.0.0
dev_dependencies:
  flutter_driver:
    sdk: flutter
`;
            const candidates = findCandidates(yaml);
            assert.deepStrictEqual(candidates, ['http']);
        });
    });
});
