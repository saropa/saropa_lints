/** Tests for POSIX (darwin/linux) parsing in the System Health monitor. */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { parsePosixPs, isAnalysisServerProcess } from '../../systemHealth/processQuery';
import { parseDarwinMemory, parseLinuxMemory } from '../../systemHealth/systemQuery';

const PS = `
    1 0 1000 10:00 /sbin/launchd
 1432   1 6888000 02-01:00:00 /Users/x/flutter/bin/cache/dart-sdk/bin/dart language-server --protocol=lsp --old_gen_heap_size=6144
 1500 1432 200000 05:00 /Users/x/flutter/bin/cache/dart-sdk/bin/dartaotruntime frontend_server_aot.dart.snapshot --sdk-root x
 1600   1 300000 01:00 /Users/x/flutter/bin/cache/artifacts/engine/darwin-x64/flutter_tester --foo
 1700   1 999 01:00 /usr/bin/vim dart.txt
`;

describe('parsePosixPs', () => {
  it('keeps dart images only and converts RSS KB to bytes', () => {
    const r = parsePosixPs(PS);
    assert.deepStrictEqual(r.map((p) => p.processId), [1432, 1500, 1600]);
    assert.strictEqual(r[0].workingSetSize, 6888000 * 1024);
    assert.strictEqual(r[1].parentProcessId, 1432);
    assert.ok(isAnalysisServerProcess(r[0]));
    assert.ok(!isAnalysisServerProcess(r[1]));
  });
});

describe('parseDarwinMemory', () => {
  it('sums free+inactive+speculative pages', () => {
    const vm = `Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               1000.
Pages active:                             5000.
Pages inactive:                           2000.
Pages speculative:                         500.
`;
    const r = parseDarwinMemory(vm, '8589934592\n')!;
    assert.strictEqual(r.freeBytes, 3500 * 16384);
    assert.strictEqual(r.totalBytes, 8589934592);
  });
  it('returns undefined without a page size', () => {
    assert.strictEqual(parseDarwinMemory('junk', '100'), undefined);
  });
});

describe('parseLinuxMemory', () => {
  it('uses MemAvailable', () => {
    const r = parseLinuxMemory('MemTotal:  8000000 kB\nMemFree: 1 kB\nMemAvailable: 2000000 kB\n')!;
    assert.strictEqual(r.freeBytes, 2000000 * 1024);
    assert.strictEqual(r.freeFraction, 0.25);
  });
});
