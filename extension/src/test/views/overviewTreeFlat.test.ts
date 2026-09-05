/**
 * Pins the multi-panel sidebar contract for the Saropa Lints activity-bar
 * container. Each section is its own VS Code view (Banner / Editor dashboards
 * / Settings / Status), and inside every section the rows are flat clickable
 * leaves only — no chevrons, no nested expansion.
 *
 * Settings (aka Quick Actions) is now action-rows-only: run analysis,
 * initialize/update config, fix stale ignores, command catalog, plus a
 * conditional Migrate row (only while legacy plugin-block config keys
 * remain). Severity toggles, setting-value rows (run-after-config/
 * dependency, UI language, detected packages), and triage rows were CUT here
 * (2026-09-04, sidebar row collapse WP1) — each was a verified duplicate of
 * a richer surface: severity toggles and the setting-value rows now live on
 * the Rules & Tiers Automation/Extension tabs, triage rows duplicated the
 * Findings Dashboard's top-rules table. See
 * plans/PLAN_sidebar_row_collapse.md §2.1. Help (Getting Started / About /
 * pub.dev / AI instructions) moved out of the tree entirely, into the
 * Dashboards view's "..." title menu.
 *
 * Regression guards:
 *   - View IDs match what package.json declares.
 *   - Every leaf returned by every provider has `CollapsibleState.None`
 *     (no chevrons inside any section).
 *   - Every leaf has a click `command` so nothing in the sidebar is dead.
 *   - Run analysis appears exactly once across all sections.
 *   - Settings carries no severity toggles, no setting-value rows, no
 *     triage rows; the Migrate row appears only when legacy keys exist.
 *   - Tier and Lane (formerly separate Settings rows, WP2 sidebar row
 *     collapse) are folded into the Dashboards "Lints Config" row
 *     description; no row anywhere still targets `saropaLints.setLane`.
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
import * as migrateConfig from '../../config/migrateConfig';
// Stubbed in the new "Lints Config row" test below — lets the test control
// the lane value without a real analysis_options_custom.yaml on disk.
import * as laneConfig from '../../config/laneConfig';
import { setTestConfig, clearTestConfig } from '../vibrancy/vscode-mock';

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
    // Default: no legacy keys to migrate, so the conditional Migrate row is
    // absent in every test except the ones that explicitly stub it present.
    sinon.stub(migrateConfig, 'migrateConfigKeys').returns({ moved: [], skipped: [] });
    memento = new MockMemento();
    configProvider = new ConfigTreeProvider();
    providers = createSidebarSectionProviders(memento, configProvider);
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  it('package.json declares exactly the section views (Actions merged into Settings)', () => {
    const pkg = loadPackageJson();
    const views = pkg.contributes.views.saropaLints;
    const ids = views.map((v) => v.id).sort();
    // The container holds exactly the tree-based section views (managed by
    // sectionedSidebar). The former standalone Debug Panel webview view
    // merged into the Health Panel editor-tab dashboard and no longer
    // exists as a sidebar view (see systemHealth/healthPanel.ts).
    const expected = [...Object.values(SECTION_VIEW_IDS)].sort();
    assert.deepStrictEqual(ids, expected, 'container = section views');
  });

  // WP5, sidebar row collapse: the Status view used to require
  // `saropaLints.hasViolations` in its `when` clause, which hid the entire
  // panel — including the Lint integration row — on a clean project. That
  // gate is exactly wrong: a clean project with integration OFF also shows
  // zero violations, so the one row that would explain why was hidden
  // whenever it mattered most. Pin the clause directly against package.json
  // rather than against sectionedSidebar.ts's runtime output, since the
  // `when` clause is VS Code manifest data this suite has no other way to
  // exercise.
  it('the Status view is no longer gated on saropaLints.hasViolations', () => {
    const pkg = loadPackageJson();
    const statusView = pkg.contributes.views.saropaLints.find((v) => v.id === SECTION_VIEW_IDS.status);
    assert.ok(statusView, 'Status view must be declared in package.json');
    assert.ok(
      !(statusView!.when ?? '').includes('hasViolations'),
      `Status view's when clause "${statusView!.when}" must not reference hasViolations any more`,
    );
    assert.ok(
      (statusView!.when ?? '').includes('isDartProject'),
      'Status view must still be gated on isDartProject',
    );
  });

  it('the debug panel is no longer a standalone sidebar view (merged into Health Panel)', () => {
    const pkg = loadPackageJson();
    const ids = pkg.contributes.views.saropaLints.map((v) => v.id);
    assert.ok(!ids.includes('saropaLints.debugPanel'), 'debugPanel view must not return');
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

  it('Editor dashboards section surfaces exactly the six first-class dashboards', () => {
    const editor = providers.find((p) => p.viewId === SECTION_VIEW_IDS.editorDashboards)!;
    const labels = editor.getChildren().map((n) => String((n as { label?: unknown }).label ?? ''));
    assert.ok(labels.includes('Lints Config'));
    assert.ok(labels.includes('Package Dashboard'));
    assert.ok(labels.includes('Code Health Dashboard'));
    assert.ok(labels.includes('Saropa Project Map'));
    assert.ok(labels.includes('Findings Dashboard'));
    // Analysis Optimizer, Upgrade Opportunities, and the Feature Inventory
    // export are reachable as tabs inside Rules & Tiers / Package Dashboard
    // (PLAN_extension_ui_redesign.md §2.1) — no longer separate rows here.
    // Command Catalog moved to the Settings panel's action rows.
    assert.ok(!labels.includes('Analysis Optimizer'));
    assert.ok(!labels.includes('Upgrade Opportunities'));
    assert.ok(!labels.includes('Full Opportunities Report'));
    assert.ok(!labels.includes('Command Catalog'));
  });

  // WP2, sidebar row collapse plan: the Settings panel's separate Tier and
  // Lane rows are gone (see the "carries no setting-value rows"-style guards
  // below) — both values now fold into the Dashboards section's "Lints
  // Config" row description instead, so the information survives even though
  // the two rows and the `saropaLints.setLane` QuickPick click target do not.
  it('Lints Config row carries tier and lane in its description', () => {
    sinon.stub(laneConfig, 'readRawLaneFromCustomConfig').returns('full');
    setTestConfig('saropaLints', 'tier', 'comprehensive');
    // Re-create providers so buildEditorDashboardItems reads the stubbed
    // config/lane values set above (the beforeEach instance predates them).
    providers = createSidebarSectionProviders(memento, configProvider);
    const editor = providers.find((p) => p.viewId === SECTION_VIEW_IDS.editorDashboards)!;
    const items = editor.getChildren().map((n) => editor.getTreeItem(n as never));
    const lintsConfig = items.find((i) => i.label === 'Lints Config');
    assert.ok(lintsConfig, 'Lints Config row must exist');
    const description = String(lintsConfig?.description ?? '');
    assert.ok(description.includes('comprehensive'), `description "${description}" must include the tier`);
    assert.ok(description.includes('full'), `description "${description}" must include the lane`);
  });

  it('no sidebar row reaches saropaLints.setLane — Lane is a Config file tab card and a Lints Config description now', () => {
    for (const provider of providers) {
      const items = (provider.getChildren() as Array<unknown>).map((n) => provider.getTreeItem(n as never));
      assert.ok(
        !items.some((i) => i.command?.command === 'saropaLints.setLane'),
        `${provider.viewId} must not have a row bound to saropaLints.setLane any more`,
      );
    }
  });

  it('Command Catalog is reachable from the Settings panel, not Dashboards', () => {
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const items = settings.getChildren().map((n) => settings.getTreeItem(n as never));
    assert.ok(
      items.some((i) => i.command?.command === 'saropaLints.showCommandCatalog'),
      'Command Catalog must be reachable from the Settings/Quick Actions rows',
    );
  });

  it('stale-ignore rows collapse to one merged find-and-fix row', () => {
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const items = settings.getChildren().map((n) => settings.getTreeItem(n as never));
    assert.ok(
      !items.some((i) => i.command?.command === 'saropaLints.findStaleIgnores'),
      'the standalone Find row must be gone from the sidebar',
    );
    assert.ok(
      items.some((i) => i.command?.command === 'saropaLints.findAndFixStaleIgnores'),
      'the merged find-and-fix row must be present',
    );
  });

  it('Settings panel diagnostics no longer duplicate Lint integration / Process health', () => {
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const items = settings.getChildren().map((n) => settings.getTreeItem(n as never));
    assert.ok(
      !items.some((i) => i.command?.command === 'saropaLints.enable' || i.command?.command === 'saropaLints.disable'),
      'Lint integration now lives only in the Status section',
    );
    assert.ok(
      !items.some((i) => i.command?.command === 'saropaLints.showProcessHealth'),
      'Process health is now reachable only via the Status section\'s Engines row',
    );
  });

  it('Help commands are reachable from the Dashboards view "..." overflow menu', () => {
    interface MenusShape { 'view/title': Array<{ command: string; when?: string }> }
    const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8')) as { contributes: { menus: MenusShape } };
    const dashboardsMenuCommands = pkg.contributes.menus['view/title']
      .filter((m) => m.when?.includes('view == saropaLints.editorDashboards'))
      .map((m) => m.command);
    for (const cmd of [
      'saropaLints.openWalkthrough',
      'saropaLints.showAbout',
      'saropaLints.openPubDevSaropaLints',
      'saropaLints.createSaropaInstructions',
    ]) {
      assert.ok(dashboardsMenuCommands.includes(cmd), `${cmd} missing from Dashboards view/title menu`);
    }
  });

  // 2026-09-04 sidebar row collapse (WP1): severity toggles were CUT from
  // Settings — they duplicate boolean controls on the Rules & Tiers
  // Automation tab (`severity.error|warning|info|hint`, same config keys,
  // same behavior). Only the palette commands (`saropaLints.toggleSeverity*`)
  // remain; the sidebar row and its `SeverityToggleItem` class are gone.
  it('Settings section carries no severity toggles — they live on the Rules & Tiers Automation tab', () => {
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const items = (settings.getChildren() as Array<unknown>).map((n) => settings.getTreeItem(n as never));
    const toggles = items.filter((item) => item.contextValue === 'severityToggle');
    assert.strictEqual(toggles.length, 0, 'severity toggles must not render in Settings any more');
    assert.ok(
      !items.some((i) => /^saropaLints\.toggleSeverity/.test(i.command?.command ?? '')),
      'no toggleSeverity* command should be reachable from a Settings row',
    );
  });

  // Setting-value rows (run-after-config/dependency toggles, UI language,
  // detected packages) were CUT in the same change: run-after-* and UI
  // language now render on the Rules & Tiers Automation/Extension tabs;
  // "Detected" duplicated the Package Dashboard's dependency list.
  it('Settings section carries no setting-value rows', () => {
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const items = (settings.getChildren() as Array<unknown>).map((n) => settings.getTreeItem(n as never));
    const removedCommands = [
      'saropaLints.toggleRunAnalysisAfterConfigChange',
      'saropaLints.toggleRunAnalysisAfterDependencyChange',
      'saropaLints.pickUiLanguage',
      'saropaLints.openPubspec',
    ];
    for (const cmd of removedCommands) {
      assert.ok(
        !items.some((i) => i.command?.command === cmd),
        `${cmd} must not be a Settings row any more`,
      );
    }
  });

  // Triage rows (volume groups, critical group, zero-issue/override counts,
  // stylistic group) were CUT: they duplicated the Findings Dashboard's
  // top-rules triage table and Errors KPI card.
  it('Settings section carries no triage rows', () => {
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const rows = settings.getChildren() as Array<{ kind?: unknown }>;
    assert.ok(
      !rows.some((n) => typeof n.kind === 'string' && n.kind.startsWith('triage')),
      'no triage-kind node should render inside the Settings panel',
    );
  });

  // The Migrate row is a one-shot action: it should only appear while legacy
  // plugin-block config keys remain to be moved (see buildActionNodes'
  // dry-run probe in configTree.ts). Two cases: absent by default (stubbed
  // via beforeEach), present when the probe reports moved keys.
  it('Migrate row is absent when no legacy keys exist', () => {
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const items = (settings.getChildren() as Array<unknown>).map((n) => settings.getTreeItem(n as never));
    assert.ok(
      !items.some((i) => i.command?.command === 'saropaLints.migrateConfig'),
      'Migrate row must not render when the dry-run probe finds nothing to move',
    );
  });

  it('Migrate row is present when legacy keys need moving', () => {
    (migrateConfig.migrateConfigKeys as sinon.SinonStub).returns({ moved: ['max_issues'], skipped: [] });
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const items = (settings.getChildren() as Array<unknown>).map((n) => settings.getTreeItem(n as never));
    assert.ok(
      items.some((i) => i.command?.command === 'saropaLints.migrateConfig'),
      'Migrate row must render when the dry-run probe finds legacy keys to move',
    );
  });

  // Skipped-only state: keys already exist in the custom file but their
  // legacy copies still sit in the plugins block causing unsupported_option
  // warnings. The non-dry-run migration cleans those up (migrateConfig.ts
  // line 128-130), so the row must appear to give the user a path to it.
  it('Migrate row is present when legacy keys are skipped (already in custom file)', () => {
    (migrateConfig.migrateConfigKeys as sinon.SinonStub).returns({ moved: [], skipped: ['log_level'] });
    const settings = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    const items = (settings.getChildren() as Array<unknown>).map((n) => settings.getTreeItem(n as never));
    assert.ok(
      items.some((i) => i.command?.command === 'saropaLints.migrateConfig'),
      'Migrate row must render when skipped-only legacy keys remain in the plugins block',
    );
  });

  // Pin removal of the composite analyzer plugin scaffold row.
  // The action targets a tiny audience (teams shipping their own custom
  // analyzer rules) and the term is jargon for the typical Saropa user.
  // It must remain reachable only via the command palette, the command
  // catalog, the CLI flag, and the guide — never as a sidebar row.
  // Asserting on the command id (not the label) keeps the guard robust
  // against future copy edits.
  it('Settings section does not surface the composite analyzer plugin scaffold', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    for (const node of actions.getChildren()) {
      const item = actions.getTreeItem(node as never);
      assert.notStrictEqual(
        item.command?.command,
        'saropaLints.emitCompositePluginScaffold',
        'composite scaffold must not be a sidebar row — keep it in the command palette',
      );
    }
  });

  // The findings dashboard is reachable from the Dashboards section
  // ("Findings Dashboard" → openViolationsWideReport). A second row in the
  // merged Settings panel that opened the same dashboard was redundant, so it
  // was removed. Pin its absence so a future copy edit does not reintroduce the
  // duplicate.
  it('Settings section does not duplicate the findings dashboard', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.settings)!;
    for (const node of actions.getChildren()) {
      const item = actions.getTreeItem(node as never);
      assert.notStrictEqual(
        item.command?.command,
        'saropaLints.revealFindingsDashboard',
        'findings dashboard is already in the Dashboards section — no Actions-panel duplicate',
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
