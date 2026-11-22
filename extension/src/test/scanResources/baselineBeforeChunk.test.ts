import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { runBaselineScan } from '../../scanOnSave/baselineScanRunner';

const fakeManager = (files: string[]) => ({
  listFiles: async () => files,
  scan: async (_root: string, chunk: readonly string[]) => ({
    payload: { version: 1, diagnostics: chunk.map((f) => ({ filePath: f, line: 1, column: 1, ruleName: 'r', severity: 'WARNING' })) },
    exitCode: 0,
  }),
});

describe('runBaselineScan beforeChunk', () => {
  const files = Array.from({ length: 10 }, (_, i) => `f${i}.dart`);

  it('is awaited before every chunk', async () => {
    let calls = 0;
    const r = await runBaselineScan(fakeManager(files), '/p', 'essential', {
      isCanceled: () => false,
      chunkSize: 3,
      beforeChunk: async () => { calls++; return 'continue'; },
    });
    assert.strictEqual(r.completed, true);
    assert.strictEqual(calls, 4);
  });

  it('cancels the pass when the hook says cancel, keeping earlier chunks', async () => {
    let calls = 0;
    const r = await runBaselineScan(fakeManager(files), '/p', 'essential', {
      isCanceled: () => false,
      chunkSize: 3,
      beforeChunk: async () => (++calls === 3 ? 'cancel' : 'continue'),
    });
    assert.strictEqual(r.canceled, true);
    assert.strictEqual(r.completed, false);
    assert.strictEqual(r.filesScanned, 6);
    assert.strictEqual(r.diagnostics.length, 6);
  });

  it('works without a hook (unchanged behaviour)', async () => {
    const r = await runBaselineScan(fakeManager(files), '/p', 'essential', {
      isCanceled: () => false,
      chunkSize: 4,
    });
    assert.strictEqual(r.completed, true);
    assert.strictEqual(r.filesScanned, 10);
  });
});
