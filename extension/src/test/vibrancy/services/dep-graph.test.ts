/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks).
 */

// Tests for the dep-graph service. Two responsibilities:
//
//   parseDepGraphJson — turn `dart pub deps --json` output into a
//     normalized graph (root + packages with name, version, kind,
//     dependencies). Defensive against three real-world failures:
//       * `dart pub deps` sometimes emits warnings before the JSON
//         payload (the "leading non-JSON text" case).
//       * Older Flutter SDKs return malformed entries.
//       * Empty / invalid input must collapse to a usable empty graph
//         rather than throw.
//
//   buildReverseDeps — flip the graph so callers can ask "who depends
//     on X?" without a full re-walk. Used for the "remove this
//     package" affordance to flag indirect consumers.

import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import { parseDepGraphJson, buildReverseDeps, DepGraphPackage } from '../../../vibrancy/services/dep-graph';

const fixturesDir = path.join(
    __dirname, '..', '..', '..', 'src', 'test', 'fixtures',
);
const FIXTURE_PATH = path.join(fixturesDir, 'pub-deps.json');

describe('dep-graph', () => {
    describe('parseDepGraphJson', () => {
        it('should parse fixture into packages', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const result = parseDepGraphJson(json);
            assert.strictEqual(result.root, 'my_app');
            assert.ok(result.packages.length > 0);
        });

        it('should extract package fields correctly', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const result = parseDepGraphJson(json);
            const http = result.packages.find(p => p.name === 'http');
            assert.ok(http);
            assert.strictEqual(http.version, '1.2.0');
            assert.strictEqual(http.kind, 'direct');
            assert.deepStrictEqual(http.dependencies, ['http_parser', 'meta']);
        });

        it('should handle empty dependencies array', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const result = parseDepGraphJson(json);
            const meta = result.packages.find(p => p.name === 'meta');
            assert.ok(meta);
            assert.deepStrictEqual(meta.dependencies, []);
        });

        it('should return empty for invalid JSON', () => {
            const result = parseDepGraphJson('not json');
            assert.strictEqual(result.root, '');
            assert.deepStrictEqual(result.packages, []);
        });

        it('should return empty for missing packages array', () => {
            const result = parseDepGraphJson('{"root": "app"}');
            assert.strictEqual(result.root, 'app');
            assert.deepStrictEqual(result.packages, []);
        });

        // Real `dart pub deps` output sometimes prepends a "Warning:"
        // line about analysis state. The parser must locate the JSON
        // payload past any such prefix or the user gets an empty graph
        // for what looks like a successful pub run.
        it('should handle leading non-JSON text', () => {
            const json = 'Warning: something\n' + JSON.stringify({
                root: 'app',
                packages: [{ name: 'pkg', version: '1.0.0', kind: 'direct', dependencies: [] }],
            });
            const result = parseDepGraphJson(json);
            assert.strictEqual(result.packages.length, 1);
        });
    });

    describe('buildReverseDeps', () => {
        it('should build reverse lookup from fixture', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = parseDepGraphJson(json);
            const reverse = buildReverseDeps(packages);

            const metaDeps = reverse.get('meta');
            assert.ok(metaDeps);
            const names = metaDeps.map(e => e.dependentPackage).sort();
            assert.ok(names.includes('http'));
            assert.ok(names.includes('firebase_core'));
        });

        it('should show intl is depended on by date_picker_timeline', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = parseDepGraphJson(json);
            const reverse = buildReverseDeps(packages);

            const intlDeps = reverse.get('intl');
            assert.ok(intlDeps);
            const names = intlDeps.map(e => e.dependentPackage);
            assert.ok(names.includes('date_picker_timeline'));
        });

        it('should return empty map for empty input', () => {
            const reverse = buildReverseDeps([]);
            assert.strictEqual(reverse.size, 0);
        });

        it('should not include packages with no dependents', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: [] },
            ];
            const reverse = buildReverseDeps(packages);
            assert.strictEqual(reverse.has('a'), false);
        });

        it('should handle multiple dependents', () => {
            const packages: DepGraphPackage[] = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['c'] },
                { name: 'b', version: '1.0.0', kind: 'direct', dependencies: ['c'] },
                { name: 'c', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const reverse = buildReverseDeps(packages);
            const cDeps = reverse.get('c')!;
            assert.strictEqual(cDeps.length, 2);
        });
    });
});
