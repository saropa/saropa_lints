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
import { HealthPanel } from '../../systemHealth/healthPanel';
import type { EngineStatus } from '../../systemHealth/engineCardsHtml';

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

  type TestLeaf = {
    label?: { label: string } | string;
    description?: string;
    command?: { command: string };
    iconPath?: { color?: { id: string } };
  };

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
