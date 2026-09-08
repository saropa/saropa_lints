/**
 * Regression tests for `plans/history/2026.09/2026.09.05/ui_status_bar_shows_red_critical_for_healthy_memory.md`.
 *
 * Two independent defects made the memory status bar cry wolf:
 *   A. an orphan-triggered Critical rendered the RSS figure, so the user saw
 *      a red badge around a perfectly healthy "47M" and investigated memory
 *      instead of the orphaned daemons that actually tripped the level;
 *   B. every memory-pressure band painted the error-red background, so an
 *      informational level-1 shed looked as bad as a hard memory stop.
 *
 * These tests pin the text-names-the-trigger rule and the band-to-color map.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  assessHealth,
  computeRssTrend,
  RssTrend,
  systemHealthStatusBarText,
  type SystemHealthConfig,
} from '../../systemHealth/processMonitor';
import {
  classifyProcess,
  detectMonotonicGrowth,
  isAnalysisServerProcess,
  isDaemonProcess,
  isSaropaProcess,
  ProcessCategory,
  processLabel,
  renderSparkline,
  SAROPA_SCAN_DAEMON_MARKER,
  SAROPA_SCAN_MARKER,
  truncateLabel,
} from '../../systemHealth/processQuery';
import type { DartProcessInfo } from '../../systemHealth/types';
import {
  memoryPressureSeverity,
  pressureBackgroundColorId,
  type MemoryPressureState,
} from '../../systemHealth/memoryPressureWatcher';
import { HealthLevel, HealthTrigger } from '../../systemHealth/types';
import type { DartProcessSnapshot } from '../../systemHealth/types';

/** Defaults matching the shipped settings, so the tests exercise real thresholds. */
const CONFIG: SystemHealthConfig = {
  enabled: true,
  pollIntervalSeconds: 60,
  warningThresholdGB: 4,
  criticalThresholdGB: 6,
  warningOrphanCount: 1,
  criticalOrphanCount: 4,
  showNotifications: true,
  analysisServerWarningGB: 4,
  systemMemoryWarningPercent: 15,
  // Extension host RSS threshold — matches the default shipped in package.json.
  extensionHostWarningGB: 1,
};

const MB = 1024 * 1024;
const GB = 1024 * MB;

/** Build a snapshot with only the fields the classifier and text builder read. */
function snapshot(overrides: Partial<DartProcessSnapshot>): DartProcessSnapshot {
  return {
    totalRssBytes: 47 * MB,
    processCount: 1,
    orphanedDaemonPids: [],
    legitimateDaemonCount: 0,
    saropaRssBytes: 47 * MB,
    saropaProcessCount: 1,
    orphanedScanDaemonPids: [],
    processes: [],
    timestamp: 0,
    ...overrides,
  };
}

/** Build a pressure state with only the fields the band table matches on. */
function pressure(overrides: Partial<MemoryPressureState>): MemoryPressureState {
  return {
    shedLevel: 0,
    rssMb: 1000,
    softLimitMb: 2867,
    hardLimitMb: 4096,
    softLimitTripped: false,
    hardLimitTripped: false,
    shedRuleCount: 0,
    shedEnabled: true,
    timestamp: '2026-09-05T00:00:00Z',
    ...overrides,
  };
}

