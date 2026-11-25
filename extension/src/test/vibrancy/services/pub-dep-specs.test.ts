/**
 * Tests for the guard's dependency-spec parser and the pub get tool choice.
 */

import * as assert from 'assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { parseDepSpecs, usesFlutterSdk } from '../../../vibrancy/services/pub-dep-specs';
import { planPubGet } from '../../../vibrancy/services/flutter-cli';

describe('pub-dep-specs', () => {
    it('parses scalar, sdk, path, git, hosted and inline forms across all sections', () => {
        const yaml = [
            'name: app', 'dependencies:', '  http: ^1.0.0 # comment', '  flutter:', '    sdk: flutter',
            '  loc:', '    path: ../loc', '  g:', '    git:', '      url: https://x', '  h:', '    hosted: https://p',
            '    version: ">=1.0.0 <2.0.0"', '  inl: {path: ../x}', 'dev_dependencies:', '  lints: ^4.0.0',
            'dependency_overrides:', '  http: 1.2.0', 'flutter:', '  uses-material-design: true', '',
        ].join('\n');
        const by = (n: string, sec?: string) => parseDepSpecs(yaml).find((s) => s.name === n && (!sec || s.section === sec));
        assert.deepStrictEqual([by('http', 'dependencies')?.kind, by('http', 'dependencies')?.constraint], ['hosted', '^1.0.0']);
        assert.strictEqual(by('flutter', 'dependencies')?.sdk, 'flutter');
        assert.deepStrictEqual([by('loc')?.kind, by('loc')?.path], ['path', '../loc']);
        assert.strictEqual(by('g')?.kind, 'git');
        assert.deepStrictEqual([by('h')?.kind, by('h')?.constraint], ['hosted', '>=1.0.0 <2.0.0']);
        assert.strictEqual(by('inl')?.kind, 'other');
        assert.strictEqual(by('lints')?.section, 'dev_dependencies');
        assert.strictEqual(by('http', 'dependency_overrides')?.constraint, '1.2.0');
        // A top-level `flutter:` section must not leak entries into dependencies.
        assert.strictEqual(parseDepSpecs(yaml).some((s) => s.name === 'uses-material-design'), false);
    });

    it('detects the Flutter SDK dependency', () => {
        assert.strictEqual(usesFlutterSdk(parseDepSpecs('dependencies:\n  flutter:\n    sdk: flutter\n')), true);
        assert.strictEqual(usesFlutterSdk(parseDepSpecs('dependencies:\n  http: ^1.0.0\n')), false);
    });

    describe('planPubGet (tool by project type)', () => {
        const withPubspec = (body: string, fn: (dir: string) => void): void => {
            const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vib-plan-'));
            try {
                fs.writeFileSync(path.join(dir, 'pubspec.yaml'), body);
                fn(dir);
            } finally {
                fs.rmSync(dir, { recursive: true, force: true });
            }
        };

        it('uses dart for a pure-Dart project', () => {
            withPubspec('name: x\ndependencies:\n  http: ^1.0.0\n', (d) => assert.strictEqual(planPubGet(d).tool, 'dart'));
        });

        it('uses flutter for a Flutter project', () => {
            withPubspec('name: x\ndependencies:\n  flutter:\n    sdk: flutter\n', (d) => assert.strictEqual(planPubGet(d).tool, 'flutter'));
        });

        it('defaults to flutter when the pubspec is unreadable', () => {
            assert.strictEqual(planPubGet(path.join(os.tmpdir(), 'vib-nonexistent-98765')).tool, 'flutter');
        });
    });
});
