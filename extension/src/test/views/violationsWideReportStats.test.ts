/**
 * Coverage for `pickTopRules`' extension to carry `correction` and `owasp`
 * alongside the existing representative `message` — the data plumbing the
 * Rule Explain fold (plan §B, `PLAN_ext_ui_dashboard_consolidation.md`) needs
 * so the Top-Rules expander can render how-to-fix / OWASP content without a
 * second read of the violation list.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { pickTopRules } from '../../views/violationsWideReportStats';
import type { Violation } from '../../violationsReader';

function violation(overrides: Partial<Violation> = {}): Violation {
  return {
    file: 'lib/a.dart',
    line: 1,
    rule: 'avoid_print',
    message: 'Avoid print() in production code.',
    severity: 'warning',
    ...overrides,
  };
}

describe('pickTopRules — correction/OWASP pass-through', () => {
  it('carries the first occurrence\'s correction and OWASP mapping', () => {
    const [entry] = pickTopRules(
      [
        violation({
          correction: 'Use a Logger instead.',
          owasp: { mobile: ['M1'], web: ['A03'] },
        }),
      ],
      10,
    );
    assert.strictEqual(entry.correction, 'Use a Logger instead.');
    assert.deepStrictEqual(entry.owasp, { mobile: ['M1'], web: ['A03'] });
  });

  it('is undefined when no occurrence carries a correction (e.g. live-diagnostics source)', () => {
    const [entry] = pickTopRules([violation()], 10);
    assert.strictEqual(entry.correction, undefined);
    assert.strictEqual(entry.owasp, undefined);
  });

  it('first-seen wins: a later occurrence without correction/OWASP does not clobber an earlier one that had it', () => {
    const [entry] = pickTopRules(
      [
        violation({ file: 'lib/a.dart', correction: 'Use a Logger instead.', owasp: { mobile: ['M1'] } }),
        violation({ file: 'lib/b.dart' }), // no correction/owasp on this occurrence
      ],
      10,
    );
    assert.strictEqual(entry.count, 2);
    assert.strictEqual(entry.correction, 'Use a Logger instead.');
    assert.deepStrictEqual(entry.owasp, { mobile: ['M1'] });
  });
});
