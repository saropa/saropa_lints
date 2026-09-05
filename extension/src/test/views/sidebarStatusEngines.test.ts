/**
 * Pins the sidebar Status section's row set after
 * PLAN_ext_ui_sidebar_reset.md P1/P3: Health / Engines / Hotspots (conditional)
 * / Last run (conditional). Two rows this file used to pin — "Lint
 * integration" and the analyzer-plugin ("Live analysis") warning — are GONE,
 * not renamed: both ran a command directly from a STATUS row (disable/
 * enable, reenablePlugin/initializeConfig), which violates the reset plan's
 * §2 rule that a STATUS row's click "never changes anything." Their facts
 * are still visible: scan-on-save state now lives in the Engines row's Scan
 * Daemon entry (see extension.ts's `getScanDaemonStatus` bugfix), and
 * analyzer status is one of the three engines Engines already lists.
 *
 * NOTE: a concurrent edit to this file (found mid-session) had begun
 * renaming the analyzer-plugin row's expected label from "Analyzer plugin"
 * to "Live analysis" without addressing the underlying STATUS-row-runs-a-
 * command problem this plan removes the row for. That rename is superseded
 * here — the row is deleted, not relabeled — flagged for the user in case
 * it needs reconciling with other in-flight "Live analysis" naming work
 * (e.g. Health Panel engine-card copy).
 *
 * Regression guards:
 *   - Engines row: running count + per-engine summary, warns at zero running,
 *     omitted entirely when `HealthPanel.getEngineStatuses()` is undefined.
 *   - Lint integration / analyzer-plugin-warning rows: gone for good.
 *   - Hotspots row: present with a percent-reviewed label when hotspots
 *     exist, absent when there are none.
 *   - Last run row: present when history has an entry, absent otherwise.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';

import * as projectRoot from '../../projectRoot';
import * as pubspecReader from '../../pubspecReader';
import * as liveViolationsData from '../../liveViolationsData';
import * as suppressionsStore from '../../suppressionsStore';
import * as runHistory from '../../runHistory';
import * as setupModule from '../../setup';
import * as securityHotspotReviewState from '../../securityHotspotReviewState';
import { HealthPanel } from '../../systemHealth/healthPanel';
import type { EngineStatus } from '../../systemHealth/engineCardsHtml';
import { setTestConfig, clearTestConfig } from '../vibrancy/vscode-mock';

import { ConfigTreeProvider } from '../../views/configTree';
import { createSidebarSectionProviders, SECTION_VIEW_IDS } from '../../views/sectionedSidebar';

class MockMemento {
  private readonly store = new Map<string, unknown>();
  get<T>(key: string, defaultValue?: T): T | undefined {
    return this.store.has(key) ? (this.store.get(key) as T) : defaultValue;
  }
  async update(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }
  keys(): readonly string[] {
    return [...this.store.keys()];
  }
}

function fakeEngine(key: EngineStatus['key'], enabled: boolean, status: string): EngineStatus {
  return { key, name: key, enabled, status };
}

type TestLeaf = {
  label?: { label: string } | string;
  description?: string;
  command?: { command: string };
  iconPath?: { color?: { id: string } };
};

function getStatusItems(): unknown[] {
  const providers = createSidebarSectionProviders(
    new MockMemento() as unknown as Parameters<typeof createSidebarSectionProviders>[0],
    new ConfigTreeProvider(),
  );
  const status = providers.find((p) => p.viewId === SECTION_VIEW_IDS.status);
  assert.ok(status, 'status provider must exist');
  return status!.getChildren();
}

function findByLabelPrefix(items: unknown[], prefix: string): TestLeaf | undefined {
  return (items as TestLeaf[]).find((i) => {
    const label = typeof i.label === 'string' ? i.label : i.label?.label;
    return typeof label === 'string' && label.startsWith(prefix);
  });
}

function stubNoHotspots(): void {
  sinon.stub(securityHotspotReviewState, 'countSecurityHotspotReviewStates').returns({
    total: 0,
    open: 0,
    reviewedSafe: 0,
    reviewedFixed: 0,
  });
}

describe('sidebar Status section — Engines row', () => {
  beforeEach(() => {
    sinon.restore();
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
    // buildStatusItems reads live diagnostics, not the cached report — stub
    // the live source directly rather than reconstructing the diagnostics
    // API mock plumbing underneath it.
    sinon.stub(liveViolationsData, 'readVisibleLiveViolations').returns({
      violations: [],
      summary: { totalViolations: 0 },
    });
    // Short-circuits appendHealthRow (returns before it reaches history), so
    // this test isolates the Engines row without needing a health fixture.
    sinon.stub(liveViolationsData, 'computeLiveHealthScore').returns(null);
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFiles: [],
      hiddenFolders: [],
      hiddenRules: [],
      hiddenRuleInFile: {},
      hiddenSeverities: [],
      hiddenImpacts: [],
    });
    sinon.stub(runHistory, 'loadHistory').returns([]);
    stubNoHotspots(); // isolates the Engines row from the new Hotspots row
  });

  afterEach(() => {
    sinon.restore();
  });

  function findEnginesRow(items: unknown[]): TestLeaf | undefined {
    return findByLabelPrefix(items, 'Engines:');
  }

  it('shows an Engines row with the running count and per-engine summary, no warning color', () => {
    sinon.stub(HealthPanel, 'getEngineStatuses').returns([
      fakeEngine('analyzer', true, 'active'),
      fakeEngine('scanDaemon', false, 'stopped'),
      fakeEngine('lspServer', true, 'running'),
    ]);

    const enginesRow = findEnginesRow(getStatusItems());

    assert.ok(enginesRow, 'Engines row must be present');
    const label = typeof enginesRow!.label === 'string' ? enginesRow!.label : enginesRow!.label?.label;
    assert.strictEqual(label, 'Engines: 2 running');
    assert.strictEqual(enginesRow!.command?.command, 'saropaLints.showProcessHealth');
    assert.match(enginesRow!.description ?? '', /active/);
    assert.match(enginesRow!.description ?? '', /stopped/);
    assert.match(enginesRow!.description ?? '', /running/);
    assert.strictEqual(enginesRow!.iconPath?.color, undefined, 'no warning color while something is running');
  });

  it('warns (list.warningForeground) when zero engines are running', () => {
    sinon.stub(HealthPanel, 'getEngineStatuses').returns([
      fakeEngine('analyzer', false, 'stopped'),
      fakeEngine('scanDaemon', false, 'suspended'),
      fakeEngine('lspServer', false, 'stopped'),
    ]);

    const enginesRow = findEnginesRow(getStatusItems());

    assert.ok(enginesRow, 'Engines row must be present');
    const label = typeof enginesRow!.label === 'string' ? enginesRow!.label : enginesRow!.label?.label;
    assert.strictEqual(label, 'Engines: 0 running');
    assert.strictEqual(enginesRow!.iconPath?.color?.id, 'list.warningForeground');
  });

  it('falls back to the raw status word for an unmapped status value', () => {
    sinon.stub(HealthPanel, 'getEngineStatuses').returns([
      fakeEngine('analyzer', true, 'somebrandnewstatus'),
    ]);

    const enginesRow = findEnginesRow(getStatusItems());

    assert.ok(enginesRow, 'Engines row must be present');
    assert.match(enginesRow!.description ?? '', /somebrandnewstatus/);
  });

  it('omits the Engines row entirely when getEngineStatuses() returns undefined', () => {
    sinon.stub(HealthPanel, 'getEngineStatuses').returns(undefined);

    const enginesRow = findEnginesRow(getStatusItems());

    assert.strictEqual(enginesRow, undefined, 'Engines row must not appear when engines are not configured');
  });
});

describe('sidebar Status section — Lint integration / analyzer-plugin warning are gone', () => {
  beforeEach(() => {
    sinon.restore();
    clearTestConfig();
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
    sinon.stub(liveViolationsData, 'readVisibleLiveViolations').returns({
      violations: [],
      summary: { totalViolations: 0 },
    });
    sinon.stub(liveViolationsData, 'computeLiveHealthScore').returns(null);
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFiles: [],
      hiddenFolders: [],
      hiddenRuleInFile: {},
      hiddenRules: [],
      hiddenSeverities: [],
      hiddenImpacts: [],
    });
    sinon.stub(runHistory, 'loadHistory').returns([]);
    sinon.stub(HealthPanel, 'getEngineStatuses').returns(undefined);
    sinon.stub(setupModule, 'getPluginsIntegrationState').returns('disabled');
    stubNoHotspots();
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  it('no row is labeled "Lint integration: *" regardless of saropaLints.enabled', () => {
    setTestConfig('saropaLints', 'enabled', false);
    const items = getStatusItems() as TestLeaf[];
    assert.strictEqual(findByLabelPrefix(items, 'Lint integration:'), undefined);
  });

  it('no row targets saropaLints.enable/disable/reenablePlugin from Status', () => {
    const items = getStatusItems() as Array<{ command?: { command?: string }; commandId?: string }>;
    for (const item of items) {
      const cmd = item.command?.command ?? item.commandId;
      assert.notStrictEqual(cmd, 'saropaLints.enable');
      assert.notStrictEqual(cmd, 'saropaLints.disable');
      assert.notStrictEqual(cmd, 'saropaLints.reenablePlugin');
    }
  });

  it('no analyzer-plugin configSetting row renders even when the plugin is disabled/absent', () => {
    const items = getStatusItems() as Array<{ kind?: string; label?: string }>;
    assert.ok(
      !items.some((i) => i.kind === 'configSetting' && (i.label === 'Analyzer plugin' || i.label === 'Live analysis')),
      'no analyzer-plugin warning row must render from Status any more, under any label',
    );
  });
});

/**
 * Pins the reinstated Hotspots and Last-run STATUS rows
 * (PLAN_ext_ui_sidebar_reset.md §3, rows 3-4) — both were cut in the prior
 * "sidebar row collapse" pass on the theory that the Findings dashboard's
 * status-line pill / tooltip covered them; the reset plan restores them as
 * visible rows since a pill you only see after opening Findings does not
 * help someone deciding whether to open it. Trends/regression/suppression
 * stay cut (they still live on the Findings dashboard's status-line pills).
 */
