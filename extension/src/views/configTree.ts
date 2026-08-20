/**
 * Tree data provider for Saropa Lints Triage view.
 * Shows current settings, detected platform/packages, triage groups, and actions.
 *
 * I1: The triage section shows rules grouped by priority (critical, volume A–D,
 * stylistic) so users can see which rules produce the most violations and
 * navigate to them in the Violations view.
 */

import * as vscode from 'vscode';
import { readPubspec } from '../pubspecReader';
import { getProjectRoot } from '../projectRoot';
import { formatLanguageChoiceLabel } from '../i18n/languagePick';
import { l10n } from '../i18n/runtime';
import { getPluginsIntegrationState } from '../setup';
import { readRawLaneFromAnalysisOptionsYaml } from '../config/laneConfig';
import { getViolationsTriageState, readViolations } from '../violationsReader';
import {
  type ConfigTreeNode,
  type ConfigSettingNode,
  type TriageData,
  type TriageGroupNode,
  buildTriageData,
  getTriageGroupChildren,
  renderTreeItem,
} from './triageTree';

function setting(label: string, description?: string, commandId?: string): ConfigSettingNode {
  return { kind: 'configSetting', label, description, commandId };
}

export class ConfigTreeProvider implements vscode.TreeDataProvider<ConfigTreeNode> {
  private _onDidChangeTreeData = new vscode.EventEmitter<ConfigTreeNode | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  // Cached per refresh so expanding groups reuses the same computation.
  private cachedTriage: TriageData | null = null;

  refresh(): void {
    this.cachedTriage = null;
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: ConfigTreeNode): vscode.TreeItem {
    return renderTreeItem(element);
  }

  getChildren(element?: ConfigTreeNode): ConfigTreeNode[] {
    // Child level: expand triage groups to show individual rules.
    if (element?.kind === 'triageGroup') {
      const issuesByRule = this.cachedTriage?.issuesByRule ?? {};
      return getTriageGroupChildren(element as TriageGroupNode, issuesByRule);
    }
    if (element) return []; // Other nodes have no children.

    // Root level — keep this view focused on triage, while full configuration lives in web dashboards.
    return [...this.buildDashboardShortcutNodes(), ...this.buildTriageSection()];
  }

  /** Settings + action nodes (no triage). Used by the overview "Settings" section. */
  getSettingAndActionNodes(): ConfigTreeNode[] {
    return [...this.buildSettingNodes(), ...this.buildActionNodes()];
  }

  /**
   * Lint integration, Analyzer plugin, and Tier nodes — the 3 core
   * diagnostic-control settings now displayed in the Diagnostics sidebar
   * section alongside severity toggles.
   */
  getDiagnosticControlNodes(): ConfigTreeNode[] {
    return this.buildDiagnosticControlNodes();
  }

  /** Triage nodes only (groups + info). Used by the overview "Issues" section. */
  getTriageNodes(): ConfigTreeNode[] {
    return this.buildTriageSection();
  }

  /**
   * Row reporting the `plugins:` block's real on-disk state.
   *
   * Clicking it offers "Re-enable Plugin" when the block is commented out —
   * previously the only route back was a command-palette entry a user had no
   * reason to look for. Omitted entirely when there is no project root, since
   * there is no analysis_options.yaml to describe.
   *
   * Every state maps to a real command: this view's invariant is that no row
   * is dead (see the "every leaf has a click command" assertion in
   * test/views/overviewTreeFlat.test.ts, and the dead "Lints" row removed
   * next to it). A live plugin offers the liveness probe — the useful question
   * about a plugin that claims to be on is whether it is actually reporting.
   */
  private buildAnalyzerPluginNode(): ConfigTreeNode[] {
    const root = getProjectRoot();
    if (!root) return [];
    const state = getPluginsIntegrationState(root);
    const byState = {
      live: {
        description: l10n('dashboards.controls.analyzerPluginLive'),
        command: 'saropaLints.verifyPlugin',
      },
      disabled: {
        description: l10n('dashboards.controls.analyzerPluginDisabled'),
        command: 'saropaLints.reenablePlugin',
      },
      absent: {
        description: l10n('dashboards.controls.analyzerPluginAbsent'),
        command: 'saropaLints.initializeConfig',
      },
    }[state];
    return [setting(l10n('dashboards.controls.analyzerPlugin'), byState.description, byState.command)];
  }

