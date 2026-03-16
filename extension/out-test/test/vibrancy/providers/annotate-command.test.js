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
const annotate_packages_1 = require("../../../vibrancy/providers/annotate-packages");
const annotate_headers_1 = require("../../../vibrancy/providers/annotate-headers");
/** Create a minimal fake TextDocument from raw text. */
function makeFakeDoc(text) {
    const lines = text.split('\n');
    return {
        lineCount: lines.length,
        lineAt: (i) => ({ text: lines[i] ?? '' }),
    };
}
describe('annotate-command', () => {
    describe('formatAnnotation', () => {
        it('should format description and URL', () => {
            const result = (0, annotate_packages_1.formatAnnotation)('http', 'An HTTP client library.');
            assert.strictEqual(result, '  # An HTTP client library.\n  # https://pub.dev/packages/http\n');
        });
        it('should return URL only when description is null', () => {
            const result = (0, annotate_packages_1.formatAnnotation)('http', null);
            assert.strictEqual(result, '  # https://pub.dev/packages/http\n');
        });
        it('should truncate long descriptions at 80 chars', () => {
            const longDesc = 'A'.repeat(100);
            const result = (0, annotate_packages_1.formatAnnotation)('pkg', longDesc);
            const lines = result.split('\n');
            const descLine = lines[0];
            // "  # " = 4 chars prefix + 77 content chars + "..." = 84 total
            assert.ok(descLine.length <= 84);
            assert.ok(descLine.endsWith('...'));
        });
        it('should not truncate descriptions at exactly 80 chars', () => {
            const exactDesc = 'B'.repeat(80);
            const result = (0, annotate_packages_1.formatAnnotation)('pkg', exactDesc);
            assert.ok(!result.includes('...'));
        });
    });
    describe('buildAnnotationEdits', () => {
        it('should insert annotations above each package', () => {
            const doc = makeFakeDoc('dependencies:\n  http: ^1.6.0\n  provider: ^6.1.1');
            const descriptions = new Map([
                ['http', 'HTTP client'],
                ['provider', 'State management'],
            ]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http', 'provider'], descriptions);
            assert.strictEqual(edits.length, 2);
            assert.ok(edits[0].text.includes('HTTP client'));
            assert.ok(edits[0].text.includes('pub.dev/packages/http'));
            assert.ok(edits[1].text.includes('State management'));
        });
        it('should skip packages not found in document', () => {
            const doc = makeFakeDoc('dependencies:\n  http: ^1.6.0');
            const descriptions = new Map([['missing', 'Gone']]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['missing'], descriptions);
            assert.strictEqual(edits.length, 0);
        });
        it('should handle missing descriptions gracefully', () => {
            const doc = makeFakeDoc('dependencies:\n  http: ^1.6.0');
            const descriptions = new Map();
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http'], descriptions);
            assert.strictEqual(edits.length, 1);
            assert.ok(edits[0].text.includes('pub.dev/packages/http'));
            assert.ok(!edits[0].text.includes('# \n'));
        });
        it('should replace existing annotations', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  # Old description\n'
                + '  # https://pub.dev/packages/http\n'
                + '  http: ^1.6.0');
            const descriptions = new Map([['http', 'New description']]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http'], descriptions);
            assert.strictEqual(edits.length, 1);
            assert.strictEqual(edits[0].deleteRanges.length, 1);
            assert.ok(edits[0].text.includes('New description'));
        });
        it('should replace URL-only existing annotations', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  # https://pub.dev/packages/http\n'
                + '  http: ^1.6.0');
            const descriptions = new Map([['http', 'Added description']]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http'], descriptions);
            assert.strictEqual(edits.length, 1);
            assert.strictEqual(edits[0].deleteRanges.length, 1);
            assert.ok(edits[0].text.includes('Added description'));
        });
        it('should handle package on first line of document', () => {
            const doc = makeFakeDoc('  http: ^1.6.0');
            const descriptions = new Map([['http', 'HTTP client']]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http'], descriptions);
            assert.strictEqual(edits.length, 1);
            assert.strictEqual(edits[0].deleteRanges.length, 0);
        });
        it('should handle empty string description as missing', () => {
            const result = (0, annotate_packages_1.formatAnnotation)('http', '');
            assert.strictEqual(result, '  # https://pub.dev/packages/http\n');
        });
        it('should not treat user comments as annotations', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  # TODO: migrate this\n'
                + '  http: ^1.6.0');
            const descriptions = new Map([['http', 'HTTP client']]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http'], descriptions);
            assert.strictEqual(edits.length, 1);
            assert.strictEqual(edits[0].deleteRanges.length, 0);
        });
        it('should detect URL with /changelog suffix', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  # Old description\n'
                + '  # https://pub.dev/packages/http/changelog\n'
                + '  http: ^1.6.0');
            const descriptions = new Map([['http', 'New description']]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http'], descriptions);
            assert.strictEqual(edits.length, 1);
            assert.strictEqual(edits[0].deleteRanges.length, 1);
            assert.ok(edits[0].text.includes('New description'));
        });
        it('should remove multiple annotation blocks', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  # First description\n'
                + '  # https://pub.dev/packages/http/changelog\n'
                + '  # NOTE: user comment\n'
                + '  # Second description\n'
                + '  # https://pub.dev/packages/http\n'
                + '  http: ^1.6.0');
            const descriptions = new Map([['http', 'Final description']]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http'], descriptions);
            assert.strictEqual(edits.length, 1);
            assert.strictEqual(edits[0].deleteRanges.length, 2);
            assert.ok(edits[0].text.includes('Final description'));
        });
        it('should preserve user comments between annotations', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  # https://pub.dev/packages/http/changelog\n'
                + '  # Because version conflict...\n'
                + '  # https://pub.dev/packages/http\n'
                + '  http: ^1.6.0');
            const descriptions = new Map([['http', 'HTTP client']]);
            const edits = (0, annotate_packages_1.buildAnnotationEdits)(doc, ['http'], descriptions);
            assert.strictEqual(edits.length, 1);
            assert.strictEqual(edits[0].deleteRanges.length, 2);
        });
    });
    describe('formatSectionHeader', () => {
        it('should create header with centered title', () => {
            const result = (0, annotate_headers_1.formatSectionHeader)('DEPENDENCIES');
            assert.ok(result.includes('DEPENDENCIES'));
            assert.ok(result.includes('##########'));
        });
        it('should include blank lines above', () => {
            const result = (0, annotate_headers_1.formatSectionHeader)('TEST');
            const lines = result.split('\n');
            assert.strictEqual(lines[0], '');
        });
        it('should include 9 single hash lines', () => {
            const result = (0, annotate_headers_1.formatSectionHeader)('TEST');
            const hashLines = result.split('\n').filter(l => l.trim() === '#');
            assert.strictEqual(hashLines.length, 9);
        });
        it('should have proper indentation', () => {
            const result = (0, annotate_headers_1.formatSectionHeader)('TEST');
            const lines = result.split('\n').filter(l => l.trim().length > 0);
            for (const line of lines) {
                assert.ok(line.startsWith('  '), `Line should be indented: "${line}"`);
            }
        });
    });
    describe('buildSectionHeaderEdits', () => {
        it('should create edit for dependencies section', () => {
            const doc = makeFakeDoc('name: test\n'
                + 'dependencies:\n'
                + '  http: ^1.6.0');
            const edits = (0, annotate_headers_1.buildSectionHeaderEdits)(doc);
            assert.strictEqual(edits.length, 1);
            assert.ok(edits[0].text.includes('DEPENDENCIES'));
        });
        it('should create edits for multiple sections', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  http: ^1.6.0\n'
                + 'dev_dependencies:\n'
                + '  test: ^1.0.0\n'
                + 'dependency_overrides:\n'
                + '  http: ^2.0.0');
            const edits = (0, annotate_headers_1.buildSectionHeaderEdits)(doc);
            assert.strictEqual(edits.length, 3);
        });
        it('should detect and replace existing section header', () => {
            const doc = makeFakeDoc('##################################\n'
                + '########  OLD HEADER  ############\n'
                + '##################################\n'
                + 'dependencies:\n'
                + '  http: ^1.6.0');
            const edits = (0, annotate_headers_1.buildSectionHeaderEdits)(doc);
            assert.strictEqual(edits.length, 1);
            assert.ok(edits[0].deleteRange);
        });
        it('should not create edit for missing sections', () => {
            const doc = makeFakeDoc('name: test\nversion: 1.0.0');
            const edits = (0, annotate_headers_1.buildSectionHeaderEdits)(doc);
            assert.strictEqual(edits.length, 0);
        });
    });
    describe('buildSubSectionHeaderEdits', () => {
        it('should create edit for assets within flutter', () => {
            const doc = makeFakeDoc('flutter:\n'
                + '  uses-material-design: true\n'
                + '  assets:\n'
                + '    - images/');
            const edits = (0, annotate_headers_1.buildSubSectionHeaderEdits)(doc);
            assert.strictEqual(edits.length, 1);
            assert.ok(edits[0].text.includes('ASSETS'));
        });
        it('should create edit for fonts within flutter', () => {
            const doc = makeFakeDoc('flutter:\n'
                + '  fonts:\n'
                + '    - family: Roboto');
            const edits = (0, annotate_headers_1.buildSubSectionHeaderEdits)(doc);
            assert.strictEqual(edits.length, 1);
            assert.ok(edits[0].text.includes('FONTS'));
        });
        it('should create edits for both assets and fonts', () => {
            const doc = makeFakeDoc('flutter:\n'
                + '  assets:\n'
                + '    - images/\n'
                + '  fonts:\n'
                + '    - family: Roboto');
            const edits = (0, annotate_headers_1.buildSubSectionHeaderEdits)(doc);
            assert.strictEqual(edits.length, 2);
        });
        it('should not create edit for assets outside flutter', () => {
            const doc = makeFakeDoc('other:\n'
                + '  assets:\n'
                + '    - images/');
            const edits = (0, annotate_headers_1.buildSubSectionHeaderEdits)(doc);
            assert.strictEqual(edits.length, 0);
        });
    });
    describe('buildOverrideMarkerEdit', () => {
        it('should create marker above first overridden dependency', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  http: ^1.0.0\n'
                + '  provider: ^6.0.0\n'
                + '  bloc: ^8.0.0');
            const edit = (0, annotate_headers_1.buildOverrideMarkerEdit)(doc, ['http', 'provider', 'bloc'], ['provider']);
            assert.ok(edit);
            assert.ok(edit.text.includes('DEP OVERRIDDEN BELOW'));
            assert.strictEqual(edit.insertPos.line, 2);
        });
        it('should return null when no overrides exist', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  http: ^1.0.0');
            const edit = (0, annotate_headers_1.buildOverrideMarkerEdit)(doc, ['http'], []);
            assert.strictEqual(edit, null);
        });
        it('should return null when no deps match overrides', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  http: ^1.0.0');
            const edit = (0, annotate_headers_1.buildOverrideMarkerEdit)(doc, ['http'], ['some_other_pkg']);
            assert.strictEqual(edit, null);
        });
        it('should detect and replace existing marker', () => {
            const doc = makeFakeDoc('dependencies:\n'
                + '  http: ^1.0.0\n'
                + '##################################\n'
                + '###  DEP OVERRIDDEN BELOW  #######\n'
                + '##################################\n'
                + '  provider: ^6.0.0');
            const edit = (0, annotate_headers_1.buildOverrideMarkerEdit)(doc, ['http', 'provider'], ['provider']);
            assert.ok(edit);
            assert.ok(edit.deleteRange);
        });
    });
});
//# sourceMappingURL=annotate-command.test.js.map