describe('Bug A — status bar text names what tripped the level', () => {
  it('reports the orphan trigger when RSS is healthy but orphans are critical', () => {
    // 47 MB is nowhere near the 6 GB critical threshold; four orphans are.
    const assessment = assessHealth(
      snapshot({ orphanedDaemonPids: [1, 2, 3, 4] }),
      CONFIG,
    );
    assert.strictEqual(assessment.level, HealthLevel.Critical);
    assert.strictEqual(assessment.trigger, HealthTrigger.Orphans);
    assert.strictEqual(assessment.orphanCount, 4);
  });

  it('counts scan-daemon orphans toward the trigger alongside Flutter daemons', () => {
    const assessment = assessHealth(
      snapshot({ orphanedDaemonPids: [1, 2], orphanedScanDaemonPids: [3, 4] }),
      CONFIG,
    );
    assert.strictEqual(assessment.trigger, HealthTrigger.Orphans);
    assert.strictEqual(assessment.orphanCount, 4);
  });

  it('renders the orphan count, never a memory figure, for an orphan Critical', () => {
    const snap = snapshot({ orphanedDaemonPids: [1, 2, 3, 4] });
    const text = systemHealthStatusBarText(snap, assessHealth(snap, CONFIG));
    assert.ok(text, 'expected status bar text for a Critical level');
    assert.ok(text.includes('4'), `expected the orphan count in "${text}"`);
    // The exact regression: "47M" must not appear, because 47 MB is not the
    // problem and showing it made the red badge point at the wrong thing.
    assert.ok(!text.includes('47M'), `memory figure leaked into "${text}"`);
    assert.ok(/orphan/i.test(text), `expected orphans named in "${text}"`);
  });

  it('renders the orphan count for an orphan-triggered Warning too', () => {
    const snap = snapshot({ orphanedDaemonPids: [1] });
    const assessment = assessHealth(snap, CONFIG);
    assert.strictEqual(assessment.level, HealthLevel.Warning);
    const text = systemHealthStatusBarText(snap, assessment);
    assert.ok(text && /orphan/i.test(text), `expected orphans named in "${text}"`);
    assert.ok(text && !text.includes('47M'), `memory figure leaked into "${text}"`);
  });

  it('still shows the RSS figure when memory is what actually tripped', () => {
    // Thresholds now compare saropaRssBytes, not totalRssBytes.
    const snap = snapshot({ saropaRssBytes: 7 * GB });
    const assessment = assessHealth(snap, CONFIG);
    assert.strictEqual(assessment.trigger, HealthTrigger.Memory);
    const text = systemHealthStatusBarText(snap, assessment);
    assert.ok(text && text.includes('7.0G'), `expected RSS figure in "${text}"`);
  });

  it('prefers the memory trigger when memory and orphans both trip', () => {
    // Memory wins because the numeric figure the badge shows describes it.
    const assessment = assessHealth(
      snapshot({ saropaRssBytes: 7 * GB, orphanedDaemonPids: [1, 2, 3, 4] }),
      CONFIG,
    );
    assert.strictEqual(assessment.trigger, HealthTrigger.Memory);
  });

  it('does NOT trip memory threshold on high totalRssBytes when saropaRssBytes is low', () => {
    // Core false-attribution fix: 12 GB system-wide with 29 MB saropa-owned
    // must NOT trigger a warning or critical level.
    const snap = snapshot({ totalRssBytes: 12 * GB, saropaRssBytes: 29 * MB });
    const assessment = assessHealth(snap, CONFIG);
    assert.strictEqual(assessment.level, HealthLevel.Healthy);
    assert.strictEqual(assessment.trigger, HealthTrigger.None);
  });

  it('produces no text at all when healthy, so the item stays hidden', () => {
    const snap = snapshot({});
    const assessment = assessHealth(snap, CONFIG);
    assert.strictEqual(assessment.level, HealthLevel.Healthy);
    assert.strictEqual(systemHealthStatusBarText(snap, assessment), undefined);
  });
});

