import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import {
    parsePubspecYaml,
    parsePubspecLock,
    findPackageRange,
    parseDependencyOverrides,
} from '../../../vibrancy/services/pubspec-parser';

const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');

describe('pubspec-parser', () => {
    let yamlContent: string;
    let lockContent: string;

    before(() => {
        yamlContent = fs.readFileSync(path.join(fixturesDir, 'pubspec.yaml'), 'utf8');
        lockContent = fs.readFileSync(path.join(fixturesDir, 'pubspec.lock'), 'utf8');
    });

    describe('parsePubspecYaml', () => {
        it('should extract direct dependencies', () => {
            const { directDeps } = parsePubspecYaml(yamlContent);
            assert.ok(directDeps.includes('http'));
            assert.ok(directDeps.includes('provider'));
            assert.ok(directDeps.includes('shared_preferences'));
        });

        it('should extract dev dependencies', () => {
            const { devDeps } = parsePubspecYaml(yamlContent);
            assert.ok(devDeps.includes('mockito'));
            assert.ok(devDeps.includes('build_runner'));
        });

        it('should not include sdk dependencies', () => {
            const { directDeps, devDeps } = parsePubspecYaml(yamlContent);
            const all = [...directDeps, ...devDeps];
            assert.ok(!all.includes('sdk'));
        });

        it('should extract version constraints', () => {
            const { constraints } = parsePubspecYaml(yamlContent);
            assert.strictEqual(constraints['http'], '^1.6.0');
            assert.strictEqual(constraints['provider'], '^6.1.5+1');
            assert.strictEqual(constraints['mockito'], '^5.4.0');
        });

        it('should not include constraints for sdk deps', () => {
            const { constraints } = parsePubspecYaml(yamlContent);
            assert.strictEqual(constraints['flutter'], undefined);
        });

        it('should handle empty content', () => {
            const { directDeps, devDeps, constraints } = parsePubspecYaml('');
            assert.strictEqual(directDeps.length, 0);
            assert.strictEqual(devDeps.length, 0);
            assert.deepStrictEqual(constraints, {});
        });
    });

    describe('parsePubspecLock', () => {
        it('should extract packages with versions', () => {
            const { directDeps } = parsePubspecYaml(yamlContent);
            const packages = parsePubspecLock(lockContent, directDeps);
            const http = packages.find(p => p.name === 'http');
            assert.ok(http);
            assert.strictEqual(http.version, '1.2.0');
            assert.strictEqual(http.source, 'hosted');
            assert.strictEqual(http.isDirect, true);
        });

        it('should mark transitive deps as not direct', () => {
            const { directDeps } = parsePubspecYaml(yamlContent);
            const packages = parsePubspecLock(lockContent, directDeps);
            const meta = packages.find(p => p.name === 'meta');
            assert.ok(meta);
            assert.strictEqual(meta.isDirect, false);
        });

        it('should parse all packages in lock file', () => {
            const packages = parsePubspecLock(lockContent, []);
            assert.strictEqual(packages.length, 5);
        });

        it('should populate constraint from yaml constraints', () => {
            const { directDeps, constraints } = parsePubspecYaml(yamlContent);
            const packages = parsePubspecLock(lockContent, directDeps, constraints);
            const http = packages.find(p => p.name === 'http');
            assert.ok(http);
            assert.strictEqual(http.constraint, '^1.6.0');
            assert.strictEqual(http.version, '1.2.0');
        });

        it('should fall back to resolved version when no constraint', () => {
            const packages = parsePubspecLock(lockContent, []);
            const meta = packages.find(p => p.name === 'meta');
            assert.ok(meta);
            assert.strictEqual(meta.constraint, '1.11.0');
        });

        it('should handle empty lock content', () => {
            const packages = parsePubspecLock('', []);
            assert.strictEqual(packages.length, 0);
        });
    });

    describe('findPackageRange', () => {
        it('should find a package name position', () => {
            const range = findPackageRange(yamlContent, 'http');
            assert.ok(range);
            assert.strictEqual(range.startChar, 2);
            assert.strictEqual(range.endChar, 6);
        });

        it('should return null for packages not in the file', () => {
            const range = findPackageRange(yamlContent, 'nonexistent_pkg');
            assert.strictEqual(range, null);
        });

        it('should find correct line number', () => {
            const range = findPackageRange(yamlContent, 'provider');
            assert.ok(range);
            const lines = yamlContent.split('\n');
            assert.ok(lines[range.line].includes('provider'));
        });
    });

    describe('parseDependencyOverrides', () => {
        it('should extract overridden package names', () => {
            const content = `
name: my_app
dependencies:
  http: ^1.0.0

dependency_overrides:
  intl: ^0.18.0
  path: ^1.8.0
`;
            const overrides = parseDependencyOverrides(content);
            assert.deepStrictEqual(overrides, ['intl', 'path']);
        });

        it('should return empty array when no overrides section', () => {
            const content = `
name: my_app
dependencies:
  http: ^1.0.0
`;
            const overrides = parseDependencyOverrides(content);
            assert.deepStrictEqual(overrides, []);
        });

        it('should stop at next top-level section', () => {
            const content = `
dependency_overrides:
  intl: ^0.18.0

dev_dependencies:
  test: ^1.0.0
`;
            const overrides = parseDependencyOverrides(content);
            assert.deepStrictEqual(overrides, ['intl']);
        });

        it('should handle empty overrides section', () => {
            const content = `
dependency_overrides:

dependencies:
  http: ^1.0.0
`;
            const overrides = parseDependencyOverrides(content);
            assert.deepStrictEqual(overrides, []);
        });
    });
});
