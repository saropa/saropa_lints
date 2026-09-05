/**
 * Pins the sidebar Status section's "Engines: N running" row, added to close
 * PLAN_extension_ui_redesign.md's Phase 1 deferred item: HealthPanel.getEngineStatuses()
 * existed specifically to let the sidebar show engine state, but nothing called it.
 *
 * Regression guards:
 *   - Row appears, with the correct running count and a per-engine status summary,
 *     when HealthPanel.getEngineStatuses() returns data.
 *   - Row is entirely absent when it returns undefined (debug panel disabled, or
 *     engines never configured) — matches HealthPanel's own gating, no crash.
 *   - The row always opens the Health Panel (saropaLints.showProcessHealth).
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
  });

  afterEach(() => {
    sinon.restore();
  });

  function getStatusItems(): unknown[] {
    const providers = createSidebarSectionProviders(
      new MockMemento() as unknown as Parameters<typeof createSidebarSectionProviders>[0],
      new ConfigTreeProvider(),
    );
    const status = providers.find((p) => p.viewId === SECTION_VIEW_IDS.status);
    assert.ok(status, 'status provider must exist');
    return status!.getChildren();
  }

  function findEnginesRow(items: unknown[]): TestLeaf | undefined {
    return (items as TestLeaf[]).find((i) => {
      const label = typeof i.label === 'string' ? i.label : i.label?.label;
      return typeof label === 'string' && label.startsWith('Engines:');
    });
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

/**
 * Pins the Status section's merged "Lint integration" row — moved in from
 * the Banner view and the Settings panel's diagnostics block, which each
 * used to carry their own copy (PLAN_extension_ui_redesign.md §2.1).
 */
describe('sidebar Status section — Lint integration row', () => {
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
    sinon.stub(runHistory, 'loadHistory').returns([]);
    sinon.stub(HealthPanel, 'getEngineStatuses').returns(undefined);
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  function getStatusItems(): unknown[] {
    const providers = createSidebarSectionProviders(
      new MockMemento() as unknown as Parameters<typeof createSidebarSectionProviders>[0],
      new ConfigTreeProvider(),
    );
    const status = providers.find((p) => p.viewId === SECTION_VIEW_IDS.status);
    assert.ok(status, 'status provider must exist');
    return status!.getChildren();
  }

  function findLintIntegrationRow(items: unknown[]): TestLeaf | undefined {
    return (items as TestLeaf[]).find((i) => {
      const label = typeof i.label === 'string' ? i.label : i.label?.label;
      return typeof label === 'string' && label.startsWith('Lint integration:');
    });
  }

  it('shows "On" and a disable command when saropaLints.enabled is true', () => {
    setTestConfig('saropaLints', 'enabled', true);
    const row = findLintIntegrationRow(getStatusItems());
    assert.ok(row, 'Lint integration row must be present');
    const label = typeof row!.label === 'string' ? row!.label : row!.label?.label;
    assert.strictEqual(label, 'Lint integration: On');
    assert.strictEqual(row!.command?.command, 'saropaLints.disable');
  });

  it('shows "Off" and an enable command when saropaLints.enabled is false', () => {
    setTestConfig('saropaLints', 'enabled', false);
    const row = findLintIntegrationRow(getStatusItems());
    assert.ok(row, 'Lint integration row must be present');
    const label = typeof row!.label === 'string' ? row!.label : row!.label?.label;
    assert.strictEqual(label, 'Lint integration: Off');
    assert.strictEqual(row!.command?.command, 'saropaLints.enable');
  });
});

/**
 * Pins the Status section's analyzer plugin warning row — MOVED here from the
 * Settings/Quick Actions panel (2026-09-04, sidebar row collapse WP3,
 * `getAnalyzerPluginWarningNode` in configTree.ts). A plugin state is a fact,
 * not a setting: it belongs beside Health/Engines/Lint integration, and it
 * should only cost a row when there is actually something to fix.
 *
 * Regression guards:
 *   - `live` → no row at all (the `verifyPlugin` liveness probe stays behind
 *     Command Catalog / Health Panel instead of a sidebar row for the
 *     expected-good state).
 *   - `disabled` → row present, clicking it runs `saropaLints.reenablePlugin`.
 *   - `absent` → row present, clicking it runs `saropaLints.initializeConfig`.
 *
 * Unlike the Engines/Lint-integration rows above, this row is a raw
 * `ConfigSettingNode` object (see triageTree.ts), not a rendered
 * `vscode.TreeItem` — `FlatSectionProvider.getChildren()` returns the
 * unrendered `SectionNode[]`; `getTreeItem()` (not exercised by this test)
 * is what later calls `renderTreeItem` on it. So the click target here is
 * `commandId`, not `command.command`, and the visible text is `label`
 * directly rather than `label.label`.
 */
/**
 * Pins the WP5 (sidebar row collapse) cut: Status carries only Health /
 * Engines / Lint integration (+ the conditional plugin warning). Hotspots,
 * Trends, Score-dropped, and Suppression rows moved to the Findings
 * dashboard's status-line pills or were cut outright — stubbing history with
 * a regression AND hotspot counts > 0 proves those rows genuinely don't
 * render any more, not merely that this particular fixture happens not to
 * trigger them.
 */
