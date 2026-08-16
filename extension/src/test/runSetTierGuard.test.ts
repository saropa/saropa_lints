/**
 * Regression: Set Tier had the same freeze-bug class already fixed in Enable
 * and Create Baseline. It ran `write_config` through the SYNCHRONOUS
 * `runInWorkspace`, which blocks the extension host event loop for the whole
 * child process — on a large project that is a hung window behind a
 * non-cancellable notification showing one static title — and it had no
 * re-entrancy guard, so reaching the command twice (sidebar row, command
 * palette, status bar all route here) started two concurrent flows rewriting
 * analysis_options.yaml.
 *
 * No workspace folder is configured here: `getProjectRoot()` then returns
 * undefined synchronously, so the flow short-circuits before any file write or
 * process spawn and the dedup logic can be pinned without a real Dart
 * toolchain. Promise identity is NOT the signal — `runSetTier` is `async`, so
 * every caller gets a distinct wrapper promise even when joined — so the
 * observable side effect (the error-toast count) is what is asserted.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { invalidateProjectRoot } from '../projectRoot';
import { runSetTier } from '../setup';
import { messageMock, mockWorkspaceFolders, resetMocks } from './vibrancy/vscode-mock';

describe('runSetTier re-entrancy guard', () => {
  beforeEach(() => {
    resetMocks();
    invalidateProjectRoot();
    mockWorkspaceFolders.value = undefined;
  });

  afterEach(() => {
    invalidateProjectRoot();
    resetMocks();
  });

  it('joins the in-flight run: two concurrent calls resolve to the same outcome', async () => {
    const [r1, r2] = await Promise.all([runSetTier({} as any), runSetTier({} as any)]);

    assert.strictEqual(r1, null);
    assert.strictEqual(r2, null);
  });

  it('does not stack duplicate error notifications from concurrent calls', async () => {
    await Promise.all([runSetTier({} as any), runSetTier({} as any), runSetTier({} as any)]);

    assert.strictEqual(
      messageMock.errors.length,
      1,
      'three concurrent Set Tier invocations must produce one flow, not three',
    );
  });

  it('allows a new flow to start once the previous one has settled', async () => {
    await runSetTier({} as any);
    assert.strictEqual(messageMock.errors.length, 1);

    await runSetTier({} as any);
    assert.strictEqual(
      messageMock.errors.length,
      2,
      'a call after the previous one settled must start its own flow, not stay joined forever',
    );
  });
});
