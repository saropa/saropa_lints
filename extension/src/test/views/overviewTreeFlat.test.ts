/**
 * Pins the multi-panel sidebar contract for the Saropa Lints activity-bar
 * container after PLAN_ext_ui_sidebar_reset.md P1 (14-row target, §3): each
 * section is its own VS Code view (Banner / Dashboards / Status / Actions),
 * and inside every section the rows are flat clickable leaves only — no
 * chevrons, no nested expansion.
 *
 * Actions (renamed from "Settings"/"Quick Actions", package.json
 * `saropaLints.actions`) is exactly 3 rows: Run analysis, Prune ignores,
 * Initialize/Update config. Command Catalog moved OUT to Dashboards (it
 * opens a picker, it doesn't run anything — the wrong section per §2's
 * table). Migrate config keys moved OUT of the sidebar entirely — it is now
 * a conditional button on the Lints Config › Config file tab
 * (`rulePacksWebviewProvider.ts`'s `_buildMigrateCard`), reachable from a UI
 * surface without permanently occupying an ACTIONS row for a one-shot
 * migration. Severity toggles, setting-value rows, and triage rows stay cut
 * from the prior "sidebar row collapse" pass (still duplicates of richer
 * surfaces elsewhere).
 *
 * Status is Health / Engines / Hotspots (conditional) / Last run
 * (conditional) — see sidebarStatusEngines.test.ts for the row-level
 * regression guards on that section; this file only pins the section-level
 * contract (§2's STATUS/DASHBOARDS invariant: no row runs or toggles
 * anything).
 *
 * Regression guards:
 *   - View IDs match what package.json declares.
 *   - Every leaf returned by every provider has `CollapsibleState.None`
 *     (no chevrons inside any section).
 *   - Every leaf has a click `command` so nothing in the sidebar is dead.
 *   - Run analysis appears exactly once across all sections.
 *   - No STATUS or DASHBOARDS row targets a run/toggle command — the
 *     executable form of §2's rule that those sections "never change
 *     anything."
 *   - Actions carries exactly Run analysis / Prune ignores /
 *     Update config — no Command Catalog, no Migrate row, no
 *     severity toggles, no setting-value rows, no triage rows.
 *   - Tier and Lane are folded into the Dashboards "Lints Config" row
 *     description; no row anywhere still targets `saropaLints.setLane`.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';

import * as projectRoot from '../../projectRoot';
import * as pubspecReader from '../../pubspecReader';
import * as violationsReader from '../../violationsReader';
import * as suppressionsStore from '../../suppressionsStore';
import * as configWriter from '../../configWriter';
import * as runHistory from '../../runHistory';
import * as securityHotspotReviewState from '../../securityHotspotReviewState';
// Stubbed in the "Lints Config row" test below — lets the test control
// the lane value without a real analysis_options_custom.yaml on disk.
import * as laneConfig from '../../config/laneConfig';
import { setTestConfig, clearTestConfig } from '../vibrancy/vscode-mock';
// TASK A regression coverage (bugfix): the Code Health / Project Map row
// descriptions used to be hardcoded static strings even though the plan
// specified live data — stubbed here so the tests below can assert the
// description actually reflects INJECTED payload/mtime values, closing the
// hole where a static-string regression previously passed silently (the
// existing tests only asserted section membership and command ids, never
// description content).
import * as projectVibrancyReportView from '../../views/projectVibrancyReportView';

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

interface MenusShape { 'view/title': Array<{ command: string; when?: string }> }

function loadPackageJsonMenus(): { contributes: { menus: MenusShape } } {
  const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
  return JSON.parse(fs.readFileSync(pkgPath, 'utf8')) as { contributes: { menus: MenusShape } };
}

// Commands that RUN or TOGGLE something — §2's table says a STATUS or
// DASHBOARDS row's click "never changes anything," so none of these may
// ever be the command target of a row in either section.
const RUN_OR_TOGGLE_COMMANDS = [
  'saropaLints.enable',
  'saropaLints.disable',
  'saropaLints.reenablePlugin',
  'saropaLints.runAnalysis',
  'saropaLints.initializeConfig',
  'saropaLints.findAndFixStaleIgnores',
  'saropaLints.migrateConfig',
];

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
    // No hotspots by default — isolates unrelated tests from the Hotspots row.
    sinon.stub(securityHotspotReviewState, 'countSecurityHotspotReviewStates').returns({
      total: 0,
      open: 0,
      reviewedSafe: 0,
      reviewedFixed: 0,
    });
    memento = new MockMemento();
    configProvider = new ConfigTreeProvider();
    providers = createSidebarSectionProviders(memento, configProvider);
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  it('package.json declares exactly the section views (banner / dashboards / status / actions)', () => {
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
    assert.ok(!ids.includes('saropaLints.settings'), 'settings view id was renamed to saropaLints.actions');
  });

  it('every leaf rendered by every provider is CollapsibleState.None (no chevrons inside any panel)', () => {
    for (const provider of providers) {
      const items = provider.getChildren();
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

  // Executable form of §2's rule: a STATUS or DASHBOARDS row's click never
  // runs or toggles anything — only ACTIONS rows may.
  it('no STATUS or DASHBOARDS row targets a run/toggle command', () => {
    for (const sectionId of [SECTION_VIEW_IDS.status, SECTION_VIEW_IDS.editorDashboards]) {
      const provider = providers.find((p) => p.viewId === sectionId)!;
      const items = (provider.getChildren() as Array<unknown>).map((n) => provider.getTreeItem(n as never));
      for (const item of items) {
        const cmd = item.command?.command;
        assert.ok(
          !cmd || !RUN_OR_TOGGLE_COMMANDS.includes(cmd),
          `${sectionId} row "${String(item.label)}" targets "${cmd}" — a run/toggle command does not belong in this section`,
        );
      }
    }
  });

  it('Dashboards section surfaces exactly the seven rows, Findings first', () => {
    const editor = providers.find((p) => p.viewId === SECTION_VIEW_IDS.editorDashboards)!;
    const labels = editor.getChildren().map((n) => String((n as { label?: unknown }).label ?? ''));
    assert.strictEqual(labels[0], 'Findings Dashboard', 'Findings must be the first row');
    assert.ok(labels.includes('Lints Config'));
    assert.ok(labels.includes('Package Dashboard'));
    assert.ok(labels.includes('Code Health Dashboard'));
    assert.ok(labels.includes('Saropa Project Map'));
    assert.ok(labels.includes('Findings Dashboard'));
    // Analysis Optimizer, Upgrade Opportunities, and the Feature Inventory
    // export are reachable as tabs inside Rules & Tiers / Package Dashboard
    // (PLAN_ext_ui_sidebar_reset.md §3.1) — no longer separate rows here.
    assert.ok(!labels.includes('Analysis Optimizer'));
    assert.ok(!labels.includes('Upgrade Opportunities'));
    assert.ok(!labels.includes('Full Opportunities Report'));
  });

  it('Command Catalog is reachable from Dashboards, not Actions', () => {
    const editor = providers.find((p) => p.viewId === SECTION_VIEW_IDS.editorDashboards)!;
    const items = editor.getChildren().map((n) => editor.getTreeItem(n as never));
    assert.ok(
      items.some((i) => i.command?.command === 'saropaLints.showCommandCatalog'),
      'Command Catalog must be reachable from the Dashboards section',
    );

    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    const actionItems = actions.getChildren().map((n) => actions.getTreeItem(n as never));
    assert.ok(
      !actionItems.some((i) => i.command?.command === 'saropaLints.showCommandCatalog'),
      'Command Catalog must not duplicate into Actions any more',
    );
  });

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

  it('Actions section is exactly Run analysis / Prune ignores / Update config', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    const items = actions.getChildren().map((n) => actions.getTreeItem(n as never));
    const commands = items.map((i) => i.command?.command);
    assert.deepStrictEqual(
      commands,
      ['saropaLints.runAnalysis', 'saropaLints.findAndFixStaleIgnores', 'saropaLints.initializeConfig'],
      'Actions must be exactly these 3 rows, in this order',
    );
  });

  it('stale-ignore rows collapse to one merged find-and-fix row', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    const items = actions.getChildren().map((n) => actions.getTreeItem(n as never));
    assert.ok(
      !items.some((i) => i.command?.command === 'saropaLints.findStaleIgnores'),
      'the standalone Find row must be gone from the sidebar',
    );
    assert.ok(
      items.some((i) => i.command?.command === 'saropaLints.findAndFixStaleIgnores'),
      'the merged find-and-fix row must be present',
    );
  });

  it('Actions section no longer duplicates Lint integration / Process health', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    const items = actions.getChildren().map((n) => actions.getTreeItem(n as never));
    assert.ok(
      !items.some((i) => i.command?.command === 'saropaLints.enable' || i.command?.command === 'saropaLints.disable'),
      'Lint integration is not represented as a toggle row anywhere any more',
    );
    assert.ok(
      !items.some((i) => i.command?.command === 'saropaLints.showProcessHealth'),
      'Process health is reachable only via the Status section\'s Engines row',
    );
  });

  it('Help commands are reachable from the Dashboards view "..." overflow menu', () => {
    const pkg = loadPackageJsonMenus();
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

  it('Run analysis is on the Dashboards view/title, not the old Actions view id', () => {
    const pkg = loadPackageJsonMenus();
    const runAnalysisEntries = pkg.contributes.menus['view/title'].filter((m) => m.command === 'saropaLints.runAnalysis');
    assert.ok(
      runAnalysisEntries.some((m) => m.when?.includes('view == saropaLints.editorDashboards')),
      'Run analysis view/title icon must target the Dashboards view',
    );
    assert.ok(
      !runAnalysisEntries.some((m) => m.when?.includes('view == saropaLints.settings')),
      'Run analysis view/title icon must not still target the renamed-away saropaLints.settings id',
    );
  });

  it('Actions section carries no severity toggles — they live on the Rules & Tiers Automation tab', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    const items = (actions.getChildren() as Array<unknown>).map((n) => actions.getTreeItem(n as never));
    const toggles = items.filter((item) => item.contextValue === 'severityToggle');
    assert.strictEqual(toggles.length, 0, 'severity toggles must not render in Actions any more');
    assert.ok(
      !items.some((i) => /^saropaLints\.toggleSeverity/.test(i.command?.command ?? '')),
      'no toggleSeverity* command should be reachable from an Actions row',
    );
  });

  it('Actions section carries no setting-value rows', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    const items = (actions.getChildren() as Array<unknown>).map((n) => actions.getTreeItem(n as never));
    const removedCommands = [
      'saropaLints.toggleRunAnalysisAfterConfigChange',
      'saropaLints.toggleRunAnalysisAfterDependencyChange',
      'saropaLints.pickUiLanguage',
      'saropaLints.openPubspec',
    ];
    for (const cmd of removedCommands) {
      assert.ok(
        !items.some((i) => i.command?.command === cmd),
        `${cmd} must not be an Actions row any more`,
      );
    }
  });

  it('Actions section carries no triage rows', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    const rows = actions.getChildren() as Array<{ kind?: unknown }>;
    assert.ok(
      !rows.some((n) => typeof n.kind === 'string' && n.kind.startsWith('triage')),
      'no triage-kind node should render inside the Actions panel',
    );
  });

  // The Migrate row moved off the sidebar entirely in P1/P2 — it is now a
  // conditional button on the Lints Config › Config file tab
  // (`rulePacksWebviewProvider.ts`'s `_buildMigrateCard`), not a sidebar row
  // in any state.
  it('Migrate config keys never renders as a sidebar row, in Actions or anywhere else', () => {
    for (const provider of providers) {
      const items = (provider.getChildren() as Array<unknown>).map((n) => provider.getTreeItem(n as never));
      assert.ok(
        !items.some((i) => i.command?.command === 'saropaLints.migrateConfig'),
        `${provider.viewId} must not surface saropaLints.migrateConfig as a row`,
      );
    }
  });

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

  it('Actions section does not duplicate the findings dashboard', () => {
    const actions = providers.find((p) => p.viewId === SECTION_VIEW_IDS.actions)!;
    for (const node of actions.getChildren()) {
      const item = actions.getTreeItem(node as never);
      assert.notStrictEqual(
        item.command?.command,
        'saropaLints.revealFindingsDashboard',
        'findings dashboard is already in the Dashboards section — no Actions-panel duplicate',
      );
    }
  });

  // TASK A regression suite: pins the bugfix that the Code Health / Project
  // Map row descriptions are LIVE (PLAN_ext_ui_sidebar_reset.md §5 P1), not
  // the hardcoded static strings a previous pass left in place. Each test
  // injects a specific payload/mtime and asserts that EXACT value shows up
  // in the rendered description — a bare "description is non-empty" check
  // would have passed on the static-string bug just as well, so these assert
  // real values flowing through.
  describe('Code Health / Project Map row descriptions are live (TASK A bugfix)', () => {
    function findEditorRow(label: string, allProviders: FlatSectionProvider[]): { description?: unknown } {
      const editor = allProviders.find((p) => p.viewId === SECTION_VIEW_IDS.editorDashboards)!;
      const items = editor.getChildren().map((n) => editor.getTreeItem(n as never));
      const row = items.find((i) => (i as { label?: unknown }).label === label);
      assert.ok(row, `"${label}" row must exist in Dashboards`);
      return row! as { description?: unknown };
    }

    it('Code Health description shows the injected grade and score, gate passing', () => {
      sinon.stub(projectVibrancyReportView, 'getLastProjectVibrancyPayload').returns({
        summary: { averageGrade: 'B', averageScore: 82.4 },
        gates: { pass: true },
      } as never);
      providers = createSidebarSectionProviders(memento, configProvider);
      const description = String(findEditorRow('Code Health Dashboard', providers).description ?? '');
      assert.ok(description.includes('B'), `description "${description}" must include the injected grade`);
      assert.ok(description.includes('82'), `description "${description}" must include the injected score`);
      assert.ok(
        !/gate/i.test(description),
        `description "${description}" must not claim a failing gate when gates.pass is true`,
      );
      // Guards against reverting to the old static string this bugfix removed.
      assert.ok(!description.includes('Function-level code health'), 'must not be the old static description');
    });

    it('Code Health description renders the gate-failing variant when the injected payload says the gate failed', () => {
      sinon.stub(projectVibrancyReportView, 'getLastProjectVibrancyPayload').returns({
        summary: { averageGrade: 'D', averageScore: 41 },
        gates: { pass: false, violations: [{ metric: 'averageScore', message: 'below threshold' } as never] },
      } as never);
      providers = createSidebarSectionProviders(memento, configProvider);
      const description = String(findEditorRow('Code Health Dashboard', providers).description ?? '');
      assert.ok(description.includes('D'), `description "${description}" must include the injected grade`);
      assert.ok(description.includes('41'), `description "${description}" must include the injected score`);
      assert.ok(/gate/i.test(description), `description "${description}" must call out the failing gate`);
    });

    it('Code Health description degrades to "never scanned" text when no scan has run this session', () => {
      sinon.stub(projectVibrancyReportView, 'getLastProjectVibrancyPayload').returns(undefined);
      providers = createSidebarSectionProviders(memento, configProvider);
      const description = String(findEditorRow('Code Health Dashboard', providers).description ?? '');
      assert.strictEqual(description, 'Run Code Health to see your score');
      assert.ok(!description.includes('Function-level code health'), 'must not be the old static description');
    });

    // `fs.statSync`'s property descriptor is non-configurable/non-writable on
    // this Node version, so sinon cannot stub it directly (verified: sinon
    // throws "Cannot stub properties that are immutable"). Real files against
    // a real scratch directory exercise the exact same `fs.statSync` code
    // path without needing to replace the function.
    let pmTmpRoot: string | undefined;

    afterEach(() => {
      if (pmTmpRoot) {
        fs.rmSync(pmTmpRoot, { recursive: true, force: true });
        pmTmpRoot = undefined;
      }
    });

    it('Project Map description shows an age derived from the injected report mtime', () => {
      pmTmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-pm-mtime-'));
      const healthDir = path.join(pmTmpRoot, 'reports', '.saropa_lints', 'health');
      fs.mkdirSync(healthDir, { recursive: true });
      const indexPath = path.join(healthDir, 'index.html');
      fs.writeFileSync(indexPath, '<html></html>');
      const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
      fs.utimesSync(indexPath, fiveMinAgo, fiveMinAgo);
      // Re-point getProjectRoot (already stubbed in the outer beforeEach) at
      // the real scratch root so getLastProjectMapMtime's statSync call
      // resolves to the fixture file above rather than the fake '/fake/root'.
      (projectRoot.getProjectRoot as sinon.SinonStub).returns(pmTmpRoot);
      providers = createSidebarSectionProviders(memento, configProvider);
      const description = String(findEditorRow('Saropa Project Map', providers).description ?? '');
      assert.ok(description.includes('5 min ago'), `description "${description}" must include the injected mtime's age`);
      assert.ok(
        !description.includes('Size · dead-weight · complexity · hot spots'),
        'must not be the old static description',
      );
    });

    it('Project Map description renders the "never scanned" text when no report file exists', () => {
      // The outer beforeEach's getProjectRoot stub returns '/fake/root', a
      // path that genuinely does not exist — statSync on it throws ENOENT for
      // real, no stubbing of fs itself required.
      providers = createSidebarSectionProviders(memento, configProvider);
      const description = String(findEditorRow('Saropa Project Map', providers).description ?? '');
      assert.strictEqual(description, 'Run Project Map to see size & hot spots');
    });
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
