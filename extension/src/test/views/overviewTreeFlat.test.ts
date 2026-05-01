/**
 * Pins the flat-sidebar contract for {@link OverviewTreeProvider}: the root
 * level returns leaf rows only — no group parents — and shows the editor
 * dashboards, action links, settings rows, and help links even when the
 * project has no analysis report yet. Triage groups remain expandable because
 * they are data nodes (group → member rules), not structural section headers.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';

import * as projectRoot from '../../projectRoot';
import * as pubspecReader from '../../pubspecReader';
import * as violationsReader from '../../violationsReader';
import * as suppressionsStore from '../../suppressionsStore';
import * as configWriter from '../../configWriter';
import * as runHistory from '../../runHistory';

import { ConfigTreeProvider } from '../../views/configTree';
import { OverviewTreeProvider } from '../../views/overviewTree';
import { TreeItemCollapsibleState } from '../vibrancy/vscode-mock-classes';

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

describe('OverviewTreeProvider — flat sidebar', () => {
  let memento: MockMemento;
  let configProvider: ConfigTreeProvider;
  let provider: OverviewTreeProvider;

  beforeEach(() => {
    sinon.restore();
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
    // No analysis report — the provider should still surface dashboards/actions/help.
    sinon.stub(violationsReader, 'readViolations').returns(null);
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFiles: [],
      hiddenFolders: [],
      hiddenRules: [],
      hiddenRuleInFile: {},
      hiddenSeverities: [],
      hiddenImpacts: [],
    });
    sinon.stub(configWriter, 'readDisabledRules').returns(new Set<string>());
    sinon.stub(runHistory, 'loadHistory').returns([]);
    memento = new MockMemento();
    configProvider = new ConfigTreeProvider();
    provider = new OverviewTreeProvider(memento, configProvider);
  });

  afterEach(() => {
    sinon.restore();
  });

  it('returns a flat list with no group-parent contextValues at root', async () => {
    const children = await provider.getChildren();
    assert.ok(Array.isArray(children));
    // The removed parent classes used these contextValues. Any reappearance of
    // them at the root means a group container has been reintroduced.
    const bannedContextValues = new Set([
      'overviewHelpSection',
      'overviewSettingsSection',
      'overviewIssuesSection',
      'overviewSummarySection',
      'overviewSuggestionsSection',
      'overviewRiskSection',
      'overviewSidebarSection',
    ]);
    for (const node of children) {
      const cv = (node as { contextValue?: string }).contextValue;
      if (cv) {
        assert.ok(
          !bannedContextValues.has(cv),
          `unexpected group-parent contextValue at root: ${cv}`,
        );
      }
    }
  });

  it('every root row except triage groups is a leaf (no expansion)', async () => {
    const children = await provider.getChildren();
    for (const node of children) {
      const item = provider.getTreeItem(node);
      // Triage group nodes (kind === 'triageGroup') are the only collapsible rows.
      const kind = (node as { kind?: string }).kind;
      if (kind === 'triageGroup') continue;
      assert.notStrictEqual(
        item.collapsibleState,
        TreeItemCollapsibleState.Expanded,
        `non-triage row should not be expanded: ${String(item.label)}`,
      );
      assert.notStrictEqual(
        item.collapsibleState,
        TreeItemCollapsibleState.Collapsed,
        `non-triage row should not be collapsed: ${String(item.label)}`,
      );
    }
  });

  it('surfaces editor dashboards and help rows even when no violations.json exists', async () => {
    const children = await provider.getChildren();
    const labels = children.map((n) => String((n as { label?: string }).label ?? ''));
    // Editor-tab dashboards should always be present in a Dart workspace.
    assert.ok(labels.includes('Lints Config'), 'expected Lints Config row');
    assert.ok(labels.includes('Findings Dashboard'), 'expected Findings Dashboard row');
    assert.ok(labels.includes('Run analysis'), 'expected Run analysis row');
    // Help rows.
    assert.ok(labels.includes('Getting Started'), 'expected Getting Started row');
    assert.ok(labels.includes('About Saropa Lints'), 'expected About Saropa Lints row');
    // No analysis cue takes the place of the status section.
    assert.ok(labels.includes('No analysis yet'), 'expected No analysis yet placeholder');
  });

  it('dedupes Run analysis — appears exactly once across Actions and Settings', async () => {
    const children = await provider.getChildren();
    const runAnalysisCount = children.filter((n) => {
      const label = String((n as { label?: string }).label ?? '');
      return label === 'Run analysis';
    }).length;
    assert.strictEqual(runAnalysisCount, 1, 'Run analysis must not be duplicated');
  });
});
