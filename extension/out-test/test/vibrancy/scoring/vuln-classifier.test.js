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
const vuln_classifier_1 = require("../../../vibrancy/scoring/vuln-classifier");
function makeVuln(severity, id = 'TEST-001') {
    return {
        id,
        summary: 'Test vulnerability',
        severity,
        cvssScore: null,
        fixedVersion: null,
        url: 'https://example.com',
    };
}
describe('vuln-classifier', () => {
    describe('classifySeverity', () => {
        it('should return critical for CVSS 9.0-10.0', () => {
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(9.0), 'critical');
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(9.5), 'critical');
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(10.0), 'critical');
        });
        it('should return high for CVSS 7.0-8.9', () => {
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(7.0), 'high');
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(8.0), 'high');
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(8.9), 'high');
        });
        it('should return medium for CVSS 4.0-6.9', () => {
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(4.0), 'medium');
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(5.5), 'medium');
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(6.9), 'medium');
        });
        it('should return low for CVSS 0.1-3.9', () => {
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(0.1), 'low');
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(2.0), 'low');
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(3.9), 'low');
        });
        it('should return medium for null CVSS', () => {
            assert.strictEqual((0, vuln_classifier_1.classifySeverity)(null), 'medium');
        });
    });
    describe('worstSeverity', () => {
        it('should return null for empty array', () => {
            assert.strictEqual((0, vuln_classifier_1.worstSeverity)([]), null);
        });
        it('should return the single severity', () => {
            assert.strictEqual((0, vuln_classifier_1.worstSeverity)([makeVuln('medium')]), 'medium');
        });
        it('should return critical when present', () => {
            assert.strictEqual((0, vuln_classifier_1.worstSeverity)([
                makeVuln('low'),
                makeVuln('critical'),
                makeVuln('medium'),
            ]), 'critical');
        });
        it('should return high when no critical', () => {
            assert.strictEqual((0, vuln_classifier_1.worstSeverity)([
                makeVuln('low'),
                makeVuln('high'),
                makeVuln('medium'),
            ]), 'high');
        });
    });
    describe('severityEmoji', () => {
        it('should return correct emojis', () => {
            assert.strictEqual((0, vuln_classifier_1.severityEmoji)('critical'), '🔴');
            assert.strictEqual((0, vuln_classifier_1.severityEmoji)('high'), '🟠');
            assert.strictEqual((0, vuln_classifier_1.severityEmoji)('medium'), '🟡');
            assert.strictEqual((0, vuln_classifier_1.severityEmoji)('low'), '🔵');
        });
    });
    describe('severityLabel', () => {
        it('should return capitalized label', () => {
            assert.strictEqual((0, vuln_classifier_1.severityLabel)('critical'), 'Critical');
            assert.strictEqual((0, vuln_classifier_1.severityLabel)('high'), 'High');
            assert.strictEqual((0, vuln_classifier_1.severityLabel)('medium'), 'Medium');
            assert.strictEqual((0, vuln_classifier_1.severityLabel)('low'), 'Low');
        });
    });
    describe('countBySeverity', () => {
        it('should return zeros for empty array', () => {
            const counts = (0, vuln_classifier_1.countBySeverity)([]);
            assert.strictEqual(counts.critical, 0);
            assert.strictEqual(counts.high, 0);
            assert.strictEqual(counts.medium, 0);
            assert.strictEqual(counts.low, 0);
        });
        it('should count vulnerabilities by severity', () => {
            const vulns = [
                makeVuln('critical'),
                makeVuln('high'),
                makeVuln('high'),
                makeVuln('medium'),
                makeVuln('low'),
                makeVuln('low'),
                makeVuln('low'),
            ];
            const counts = (0, vuln_classifier_1.countBySeverity)(vulns);
            assert.strictEqual(counts.critical, 1);
            assert.strictEqual(counts.high, 2);
            assert.strictEqual(counts.medium, 1);
            assert.strictEqual(counts.low, 3);
        });
    });
    describe('filterBySeverity', () => {
        const vulns = [
            makeVuln('critical', 'C1'),
            makeVuln('high', 'H1'),
            makeVuln('medium', 'M1'),
            makeVuln('low', 'L1'),
        ];
        it('should return all when threshold is low', () => {
            const filtered = (0, vuln_classifier_1.filterBySeverity)(vulns, 'low');
            assert.strictEqual(filtered.length, 4);
        });
        it('should filter out low when threshold is medium', () => {
            const filtered = (0, vuln_classifier_1.filterBySeverity)(vulns, 'medium');
            assert.strictEqual(filtered.length, 3);
            assert.ok(filtered.every(v => v.severity !== 'low'));
        });
        it('should filter to high and critical when threshold is high', () => {
            const filtered = (0, vuln_classifier_1.filterBySeverity)(vulns, 'high');
            assert.strictEqual(filtered.length, 2);
            assert.ok(filtered.every(v => v.severity === 'high' || v.severity === 'critical'));
        });
        it('should filter to critical only when threshold is critical', () => {
            const filtered = (0, vuln_classifier_1.filterBySeverity)(vulns, 'critical');
            assert.strictEqual(filtered.length, 1);
            assert.strictEqual(filtered[0].severity, 'critical');
        });
    });
    describe('calcVulnPenalty', () => {
        it('should return 0 for no vulnerabilities', () => {
            assert.strictEqual((0, vuln_classifier_1.calcVulnPenalty)([]), 0);
        });
        it('should calculate penalty based on severities', () => {
            assert.strictEqual((0, vuln_classifier_1.calcVulnPenalty)([makeVuln('low')]), 2);
            assert.strictEqual((0, vuln_classifier_1.calcVulnPenalty)([makeVuln('medium')]), 5);
            assert.strictEqual((0, vuln_classifier_1.calcVulnPenalty)([makeVuln('high')]), 10);
            assert.strictEqual((0, vuln_classifier_1.calcVulnPenalty)([makeVuln('critical')]), 15);
        });
        it('should sum penalties', () => {
            const vulns = [
                makeVuln('high'),
                makeVuln('medium'),
            ];
            assert.strictEqual((0, vuln_classifier_1.calcVulnPenalty)(vulns), 15);
        });
        it('should cap penalty at 30', () => {
            const vulns = [
                makeVuln('critical'),
                makeVuln('critical'),
                makeVuln('critical'),
            ];
            assert.strictEqual((0, vuln_classifier_1.calcVulnPenalty)(vulns), 30);
        });
    });
});
//# sourceMappingURL=vuln-classifier.test.js.map