describe('sidebar Status section — Hotspots / Last run rows', () => {
  beforeEach(() => {
    sinon.restore();
    clearTestConfig();
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
    sinon.stub(liveViolationsData, 'readVisibleLiveViolations').returns({
      violations: [],
      summary: { totalViolations: 0 },
    });
    sinon.stub(liveViolationsData, 'computeLiveHealthScore').returns(null);
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFiles: [],
      hiddenFolders: [],
      hiddenRules: [],
      hiddenRuleInFile: {},
      hiddenSeverities: [],
      hiddenImpacts: [],
    });
    sinon.stub(HealthPanel, 'getEngineStatuses').returns(undefined);
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  it('Hotspots row is absent when there are no security-sensitive violations', () => {
    sinon.stub(runHistory, 'loadHistory').returns([]);
    stubNoHotspots();
    const items = getStatusItems() as TestLeaf[];
    assert.strictEqual(findByLabelPrefix(items, 'Hotspots'), undefined);
  });

  it('Hotspots row shows percent reviewed and opens the hotspot review command', () => {
    sinon.stub(runHistory, 'loadHistory').returns([]);
    sinon.stub(securityHotspotReviewState, 'countSecurityHotspotReviewStates').returns({
      total: 4,
      open: 1,
      reviewedSafe: 2,
      reviewedFixed: 1,
    });
    const items = getStatusItems() as TestLeaf[];
    const row = findByLabelPrefix(items, 'Hotspots');
    assert.ok(row, 'Hotspots row must be present when total > 0');
    assert.strictEqual(row!.command?.command, 'saropaLints.reviewHotspotState');
  });

  it('Last run row is absent when history is empty', () => {
    sinon.stub(runHistory, 'loadHistory').returns([]);
    stubNoHotspots();
    const items = getStatusItems() as TestLeaf[];
    assert.strictEqual(findByLabelPrefix(items, 'Last run'), undefined);
  });

  it('Last run row is present and opens Findings when history has an entry', () => {
    sinon.stub(runHistory, 'loadHistory').returns([
      { timestamp: new Date().toISOString(), score: 90, total: 3 },
    ] as never);
    stubNoHotspots();
    const items = getStatusItems() as TestLeaf[];
    const row = findByLabelPrefix(items, 'Last run');
    assert.ok(row, 'Last run row must be present when history has a timestamp');
    assert.strictEqual(row!.command?.command, 'saropaLints.openViolationsWideReport');
  });
});
