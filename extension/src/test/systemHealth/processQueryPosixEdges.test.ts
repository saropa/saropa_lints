/**
 * POSIX edge cases in the process query: same-second parent/daemon starts
 * (ps lstart has one-second resolution) and the orphan check's pid-reuse
 * guard, which must keep working now that equal timestamps count as alive.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { isParentAlive, parsePsLstart } from '../../systemHealth/processQuery';

describe('isParentAlive with ps lstart timestamps', () => {
  const daemonStart = parsePsLstart('Thu Sep 18 10:15:02 2026');

  it('treats a parent started in the same second as alive', () => {
    const parent = { processId: 1, creationDate: parsePsLstart('Thu Sep 18 10:15:02 2026') };
    assert.strictEqual(isParentAlive(parent, daemonStart), true);
  });

  it('treats an earlier parent as alive', () => {
    const parent = { processId: 1, creationDate: parsePsLstart('Mon Sep  1 10:00:00 2026') };
    assert.strictEqual(isParentAlive(parent, daemonStart), true);
  });

  it('treats a parent that started after the daemon as a reused pid', () => {
    const parent = { processId: 1, creationDate: parsePsLstart('Thu Sep 18 10:15:03 2026') };
    assert.strictEqual(isParentAlive(parent, daemonStart), false);
  });

  it('treats a missing parent as dead', () => {
    assert.strictEqual(isParentAlive(undefined, daemonStart), false);
  });
});
