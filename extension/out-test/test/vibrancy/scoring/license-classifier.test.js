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
const license_classifier_1 = require("../../../vibrancy/scoring/license-classifier");
describe('license-classifier', () => {
    describe('classifyLicense', () => {
        it('should classify MIT as permissive', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('MIT'), 'permissive');
        });
        it('should classify BSD-3-Clause as permissive', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('BSD-3-Clause'), 'permissive');
        });
        it('should classify Apache-2.0 as permissive', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('Apache-2.0'), 'permissive');
        });
        it('should classify GPL-3.0 as copyleft', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('GPL-3.0'), 'copyleft');
        });
        it('should classify LGPL-2.1 as copyleft', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('LGPL-2.1'), 'copyleft');
        });
        it('should classify MPL-2.0 as copyleft', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('MPL-2.0'), 'copyleft');
        });
        it('should return unknown for null', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)(null), 'unknown');
        });
        it('should return unknown for empty string', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)(''), 'unknown');
        });
        it('should return unknown for whitespace', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('   '), 'unknown');
        });
        it('should return unknown for unrecognized license', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('WTFPL'), 'unknown');
        });
        it('should use least restrictive for OR expression', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('MIT OR GPL-3.0'), 'permissive');
        });
        it('should use most restrictive for AND expression', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('MIT AND GPL-3.0'), 'copyleft');
        });
        it('should handle compound with unknown component', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('MIT OR CustomLicense'), 'permissive');
        });
        it('should handle case-insensitive OR/AND', () => {
            assert.strictEqual((0, license_classifier_1.classifyLicense)('MIT or Apache-2.0'), 'permissive');
        });
    });
    describe('licenseEmoji', () => {
        const cases = [
            ['permissive', '🟢'],
            ['copyleft', '🟡'],
            ['unknown', '🔴'],
        ];
        for (const [tier, emoji] of cases) {
            it(`should return ${emoji} for ${tier}`, () => {
                assert.strictEqual((0, license_classifier_1.licenseEmoji)(tier), emoji);
            });
        }
    });
});
//# sourceMappingURL=license-classifier.test.js.map