  /**
   * Lint integration, Analyzer plugin, and Tier — the 3 core diagnostic
   * controls now surfaced in the Diagnostics sidebar section.
   */
  private buildDiagnosticControlNodes(): ConfigTreeNode[] {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const enabled = cfg.get<boolean>('enabled', true) ?? true;
    const tier = cfg.get<string>('tier', 'recommended') ?? 'recommended';
    const root = getProjectRoot();
    return [
      setting('Lint integration', enabled ? 'On' : 'Off', enabled ? 'saropaLints.disable' : 'saropaLints.enable'),
      // The in-process analyzer plugin is a SEPARATE subsystem from the row
      // above: "Lint integration" gates scan-on-save delivery, this gates the
      // plugins: block the Dart analysis server reads for live in-editor
      // squiggles. Reporting only the first one made the sidebar claim
      // "Lint integration: On" over an analysis_options.yaml whose plugins
      // block was commented out, which reads as the extension lying.
      ...this.buildAnalyzerPluginNode(),
      // Tier click → Lints Config dashboard. The dashboard's tier control is a
      // visual segmented radio (Essential → Pedantic) with rule counts and
      // descriptions per tier — far richer than the bare quickpick the row
      // used to launch (`saropaLints.setTier`). Users get the full context of
      // each option instead of guessing from a one-line label.
      setting('Tier', tier, 'saropaLints.openConfigDashboard'),
      // Lane click → the light/full QuickPick (`saropaLints.setLane`), not the
      // dashboard: unlike Tier's 5-way segmented control, this is a plain
      // binary switch with no rule list to browse, so a QuickPick with two
      // detailed items is the right amount of UI — same reasoning that used to
      // apply to Tier before it grew a dedicated dashboard section.
      ...this.buildLaneNode(root),
    ];
  }

  /**
   * Row reporting the configured analysis lane (`plugins.saropa_lints.lane`
   * in analysis_options.yaml). Omitted with no project root, mirroring
   * {@link buildAnalyzerPluginNode} — there is no yaml to describe.
   */
  private buildLaneNode(root: string | undefined): ConfigTreeNode[] {
    if (!root) return [];
    // Absent/unrecognized reads as 'light' — matches the Dart-side default
    // (RuleLane.light) so the sidebar agrees with what the in-process plugin
    // is actually doing when the key was never written.
    const raw = readRawLaneFromAnalysisOptionsYaml(root);
    const lane = raw === 'full' ? 'full' : 'light';
    const description =
      lane === 'full' ? l10n('dashboards.controls.laneFull') : l10n('dashboards.controls.laneLight');
    return [setting(l10n('dashboards.controls.lane'), description, 'saropaLints.setLane')];
  }

  /** Run-after-config, UI language, detected packages. */
  private buildSettingNodes(): ConfigTreeNode[] {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const runAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true) ?? true;
    const runAfterDep = cfg.get<boolean>('runAnalysisAfterDependencyChange', true) ?? true;
    const uiLanguage = cfg.get<string>('uiLanguage', 'auto') ?? 'auto';
    const localeLabel = formatLanguageChoiceLabel(uiLanguage);

    const items: ConfigTreeNode[] = [
      // Each settings row needs a click target — the user expects every visible
      // sidebar item to navigate somewhere. Toggling a boolean in one click
      // beats opening the Settings UI just to flip a checkbox.
      setting('Run analysis after config change', runAfter ? 'Yes' : 'No', 'saropaLints.toggleRunAnalysisAfterConfigChange'),
      setting('Run analysis after dependency change', runAfterDep ? 'Yes' : 'No', 'saropaLints.toggleRunAnalysisAfterDependencyChange'),
      setting('UI language', localeLabel, 'saropaLints.pickUiLanguage'),
    ];

    // Detected platform/packages from pubspec.
    const root = getProjectRoot();
    if (root) {
      const pubspec = readPubspec(root);
      const parts: string[] = [];
      if (pubspec.isFlutter) parts.push('Flutter');
      if (pubspec.packages.length > 0) {
        const pkgs = pubspec.packages.slice(0, 5).join(', ');
        parts.push(pubspec.packages.length > 5 ? pkgs + '…' : pkgs);
      }
      // The Detected row summarizes what's in pubspec.yaml — clicking should
      // open that file so the user can edit it directly.
      if (parts.length > 0) items.push(setting('Detected', parts.join(' · '), 'saropaLints.openPubspec'));
    }

