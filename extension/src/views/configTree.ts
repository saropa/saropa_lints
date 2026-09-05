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
import { l10n } from '../i18n/runtime';
import { getPluginsIntegrationState } from '../setup';
// `readRawLaneFromCustomConfig` (Lane row reader) was removed here (2026-09-04,
// sidebar row collapse WP2) along with `buildLaneNode`, its only caller — Lane
// is now read in `sectionedSidebar.ts`'s `buildEditorDashboardItems` for the
// folded Lints Config row description, and in `rulePacksWebviewProvider.ts`'s
// `_buildLaneCard` for the Config file tab card.
// Dry-run probe for the conditional Migrate row in buildActionNodes — see
// its doc comment. `readPubspec` / `formatLanguageChoiceLabel` were removed
// here (2026-09-04, sidebar row collapse WP1) along with buildSettingNodes,
// their only caller.
import { migrateConfigKeys } from '../config/migrateConfig';
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

  /**
   * Action nodes for the overview "Settings" (now Quick Actions) section.
   * Was `[...buildSettingNodes(), ...buildActionNodes()]` — `buildSettingNodes`
   * (run-after-config/dependency toggles, UI language, detected packages) was
   * deleted in the 2026-09-04 sidebar row collapse (WP1): every row in it
   * duplicated a richer control elsewhere (Rules & Tiers Automation/Extension
   * tabs, Package Dashboard). Only the action rows remain.
   */
  getSettingAndActionNodes(): ConfigTreeNode[] {
    return this.buildActionNodes();
  }

  // `getTriageNodes()` (public wrapper around `buildTriageSection()`) was
  // removed here (2026-09-04, sidebar row collapse WP1): its only caller was
  // the Settings overview section's `triage` spread in sectionedSidebar.ts,
  // which is gone — those rows duplicated the Findings Dashboard's top-rules
  // triage table. `getChildren()` below still calls `buildTriageSection()`
  // directly for the ConfigTreeProvider's own (unregistered) triage view —
  // that data source is intentionally untouched, see
  // plans/PLAN_sidebar_row_collapse.md §5.

  /**
   * Row reporting the `plugins:` block's real on-disk state — MOVED here from
   * the Settings section to the Status section (2026-09-04, sidebar row
   * collapse WP3). A plugin state is a fact about the project, not a
   * configurable setting, so it belongs with the other Status facts
   * (Health / Engines / Lint integration) rather than in Quick Actions.
   *
   * Renamed from the former private `buildAnalyzerPluginNode` to a public
   * `getAnalyzerPluginWarningNode` because `sectionedSidebar.ts`'s
   * `buildStatusItems` now calls it directly — the analyzer plugin no longer
   * has a home in `buildDiagnosticControlNodes` / `getDiagnosticControlNodes`
   * (both deleted here, WP3; they existed only to wrap this single call
   * after Tier/Lane moved out in WP2).
   *
   * Returns `[]` for the `live` state: a plugin that is live and reporting is
   * not a warning — it is the expected state, already implied by the Status
   * section's Engines row when debug mode is on. The `live` → verifyPlugin
   * liveness probe is NOT deleted; it stays reachable via Command Catalog and
   * the Health Panel for the case where a user wants to double-check a
   * plugin that claims to be on. Only `disabled` (re-enable) and `absent`
   * (initialize config) render a row here — both are actionable warnings,
   * hence "warning" in the method name and the `list.warningForeground`
   * color applied at the call site in `sectionedSidebar.ts`.
   *
   * Omitted entirely when there is no project root, since there is no
   * analysis_options.yaml to describe.
   */
  getAnalyzerPluginWarningNode(): ConfigTreeNode[] {
    const root = getProjectRoot();
    if (!root) return [];
    const state = getPluginsIntegrationState(root);
    // Live: nothing to warn about — the probe command stays reachable
    // elsewhere (Command Catalog / Health Panel), not as a sidebar row.
    if (state === 'live') return [];
    const byState = {
      disabled: {
        description: l10n('dashboards.controls.analyzerPluginDisabled'),
        command: 'saropaLints.reenablePlugin',
      },
      absent: {
        description: l10n('dashboards.controls.analyzerPluginAbsent'),
        command: 'saropaLints.initializeConfig',
      },
    }[state];
    return [setting(l10n('dashboards.controls.analyzerPlugin'), byState.description, byState.command, 'plug')];
  }

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

  /**
   * Open config, initialize, run analysis, plus a conditional Migrate row.
   *
   * The Migrate row is conditional (unlike the other actions): it runs the
   * migration in dry-run mode first (`migrateConfigKeys(root, { dryRun: true })`)
   * and only renders when there are legacy plugin-block keys left to move.
   * This is a one-shot migration (legacy `plugins > saropa_lints:` keys →
   * top-level `analysis_options_custom.yaml` keys) — once a project has
   * migrated, the row has nothing to do and would sit dead in the sidebar
   * forever if shown unconditionally. Steady state after migration: 0 rows
   * for this action, matching plans/PLAN_sidebar_row_collapse.md §2.1 row 9.
   */
  private buildActionNodes(): ConfigTreeNode[] {
    const nodes: ConfigTreeNode[] = [
      setting('Open analysis_options_custom.yaml', undefined, 'saropaLints.openConfig', 'file-code'),
      setting('Initialize / Update config', undefined, 'saropaLints.initializeConfig', 'tools'),
    ];

    // No project root → no yaml to probe → no row (mirrors getAnalyzerPluginWarningNode).
    const root = getProjectRoot();
    if (root) {
      const probe = migrateConfigKeys(root, { dryRun: true });
      // Show the row when ANY legacy keys remain in the plugins block — not
      // just movable ones. `skipped` keys are already in the custom file but
      // their legacy copies still sit in analysis_options.yaml's plugin block,
      // causing `unsupported_option` warnings; the non-dry-run path removes
      // those too (migrateConfig.ts line 128-130). Without this check a
      // skipped-only project gets stuck with warnings and no sidebar row.
      const legacyCount = probe.moved.length + probe.skipped.length;
      if (!probe.error && legacyCount > 0) {
        nodes.push(
          setting(
            l10n('dashboards.controls.migrateLegacyKeys', { count: String(legacyCount) }),
            l10n('dashboards.controls.migrateLegacyKeysDesc'),
            'saropaLints.migrateConfig',
            'arrow-right',
          ),
        );
      }
    }

    // Composite analyzer plugin scaffold is intentionally NOT exposed here.
    // The action targets a tiny audience (teams shipping their own custom
    // analyzer rules alongside Saropa) and the term is jargon to everyone
    // else. It remains discoverable via the command palette
    // (`Saropa Lints: Create Composite Analyzer Plugin (scaffold)`),
    // `Saropa Lints: Show All Commands`, the CLI
    // (`dart run saropa_lints:init --emit-composite-plugin-scaffold`),
    // and `doc/guides/composite_analyzer_plugin.md`. Keeping it out of the
    // sidebar avoids confusing the 99% of users who only want Saropa rules.
    nodes.push(setting('Run analysis', undefined, 'saropaLints.runAnalysis', 'play'));
    return nodes;
  }

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
