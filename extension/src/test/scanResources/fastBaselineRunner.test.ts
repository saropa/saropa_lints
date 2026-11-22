import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { buildFastBaselineArgs } from '../../scanResources/fastBaselineRunner';

describe('buildFastBaselineArgs', () => {
  it('puts the project root first and passes explicit resources', () => {
    const args = buildFastBaselineArgs('/proj', 'recommended', { jobs: 4, maxMemoryMb: 2048 });
    assert.strictEqual(args[0], '/proj');
    assert.deepStrictEqual(args.slice(1), [
      '--tier', 'recommended',
      '--jobs', '4',
      '--max-memory-mb', '2048',
      '--max-issues', '0',
      '--progress', 'json',
      '--format', 'json',
    ]);
  });
});

describe('buildFastBaselineArgs max issues', () => {
  it('passes a configured cap and clamps nonsense to unlimited', () => {
    const r = { jobs: 2, maxMemoryMb: 1024 };
    assert.ok(buildFastBaselineArgs('/p', 'essential', r, 300).join(' ').includes('--max-issues 300'));
    assert.ok(buildFastBaselineArgs('/p', 'essential', r, -5).join(' ').includes('--max-issues 0'));
  });
});