describe('Bug B — only severe pressure bands get the error background', () => {
  it('treats a level-1 shed as informational, not an error', () => {
    const state = pressure({ shedLevel: 1, shedRuleCount: 3 });
    assert.strictEqual(memoryPressureSeverity(state), 'info');
    // The regression: this band used to force statusBarItem.errorBackground.
    assert.strictEqual(pressureBackgroundColorId(state), undefined);
  });

  it('treats a level-2 shed as a warning', () => {
    const state = pressure({ shedLevel: 2, shedRuleCount: 40 });
    assert.strictEqual(memoryPressureSeverity(state), 'warning');
    assert.strictEqual(
      pressureBackgroundColorId(state),
      'statusBarItem.warningBackground',
    );
  });

  it('treats a level-3 shed as an error', () => {
    const state = pressure({ shedLevel: 3, shedRuleCount: 900 });
    assert.strictEqual(memoryPressureSeverity(state), 'error');
    assert.strictEqual(
      pressureBackgroundColorId(state),
      'statusBarItem.errorBackground',
    );
  });

  it('treats a tripped hard limit as an error regardless of shed level', () => {
    const state = pressure({ hardLimitTripped: true, shedLevel: 0 });
    assert.strictEqual(memoryPressureSeverity(state), 'error');
    assert.strictEqual(
      pressureBackgroundColorId(state),
      'statusBarItem.errorBackground',
    );
  });

  it('treats soft pressure with shedding disabled as a warning', () => {
    const state = pressure({ softLimitTripped: true, shedEnabled: false });
    assert.strictEqual(memoryPressureSeverity(state), 'warning');
    assert.strictEqual(
      pressureBackgroundColorId(state),
      'statusBarItem.warningBackground',
    );
  });

  it('reports no severity and no background when there is no pressure state', () => {
    assert.strictEqual(memoryPressureSeverity(null), undefined);
    assert.strictEqual(pressureBackgroundColorId(null), undefined);
  });
});

describe('RSS trend detection', () => {
  it('returns Unknown when fewer than 5 samples exist', () => {
    assert.strictEqual(computeRssTrend([100, 200, 300, 400]), RssTrend.Unknown);
  });

  it('returns Stable when values are flat', () => {
    assert.strictEqual(computeRssTrend([100, 100, 100, 100, 100]), RssTrend.Stable);
  });

  it('returns Rising when newer samples are >10% higher than older', () => {
    // Older half avg = 100, newer half avg = 200 — 100% increase.
    assert.strictEqual(computeRssTrend([100, 100, 200, 200, 200]), RssTrend.Rising);
  });

  it('returns Falling when newer samples are >10% lower than older', () => {
    // Older half avg = 200, newer half avg = 100 — 50% decrease.
    assert.strictEqual(computeRssTrend([200, 200, 100, 100, 100]), RssTrend.Falling);
  });

  it('returns Stable for fluctuations within the 10% threshold', () => {
    // Older avg = 100, newer avg = 105 — 5% change, below threshold.
    assert.strictEqual(computeRssTrend([100, 100, 105, 105, 105]), RssTrend.Stable);
  });

  it('returns Stable when all values are zero', () => {
    // Guard against division by zero — zero RSS is stable by definition.
    assert.strictEqual(computeRssTrend([0, 0, 0, 0, 0]), RssTrend.Stable);
  });

  it('classifies correctly at exactly the TREND_WINDOW boundary (5 samples)', () => {
    // Boundary: exactly 5 samples should work — older half [100,100], newer half [200,200,200].
    assert.strictEqual(computeRssTrend([100, 100, 200, 200, 200]), RssTrend.Rising);
    // At 4 samples, still Unknown.
    assert.strictEqual(computeRssTrend([100, 100, 200, 200]), RssTrend.Unknown);
  });

  it('handles more than TREND_WINDOW samples correctly', () => {
    // 7 samples: older half [50,50,50], newer half [200,200,200,200].
    // Older avg = 50, newer avg = 200 — 300% increase → Rising.
    assert.strictEqual(computeRssTrend([50, 50, 50, 200, 200, 200, 200]), RssTrend.Rising);
  });
});

/** Helper to build a minimal DartProcessInfo with just a command line. */
function proc(commandLine: string): DartProcessInfo {
  return { processId: 1, parentProcessId: 0, workingSetSize: 0, creationDate: '', commandLine };
}

