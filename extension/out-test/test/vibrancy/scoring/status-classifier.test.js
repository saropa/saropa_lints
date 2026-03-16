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
const status_classifier_1 = require("../../../vibrancy/scoring/status-classifier");
describe('status-classifier', () => {
    describe('classifyStatus', () => {
        it('should classify high scores as vibrant', () => {
            const cat = (0, status_classifier_1.classifyStatus)({ score: 75, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'vibrant');
        });
        it('should classify 40-69 as quiet', () => {
            const cat = (0, status_classifier_1.classifyStatus)({ score: 50, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'quiet');
        });
        it('should classify 10-39 as legacy-locked', () => {
            const cat = (0, status_classifier_1.classifyStatus)({ score: 25, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'legacy-locked');
        });
        // Score < 10 is now 'stale' (low maintenance), not 'end-of-life'
        it('should classify <10 as stale', () => {
            const cat = (0, status_classifier_1.classifyStatus)({ score: 5, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'stale');
        });
        it('should override with known issue', () => {
            const cat = (0, status_classifier_1.classifyStatus)({
                score: 90,
                knownIssue: {
                    name: 'pkg', status: 'end_of_life',
                    reason: 'bad', as_of: '2024-01-01',
                    replacement: undefined, migrationNotes: undefined,
                },
                pubDev: null,
            });
            assert.strictEqual(cat, 'end-of-life');
        });
        it('should override when discontinued', () => {
            const cat = (0, status_classifier_1.classifyStatus)({
                score: 90,
                knownIssue: null,
                pubDev: {
                    name: 'pkg', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: true, isUnlisted: false,
                    pubPoints: 100,
                    publisher: null,
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'end-of-life');
        });
        it('should handle boundary at 70', () => {
            assert.strictEqual((0, status_classifier_1.classifyStatus)({ score: 70, knownIssue: null, pubDev: null }), 'vibrant');
            assert.strictEqual((0, status_classifier_1.classifyStatus)({ score: 69.9, knownIssue: null, pubDev: null }), 'quiet');
        });
        it('should handle boundary at 10 (legacy-locked vs stale)', () => {
            assert.strictEqual((0, status_classifier_1.classifyStatus)({ score: 10, knownIssue: null, pubDev: null }), 'legacy-locked');
            assert.strictEqual((0, status_classifier_1.classifyStatus)({ score: 9.9, knownIssue: null, pubDev: null }), 'stale');
        });
        it('should classify archived repos as end-of-life', () => {
            // Archived repos are end-of-life regardless of score
            const cat = (0, status_classifier_1.classifyStatus)({
                score: 90, knownIssue: null, pubDev: null,
                isArchived: true,
            });
            assert.strictEqual(cat, 'end-of-life');
        });
        it('should not override when isArchived is false', () => {
            const cat = (0, status_classifier_1.classifyStatus)({
                score: 90, knownIssue: null, pubDev: null,
                isArchived: false,
            });
            assert.strictEqual(cat, 'vibrant');
        });
        it('should not override when isArchived is undefined', () => {
            // When GitHub data is unavailable, isArchived is undefined
            const cat = (0, status_classifier_1.classifyStatus)({
                score: 90, knownIssue: null, pubDev: null,
                isArchived: undefined,
            });
            assert.strictEqual(cat, 'vibrant');
        });
    });
    describe('categoryIcon', () => {
        it('should map categories to icon ids', () => {
            assert.strictEqual((0, status_classifier_1.categoryIcon)('vibrant'), 'pass');
            assert.strictEqual((0, status_classifier_1.categoryIcon)('stale'), 'warning');
            assert.strictEqual((0, status_classifier_1.categoryIcon)('end-of-life'), 'error');
        });
    });
    describe('categoryToSeverity', () => {
        it('should map end-of-life to Warning (1)', () => {
            assert.strictEqual((0, status_classifier_1.categoryToSeverity)('end-of-life'), 1);
        });
        it('should map stale to Information (2)', () => {
            assert.strictEqual((0, status_classifier_1.categoryToSeverity)('stale'), 2);
        });
        it('should map vibrant to Hint (3)', () => {
            assert.strictEqual((0, status_classifier_1.categoryToSeverity)('vibrant'), 3);
        });
    });
    describe('categoryLabel', () => {
        it('should return human-readable labels', () => {
            assert.strictEqual((0, status_classifier_1.categoryLabel)('legacy-locked'), 'Legacy-Locked');
            assert.strictEqual((0, status_classifier_1.categoryLabel)('stale'), 'Stale');
        });
    });
});
//# sourceMappingURL=status-classifier.test.js.map