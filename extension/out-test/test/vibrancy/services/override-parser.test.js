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
const override_parser_1 = require("../../../vibrancy/services/override-parser");
const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');
describe('override-parser', () => {
    let yamlWithOverrides;
    before(() => {
        yamlWithOverrides = fs.readFileSync(path.join(fixturesDir, 'pubspec-with-overrides.yaml'), 'utf8');
    });
    describe('parseOverrides', () => {
        it('should extract version string overrides', () => {
            const overrides = (0, override_parser_1.parseOverrides)(yamlWithOverrides);
            const intl = overrides.find(o => o.name === 'intl');
            assert.ok(intl);
            assert.strictEqual(intl.version, '0.19.0');
            assert.strictEqual(intl.isPathDep, false);
            assert.strictEqual(intl.isGitDep, false);
        });
        it('should extract path dependency overrides', () => {
            const overrides = (0, override_parser_1.parseOverrides)(yamlWithOverrides);
            const pathOverride = overrides.find(o => o.name === 'path');
            assert.ok(pathOverride);
            assert.strictEqual(pathOverride.isPathDep, true);
            assert.strictEqual(pathOverride.isGitDep, false);
        });
        it('should extract git dependency overrides', () => {
            const overrides = (0, override_parser_1.parseOverrides)(yamlWithOverrides);
            const gitOverride = overrides.find(o => o.name === 'some_git_pkg');
            assert.ok(gitOverride);
            assert.strictEqual(gitOverride.isPathDep, false);
            assert.strictEqual(gitOverride.isGitDep, true);
        });
        it('should capture line numbers', () => {
            const overrides = (0, override_parser_1.parseOverrides)(yamlWithOverrides);
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
            const overrides = (0, override_parser_1.parseOverrides)(yaml);
            assert.strictEqual(overrides.length, 0);
        });
        it('should return empty array for empty overrides section', () => {
            const yaml = `
name: test
dependency_overrides:
`;
            const overrides = (0, override_parser_1.parseOverrides)(yaml);
            assert.strictEqual(overrides.length, 0);
        });
        it('should handle quoted version constraints', () => {
            const yaml = `
dependency_overrides:
  test_pkg: "^1.0.0"
`;
            const overrides = (0, override_parser_1.parseOverrides)(yaml);
            assert.strictEqual(overrides.length, 1);
            assert.strictEqual(overrides[0].name, 'test_pkg');
        });
    });
    describe('findOverridesSection', () => {
        it('should find the overrides section range', () => {
            const section = (0, override_parser_1.findOverridesSection)(yamlWithOverrides);
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
            const section = (0, override_parser_1.findOverridesSection)(yaml);
            assert.strictEqual(section, null);
        });
    });
    describe('findOverrideRange', () => {
        it('should find the range for a specific override', () => {
            const range = (0, override_parser_1.findOverrideRange)(yamlWithOverrides, 'intl');
            assert.ok(range);
            assert.ok(range.startLine >= 0);
            assert.ok(range.endLine >= range.startLine);
        });
        it('should find range for path dep override', () => {
            const range = (0, override_parser_1.findOverrideRange)(yamlWithOverrides, 'path');
            assert.ok(range);
            assert.ok(range.endLine > range.startLine);
        });
        it('should return null for non-existent override', () => {
            const range = (0, override_parser_1.findOverrideRange)(yamlWithOverrides, 'nonexistent');
            assert.strictEqual(range, null);
        });
    });
});
//# sourceMappingURL=override-parser.test.js.map