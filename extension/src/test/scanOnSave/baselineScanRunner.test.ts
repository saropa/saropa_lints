import * as assert from 'node:assert';
import { chunkFiles, runBaselineScan } from '../../scanOnSave/baselineScanRunner';
import type { ScanOnSaveDiagnostic, ScanOnSaveResult } from '../../scanOnSave/scanOnSaveRunner';

function diag(filePath: string): ScanOnSaveDiagnostic {
  return { filePath, line: 1, column: 1, ruleName: 'r', severity: 'INFO' };
}

describe('chunkFiles', () => {
  it('splits into fixed-size batches, last batch smaller', () => {
    const files = ['a', 'b', 'c', 'd', 'e'];
    assert.deepStrictEqual(chunkFiles(files, 2), [['a', 'b'], ['c', 'd'], ['e']]);
  });

  it('returns one batch when files fit within chunkSize', () => {
    assert.deepStrictEqual(chunkFiles(['a', 'b'], 200), [['a', 'b']]);
  });

  it('returns no batches for an empty file list', () => {
    assert.deepStrictEqual(chunkFiles([], 200), []);
  });

  it('throws on a non-positive chunk size', () => {
    assert.throws(() => chunkFiles(['a'], 0), RangeError);
  });
});

describe('runBaselineScan', () => {
  function fakeManager(files: string[] | null, scanResults: ScanOnSaveResult[]) {
    let callIndex = 0;
    const scannedChunks: string[][] = [];
    return {
      scannedChunks,
      manager: {
        listFiles: async () => files,
        scan: async (_root: string, chunk: string[]) => {
          scannedChunks.push(chunk);
          return scanResults[callIndex++];
        },
      },
    };
  }

  it('reports daemon-down when listFiles fails, without scanning', async () => {
    const { manager, scannedChunks } = fakeManager(null, []);
    const result = await runBaselineScan(manager, '/root', 'recommended', {
      isCanceled: () => false,
    });
    assert.strictEqual(result.completed, false);
    assert.strictEqual(result.errorMessage, 'notify.commands.scanOnSaveDaemonDown');
    assert.strictEqual(scannedChunks.length, 0);
  });

  it('scans every file in chunks and aggregates diagnostics', async () => {
    const files = ['a.dart', 'b.dart', 'c.dart'];
    const { manager, scannedChunks } = fakeManager(files, [
      { payload: { version: 1, diagnostics: [diag('a.dart')] }, exitCode: 0 },
      { payload: { version: 1, diagnostics: [diag('b.dart'), diag('c.dart')] }, exitCode: 0 },
    ]);
    const progressCalls: number[] = [];
    const chunkCalls: number[] = [];
    const result = await runBaselineScan(manager, '/root', 'recommended', {
      isCanceled: () => false,
      onProgress: (p) => progressCalls.push(p.filesScanned),
      onChunk: (_chunk, d) => chunkCalls.push(d.length),
      chunkSize: 2, // 3 files -> [[a,b],[c]], matching the 2 mocked scan results
    });
    assert.deepStrictEqual(scannedChunks, [['a.dart', 'b.dart'], ['c.dart']]);
    assert.strictEqual(result.completed, true);
    assert.strictEqual(result.diagnostics.length, 3);
    assert.strictEqual(result.filesScanned, 3);
    assert.strictEqual(result.totalFiles, 3);
    assert.deepStrictEqual(progressCalls, [2, 3]);
    assert.deepStrictEqual(chunkCalls, [1, 2]);
  });

  it('stops at the failing chunk and reports the error, keeping prior diagnostics', async () => {
    const files = ['a.dart', 'b.dart'];
    const { manager } = fakeManager(files, [
      { payload: { version: 1, diagnostics: [diag('a.dart')] }, exitCode: 0 },
      { payload: null, exitCode: -1, errorMessage: 'timed out' },
    ]);
    const result = await runBaselineScan(manager, '/root', 'recommended', {
      isCanceled: () => false,
      chunkSize: 1,
    });
    assert.strictEqual(result.completed, false);
    assert.strictEqual(result.errorMessage, 'timed out');
    assert.strictEqual(result.filesScanned, 1);
    assert.strictEqual(result.diagnostics.length, 1);
  });

  it('stops between chunks when canceled, losing at most the next chunk', async () => {
    const files = ['a.dart', 'b.dart'];
    const { manager, scannedChunks } = fakeManager(files, [
      { payload: { version: 1, diagnostics: [] }, exitCode: 0 },
      { payload: { version: 1, diagnostics: [] }, exitCode: 0 },
    ]);
    let calls = 0;
    const result = await runBaselineScan(manager, '/root', 'recommended', {
      isCanceled: () => {
        calls++;
        return calls > 1; // allow the first chunk, cancel before the second
      },
      chunkSize: 1,
    });
    assert.strictEqual(result.canceled, true);
    assert.strictEqual(result.completed, false);
    assert.strictEqual(scannedChunks.length, 1);
  });
});
