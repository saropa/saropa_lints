import * as assert from 'assert';
import {
    classifySeverity,
    worstSeverity,
    severityEmoji,
    severityLabel,
    countBySeverity,
    filterBySeverity,
    calcVulnPenalty,
} from '../../../vibrancy/scoring/vuln-classifier';
import { Vulnerability, VulnSeverity } from '../../../vibrancy/types';

function makeVuln(severity: VulnSeverity, id: string = 'TEST-001'): Vulnerability {
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
            assert.strictEqual(classifySeverity(9.0), 'critical');
            assert.strictEqual(classifySeverity(9.5), 'critical');
            assert.strictEqual(classifySeverity(10.0), 'critical');
        });

        it('should return high for CVSS 7.0-8.9', () => {
            assert.strictEqual(classifySeverity(7.0), 'high');
            assert.strictEqual(classifySeverity(8.0), 'high');
            assert.strictEqual(classifySeverity(8.9), 'high');
        });

        it('should return medium for CVSS 4.0-6.9', () => {
            assert.strictEqual(classifySeverity(4.0), 'medium');
            assert.strictEqual(classifySeverity(5.5), 'medium');
            assert.strictEqual(classifySeverity(6.9), 'medium');
        });

        it('should return low for CVSS 0.1-3.9', () => {
            assert.strictEqual(classifySeverity(0.1), 'low');
            assert.strictEqual(classifySeverity(2.0), 'low');
            assert.strictEqual(classifySeverity(3.9), 'low');
        });

        it('should return medium for null CVSS', () => {
            assert.strictEqual(classifySeverity(null), 'medium');
        });
    });

    describe('worstSeverity', () => {
        it('should return null for empty array', () => {
            assert.strictEqual(worstSeverity([]), null);
        });

        it('should return the single severity', () => {
            assert.strictEqual(
                worstSeverity([makeVuln('medium')]),
                'medium',
            );
        });

        it('should return critical when present', () => {
            assert.strictEqual(
                worstSeverity([
                    makeVuln('low'),
                    makeVuln('critical'),
                    makeVuln('medium'),
                ]),
                'critical',
            );
        });

        it('should return high when no critical', () => {
            assert.strictEqual(
                worstSeverity([
                    makeVuln('low'),
                    makeVuln('high'),
                    makeVuln('medium'),
                ]),
                'high',
            );
        });
    });

    describe('severityEmoji', () => {
        it('should return correct emojis', () => {
            assert.strictEqual(severityEmoji('critical'), '🔴');
            assert.strictEqual(severityEmoji('high'), '🟠');
            assert.strictEqual(severityEmoji('medium'), '🟡');
            assert.strictEqual(severityEmoji('low'), '🔵');
        });
    });

    describe('severityLabel', () => {
        it('should return capitalized label', () => {
            assert.strictEqual(severityLabel('critical'), 'Critical');
            assert.strictEqual(severityLabel('high'), 'High');
            assert.strictEqual(severityLabel('medium'), 'Medium');
            assert.strictEqual(severityLabel('low'), 'Low');
        });
    });

    describe('countBySeverity', () => {
        it('should return zeros for empty array', () => {
            const counts = countBySeverity([]);
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
            const counts = countBySeverity(vulns);
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
            const filtered = filterBySeverity(vulns, 'low');
            assert.strictEqual(filtered.length, 4);
        });

        it('should filter out low when threshold is medium', () => {
            const filtered = filterBySeverity(vulns, 'medium');
            assert.strictEqual(filtered.length, 3);
            assert.ok(filtered.every(v => v.severity !== 'low'));
        });

        it('should filter to high and critical when threshold is high', () => {
            const filtered = filterBySeverity(vulns, 'high');
            assert.strictEqual(filtered.length, 2);
            assert.ok(filtered.every(v =>
                v.severity === 'high' || v.severity === 'critical',
            ));
        });

        it('should filter to critical only when threshold is critical', () => {
            const filtered = filterBySeverity(vulns, 'critical');
            assert.strictEqual(filtered.length, 1);
            assert.strictEqual(filtered[0].severity, 'critical');
        });
    });

    describe('calcVulnPenalty', () => {
        it('should return 0 for no vulnerabilities', () => {
            assert.strictEqual(calcVulnPenalty([]), 0);
        });

        it('should calculate penalty based on severities', () => {
            assert.strictEqual(calcVulnPenalty([makeVuln('low')]), 2);
            assert.strictEqual(calcVulnPenalty([makeVuln('medium')]), 5);
            assert.strictEqual(calcVulnPenalty([makeVuln('high')]), 10);
            assert.strictEqual(calcVulnPenalty([makeVuln('critical')]), 15);
        });

        it('should sum penalties', () => {
            const vulns = [
                makeVuln('high'),
                makeVuln('medium'),
            ];
            assert.strictEqual(calcVulnPenalty(vulns), 15);
        });

        it('should cap penalty at 30', () => {
            const vulns = [
                makeVuln('critical'),
                makeVuln('critical'),
                makeVuln('critical'),
            ];
            assert.strictEqual(calcVulnPenalty(vulns), 30);
        });
    });
});
