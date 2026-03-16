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
    });
});
