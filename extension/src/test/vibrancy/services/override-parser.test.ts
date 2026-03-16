import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import {
    parseOverrides,
    findOverridesSection,
    findOverrideRange,
} from '../../../vibrancy/services/override-parser';

const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');

describe('override-parser', () => {
    let yamlWithOverrides: string;

    before(() => {
        yamlWithOverrides = fs.readFileSync(
            path.join(fixturesDir, 'pubspec-with-overrides.yaml'),
            'utf8',
        );
    });

    describe('parseOverrides', () => {
        it('should extract version string overrides', () => {
            const overrides = parseOverrides(yamlWithOverrides);
            const intl = overrides.find(o => o.name === 'intl');
            assert.ok(intl);
            assert.strictEqual(intl.version, '0.19.0');
            assert.strictEqual(intl.isPathDep, false);
            assert.strictEqual(intl.isGitDep, false);
        });

        it('should extract path dependency overrides', () => {
            const overrides = parseOverrides(yamlWithOverrides);
            const pathOverride = overrides.find(o => o.name === 'path');
            assert.ok(pathOverride);
            assert.strictEqual(pathOverride.isPathDep, true);
            assert.strictEqual(pathOverride.isGitDep, false);
        });

        it('should extract git dependency overrides', () => {
            const overrides = parseOverrides(yamlWithOverrides);
            const gitOverride = overrides.find(o => o.name === 'some_git_pkg');
            assert.ok(gitOverride);
            assert.strictEqual(gitOverride.isPathDep, false);
            assert.strictEqual(gitOverride.isGitDep, true);
        });

        it('should capture line numbers', () => {
            const overrides = parseOverrides(yamlWithOverrides);
            const intl = overrides.find(o => o.name === 'intl');
            assert.ok(intl);
            assert.ok(intl.line >= 0);
        });

        it('should return empty array for no overrides section', () => {
            const yaml = `
name: test
dependencies:
  http: ^1.0.0
`;
            const overrides = parseOverrides(yaml);
            assert.strictEqual(overrides.length, 0);
        });

        it('should return empty array for empty overrides section', () => {
            const yaml = `
name: test
dependency_overrides:
`;
            const overrides = parseOverrides(yaml);
            assert.strictEqual(overrides.length, 0);
        });

        it('should handle quoted version constraints', () => {
            const yaml = `
dependency_overrides:
  test_pkg: "^1.0.0"
`;
            const overrides = parseOverrides(yaml);
            assert.strictEqual(overrides.length, 1);
            assert.strictEqual(overrides[0].name, 'test_pkg');
        });
    });

    describe('findOverridesSection', () => {
        it('should find the overrides section range', () => {
            const section = findOverridesSection(yamlWithOverrides);
            assert.ok(section);
            assert.ok(section.startLine >= 0);
            assert.ok(section.endLine > section.startLine);
        });

        it('should return null when no overrides section exists', () => {
            const yaml = `
name: test
dependencies:
  http: ^1.0.0
`;
            const section = findOverridesSection(yaml);
            assert.strictEqual(section, null);
        });
    });

    describe('findOverrideRange', () => {
        it('should find the range for a specific override', () => {
            const range = findOverrideRange(yamlWithOverrides, 'intl');
            assert.ok(range);
            assert.ok(range.startLine >= 0);
            assert.ok(range.endLine >= range.startLine);
        });

        it('should find range for path dep override', () => {
            const range = findOverrideRange(yamlWithOverrides, 'path');
            assert.ok(range);
            assert.ok(range.endLine > range.startLine);
        });

        it('should return null for non-existent override', () => {
            const range = findOverrideRange(yamlWithOverrides, 'nonexistent');
            assert.strictEqual(range, null);
        });
    });
});