    return items;
  }

  /** Open config, initialize, run analysis. */
  private buildActionNodes(): ConfigTreeNode[] {
    return [
      setting('Open analysis_options_custom.yaml', undefined, 'saropaLints.openConfig'),
      setting('Initialize / Update config', undefined, 'saropaLints.initializeConfig'),
      // Composite analyzer plugin scaffold is intentionally NOT exposed here.
      // The action targets a tiny audience (teams shipping their own custom
      // analyzer rules alongside Saropa) and the term is jargon to everyone
      // else. It remains discoverable via the command palette
      // (`Saropa Lints: Create Composite Analyzer Plugin (scaffold)`),
      // `Saropa Lints: Show All Commands`, the CLI
      // (`dart run saropa_lints:init --emit-composite-plugin-scaffold`),
      // and `doc/guides/composite_analyzer_plugin.md`. Keeping it out of the
      // sidebar avoids confusing the 99% of users who only want Saropa rules.
      setting('Run analysis', undefined, 'saropaLints.runAnalysis'),
    ];
  }

  /** Quick links to the richer web dashboards. */
  private buildDashboardShortcutNodes(): ConfigTreeNode[] {
    return [
      setting('Open Lints Config', 'Editor tab: tiers, packs, charts, docs', 'saropaLints.openConfigDashboard'),
      setting('Open Package Vibrancy', 'Dependency health and reports', 'saropaLints.openPackageVibrancy'),
    ];
  }

  /** I1: Triage groups — only when violations data with issuesByRule is available. */
  private buildTriageSection(): ConfigTreeNode[] {
    const root = getProjectRoot();
    if (!root) return [];

    const data = readViolations(root);
    const { triage: tri } = getViolationsTriageState(root, data);

    if (tri.kind === 'missing' || (tri.kind === 'incomplete' && tri.reason === 'unreadable')) {
      this.cachedTriage = null;
      return this.buildTriageGuardNodes(
        'Run Saropa Lints analysis first',
        'No violations.json yet, or the file is unreadable. Triage needs a current export.',
        false,
      );
    }
    if (tri.kind === 'stale') {
      this.cachedTriage = null;
      return this.buildTriageGuardNodes(
        'Triage data may be outdated',
        `Run analysis to refresh. Export is ${this.formatAge(tri.ageMs)} old.`,
        true,
      );
    }
    if (tri.kind === 'incomplete' && tri.reason === 'no_per_rule') {
      this.cachedTriage = null;
      return this.buildTriageGuardNodes(
        'Re-run analysis for full triage export',
        'This violations.json is missing per-rule summary (issuesByRule). Triage is disabled until you re-analyze with a current plugin.',
        true,
      );
    }
    if (!data) {
      this.cachedTriage = null;
      return [];
    }

    this.cachedTriage = buildTriageData(data, root);
    if (!this.cachedTriage) {
      this.cachedTriage = null;
      return this.buildTriageGuardNodes(
        'Re-run analysis for full triage export',
        'Could not build triage from this export. Run a fresh Saropa Lints analysis.',
        true,
      );
    }

    return this.buildTriageNodes(this.cachedTriage);
  }

  private formatAge(ageMs: number): string {
    const h = Math.floor(ageMs / (60 * 60 * 1000));
    if (h >= 24) return `${Math.floor(h / 24)}d`;
    if (h > 0) return `${h}h`;
    const m = Math.floor(ageMs / (60 * 1000));
    return `${m}m`;
  }

  /** Blocked state: triage should not use stale or incomplete exports. */
  private buildTriageGuardNodes(label: string, description: string, warning: boolean): ConfigTreeNode[] {
    return [
      {
        kind: 'triageInfo' as const,
        label,
        description,
        triageInfoVariant: warning ? 'warning' : 'default',
        commandId: 'saropaLints.runAnalysis',
      },
    ];
  }

  /** Build the flat list of triage group nodes for the root level. */
  private buildTriageNodes(triage: TriageData): ConfigTreeNode[] {
    const nodes: ConfigTreeNode[] = [];
    if (triage.criticalGroup) nodes.push(triage.criticalGroup);
    nodes.push(...triage.volumeGroups);
    if (triage.zeroIssueCount > 0) {
      nodes.push({
        kind: 'triageInfo',
        label: `${triage.zeroIssueCount} rules with zero issues`,
        description: 'auto-enabled',
        // Clickable: jump to the Lints Config dashboard, which lists every
        // enabled rule (including the ones with zero current violations).
        commandId: 'saropaLints.openConfigDashboard',
      });
    }
    // I2: Show count of rules explicitly disabled by user overrides.
    if (triage.disabledOverrideCount > 0) {
      nodes.push({
        kind: 'triageInfo',
        label: `${triage.disabledOverrideCount} rules disabled by override`,
        // Click → Lints Config dashboard. The dashboard now has a "Disabled
        // rules" section listing each one with a re-enable button. The raw
        // analysis_options_custom.yaml file carries a "do not edit manually"
        // banner, so sending users there directly is the wrong UX — the
        // dashboard is the canonical management surface.
        commandId: 'saropaLints.openConfigDashboard',
      });
    }
    if (triage.stylisticGroup) nodes.push(triage.stylisticGroup);
    return nodes;
  }
}
