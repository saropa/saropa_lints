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
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const pubspec_parser_1 = require("../../../vibrancy/services/pubspec-parser");
const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');
describe('pubspec-parser', () => {
    let yamlContent;
    let lockContent;
    before(() => {
        yamlContent = fs.readFileSync(path.join(fixturesDir, 'pubspec.yaml'), 'utf8');
        lockContent = fs.readFileSync(path.join(fixturesDir, 'pubspec.lock'), 'utf8');
    });
    describe('parsePubspecYaml', () => {
        it('should extract direct dependencies', () => {
            const { directDeps } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
            assert.ok(directDeps.includes('http'));
            assert.ok(directDeps.includes('provider'));
            assert.ok(directDeps.includes('shared_preferences'));
        });
        it('should extract dev dependencies', () => {
            const { devDeps } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
            assert.ok(devDeps.includes('mockito'));
            assert.ok(devDeps.includes('build_runner'));
        });
        it('should not include sdk dependencies', () => {
            const { directDeps, devDeps } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
            const all = [...directDeps, ...devDeps];
            assert.ok(!all.includes('sdk'));
        });
        it('should extract version constraints', () => {
            const { constraints } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
            assert.strictEqual(constraints['http'], '^1.6.0');
            assert.strictEqual(constraints['provider'], '^6.1.5+1');
            assert.strictEqual(constraints['mockito'], '^5.4.0');
        });
        it('should not include constraints for sdk deps', () => {
            const { constraints } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
            assert.strictEqual(constraints['flutter'], undefined);
        });
        it('should handle empty content', () => {
            const { directDeps, devDeps, constraints } = (0, pubspec_parser_1.parsePubspecYaml)('');
            assert.strictEqual(directDeps.length, 0);
            assert.strictEqual(devDeps.length, 0);
            assert.deepStrictEqual(constraints, {});
        });
    });
    describe('parsePubspecLock', () => {
        it('should extract packages with versions', () => {
            const { directDeps } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
            const packages = (0, pubspec_parser_1.parsePubspecLock)(lockContent, directDeps);
            const http = packages.find(p => p.name === 'http');
            assert.ok(http);
            assert.strictEqual(http.version, '1.2.0');
            assert.strictEqual(http.source, 'hosted');
            assert.strictEqual(http.isDirect, true);
        });
        it('should mark transitive deps as not direct', () => {
            const { directDeps } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
            const packages = (0, pubspec_parser_1.parsePubspecLock)(lockContent, directDeps);
            const meta = packages.find(p => p.name === 'meta');
            assert.ok(meta);
            assert.strictEqual(meta.isDirect, false);
        });
        it('should parse all packages in lock file', () => {
            const packages = (0, pubspec_parser_1.parsePubspecLock)(lockContent, []);
            assert.strictEqual(packages.length, 5);
        });
        it('should populate constraint from yaml constraints', () => {
            const { directDeps, constraints } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
            const packages = (0, pubspec_parser_1.parsePubspecLock)(lockContent, directDeps, constraints);
            const http = packages.find(p => p.name === 'http');
            assert.ok(http);
            assert.strictEqual(http.constraint, '^1.6.0');
            assert.strictEqual(http.version, '1.2.0');
        });
        it('should fall back to resolved version when no constraint', () => {
            const packages = (0, pubspec_parser_1.parsePubspecLock)(lockContent, []);
            const meta = packages.find(p => p.name === 'meta');
            assert.ok(meta);
            assert.strictEqual(meta.constraint, '1.11.0');
        });
        it('should handle empty lock content', () => {
            const packages = (0, pubspec_parser_1.parsePubspecLock)('', []);
            assert.strictEqual(packages.length, 0);
        });
    });
    describe('findPackageRange', () => {
        it('should find a package name position', () => {
            const range = (0, pubspec_parser_1.findPackageRange)(yamlContent, 'http');
            assert.ok(range);
            assert.strictEqual(range.startChar, 2);
            assert.strictEqual(range.endChar, 6);
        });
        it('should return null for packages not in the file', () => {
            const range = (0, pubspec_parser_1.findPackageRange)(yamlContent, 'nonexistent_pkg');
            assert.strictEqual(range, null);
        });
        it('should find correct line number', () => {
            const range = (0, pubspec_parser_1.findPackageRange)(yamlContent, 'provider');
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
            const overrides = (0, pubspec_parser_1.parseDependencyOverrides)(content);
            assert.deepStrictEqual(overrides, ['intl', 'path']);
        });
        it('should return empty array when no overrides section', () => {
            const content = `
name: my_app
dependencies:
  http: ^1.0.0
`;
            const overrides = (0, pubspec_parser_1.parseDependencyOverrides)(content);
            assert.deepStrictEqual(overrides, []);
        });
        it('should stop at next top-level section', () => {
            const content = `
dependency_overrides:
  intl: ^0.18.0

dev_dependencies:
  test: ^1.0.0
`;
            const overrides = (0, pubspec_parser_1.parseDependencyOverrides)(content);
            assert.deepStrictEqual(overrides, ['intl']);
        });
        it('should handle empty overrides section', () => {
            const content = `
dependency_overrides:

dependencies:
  http: ^1.0.0
`;
            const overrides = (0, pubspec_parser_1.parseDependencyOverrides)(content);
            assert.deepStrictEqual(overrides, []);
        });
    });
});
//# sourceMappingURL=pubspec-parser.test.js.map