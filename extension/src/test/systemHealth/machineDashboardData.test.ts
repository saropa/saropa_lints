/**
 * Unit tests for the pure grouping/recommendation logic behind the Machine
 * Health dashboard (PLAN_memory_stability_features.md Phase 1). Deliberately
 * excludes the webview class and HTML renderer — those need a live
 * vscode.WebviewPanel and are covered by manual F5 verification instead; see
 * .claude/rules/extension-verification.md.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  buildRecommendations,
  computeDevToolBudget,
  groupDartProcesses,
  groupModelHosts,
  type RecommendationInput,
} from '../../systemHealth/machineDashboardData';
import type { DartProcessInfo } from '../../systemHealth/types';
import type { HostProcessInfo } from '../../systemHealth/orphanHosts';

const GB = 1_073_741_824;

/** Build a Dart process row; defaults describe an unremarkable small process. */
function dartProcess(overrides: Partial<DartProcessInfo>): DartProcessInfo {
  return {
    processId: 1,
    parentProcessId: 100,
    workingSetSize: 100 * 1024 * 1024,
    creationDate: '',
    commandLine: '',
    ...overrides,
  };
}

/** Build a model-host row; defaults describe an idle ollama.exe with nothing committed. */
function hostProcess(overrides: Partial<HostProcessInfo>): HostProcessInfo {
  return {
    processId: 1,
    parentProcessId: 100,
    name: 'ollama.exe',
    committedBytes: 0,
    createdAtMs: 0,
    ...overrides,
  };
}

/** Build recommendation input; defaults describe a perfectly healthy machine with nothing to report. */
function baseRecommendationInput(overrides: Partial<RecommendationInput> = {}): RecommendationInput {
  return {
    system: undefined,
    groups: [],
    loadedModels: [],
    orphanCount: 0,
    orphanTotalBytes: 0,
    analysisServerWarningGB: 4,
    systemMemoryWarningPercent: 15,
    devToolBudgetPercent: 60,
    analyzerVmArgs: [],
    ...overrides,
  };
}

describe('groupDartProcesses', () => {
  it('buckets by category and sums RSS per bucket', () => {
    const processes = [
      dartProcess({ processId: 1, workingSetSize: 1 * GB, commandLine: 'dart language-server --protocol=lsp' }),
      dartProcess({ processId: 2, workingSetSize: 2 * GB, commandLine: 'dart language-server --protocol=lsp' }),
      dartProcess({ processId: 3, workingSetSize: 500 * 1024 * 1024, commandLine: 'flutter_tools.snapshot daemon' }),
    ];
    const groups = groupDartProcesses(processes, new Set());

    const analysisGroup = groups.find((g) => g.key === 'analysisServer');
    assert.ok(analysisGroup, 'expected an analysisServer group');
    assert.strictEqual(analysisGroup!.processCount, 2);
    assert.strictEqual(analysisGroup!.totalRssBytes, 3 * GB);

    const daemonGroup = groups.find((g) => g.key === 'flutterDaemon');
    assert.ok(daemonGroup, 'expected a flutterDaemon group');
    assert.strictEqual(daemonGroup!.processCount, 1);
  });

  it('omits categories with zero processes', () => {
    // Only saropa-marked processes present — every other category's bucket
    // must never appear at all, not appear with processCount: 0. The HTML
    // renderer relies on this to skip empty <details> sections without its
    // own zero-check duplicating this module's classification logic.
    const processes = [dartProcess({ commandLine: 'dart run saropa_lints:scan_daemon' })];
    const groups = groupDartProcesses(processes, new Set());
    assert.strictEqual(groups.length, 1);
    assert.strictEqual(groups[0].key, 'saropa');
  });

  it('marks orphan rows and counts them per group', () => {
    const processes = [
      dartProcess({ processId: 1, commandLine: 'flutter_tools.snapshot daemon' }),
      dartProcess({ processId: 2, commandLine: 'flutter_tools.snapshot daemon' }),
    ];
    const groups = groupDartProcesses(processes, new Set([1]));
    const daemonGroup = groups.find((g) => g.key === 'flutterDaemon')!;
    assert.strictEqual(daemonGroup.orphanCount, 1);
    assert.strictEqual(daemonGroup.rows.find((r) => r.processId === 1)!.isOrphan, true);
    assert.strictEqual(daemonGroup.rows.find((r) => r.processId === 2)!.isOrphan, false);
  });
});

describe('groupModelHosts', () => {
  it('sums committed bytes, not working-set size', () => {
    const hosts = [
      hostProcess({ processId: 1, committedBytes: 4 * GB }),
      hostProcess({ processId: 2, committedBytes: 6 * GB }),
    ];
    const group = groupModelHosts(hosts, new Set());
    assert.strictEqual(group.key, 'modelHost');
    assert.strictEqual(group.processCount, 2);
    assert.strictEqual(group.totalRssBytes, 10 * GB);
  });
});

