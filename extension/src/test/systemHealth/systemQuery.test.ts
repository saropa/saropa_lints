/**
 * Tests for the cross-platform system memory query added by
 * `plans/history/2026.09/2026.09.19/infra_system_health_monitor_windows_only_no_macos_analysis_server_warning.md`.
 *
 * These pin the pure parsers (`parseVmStat`, `parseHwMemsize`,
 * `parseMeminfo`) against captured real-world output shapes, so the
 * darwin/linux memory math can be verified without shelling out to `vm_stat`
 * or reading `/proc/meminfo` in CI.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  parseHwMemsize,
  parseMeminfo,
  parseVmStat,
} from '../../systemHealth/systemQuery';

const GB = 1024 * 1024 * 1024;

describe('parseVmStat', () => {
  it('parses a real Apple-silicon vm_stat sample (16384-byte pages)', () => {
    // Captured verbatim from `vm_stat` on an Apple-silicon Mac (page size
    // line and the fields this parser reads are untouched); the counts below
    // are crafted for an 8 GB machine with roughly 1.2 GB reclaimable:
    // (5000 + 70000 + 1800) pages x 16384 bytes = 1,258,291,200 bytes.
    const sample = `Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                     5000.
Pages active:                                  80058.
Pages inactive:                                70000.
Pages speculative:                              1800.
Pages throttled:                                   0.
Pages wired down:                             108064.
Pages purgeable:                                   2.
"Translation faults":                      915948350.
Pages copy-on-write:                         7136691.
Pages zero filled:                         170148031.
Pages reactivated:                         253461563.
Pages purged:                                3860158.
File-backed pages:                             55623.
Anonymous pages:                              103196.
Pages stored in compressor:                  1148329.
Pages occupied by compressor:                 216562.
Decompressions:                            445774738.
Compressions:                              500118306.
Pageins:                                    19451320.
Pageouts:                                     131323.
Swapins:                                    56701886.
Swapouts:                                   60020643.
`;
    const result = parseVmStat(sample);
    assert.ok(result, 'expected a parsed result');
    assert.strictEqual(result?.pageSize, 16384);
    assert.strictEqual(result?.freeBytes, 76800 * 16384);
    assert.ok(
      Math.abs(result!.freeBytes / GB - 1.171875) < 0.001,
      `expected ~1.17 GB reclaimable, got ${result!.freeBytes / GB} GB`,
    );

    // Cross-check against the whole-snapshot math querySystemMemory would do.
    const totalBytes = 8 * GB;
    const freeFraction = result!.freeBytes / totalBytes;
    assert.ok(freeFraction > 0.14 && freeFraction < 0.15);
  });

  it('parses a 4096-byte-page Intel vm_stat sample', () => {
    const sample = `Mach Virtual Memory Statistics: (page size of 4096 bytes)
Pages free:                               100000.
Pages active:                             900000.
Pages inactive:                           300000.
Pages speculative:                         20000.
Pages throttled:                               0.
Pages wired down:                         400000.
Pages purgeable:                               0.
`;
    const result = parseVmStat(sample);
    assert.ok(result);
    assert.strictEqual(result?.pageSize, 4096);
    // (100000 + 300000 + 20000) pages x 4096 bytes.
    assert.strictEqual(result?.freeBytes, 420000 * 4096);
  });

  it('returns undefined for empty input', () => {
    assert.strictEqual(parseVmStat(''), undefined);
  });

  it('returns undefined for malformed input missing the page-size header', () => {
    assert.strictEqual(parseVmStat('not vm_stat output at all'), undefined);
  });

  it('returns undefined when a required field is missing', () => {
    const sample = `Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                     5000.
Pages active:                                  80058.
`;
    // No "Pages inactive" / "Pages speculative" lines.
    assert.strictEqual(parseVmStat(sample), undefined);
  });
});

describe('parseHwMemsize', () => {
  it('parses a plain byte-count line', () => {
    assert.strictEqual(parseHwMemsize('8589934592\n'), 8589934592);
  });

  it('returns undefined for empty output', () => {
    assert.strictEqual(parseHwMemsize(''), undefined);
  });

  it('returns undefined for non-numeric output', () => {
    assert.strictEqual(parseHwMemsize('sysctl: unknown oid\n'), undefined);
  });

  it('returns undefined for a zero reading', () => {
    assert.strictEqual(parseHwMemsize('0\n'), undefined);
  });
});

describe('parseMeminfo', () => {
  it('uses MemAvailable when present', () => {
    const sample = `MemTotal:       16384000 kB
MemFree:         1000000 kB
MemAvailable:    8000000 kB
Buffers:          200000 kB
Cached:          3000000 kB
SwapTotal:       2000000 kB
SwapFree:        2000000 kB
`;
    const result = parseMeminfo(sample);
    assert.ok(result);
    assert.strictEqual(result?.totalBytes, 16384000 * 1024);
    assert.strictEqual(result?.freeBytes, 8000000 * 1024);
    assert.ok(Math.abs(result!.freeFraction - 8000000 / 16384000) < 1e-9);
  });

  it('falls back to MemFree + Buffers + Cached when MemAvailable is absent', () => {
    // Pre-3.14-kernel shape: no MemAvailable field at all.
    const sample = `MemTotal:       16384000 kB
MemFree:         1000000 kB
Buffers:          200000 kB
Cached:          3000000 kB
`;
    const result = parseMeminfo(sample);
    assert.ok(result);
    assert.strictEqual(result?.totalBytes, 16384000 * 1024);
    assert.strictEqual(result?.freeBytes, (1000000 + 200000 + 3000000) * 1024);
  });

  it('returns undefined when MemTotal is zero', () => {
    const sample = `MemTotal:       0 kB
MemAvailable:    8000000 kB
`;
    assert.strictEqual(parseMeminfo(sample), undefined);
  });

  it('returns undefined for empty input', () => {
    assert.strictEqual(parseMeminfo(''), undefined);
  });

  it('returns undefined when neither MemAvailable nor the fallback fields are present', () => {
    const sample = `MemTotal:       16384000 kB
`;
    assert.strictEqual(parseMeminfo(sample), undefined);
  });
});