describe('sidebar Status section — row collapse (WP5)', () => {
  beforeEach(() => {
    sinon.restore();
    clearTestConfig();
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
    sinon.stub(liveViolationsData, 'readVisibleLiveViolations').returns({
      violations: [],
      summary: { totalViolations: 0 },
    });
    sinon.stub(liveViolationsData, 'computeLiveHealthScore').returns({ score: 90, filesAnalyzed: 10 } as never);
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFiles: [],
      hiddenFolders: [],
      hiddenRules: [],
      hiddenRuleInFile: {},
      hiddenSeverities: [],
      hiddenImpacts: [],
    });
    // History carrying BOTH a score regression (previous run scored higher)
    // and two entries whose totals fell — exactly the fixture that used to
    // fire Score-dropped, Trends, and the "fewer issues" milestone rows.
    // If any of those rows survived the WP5 cut, this stub would surface it.
    sinon.stub(runHistory, 'loadHistory').returns([
      { timestamp: '2026-09-01T00:00:00.000Z', score: 95, total: 10 },
      { timestamp: '2026-09-02T00:00:00.000Z', score: 80, total: 5 },
    ] as never);
    sinon.stub(HealthPanel, 'getEngineStatuses').returns(undefined);
    sinon.stub(setupModule, 'getPluginsIntegrationState').returns('live');
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  function getStatusItems(): unknown[] {
    const providers = createSidebarSectionProviders(
      new MockMemento() as unknown as Parameters<typeof createSidebarSectionProviders>[0],
      new ConfigTreeProvider(),
    );
    const status = providers.find((p) => p.viewId === SECTION_VIEW_IDS.status);
    assert.ok(status, 'status provider must exist');
    return status!.getChildren();
  }

  it('carries only Health / Engines / Lint integration (+ plugin warning) — no hotspot/trend/regression/suppression/last-run rows', () => {
    const items = getStatusItems() as TestLeaf[];

    assert.ok(
      !items.some((i) => (i as unknown as { commandId?: string }).commandId === 'reviewHotspotState'
        || i.command?.command === 'saropaLints.reviewHotspotState'),
      'no row must be wired to the hotspot review command any more',
    );

    for (const item of items) {
      const label = typeof item.label === 'string' ? item.label : item.label?.label ?? '';
      assert.ok(!label.startsWith('Trends'), `label "${label}" must not be a Trends row`);
      assert.ok(!label.startsWith('Score dropped'), `label "${label}" must not be a Score-dropped row`);
      assert.ok(!label.startsWith('↓'), `label "${label}" must not be a "fewer issues" milestone row`);
      assert.ok(!label.startsWith('Last run'), `label "${label}" must not be a standalone Last-run row`);
    }

    assert.ok(
      !items.some((i) => i.iconPath && (i.iconPath as unknown as { id?: string }).id === 'eye-closed'),
      'no eye-closed (suppressions) icon should render any more',
    );
  });

  it('Health row tooltip carries the relative last-run time when history has a timestamp', () => {
    const items = getStatusItems() as TestLeaf[];
    const healthRow = items.find((i) => {
      const label = typeof i.label === 'string' ? i.label : i.label?.label;
      return typeof label === 'string' && label.startsWith('Health:');
    }) as unknown as { tooltip?: string } | undefined;
    assert.ok(healthRow, 'Health row must be present');
    assert.ok(healthRow!.tooltip, 'Health row must carry a tooltip when history has a timestamp');
    assert.match(String(healthRow!.tooltip), /ago|just now/);
  });
});

describe('sidebar Status section — Analyzer plugin warning row', () => {
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
    sinon.stub(runHistory, 'loadHistory').returns([]);
    sinon.stub(HealthPanel, 'getEngineStatuses').returns(undefined);
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  function getStatusItems(): unknown[] {
    const providers = createSidebarSectionProviders(
      new MockMemento() as unknown as Parameters<typeof createSidebarSectionProviders>[0],
      new ConfigTreeProvider(),
    );
    const status = providers.find((p) => p.viewId === SECTION_VIEW_IDS.status);
    assert.ok(status, 'status provider must exist');
    return status!.getChildren();
  }

  type TestConfigSettingNode = { kind?: string; label?: string; commandId?: string };

  function findAnalyzerPluginRow(items: unknown[]): TestConfigSettingNode | undefined {
    return (items as TestConfigSettingNode[]).find((i) => i.kind === 'configSetting' && i.label === 'Analyzer plugin');
  }

  it('renders no row when the plugin is live', () => {
    sinon.stub(setupModule, 'getPluginsIntegrationState').returns('live');
    const row = findAnalyzerPluginRow(getStatusItems());
    assert.strictEqual(row, undefined, 'a live plugin is the expected-good state and must not cost a row');
  });

  it('renders a row wired to reenablePlugin when the plugin is disabled', () => {
    sinon.stub(setupModule, 'getPluginsIntegrationState').returns('disabled');
    const row = findAnalyzerPluginRow(getStatusItems());
    assert.ok(row, 'Analyzer plugin row must be present when disabled');
    assert.strictEqual(row!.commandId, 'saropaLints.reenablePlugin');
  });

  it('renders a row wired to initializeConfig when the plugin config is absent', () => {
    sinon.stub(setupModule, 'getPluginsIntegrationState').returns('absent');
    const row = findAnalyzerPluginRow(getStatusItems());
    assert.ok(row, 'Analyzer plugin row must be present when absent');
    assert.strictEqual(row!.commandId, 'saropaLints.initializeConfig');
  });
});
