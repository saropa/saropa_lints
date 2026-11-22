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
      '--progress', 'json',
      '--format', 'json',
    ]);
  });
});
