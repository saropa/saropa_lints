/**
 * Tree data provider for Saropa Lints Triage view.
 * Shows current settings, detected platform/packages, triage groups, and actions.
 *
 * I1: The triage section shows rules grouped by priority (critical, volume A–D,
 * stylistic) so users can see which rules produce the most violations and
 * navigate to them in the Violations view.
 */

import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
// `readRawLaneFromCustomConfig` (Lane row reader) was removed here (2026-09-04,
// sidebar row collapse WP2) along with `buildLaneNode`, its only caller — Lane
// is now read in `sectionedSidebar.ts`'s `buildEditorDashboardItems` for the
// folded Lints Config row description, and in `rulePacksWebviewProvider.ts`'s
// `_buildLaneCard` for the Config file tab card. `readPubspec` /
// `formatLanguageChoiceLabel` were removed here (2026-09-04, sidebar row
// collapse WP1) along with buildSettingNodes, their only caller.
// `l10n`, `getPluginsIntegrationState` (from '../setup'), and
// `migrateConfigKeys` (from '../config/migrateConfig') were removed here
// (PLAN_ext_ui_sidebar_reset.md P1/P2): each was used only by
// `buildActionNodes()` / `getAnalyzerPluginWarningNode()`, both deleted
// above — see the comments left in their place. `migrateConfigKeys`'s
// dry-run probe now lives in `rulePacksWebviewProvider.ts`'s Config file tab
// (P2), which imports it directly.
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

function setting(label: string, description?: string, commandId?: string, icon?: string): ConfigSettingNode {
  return { kind: 'configSetting', label, description, commandId, icon };
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

  // `getSettingAndActionNodes()` / `buildActionNodes()` (the sidebar
  // Actions panel's Migrate-config-keys row + the redundant open-config/
  // initialize-config/run-analysis entries `sectionedSidebar.ts` filtered
  // back out) were REMOVED here (PLAN_ext_ui_sidebar_reset.md P1/P2, §3.1
  // row "Migrate config keys"): the row moved off the sidebar entirely — its
  // one-shot job now lives as a button on the Lints Config › Config file tab
  // (`rulePacksWebviewProvider.ts`) plus the command palette
  // (`saropaLints.migrateConfig`), never as a sidebar row. `migrateConfigKeys`
  // stays imported/used by the Config file tab's dry-run probe there, not
  // here any more.

  // `getTriageNodes()` (public wrapper around `buildTriageSection()`) was
  // removed here (2026-09-04, sidebar row collapse WP1): its only caller was
  // the Settings overview section's `triage` spread in sectionedSidebar.ts,
  // which is gone — those rows duplicated the Findings Dashboard's top-rules
  // triage table. `getChildren()` below still calls `buildTriageSection()`
  // directly for the ConfigTreeProvider's own (unregistered) triage view —
  // that data source is intentionally untouched, see
  // plans/PLAN_sidebar_row_collapse.md §5.

  // `getAnalyzerPluginWarningNode()` (formerly reported the `plugins:` block's
  // live/disabled/absent state as a Status row) was REMOVED here
  // (PLAN_ext_ui_sidebar_reset.md P1, §2 STATUS invariant): its click ran
  // `saropaLints.reenablePlugin` / `saropaLints.initializeConfig` directly
  // from a STATUS row — the exact "a STATUS click changes something" bug the
  // reset plan exists to remove. The fact it reported is still visible: it
  // is one of the three engines the Status Engines row already lists
  // (`sectionedSidebar.ts` `appendEnginesRow`, sourced from
  // `HealthPanel.getEngineStatuses()`), and the actual toggle lives on the
  // Health Panel that row opens. NOTE FOR THE USER: this file's doc comment
  // for this method had already been partway rewritten toward "Live
  // analysis" wording (method body/call sites unchanged) when this pass
  // started — evidence of another edit landing on this file concurrently
  // despite it being assigned single-owner in this work package. That
  // rename is superseded by this deletion, not carried forward; flagging in
  // case it was in-flight work from another session that needs to be
  // reconciled elsewhere (e.g. Health Panel engine-card copy).

  // `buildSettingNodes()` (run-after-config/dependency toggles, UI language,
  // detected packages) was removed here (2026-09-04, sidebar row collapse
  // WP1). Each row was a verified duplicate of a richer control: the two
  // "run analysis after X change" toggles and UI language now render as
  // boolean/choice controls on the Rules & Tiers Automation/Extension tabs
  // (`settingsCatalog.ts` already routed them there; only the sidebar copy
  // was cut), and "Detected: <packages>" duplicated the Package Dashboard's
  // full dependency list plus the Extension tab's platforms block. The
  // `toggleRunAnalysisAfterConfigChange` / `toggleRunAnalysisAfterDependencyChange`
  // / `pickUiLanguage` / `openPubspec` commands stay registered for the
  // command palette; only the sidebar rows are gone.

  /** Quick links to the richer web dashboards. */
  private buildDashboardShortcutNodes(): ConfigTreeNode[] {
    return [
      setting('Open Lints Config', 'Editor tab: tiers, packs, charts, docs', 'saropaLints.openConfigDashboard', 'settings-gear'),
      setting('Open Package Vibrancy', 'Dependency health and reports', 'saropaLints.openPackageVibrancy', 'graph'),
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
