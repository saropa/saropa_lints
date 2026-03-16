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
const adoption_classifier_1 = require("../../../vibrancy/scoring/adoption-classifier");
function makeInput(overrides = {}) {
    return {
        pubPoints: 0,
        verifiedPublisher: false,
        isDiscontinued: false,
        knownIssueStatus: null,
        knownIssueReason: null,
        exists: true,
        ...overrides,
    };
}
describe('adoption-classifier', () => {
    describe('classifyAdoption', () => {
        it('should return healthy for high points and verified publisher', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 120, verifiedPublisher: true,
            }));
            assert.strictEqual(result.tier, 'healthy');
            assert.ok(result.badgeText.includes('120'));
            assert.ok(result.badgeText.includes('verified'));
        });
        it('should return caution for medium points and unverified', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 45, verifiedPublisher: false,
            }));
            assert.strictEqual(result.tier, 'caution');
            assert.ok(result.badgeText.includes('45'));
            assert.ok(result.badgeText.includes('unverified'));
        });
        it('should return caution for high points but unverified', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 120, verifiedPublisher: false,
            }));
            assert.strictEqual(result.tier, 'caution');
            assert.ok(result.badgeText.includes('120'));
        });
        it('should return warning for discontinued package', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 100, verifiedPublisher: true,
                isDiscontinued: true,
            }));
            assert.strictEqual(result.tier, 'warning');
            assert.ok(result.badgeText.includes('Discontinued'));
        });
        it('should return warning for known end-of-life issue', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                knownIssueStatus: 'end-of-life',
                knownIssueReason: 'replaced by new_pkg',
            }));
            assert.strictEqual(result.tier, 'warning');
            assert.ok(result.badgeText.includes('replaced by new_pkg'));
        });
        it('should return unknown when not found on pub.dev', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({ exists: false }));
            assert.strictEqual(result.tier, 'unknown');
            assert.ok(result.badgeText.includes('Not found'));
        });
        it('should return caution for zero points but existing', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 0, exists: true,
            }));
            assert.strictEqual(result.tier, 'caution');
        });
        it('should include point count in healthy badge', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 140, verifiedPublisher: true,
            }));
            assert.ok(result.badgeText.includes('140'));
        });
        it('should include point count in caution badge', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 55,
            }));
            assert.ok(result.badgeText.includes('55'));
        });
        it('should prioritize discontinued over high score', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 150, verifiedPublisher: true,
                isDiscontinued: true,
            }));
            assert.strictEqual(result.tier, 'warning');
        });
        it('should prioritize not-found over known issue', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                exists: false,
                knownIssueStatus: 'end-of-life',
            }));
            assert.strictEqual(result.tier, 'unknown');
        });
        it('should show default reason for end-of-life without reason', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                knownIssueStatus: 'end-of-life',
                knownIssueReason: null,
            }));
            assert.strictEqual(result.tier, 'warning');
            assert.ok(result.badgeText.includes('end of life'));
        });
        it('should return caution for verified publisher with low points', () => {
            const result = (0, adoption_classifier_1.classifyAdoption)(makeInput({
                pubPoints: 30, verifiedPublisher: true,
            }));
            assert.strictEqual(result.tier, 'caution');
            assert.ok(result.badgeText.includes('verified'));
        });
    });
});
//# sourceMappingURL=adoption-classifier.test.js.map