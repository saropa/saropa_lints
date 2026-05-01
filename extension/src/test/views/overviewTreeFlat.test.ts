/**
 * Pins the multi-panel sidebar contract for the Saropa Lints activity-bar
 * container. Each section is its own VS Code view (Banner / Editor dashboards
 * / Actions / Status / Settings / Triage / Help), and inside every section
 * the rows are flat clickable leaves only — no chevrons, no nested expansion.
 *
 * Regression guards:
 *   - View IDs match what package.json declares.
 *   - Every leaf returned by every provider has `CollapsibleState.None`
 *     (no chevrons inside any section).
 *   - Every leaf has a click `command` so nothing in the sidebar is dead.
 *   - Run analysis appears exactly once across all sections.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';
import * as fs from 'node:fs';
import * as path from 'node:path';

import * as projectRoot from '../../projectRoot';
import * as pubspecReader from '../../pubspecReader';
import * as violationsReader from '../../violationsReader';
import * as suppressionsStore from '../../suppressionsStore';
import * as configWriter from '../../configWriter';
import * as runHistory from '../../runHistory';

import { ConfigTreeProvider } from '../../views/configTree';
import {
  createSidebarSectionProviders,
  SECTION_VIEW_IDS,
  type FlatSectionProvider,
} from '../../views/sectionedSidebar';
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

interface PackageJsonShape {
  contributes: {
    views: { saropaLints: Array<{ id: string; name: string; when?: string }> };
  };
}

function loadPackageJson(): PackageJsonShape {
  const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
  return JSON.parse(fs.readFileSync(pkgPath, 'utf8')) as PackageJsonShape;
}

describe('Saropa Lints sidebar — multi-panel section providers', () => {
  let memento: MockMemento;
  let configProvider: ConfigTreeProvider;
  let providers: FlatSectionProvider[];

  beforeEach(() => {
    sinon.restore();
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
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
    providers = createSidebarSectionProviders(memento, configProvider);
  });

  afterEach(() => {
    sinon.restore();
  });

  it('package.json declares exactly the seven section views in the saropaLints container', () => {
    const pkg = loadPackageJson();
    const views = pkg.contributes.views.saropaLints;
    const ids = views.map((v) => v.id).sort();
    const expected = Object.values(SECTION_VIEW_IDS).sort();
    assert.deepStrictEqual(ids, expected, 'view IDs in package.json must match SECTION_VIEW_IDS exactly');
  });

  it('the legacy single saropaLints.overview view is no longer registered', () => {
    const pkg = loadPackageJson();
    const ids = pkg.contributes.views.saropaLints.map((v) => v.id);
    assert.ok(!ids.includes('saropaLints.overview'), 'monolithic overview view must not return');
    assert.ok(!ids.includes('saropaLints.dashboardHub'), 'dashboardHub view must not return');
  });

  it('every leaf rendered by every provider is CollapsibleState.None (no chevrons inside any panel)', () => {
    for (const provider of providers) {
      const items = provider.getChildren();
      // getChildren may be async in TS but the implementation here is sync.
      const rows = items as Array<unknown>;
      for (const node of rows) {
        const item = provider.getTreeItem(node as never);
        assert.strictEqual(
          item.collapsibleState,
          TreeItemCollapsibleState.None,
          `view ${provider.viewId} renders a non-leaf row: ${String(item.label)}`,
        );
      }
    }
  });

  it('every leaf has a click command — nothing dead in the sidebar', () => {
    for (const provider of providers) {
      const rows = provider.getChildren() as Array<unknown>;
      for (const node of rows) {
        const item = provider.getTreeItem(node as never);
        assert.ok(
          item.command !== undefined,
          `${provider.viewId} leaf "${String(item.label)}" has no command`,
        );
      }
    }
  });

  it('non-root getChildren() always returns [] — no second level of nesting', () => {
    for (const provider of providers) {
      const rows = provider.getChildren() as Array<unknown>;
      for (const node of rows) {
        const grandkids = provider.getChildren(node as never);
        assert.deepStrictEqual(
          grandkids,
          [],
          `${provider.viewId} leaf "${String((node as { label?: unknown }).label)}" returned children — must stay flat`,
        );
      }
    }
  });

  it('Run analysis appears exactly once across all sections', () => {
    let count = 0;
    for (const provider of providers) {
      const rows = provider.getChildren() as Array<unknown>;
      for (const node of rows) {
        const label = String((node as { label?: unknown }).label ?? '');
        if (label === 'Run analysis') count += 1;
      }
    }
    assert.strictEqual(count, 1, 'Run analysis must not be duplicated');
  });

  it('Editor dashboards section surfaces the five expected dashboards', () => {
    const editor = providers.find((p) => p.viewId === SECTION_VIEW_IDS.editorDashboards)!;
    const labels = editor.getChildren().map((n) => String((n as { label?: unknown }).label ?? ''));
    assert.ok(labels.includes('Lints Config'));
    assert.ok(labels.includes('Package Dashboard'));
    assert.ok(labels.includes('Code Health Dashboard'));
    assert.ok(labels.includes('Findings Dashboard'));
    assert.ok(labels.includes('Command Catalog'));
  });

  it('Help section omits the dead "Lints" info row that had no command', () => {
    const help = providers.find((p) => p.viewId === SECTION_VIEW_IDS.help)!;
    const labels = help.getChildren().map((n) => String((n as { label?: unknown }).label ?? ''));
    assert.ok(!labels.includes('Lints'), 'Lints info row was removed (no click target)');
    assert.ok(labels.includes('Getting Started'));
    assert.ok(labels.includes('About Saropa Lints'));
  });

  // Pin removal of the composite analyzer plugin scaffold row.
  // The action targets a tiny audience (teams shipping their own custom
  // analyzer rules) and the term is jargon for the typical Saropa user.
  // It must remain reachable only via the command palette, the command
  // catalog, the CLI flag, and the guide — never as a sidebar row.
  // Asserting on the command id (not the label) keeps the guard robust
  // against future copy edits.
  it('Actions section does not surface the composite analyzer plugin scaffold', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    for (const node of actions.getChildren()) {
      const item = actions.getTreeItem(node as never);
      assert.notStrictEqual(
        item.command?.command,
        'saropaLints.emitCompositePluginScaffold',
        'composite scaffold must not be a sidebar row — keep it in the command palette',
      );
    }
  });

  it('Config tree does not surface the composite analyzer plugin scaffold', () => {
    type CommandShape = { command?: { command?: string } };
    const rows = configProvider.getChildren() as Array<unknown>;
    const collect = (nodes: Array<unknown>): CommandShape[] => {
      const acc: CommandShape[] = [];
      for (const n of nodes) {
        acc.push(configProvider.getTreeItem(n as never) as unknown as CommandShape);
        const kids = configProvider.getChildren(n as never) as Array<unknown> | undefined;
        if (Array.isArray(kids) && kids.length > 0) acc.push(...collect(kids));
      }
      return acc;
    };
    for (const item of collect(rows)) {
      assert.notStrictEqual(
        item.command?.command,
        'saropaLints.emitCompositePluginScaffold',
        'composite scaffold must not appear in the Config tree',
      );
    }
  });
});
