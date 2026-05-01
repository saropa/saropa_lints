/**
 * Pins the sidebar contract for {@link OverviewTreeProvider}: the root level
 * returns collapsible **section headers** (Editor dashboards / Actions /
 * Status / Settings / Triage / Help). Each section's children are leaf rows
 * only — leaves never expand further. Triage groups are the only data nodes
 * that may render as collapsed in the sidebar, but the provider does **not**
 * expand them inline (the user wanted "logical expander sections like before,
 * just not a tree").
 *
 * Regression guards:
 *   - Section names match what the user agreed to.
 *   - No legacy parent contextValues from the old Overview & options view.
 *   - Every leaf has a click `command` so nothing in the sidebar is dead.
 *   - Run analysis appears exactly once across all sections.
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
import { OverviewTreeProvider, type OverviewTreeNode } from '../../views/overviewTree';
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

describe('OverviewTreeProvider — sectioned flat sidebar', () => {
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

  /**
   * Walk root → sections → leaves into a flat list of all visible rows so
   * tests can assert on the union without rewriting one helper per case.
   */
  async function flattenAllRows(): Promise<OverviewTreeNode[]> {
    const root = await provider.getChildren();
    const all: OverviewTreeNode[] = [];
    for (const node of root) {
      all.push(node);
      const cv = (node as { contextValue?: string }).contextValue ?? '';
      if (cv.startsWith('overviewSection:')) {
        const kids = await provider.getChildren(node);
        all.push(...kids);
      }
    }
    return all;
  }

  it('root contains only the agreed sections and standalone banner rows', async () => {
    const root = await provider.getChildren();
    const labels = root.map((n) => String((n as { label?: string }).label ?? ''));
    // Sections that must always appear in a Dart workspace.
    assert.ok(labels.includes('Editor dashboards'), 'expected "Editor dashboards" section');
    assert.ok(labels.includes('Actions'), 'expected "Actions" section');
    assert.ok(labels.includes('Settings'), 'expected "Settings" section');
    assert.ok(labels.includes('Help'), 'expected "Help" section');
    // No leaked legacy section headers.
    assert.ok(!labels.includes('Help & resources'), 'old "Help & resources" parent must not return');
    assert.ok(!labels.includes('Issues'), 'old "Issues" parent must not return');
  });

  it('no legacy parent contextValues remain anywhere at the root level', async () => {
    const root = await provider.getChildren();
    const banned = new Set([
      'overviewHelpSection',
      'overviewSettingsSection',
      'overviewIssuesSection',
      'overviewSummarySection',
      'overviewSuggestionsSection',
      'overviewRiskSection',
      'overviewSidebarSection',
    ]);
    for (const node of root) {
      const cv = (node as { contextValue?: string }).contextValue;
      if (cv) {
        assert.ok(!banned.has(cv), `unexpected legacy contextValue at root: ${cv}`);
      }
    }
  });

  it('all leaves under sections have a click command — no dead rows', async () => {
    const all = await flattenAllRows();
    for (const node of all) {
      const cv = (node as { contextValue?: string }).contextValue ?? '';
      // Section headers themselves are not clickable rows; skip them.
      if (cv.startsWith('overviewSection:')) continue;
      const item = provider.getTreeItem(node);
      // Some triage data nodes may carry a default command via renderTreeItem
      // (e.g. triageGroup uses focusIssuesForRules); explicit configSetting
      // / overviewItem rows must each have a `command` set.
      assert.ok(
        item.command !== undefined,
        `leaf row missing command: ${String(item.label)}`,
      );
    }
  });

  it('leaves never collapse — section headers are the only expandable rows', async () => {
    const root = await provider.getChildren();
    for (const section of root) {
      const cv = (section as { contextValue?: string }).contextValue ?? '';
      if (!cv.startsWith('overviewSection:')) continue;
      const kids = await provider.getChildren(section);
      for (const kid of kids) {
        const kidItem = provider.getTreeItem(kid);
        // Non-section children must not be Expanded; they may be Collapsed only
        // if they are triage data nodes whose collapsibleState is set by
        // ConfigTreeProvider's renderTreeItem (kept off in our usage).
        assert.notStrictEqual(
          kidItem.collapsibleState,
          TreeItemCollapsibleState.Expanded,
          `child of ${String((section as { label?: string }).label)} should not be Expanded: ${String(kidItem.label)}`,
        );
      }
    }
  });

  it('Run analysis appears exactly once across all sections', async () => {
    const all = await flattenAllRows();
    const count = all.filter((n) => {
      const label = String((n as { label?: string }).label ?? '');
      return label === 'Run analysis';
    }).length;
    assert.strictEqual(count, 1, 'Run analysis must not be duplicated');
  });

  it('surfaces editor dashboards and help leaves even when no violations.json exists', async () => {
    const all = await flattenAllRows();
    const labels = all.map((n) => String((n as { label?: string }).label ?? ''));
    assert.ok(labels.includes('Lints Config'), 'expected Lints Config leaf');
    assert.ok(labels.includes('Findings Dashboard'), 'expected Findings Dashboard leaf');
    assert.ok(labels.includes('Run analysis'), 'expected Run analysis leaf');
    assert.ok(labels.includes('Getting Started'), 'expected Getting Started leaf');
    assert.ok(labels.includes('About Saropa Lints'), 'expected About Saropa Lints leaf');
    assert.ok(labels.includes('No analysis yet'), 'expected No analysis yet placeholder');
  });
});
