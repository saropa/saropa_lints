import * as assert from 'node:assert';
import { generateOwaspReport } from '../owaspExport';
import type { ViolationsData } from '../violationsReader';

describe('generateOwaspReport', () => {
  it('includes suppression governance with security-related suppressions', () => {
    const data: ViolationsData = {
      violations: [
        {
          file: 'lib/a.dart',
          line: 10,
          rule: 'insecure_transport',
          message: 'Avoid insecure transport',
          owasp: { mobile: ['M5'], web: ['A02'] },
        },
      ],
      summary: {
        totalViolations: 1,
        suppressions: {
          total: 6,
          byKind: { ignore: 3, ignoreForFile: 2, baseline: 1 },
          byRule: {
            insecure_transport: 4,
            prefer_final_locals: 2,
          },
          byFile: {
            'lib/a.dart': 4,
            'lib/b.dart': 2,
          },
        },
      },
      config: {
        tier: 'recommended',
        enabledRuleCount: 100,
        ruleMetadataByRule: {
          insecure_transport: { ruleType: 'securityVulnerability', tags: ['security'] },
          prefer_final_locals: { ruleType: 'style' },
        },
      },
    };

    const report = generateOwaspReport(data, '/workspace');
    assert.ok(report.includes('## Suppression Governance'));
    assert.ok(report.includes('- Total suppressions: **6**'));
    assert.ok(report.includes('- Security-related suppressions: **4**'));
    assert.ok(report.includes('| insecure_transport | 4 | Yes |'));
    assert.ok(report.includes('| prefer_final_locals | 2 | No |'));
  });
});
