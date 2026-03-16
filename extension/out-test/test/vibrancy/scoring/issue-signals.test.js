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
const issue_signals_1 = require("../../../vibrancy/scoring/issue-signals");
describe('issue-signals', () => {
    describe('detectIssueSignals', () => {
        it('should detect deprecated keyword', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('This API is deprecated', []);
            assert.ok(signals.includes('deprecated'));
        });
        it('should detect obsolete keyword', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Warning about obsolete java version (8)', []);
            assert.ok(signals.includes('obsolete'));
            assert.ok(signals.includes('java version'));
        });
        it('should detect multiple signals in one title', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Build fails with Dart 3.5 - breaking change', []);
            assert.ok(signals.includes('build failure'));
            assert.ok(signals.includes('dart version'));
            assert.ok(signals.includes('breaking change'));
        });
        it('should be case insensitive', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('DEPRECATED API', []);
            assert.ok(signals.includes('deprecated'));
        });
        it('should return empty array for non-signal titles', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Add dark mode support', []);
            assert.deepStrictEqual(signals, []);
        });
        it('should detect signal labels', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Some issue', ['breaking-change']);
            assert.ok(signals.includes('label:breaking-change'));
        });
        it('should detect labels case-insensitively', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Some issue', ['Critical']);
            assert.ok(signals.includes('label:critical'));
        });
        it('should deduplicate signals', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('deprecated deprecated deprecated', []);
            const count = signals.filter(s => s === 'deprecated').length;
            assert.strictEqual(count, 1);
        });
        it('should detect crash signal', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('App crashes on startup', []);
            assert.ok(signals.includes('crash'));
        });
        it('should detect memory leak signal', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Memory leak in background service', []);
            assert.ok(signals.includes('memory leak'));
        });
        it('should detect null safety signal', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Package lacks null-safety support', []);
            assert.ok(signals.includes('null safety'));
        });
        it('should detect gradle signal', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Incompatible with gradle 8.5', []);
            assert.ok(signals.includes('gradle'));
            assert.ok(signals.includes('incompatible'));
        });
        it('should detect impeller signal', () => {
            const signals = (0, issue_signals_1.detectIssueSignals)('Rendering broken on Impeller', []);
            assert.ok(signals.includes('impeller'));
        });
    });
    describe('flagHighSignalIssues', () => {
        const repoUrl = 'https://github.com/test/repo';
        it('should flag issues with signal keywords', () => {
            const issues = [
                {
                    number: 60,
                    title: 'Warning about obsolete java version (8)',
                    labels: [{ name: 'bug' }],
                    comments: 12,
                },
            ];
            const flagged = (0, issue_signals_1.flagHighSignalIssues)(issues, repoUrl);
            assert.strictEqual(flagged.length, 1);
            assert.strictEqual(flagged[0].number, 60);
            assert.ok(flagged[0].matchedSignals.includes('obsolete'));
            assert.ok(flagged[0].matchedSignals.includes('java version'));
        });
        it('should skip non-signal issues', () => {
            const issues = [
                {
                    number: 61,
                    title: 'Add dark mode support',
                    labels: [{ name: 'enhancement' }],
                    comments: 8,
                },
            ];
            const flagged = (0, issue_signals_1.flagHighSignalIssues)(issues, repoUrl);
            assert.strictEqual(flagged.length, 0);
        });
        it('should construct correct URL', () => {
            const issues = [
                {
                    number: 42,
                    title: 'App crashes on load',
                    labels: [],
                    comments: 3,
                },
            ];
            const flagged = (0, issue_signals_1.flagHighSignalIssues)(issues, repoUrl);
            assert.strictEqual(flagged[0].url, 'https://github.com/test/repo/issues/42');
        });
        it('should return empty array for empty input', () => {
            const flagged = (0, issue_signals_1.flagHighSignalIssues)([], repoUrl);
            assert.deepStrictEqual(flagged, []);
        });
        it('should handle mixed label formats', () => {
            const issues = [
                {
                    number: 70,
                    title: 'Minor issue',
                    labels: ['breaking-change'],
                    comments: 2,
                },
            ];
            const flagged = (0, issue_signals_1.flagHighSignalIssues)(issues, repoUrl);
            assert.strictEqual(flagged.length, 1);
            assert.ok(flagged[0].matchedSignals.includes('label:breaking-change'));
        });
        it('should preserve comment count', () => {
            const issues = [
                {
                    number: 99,
                    title: 'deprecated method',
                    labels: [],
                    comments: 42,
                },
            ];
            const flagged = (0, issue_signals_1.flagHighSignalIssues)(issues, repoUrl);
            assert.strictEqual(flagged[0].commentCount, 42);
        });
        it('should filter from mixed set correctly', () => {
            const issues = [
                {
                    number: 1, title: 'deprecated API',
                    labels: [], comments: 5,
                },
                {
                    number: 2, title: 'Add feature X',
                    labels: [], comments: 10,
                },
                {
                    number: 3, title: 'Build fails on Dart 3',
                    labels: [], comments: 20,
                },
                {
                    number: 4, title: 'Update readme',
                    labels: [], comments: 1,
                },
            ];
            const flagged = (0, issue_signals_1.flagHighSignalIssues)(issues, repoUrl);
            assert.strictEqual(flagged.length, 2);
            assert.strictEqual(flagged[0].number, 1);
            assert.strictEqual(flagged[1].number, 3);
        });
    });
});
//# sourceMappingURL=issue-signals.test.js.map