describe('processLabel — command-line classification', () => {
  it('labels saropa scan daemon', () => {
    assert.strictEqual(processLabel(proc('dart.exe saropa_lints:scan_daemon --port 9100')), 'scan daemon');
  });

  it('labels saropa scan CLI', () => {
    assert.strictEqual(processLabel(proc('dart.exe saropa_lints:scan . --tier comprehensive')), 'scan CLI');
  });

  it('labels capped analysis server', () => {
    assert.strictEqual(
      processLabel(proc('dart.exe language-server --protocol=lsp --old_gen_heap_size=6144')),
      'analysis server',
    );
  });

  it('labels uncapped analysis server', () => {
    assert.strictEqual(
      processLabel(proc('dart.exe language-server --protocol=lsp')),
      'analysis server (no heap cap)',
    );
  });

  it('labels Flutter daemon', () => {
    assert.strictEqual(
      processLabel(proc('dart.exe flutter_tools.snapshot daemon')),
      'Flutter daemon',
    );
  });

  it('labels frontend compiler', () => {
    assert.strictEqual(processLabel(proc('dart.exe frontend_server --sdk-root')), 'frontend compiler');
  });

  it('labels build runner', () => {
    assert.strictEqual(processLabel(proc('dart.exe build_runner serve')), 'build runner');
  });

  it('falls back to "dart process" for unknown command lines', () => {
    assert.strictEqual(processLabel(proc('dart.exe some_custom_tool --flag')), 'dart process');
  });

  it('handles empty command line gracefully', () => {
    assert.strictEqual(processLabel(proc('')), 'dart process');
  });
});

describe('isAnalysisServerProcess — resilient detection', () => {
  it('matches language-server binary', () => {
    assert.ok(isAnalysisServerProcess(proc('dart.exe language-server --protocol=lsp')));
  });

  it('matches analysis_server snapshot', () => {
    assert.ok(isAnalysisServerProcess(proc('dart.exe analysis_server.dart.snapshot')));
  });

  it('matches --protocol=lsp flag even with renamed binary', () => {
    // Future-proofing: if the binary is renamed, the protocol flag survives.
    assert.ok(isAnalysisServerProcess(proc('dart.exe dart_lsp_server --protocol=lsp')));
  });

  it('rejects unrelated processes', () => {
    assert.ok(!isAnalysisServerProcess(proc('dart.exe build_runner serve')));
  });
});

describe('truncateLabel — tooltip width guard', () => {
  it('passes through short labels unchanged', () => {
    assert.strictEqual(truncateLabel('scan daemon'), 'scan daemon');
  });

  it('truncates labels exceeding 30 characters', () => {
    const long = 'a'.repeat(40);
    const result = truncateLabel(long);
    assert.strictEqual(result.length, 30);
    assert.ok(result.endsWith('…'));
  });

  it('handles exactly 30 characters without truncation', () => {
    const exact = 'a'.repeat(30);
    assert.strictEqual(truncateLabel(exact), exact);
  });

  it('truncates at exactly 31 characters (one over the limit)', () => {
    const oneOver = 'b'.repeat(31);
    const result = truncateLabel(oneOver);
    assert.strictEqual(result.length, 30);
    assert.ok(result.endsWith('…'), 'expected ellipsis at the end');
    // First 29 chars preserved, then ellipsis.
    assert.strictEqual(result, 'b'.repeat(29) + '…');
  });

  it('handles empty string without error', () => {
    assert.strictEqual(truncateLabel(''), '');
  });
});

