/**
 * Status bar hover and click-menu builders (pure; no VS Code host needed).
 */
import * as assert from 'node:assert';
import {
  buildMemoryModel,
  escapeMd,
  buildStatusBarModel,
  buildStatusBarQuickPickItems,
  formatFindings,
  pillHtml,
  renderStatusBarTooltip,
  type StatusBarInput,
} from '../statusBarTooltip';
import { STATUS_BAR_TRUSTED_COMMANDS } from '../statusBarLabel';
import { HealthLevel, HealthTrigger } from '../systemHealth/types';
import type { DartProcessSnapshot } from '../systemHealth/types';

const base: StatusBarInput = {
  kind: 'on',
  label: 'Saropa Lints: On',
  extVersion: '17.0.1',
  details: {
    tier: 'recommended',
    scorePercent: 90,
    scorePending: false,
    vibrancy: { label: '9/10', packageCount: 12, suppressedCount: 0, updateCount: 3, actionCount: 1 },
    findings: { total: 18368, errors: 18368 },
  },
  readinessIssues: [],
  memoryHints: [],
};

function commandIds(md: string): string[] {
  return [...md.matchAll(/\(command:([\w.]+)/g)].map((m) => m[1]);
}

describe('formatFindings', () => {
  it('says "all errors" with thousands separators when every finding is an error', () => {
    assert.strictEqual(formatFindings(18368, 18368), '18,368 findings (all errors)');
  });
  it('splits errors and warnings otherwise', () => {
    assert.strictEqual(formatFindings(12000, 1500), '1,500 errors · 10,500 warnings');
  });
  it('handles no errors and a single error', () => {
    assert.strictEqual(formatFindings(1200, 0), '1,200 findings');
    assert.strictEqual(formatFindings(1, 1), '1 finding (an error)');
  });
});

describe('escapeMd', () => {
  it('collapses newlines to a single space', () => {
    assert.strictEqual(escapeMd('a\r\n\nb\n  c'), 'a b c');
  });
  it('escapes dollar signs so text cannot render codicons', () => {
    assert.strictEqual(escapeMd('$(error) x'), '\\$(error) x');
  });
});

describe('pillHtml', () => {
  it('uses only color and background-color styles and escapes the text', () => {
    const html = pillHtml('a<b', 'warn');
    assert.match(html, /^<span style="color:#[0-9a-f]{6};background-color:#[0-9a-f]{6};">/);
    assert.ok(html.includes('a&lt;b'));
  });
});

describe('buildStatusBarModel / renderStatusBarTooltip', () => {
  it('orders sections Status, Project, Memory-less Actions and omits Problems when none', () => {
    const md = renderStatusBarTooltip(buildStatusBarModel(base));
    const order = ['Status', 'Project', 'Actions'].map((h) => md.indexOf(`#### ${h}`));
    assert.ok(order.every((i) => i >= 0) && order[0] < order[1] && order[1] < order[2], md);
    assert.ok(!md.includes('#### Problems'));
    assert.ok(!md.includes('#### Memory'));
    assert.ok(md.includes('18,368 findings (all errors)'));
  });

  it('toggle text follows real state: partly off never says "Analysis enabled"', () => {
    const partial = renderStatusBarTooltip(buildStatusBarModel({
      ...base, kind: 'partial', partialOff: 'plugin', label: 'Saropa Lints: Partly off',
    }));
    assert.ok(!partial.includes('Analysis enabled'));
    assert.ok(!partial.includes('command:saropaLints.toggleLints'));
    assert.ok(partial.includes('command:saropaLints.showProcessHealth'));
    const on = renderStatusBarTooltip(buildStatusBarModel(base));
    assert.ok(!on.includes('command:saropaLints.toggleLints'));
    assert.ok(!on.includes('Fix:'));
  });

  it('gives one "not set up" diagnosis per state, whichever source noticed it', () => {
    const route = { state: 'neither', text: 'saropa_lints: not configured', tip: 'x' };
    for (const input of [
      { ...base, kind: 'partial' as const, partialOff: 'plugin' as const, route },
      { ...base, kind: 'off' as const, route },
    ]) {
      const md = renderStatusBarTooltip(buildStatusBarModel(input));
      assert.strictEqual(md.split('is not set up in this project').length - 1, 1, md);
      assert.ok(!md.includes('not configured'));
      assert.ok(!md.includes('plugin entry is off') && !md.includes('is off in analysis_options.yaml'));
    }
  });

  it('names each problem with its own link', () => {
    const md = renderStatusBarTooltip(buildStatusBarModel({
      ...base,
      readinessIssues: ['Heap dump in workspace', 'Watcher excludes missing'],
      route: { state: 'bothDisagree', text: 'disagree', tip: 'Versions differ.' },
    }));
    assert.ok(md.includes('#### Problems'));
    assert.ok(md.includes('Heap dump in workspace'));
    assert.ok(md.includes('Watcher excludes missing'));
    assert.ok(md.includes('Versions differ.'));
    assert.strictEqual((md.match(/Review workspace issues/g) ?? []).length, 2);
    assert.ok(md.includes('Open version compatibility card'));
  });

  it('every command link it emits is allow-listed for the hover', () => {
    const inputs: StatusBarInput[] = [
      base,
      { ...base, kind: 'partial', partialOff: 'setting', readinessIssues: ['A'] },
      { ...base, kind: 'off', details: undefined, route: { state: 'neither', text: 't', tip: 'p' } },
      { ...base, route: { state: 'dartTooOld', text: 't', tip: 'p' } },
    ];
    for (const input of inputs) {
      const ids = commandIds(renderStatusBarTooltip(buildStatusBarModel(input)));
      assert.ok(ids.length > 0);
      assert.deepStrictEqual(ids.filter((id) => !STATUS_BAR_TRUSTED_COMMANDS.includes(id)), []);
    }
  });

  it('pills carry a link title as hover text', () => {
    const md = renderStatusBarTooltip(buildStatusBarModel(base));
    assert.match(md, /\[<span style="[^"]+">[^\]]*\]\(command:saropaLints\.openViolationsWideReport "[^"]+"\)/);
  });
});

describe('buildStatusBarQuickPickItems', () => {
  it('has the status, problems and action rows, and no toggle row', () => {
    const model = buildStatusBarModel({
      ...base, kind: 'partial', partialOff: 'plugin', readinessIssues: ['Heap dump'],
    });
    const rows = buildStatusBarQuickPickItems(model);
    assert.ok(rows.every((r) => r.commandId !== 'saropaLints.toggleLints'));
    assert.ok(rows.some((r) => r.separator && r.label === 'Problems'));
    assert.ok(rows.some((r) => r.label.includes('Heap dump') && r.commandId === 'saropaLints.showWorkspaceReadiness'));
    assert.ok(rows.some((r) => r.commandId === 'saropaLints.showAbout'));
    assert.ok(rows.every((r) => !r.commandId || STATUS_BAR_TRUSTED_COMMANDS.includes(r.commandId)));
  });
});

describe('buildMemoryModel', () => {
  const proc = (id: number, rss: number, cmd: string) => ({
    processId: id, parentProcessId: 1, workingSetSize: rss, creationDate: '', commandLine: cmd,
  });
  const snap: DartProcessSnapshot = {
    totalRssBytes: 0, processCount: 3, orphanedDaemonPids: [9], legitimateDaemonCount: 2,
    saropaRssBytes: 0, saropaProcessCount: 0, orphanedScanDaemonPids: [], timestamp: 0,
    processes: [proc(1, 300 * 1024 * 1024, 'dart language-server'), proc(2, 100 * 1024 * 1024, 'dart language-server')],
  };
  const healthy = { level: HealthLevel.Healthy, trigger: HealthTrigger.None, orphanCount: 0 };

  it('keeps full detail as rows: daemons, other Dart (named), host, RAM, sparkline', () => {
    const m = buildMemoryModel({
      snap, assessment: healthy, saropaTrendArrow: '', saropaRising: false,
      rssHistory: [1, 2, 3], extHostTrendArrow: ' ↑',
      extHost: { rssBytes: 400 * 1024 * 1024, heapUsedBytes: 100 * 1024 * 1024, heapTotalBytes: 200 * 1024 * 1024,
        externalBytes: 0, arrayBuffersBytes: 0, timestamp: 0 },
      systemRam: { freeBytes: 2 * 1024 ** 3, totalBytes: 16 * 1024 ** 3 },
    });
    const text = m.rows.map((r) => `${r.label}=${r.value}`).join('\n');
    assert.ok(text.includes('Flutter daemons=3 (1 orphaned)'), text);
    assert.ok(text.includes('Other Dart=2 process(es)'), text);
    assert.ok(text.includes('Extension host=400M RSS · 100M / 200M heap ↑'), text);
    assert.ok(text.includes('Machine RAM=2.0G free of 16.0G'), text);
    assert.ok(m.sparkline && m.sparkline.length === 3);
    assert.ok(m.hints.some((h) => h.includes('analysis server')), 'multiple servers hint');
  });

  it('shows "none running" instead of "0 process(es) ✓" and omits the sparkline without history', () => {
    const m = buildMemoryModel({
      snap, assessment: healthy, saropaTrendArrow: '', saropaRising: false,
      rssHistory: [], extHostTrendArrow: '',
    });
    assert.ok(m.rows.some((r) => r.label === 'Saropa Lints' && r.value === 'none running'));
    assert.strictEqual(m.sparkline, undefined);
  });

  it('works with only machine RAM before the first snapshot', () => {
    const m = buildMemoryModel({
      assessment: healthy, saropaTrendArrow: '', saropaRising: false, rssHistory: [],
      extHostTrendArrow: '', systemRam: { freeBytes: 1024 ** 3, totalBytes: 8 * 1024 ** 3 },
    });
    assert.deepStrictEqual(m.rows.map((r) => r.label), ['Machine RAM']);
  });
});
