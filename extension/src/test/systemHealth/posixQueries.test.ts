/** Tests for POSIX (darwin/linux) parsing in the System Health monitor. */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { parsePsDartProcesses, isAnalysisServerProcess } from '../../systemHealth/processQuery';
import { parseVmStat, parseHwMemsize, parseMeminfo } from '../../systemHealth/systemQuery';

const PS = `
    1     0  1000 Mon Sep  1 10:00:00 2026 /sbin/launchd
 1432     1 6888000 Fri Sep  8 21:38:25 2026 /Users/x/flutter/bin/cache/dart-sdk/bin/dart language-server --protocol=lsp --old_gen_heap_size=6144
 1500  1432 200000 Thu Sep 18 10:15:02 2026 /Users/x/flutter/bin/cache/dart-sdk/bin/dartaotruntime frontend_server_aot.dart.snapshot --sdk-root x
 1600     1 300000 Thu Sep 18 10:15:02 2026 /Users/x/flutter/bin/cache/artifacts/engine/darwin-x64/flutter_tester --foo
 1700     1 999 Thu Sep 18 10:15:02 2026 /usr/bin/vim dart.txt
`;

describe('POSIX ps -> analysis-server integration', () => {
  it('keeps dart images only, converts RSS KB to bytes, flags the analysis server', () => {
    const r = parsePsDartProcesses(PS);
    assert.deepStrictEqual(r.map((p) => p.processId), [1432, 1500, 1600]);
    assert.strictEqual(r[0].workingSetSize, 6888000 * 1024);
    assert.strictEqual(r[1].parentProcessId, 1432);
    assert.ok(isAnalysisServerProcess(r[0]));
    assert.ok(!isAnalysisServerProcess(r[1]));
  });
});

describe('POSIX memory parsers (vm_stat + hw.memsize, meminfo)', () => {
  it('darwin: free = free+inactive+speculative pages; total from hw.memsize', () => {
    const vm = `Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               1000.
Pages active:                             5000.
Pages inactive:                           2000.
Pages speculative:                         500.
`;
    const r = parseVmStat(vm)!;
    assert.strictEqual(r.freeBytes, 3500 * 16384);
    assert.strictEqual(parseHwMemsize('8589934592\n'), 8589934592);
  });
  it('linux: uses MemAvailable', () => {
    const r = parseMeminfo('MemTotal:  8000000 kB\nMemFree: 1 kB\nMemAvailable: 2000000 kB\n')!;
    assert.strictEqual(r.freeBytes, 2000000 * 1024);
    assert.strictEqual(r.freeFraction, 0.25);
  });
});