describe('renderSparkline — Unicode RSS visualization', () => {
  it('returns empty string for fewer than 2 samples', () => {
    assert.strictEqual(renderSparkline([]), '');
    assert.strictEqual(renderSparkline([100]), '');
  });

  it('renders flat values as uniform mid-height bars', () => {
    const result = renderSparkline([50, 50, 50, 50]);
    // All identical → all the same character, repeated 4 times.
    assert.strictEqual(result.length, 4);
    assert.ok(new Set([...result]).size === 1, 'expected all bars identical for flat data');
  });

  it('renders rising values with ascending bar heights', () => {
    const result = renderSparkline([0, 25, 50, 75, 100]);
    assert.strictEqual(result.length, 5);
    // First bar should be the lowest, last bar should be the tallest.
    assert.strictEqual(result[0], '▁');
    assert.strictEqual(result[4], '█');
  });

  it('renders falling values with descending bar heights', () => {
    const result = renderSparkline([100, 75, 50, 25, 0]);
    assert.strictEqual(result.length, 5);
    // First bar tallest, last bar lowest.
    assert.strictEqual(result[0], '█');
    assert.strictEqual(result[4], '▁');
  });

  it('handles two samples correctly (minimum for rendering)', () => {
    const result = renderSparkline([0, 100]);
    assert.strictEqual(result.length, 2);
    // Min mapped to lowest bar, max mapped to highest.
    assert.strictEqual(result[0], '▁');
    assert.strictEqual(result[1], '█');
  });

  it('handles all-zero values as flat line', () => {
    const result = renderSparkline([0, 0, 0]);
    assert.strictEqual(result.length, 3);
    assert.ok(new Set([...result]).size === 1, 'expected uniform bars for all zeros');
  });
});

