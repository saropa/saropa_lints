import * as assert from 'node:assert';
import { shouldRunLsp } from '../lspGate';

describe('shouldRunLsp', () => {
  it('master off wins over lspServer.enabled=true', () => {
    assert.strictEqual(shouldRunLsp(false, true), false);
  });
  it('runs only when both are on', () => {
    assert.strictEqual(shouldRunLsp(true, true), true);
    assert.strictEqual(shouldRunLsp(true, false), false);
    assert.strictEqual(shouldRunLsp(false, false), false);
  });
});
