/**
 * Unit tests for the pure, vscode-free heap-cap helpers
 * (`recommendHeapCapMb`, `parseHeapCapMb`, `assessHeapCap`,
 * `pickWriteTarget`, `withHeapCap`) behind the analysis-server heap-cap
 * startup audit and dashboard recommendation. No vscode mock needed —
 * `heapCap.ts` only imports `HEAP_CAP_FLAG` from `processQuery.ts`, which
 * is itself vscode-free.
 */
import * as assert from 'node:assert';
import {
  assessHeapCap,
  parseHeapCapMb,
  pickWriteTarget,
  recommendHeapCapMb,
  withHeapCap,
  writeTargetToConfigurationTargetValue,
} from '../../systemHealth/heapCap';

const GB = 1_073_741_824;
const MB = 1024 * 1024;

describe('recommendHeapCapMb', () => {
  it('recommends 40% of RAM rounded down to a 512 MB multiple', () => {
    assert.strictEqual(recommendHeapCapMb(8 * GB), 3072);
    assert.strictEqual(recommendHeapCapMb(16 * GB), 6144);
  });

  it('clamps to the 8192 MB ceiling for large machines', () => {
    assert.strictEqual(recommendHeapCapMb(32 * GB), 8192);
    assert.strictEqual(recommendHeapCapMb(64 * GB), 8192);
  });

  it('clamps to the 2048 MB floor for small machines', () => {
    assert.strictEqual(recommendHeapCapMb(4 * GB), 2048);
  });
});

describe('parseHeapCapMb', () => {
  it('returns undefined when the flag is absent', () => {
    assert.strictEqual(parseHeapCapMb([]), undefined);
    assert.strictEqual(parseHeapCapMb(['--foo=bar']), undefined);
  });

  it('parses the flag value in MB', () => {
    assert.strictEqual(parseHeapCapMb(['--old_gen_heap_size=4096']), 4096);
  });

  it('the last occurrence wins when the flag appears more than once', () => {
    assert.strictEqual(
      parseHeapCapMb(['--old_gen_heap_size=2048', '--foo=1', '--old_gen_heap_size=6144']),
      6144,
    );
  });

  it('ignores a malformed or non-positive value', () => {
    assert.strictEqual(parseHeapCapMb(['--old_gen_heap_size=abc']), undefined);
    assert.strictEqual(parseHeapCapMb(['--old_gen_heap_size=0']), undefined);
    assert.strictEqual(parseHeapCapMb(['--old_gen_heap_size=-100']), undefined);
  });
});

describe('assessHeapCap', () => {
  it('is "none" when no cap is set', () => {
    assert.strictEqual(assessHeapCap({ capMb: undefined, totalBytes: 8 * GB }), 'none');
  });

  it('is "tooHigh" when the cap exceeds 50% of RAM (the 8 GB/6144 MB incident)', () => {
    assert.strictEqual(assessHeapCap({ capMb: 6144, totalBytes: 8 * GB }), 'tooHigh');
  });

  it('is "ok" when the cap leaves at least half the machine free', () => {
    assert.strictEqual(assessHeapCap({ capMb: 3072, totalBytes: 8 * GB }), 'ok');
  });

  it('is "ok" exactly at the 50% boundary', () => {
    const halfMb = (8 * GB) / 2 / MB;
    assert.strictEqual(assessHeapCap({ capMb: halfMb, totalBytes: 8 * GB }), 'ok');
  });
});

describe('pickWriteTarget', () => {
  it('defaults to global when nothing defines the setting', () => {
    assert.strictEqual(pickWriteTarget(undefined), 'global');
    assert.strictEqual(pickWriteTarget({}), 'global');
  });

  it('prefers workspaceFolder over workspace and global', () => {
    assert.strictEqual(
      pickWriteTarget({
        globalValue: ['--a'],
        workspaceValue: ['--b'],
        workspaceFolderValue: ['--c'],
      }),
      'workspaceFolder',
    );
  });

  it('prefers workspace over global when no workspaceFolder value is set', () => {
    assert.strictEqual(
      pickWriteTarget({ globalValue: ['--a'], workspaceValue: ['--b'] }),
      'workspace',
    );
  });

  it('falls back to global when only a global value is set', () => {
    assert.strictEqual(pickWriteTarget({ globalValue: ['--a'] }), 'global');
  });
});

describe('writeTargetToConfigurationTargetValue', () => {
  it('maps to the vscode.ConfigurationTarget numeric values', () => {
    assert.strictEqual(writeTargetToConfigurationTargetValue('global'), 1);
    assert.strictEqual(writeTargetToConfigurationTargetValue('workspace'), 2);
    assert.strictEqual(writeTargetToConfigurationTargetValue('workspaceFolder'), 3);
  });
});

describe('withHeapCap', () => {
  it('appends the flag when none exists, preserving other args', () => {
    assert.deepStrictEqual(
      withHeapCap(['--enable-experiment=foo'], 4096),
      ['--enable-experiment=foo', '--old_gen_heap_size=4096'],
    );
  });

  it('replaces an existing flag in place order-independently, keeping others', () => {
    assert.deepStrictEqual(
      withHeapCap(['--old_gen_heap_size=2048', '--enable-experiment=foo'], 4096),
      ['--enable-experiment=foo', '--old_gen_heap_size=4096'],
    );
  });

  it('collapses duplicate stale flags into one fresh one', () => {
    assert.deepStrictEqual(
      withHeapCap(['--old_gen_heap_size=1024', '--old_gen_heap_size=2048'], 4096),
      ['--old_gen_heap_size=4096'],
    );
  });
});