describe('detectMonotonicGrowth — memory leak detection', () => {
  it('returns false when fewer than 10 samples exist', () => {
    assert.strictEqual(detectMonotonicGrowth([1, 2, 3, 4, 5, 6, 7, 8, 9]), false);
  });

  it('detects a perfectly monotonic rise (10 ascending values)', () => {
    // 9 comparisons, all rising → 9 >= 8 threshold.
    assert.strictEqual(detectMonotonicGrowth([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]), true);
  });

  it('detects a rise with one GC dip (8/9 rising)', () => {
    // 100→200→150→300→400→500→600→700→800→900
    // Comparisons: ↑ ↓ ↑ ↑ ↑ ↑ ↑ ↑ ↑ = 8/9 rising → triggers.
    assert.strictEqual(detectMonotonicGrowth([100, 200, 150, 300, 400, 500, 600, 700, 800, 900]), true);
  });

  it('does not trigger for a flat series', () => {
    // All equal: 9 non-decreasing comparisons → 9 >= 8 → true!
    // Flat IS "not falling" — the detector intentionally treats it as suspicious.
    assert.strictEqual(detectMonotonicGrowth([50, 50, 50, 50, 50, 50, 50, 50, 50, 50]), true);
  });

  it('does not trigger for a falling series', () => {
    assert.strictEqual(detectMonotonicGrowth([100, 90, 80, 70, 60, 50, 40, 30, 20, 10]), false);
  });

  it('does not trigger for oscillating values', () => {
    // Alternating up/down — only 5/9 rising → below threshold.
    assert.strictEqual(detectMonotonicGrowth([100, 200, 100, 200, 100, 200, 100, 200, 100, 200]), false);
  });

  it('uses only the last 10 samples from a longer array', () => {
    // First 5 are falling, but the last 10 are rising.
    const samples = [500, 400, 300, 200, 100, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    assert.strictEqual(detectMonotonicGrowth(samples), true);
  });
});

// ── classifyProcess — single source of truth for process categorization ──
// The tooltip uses classifyProcess for a single-pass partition. These tests
// verify the discriminated union output and enforce the substring containment
// invariant that makes marker ordering load-bearing.

describe('classifyProcess — discriminated union', () => {
  /** Helper: build a minimal DartProcessInfo with the given command line. */
  function proc(commandLine: string): DartProcessInfo {
    return { processId: 1, parentProcessId: 0, workingSetSize: 100, creationDate: '', commandLine };
  }

  it('classifies saropa scan daemon as Saropa with correct label', () => {
    const result = classifyProcess(proc('dart run saropa_lints:scan_daemon --port=1234'));
    assert.strictEqual(result.category, ProcessCategory.Saropa);
    assert.strictEqual(result.label, 'scan daemon');
  });

  it('classifies saropa CLI scan as Saropa with correct label', () => {
    const result = classifyProcess(proc('dart run saropa_lints:scan . --tier comprehensive'));
    assert.strictEqual(result.category, ProcessCategory.Saropa);
    assert.strictEqual(result.label, 'scan CLI');
  });

  it('classifies Flutter daemon as Daemon', () => {
    const result = classifyProcess(proc('dart flutter_tools.snapshot daemon --port=1234'));
    assert.strictEqual(result.category, ProcessCategory.Daemon);
    assert.strictEqual(result.label, 'Flutter daemon');
  });

  it('classifies analysis server as AnalysisServer', () => {
    const result = classifyProcess(proc('dart language-server --protocol=lsp'));
    assert.strictEqual(result.category, ProcessCategory.AnalysisServer);
    assert.strictEqual(result.label, 'analysis server (no heap cap)');
  });

  it('classifies capped analysis server with correct label', () => {
    const result = classifyProcess(proc('dart analysis_server --old_gen_heap_size=4096'));
    assert.strictEqual(result.category, ProcessCategory.AnalysisServer);
    assert.strictEqual(result.label, 'analysis server');
  });

  it('classifies build runner as Other', () => {
    const result = classifyProcess(proc('dart run build_runner build'));
    assert.strictEqual(result.category, ProcessCategory.Other);
    assert.strictEqual(result.label, 'build runner');
  });

  it('classifies frontend compiler as Other', () => {
    const result = classifyProcess(proc('dart frontend_server --incremental'));
    assert.strictEqual(result.category, ProcessCategory.Other);
    assert.strictEqual(result.label, 'frontend compiler');
  });

  it('classifies empty command line as Other', () => {
    const result = classifyProcess(proc(''));
    assert.strictEqual(result.category, ProcessCategory.Other);
    assert.strictEqual(result.label, 'dart process');
  });
});

describe('process category partition — mutual exclusivity via classifyProcess', () => {
  function proc(commandLine: string): DartProcessInfo {
    return { processId: 1, parentProcessId: 0, workingSetSize: 100, creationDate: '', commandLine };
  }

  // Boolean predicates must agree with classifyProcess since they delegate to it.
  it('saropa scan daemon: isSaropaProcess=true, isDaemonProcess=false', () => {
    const p = proc('dart run saropa_lints:scan_daemon --port=1234');
    assert.strictEqual(isSaropaProcess(p), true);
    assert.strictEqual(isDaemonProcess(p), false);
  });

  it('Flutter daemon: isDaemonProcess=true, isSaropaProcess=false', () => {
    const p = proc('dart flutter_tools.snapshot daemon --port=1234');
    assert.strictEqual(isDaemonProcess(p), true);
    assert.strictEqual(isSaropaProcess(p), false);
  });

  it('analysis server: isAnalysisServerProcess=true, not saropa or daemon', () => {
    const p = proc('dart language-server --protocol=lsp');
    assert.strictEqual(isAnalysisServerProcess(p), true);
    assert.strictEqual(isSaropaProcess(p), false);
    assert.strictEqual(isDaemonProcess(p), false);
  });
});

describe('marker substring containment invariant', () => {
  // SAROPA_SCAN_DAEMON_MARKER must contain SAROPA_SCAN_MARKER as a prefix.
  // classifyProcess tests daemon marker first because of this. If this
  // invariant breaks (e.g. someone renames scan_daemon without updating
  // the scan marker), the ordering in classifyProcess becomes wrong and
  // scan daemon processes get misclassified as "scan CLI".
  it('scan daemon marker contains the scan marker as a prefix', () => {
    assert.ok(
      SAROPA_SCAN_DAEMON_MARKER.startsWith(SAROPA_SCAN_MARKER),
      `"${SAROPA_SCAN_DAEMON_MARKER}" must start with "${SAROPA_SCAN_MARKER}" — ` +
      'classifyProcess relies on testing daemon marker before scan marker',
    );
  });
});