describe('buildRecommendations', () => {
  it('fires systemLowMemory only under the fraction threshold', () => {
    const healthy = buildRecommendations(
      baseRecommendationInput({ system: { totalBytes: 32 * GB, freeBytes: 10 * GB, freeFraction: 10 / 32 } }),
    );
    assert.strictEqual(healthy.some((r) => r.id === 'systemLowMemory'), false);

    const low = buildRecommendations(
      baseRecommendationInput({ system: { totalBytes: 32 * GB, freeBytes: 2 * GB, freeFraction: 2 / 32 } }),
    );
    assert.strictEqual(low.some((r) => r.id === 'systemLowMemory'), true);
    assert.strictEqual(low.find((r) => r.id === 'systemLowMemory')!.severity, 'critical');
  });

  it('surfaces orphansFound with a reclaim action', () => {
    const recs = buildRecommendations(
      baseRecommendationInput({ orphanCount: 3, orphanTotalBytes: 5 * GB }),
    );
    const rec = recs.find((r) => r.id === 'orphansFound');
    assert.ok(rec);
    assert.strictEqual(rec!.actionCommand, 'saropaLints.checkOrphanedProcesses');
  });

  it('flags an oversized analysis server by per-process RSS, not group total', () => {
    const groups = groupDartProcesses(
      [
        dartProcess({ processId: 1, workingSetSize: 1 * GB, commandLine: 'dart language-server --protocol=lsp' }),
        dartProcess({ processId: 2, workingSetSize: 1 * GB, commandLine: 'dart language-server --protocol=lsp' }),
      ],
      new Set(),
    );
    // Two 1 GB servers sum to 2 GB (under the 4 GB default warning) — this
    // must NOT trigger analysisServerLarge, only multipleAnalysisServers.
    const recs = buildRecommendations(baseRecommendationInput({ groups }));
    assert.strictEqual(recs.some((r) => r.id === 'analysisServerLarge'), false);
    assert.strictEqual(recs.some((r) => r.id === 'multipleAnalysisServers'), true);
  });

  it('flags analysisServerLarge when a single process crosses the threshold', () => {
    const groups = groupDartProcesses(
      [dartProcess({ processId: 1, workingSetSize: 6 * GB, commandLine: 'dart language-server --protocol=lsp' })],
      new Set(),
    );
    const recs = buildRecommendations(baseRecommendationInput({ groups, analysisServerWarningGB: 4 }));
    assert.strictEqual(recs.some((r) => r.id === 'analysisServerLarge'), true);
  });

  it('suppresses noHeapCap once --old_gen_heap_size is present', () => {
    const groups = groupDartProcesses(
      [dartProcess({ workingSetSize: 1 * GB, commandLine: 'dart language-server --protocol=lsp' })],
      new Set(),
    );
    const withoutCap = buildRecommendations(baseRecommendationInput({ groups, analyzerVmArgs: [] }));
    assert.strictEqual(withoutCap.some((r) => r.id === 'noHeapCap'), true);

    const withCap = buildRecommendations(
      baseRecommendationInput({ groups, analyzerVmArgs: ['--old_gen_heap_size=4096'] }),
    );
    assert.strictEqual(withCap.some((r) => r.id === 'noHeapCap'), false);
  });

  it('emits one modelLoaded recommendation per model with its name as actionArgs', () => {
    const recs = buildRecommendations(
      baseRecommendationInput({
        loadedModels: [{ name: 'qwen2.5:7b', sizeBytes: 5 * GB }, { name: 'llama3:8b', sizeBytes: 6 * GB }],
      }),
    );
    const qwen = recs.find((r) => r.id === 'modelLoaded:qwen2.5:7b');
    assert.ok(qwen);
    assert.deepStrictEqual(qwen!.actionArgs, ['qwen2.5:7b']);
    assert.strictEqual(recs.filter((r) => r.id.startsWith('modelLoaded:')).length, 2);
  });

  it('fires budgetOverspend when dev tools exceed the configured budget', () => {
    // 32 GB total, 20 GB of dev tools = 62.5% — over the 60% default budget.
    const groups = groupDartProcesses(
      [dartProcess({ processId: 1, workingSetSize: 20 * GB, commandLine: 'dart language-server --protocol=lsp' })],
      new Set(),
    );
    const recs = buildRecommendations(baseRecommendationInput({
      system: { totalBytes: 32 * GB, freeBytes: 12 * GB, freeFraction: 12 / 32 },
      groups,
      devToolBudgetPercent: 60,
    }));
    assert.ok(recs.some((r) => r.id === 'budgetOverspend'));
  });

  it('does not fire budgetOverspend when under budget', () => {
    // 32 GB total, 10 GB of dev tools = 31.25% — well under 60%.
    const groups = groupDartProcesses(
      [dartProcess({ processId: 1, workingSetSize: 10 * GB, commandLine: 'dart language-server --protocol=lsp' })],
      new Set(),
    );
    const recs = buildRecommendations(baseRecommendationInput({
      system: { totalBytes: 32 * GB, freeBytes: 22 * GB, freeFraction: 22 / 32 },
      groups,
      devToolBudgetPercent: 60,
    }));
    assert.strictEqual(recs.some((r) => r.id === 'budgetOverspend'), false);
  });
});

describe('computeDevToolBudget', () => {
  it('returns undefined when system memory is unknown', () => {
    assert.strictEqual(computeDevToolBudget(undefined, [], 60), undefined);
  });

  it('computes correct percentage and over-budget flag', () => {
    const system = { totalBytes: 32 * GB, freeBytes: 12 * GB, freeFraction: 12 / 32 };
    const groups = groupDartProcesses(
      [dartProcess({ processId: 1, workingSetSize: 20 * GB, commandLine: 'dart language-server --protocol=lsp' })],
      new Set(),
    );
    const budget = computeDevToolBudget(system, groups, 60);
    assert.ok(budget);
    assert.strictEqual(budget!.overBudget, true);
    assert.strictEqual(budget!.devToolBytes, 20 * GB);
    // 20/32 = 62.5%
    assert.strictEqual(budget!.usedPercent, 62.5);
  });
});
