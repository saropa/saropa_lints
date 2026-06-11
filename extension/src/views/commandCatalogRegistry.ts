/**
 * Static registry of all extension commands for the command catalog webview.
 *
 * Maintenance: when adding or removing a command in package.json, update this
 * registry to match. A test validates that the two stay in sync.
 *
 * Most of this file is the `catalogEntries` literal: titles align with
 * `package.json` `contributes.commands` labels so the palette and catalog stay
 * consistent. Descriptions stay short; the webview search field concatenates
 * title, id, and description for matching.
 */

// ── Types ────────────────────────────────────────────────────────────────────

/** Categories that group commands in the catalog UI. */
export type CatalogCategory =
  | 'Setup & Configuration'
  | 'Analysis'
  | 'Violations & Filtering'
  | 'Rules & Fixes'
  | 'Reporting & Export'
  | 'Security Posture'
  | 'Code Health'
  | 'Package Vibrancy'
  | 'Package Vibrancy — Filters'
  | 'Package Vibrancy — Updates'
  | 'Package Vibrancy — Registries'
  | 'TODOs & Hacks'
  | 'Drift Advisor'
  | 'Views & Navigation';

export interface CatalogEntry {
  /** VS Code command ID, e.g. 'saropaLints.runAnalysis'. */
  command: string;

  /** Human-readable title shown in the catalog. */
  title: string;

  /** One-liner explaining what this does and when to use it. */
  description: string;

  /** Category for grouping in the catalog. */
  category: CatalogCategory;

  /** Codicon name (without the `$()` wrapper), e.g. 'play'. */
  icon: string;

  /**
   * When true the command is internal-only (triggered programmatically or
   * from context menus) and should appear dimmed in the catalog with a note
   * that it is not meant to be invoked directly.
   */
  internal?: boolean;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Ordered list of categories — controls the display order of sections in the
 * catalog webview.
 */
export const catalogCategoryOrder: readonly CatalogCategory[] = [
  'Setup & Configuration',
  'Analysis',
  'Violations & Filtering',
  'Rules & Fixes',
  'Security Posture',
  'Reporting & Export',
  'Code Health',
  'Package Vibrancy',
  'Package Vibrancy — Filters',
  'Package Vibrancy — Updates',
  'Package Vibrancy — Registries',
  'TODOs & Hacks',
  'Drift Advisor',
  'Views & Navigation',
];

// ── Registry ─────────────────────────────────────────────────────────────────

export const catalogEntries: readonly CatalogEntry[] = [

  // ── Setup & Configuration ────────────────────────────────────────────────

  {
    command: 'saropaLints.enable',
    title: 'Set Up Project',
    description: 'Add saropa_lints to pubspec.yaml and create analysis_options.yaml.',
    category: 'Setup & Configuration',
    icon: 'package',
  },
  {
    command: 'saropaLints.disable',
    title: 'Turn Off Lint Integration',
    description: 'Remove saropa_lints integration from the current project.',
    category: 'Setup & Configuration',
    icon: 'circle-slash',
  },
  {
    command: 'saropaLints.initializeConfig',
    title: 'Initialize / Update Analysis Options',
    description: 'Create or refresh the analysis_options.yaml configuration file.',
    category: 'Setup & Configuration',
    icon: 'gear',
  },
  {
    command: 'saropaLints.enableRulePack',
    title: 'Enable Rule Pack',
    description: 'Enable a rule pack for a package in your pubspec, from a Suggestions item.',
    category: 'Setup & Configuration',
    icon: 'extensions',
    internal: true,
  },
  {
    command: 'saropaLints.openConfig',
    title: 'Open Analysis Options',
    description: 'Open the analysis_options.yaml file in the editor.',
    category: 'Setup & Configuration',
    icon: 'go-to-file',
  },
  {
    command: 'saropaLints.openPubspec',
    title: 'Open pubspec.yaml',
    description: 'Open the project root pubspec.yaml in the editor.',
    category: 'Setup & Configuration',
    icon: 'go-to-file',
  },
  {
    command: 'saropaLints.toggleRunAnalysisAfterConfigChange',
    title: 'Toggle Run Analysis After Config Change',
    description: 'Flip the saropaLints.runAnalysisAfterConfigChange setting in one click.',
    category: 'Setup & Configuration',
    icon: 'sync',
  },
  {
    command: 'saropaLints.toggleRunAnalysisAfterDependencyChange',
    title: 'Toggle Run Analysis After Dependency Change',
    description: 'Flip the saropaLints.runAnalysisAfterDependencyChange setting in one click. When on, pubspec.lock changes auto-trigger analysis after a 10-second debounce.',
    category: 'Setup & Configuration',
    icon: 'sync',
  },
  {
    command: 'saropaLints.toggleTodosAndHacksScanner',
    title: 'Toggle TODO/HACK Workspace Scanner',
    description:
      'Enable or disable the saropa file-system TODO/HACK scanner (saropaLints.todosAndHacks.workspaceScanEnabled). When on, the Findings Dashboard and sidebar surface open TODO/HACK markers across the workspace.',
    category: 'Setup & Configuration',
    icon: 'list-tree',
  },
  {
    command: 'saropaLints.pickUiLanguage',
    title: 'Pick UI Language',
    description:
      'Choose the extension UI language from installed locale bundles or follow VS Code display language.',
    category: 'Setup & Configuration',
    icon: 'globe',
  },
  {
    command: 'saropaLints.openConfigDashboard',
    title: 'Open Lints Config',
    description: 'Open the Lints Config dashboard in an editor tab for tiers, packs, and config guidance.',
    category: 'Setup & Configuration',
    icon: 'dashboard',
  },
  {
    command: 'saropaLints.openViolationsWideReport',
    title: 'Open Findings Dashboard',
    description:
      'Open the Findings Dashboard in an editor tab (violations, TODOs, Drift Advisor snapshot).',
    category: 'Setup & Configuration',
    icon: 'warning',
  },
  {
    command: 'saropaLints.revealFindingsDashboard',
    title: 'Open Findings Dashboard (preserve filters)',
    description:
      'Same editor tab as Open Findings Dashboard; preserves current filters (does not clear first).',
    category: 'Setup & Configuration',
    icon: 'warning',
  },
  {
    command: 'saropaLints.openPackageVibrancy',
    title: 'Open Package Vibrancy',
    description:
      'Focus the Package Vibrancy activity-bar section and run a scan when no dependency results are loaded yet.',
    category: 'Setup & Configuration',
    icon: 'package',
  },
  {
    command: 'saropaLints.repairConfig',
    title: 'Repair Analysis Options',
    description: 'Detect and fix problems in the analysis_options.yaml file.',
    category: 'Setup & Configuration',
    icon: 'tools',
  },
  {
    command: 'saropaLints.setTier',
    title: 'Set Tier',
    description: 'Choose which rule tier to enforce (Essential through Pedantic).',
    category: 'Setup & Configuration',
    icon: 'layers',
  },
  {
    command: 'saropaLints.emitCompositePluginScaffold',
    title: 'Composite Analyzer Plugin (scaffold)',
    description:
      'Generate a minimal meta-plugin package (Saropa + your rules hook) under a workspace-relative folder.',
    category: 'Setup & Configuration',
    icon: 'new-folder',
  },
  {
    command: 'saropaLints.createSaropaInstructions',
    title: 'Create AI Agent Instructions',
    description: 'Generate a Saropa Lints instruction file for AI coding assistants.',
    category: 'Setup & Configuration',
    icon: 'book',
  },

  // ── Analysis ─────────────────────────────────────────────────────────────

  {
    command: 'saropaLints.runAnalysis',
    title: 'Run Analysis',
    description: 'Analyze the current project and refresh all violation data.',
    category: 'Analysis',
    icon: 'play',
  },
  {
    command: 'saropaLints.crossFile.unusedFiles',
    title: 'Cross-File — Find Unused Files',
    description: 'Run project-wide analysis to find Dart files that are not imported by any other file.',
    category: 'Analysis',
    icon: 'search-remove',
  },
  {
    command: 'saropaLints.crossFile.circularDeps',
    title: 'Cross-File — Detect Circular Dependencies',
    description: 'Run project-wide analysis to detect circular import chains across files.',
    category: 'Analysis',
    icon: 'references',
  },
  {
    command: 'saropaLints.crossFile.importStats',
    title: 'Cross-File — Show Import Statistics',
    description: 'Show cross-file import graph totals like file count and import edges.',
    category: 'Analysis',
    icon: 'graph',
  },
  {
    command: 'saropaLints.crossFile.featureDeps',
    title: 'Cross-File — Show Feature Dependencies',
    description: 'Show feature-to-feature import relationships for projects using lib/features.',
    category: 'Analysis',
    icon: 'organization',
  },
  {
    command: 'saropaLints.crossFile.unusedSymbols',
    title: 'Cross-File — Find Unused Symbols',
    description: 'Report likely unused top-level symbols across project files.',
    category: 'Analysis',
    icon: 'symbol-method',
  },
  {
    command: 'saropaLints.crossFile.deadImports',
    title: 'Cross-File — Find Dead Imports',
    description: 'Report likely dead relative imports where no imported symbols are used.',
    category: 'Analysis',
    icon: 'symbol-namespace',
  },
  {
    command: 'saropaLints.crossFile.unusedL10n',
    title: 'Cross-File — Find Unused l10n Keys',
    description: 'Compare ARB keys to identifier usage in lib/ and test/ (heuristic; may miss dynamic keys).',
    category: 'Analysis',
    icon: 'symbol-string',
  },
  {
    command: 'saropaLints.crossFile.duplicates',
    title: 'Cross-File — Find Duplicate Line Blocks',
    description: 'Find repeated normalized multi-line blocks across Dart files (line-based, not AST).',
    category: 'Analysis',
    icon: 'copy',
  },
  {
    command: 'saropaLints.crossFile.snapshot',
    title: 'Cross-File — Write Project Snapshot (JSON)',
    description: 'Run full cross-file analysis and write cross_file_snapshot.json for ProjectContext consumers.',
    category: 'Analysis',
    icon: 'database',
  },
  {
    command: 'saropaLints.crossFile.graph',
    title: 'Cross-File — Export Import Graph (DOT)',
    description: 'Export the cross-file import graph as a Graphviz DOT file.',
    category: 'Analysis',
    icon: 'type-hierarchy',
  },
  {
    command: 'saropaLints.crossFile.report',
    title: 'Cross-File — Generate HTML Report',
    description: 'Generate an HTML cross-file analysis report under reports/.saropa_lints/cross_file.',
    category: 'Analysis',
    icon: 'output',
  },
  {
    command: 'saropaLints.verifyPlugin',
    title: 'Verify Plugin Is Running',
    description: 'Run the liveness check to confirm the analyzer plugin is connected and producing diagnostics.',
    category: 'Analysis',
    icon: 'pulse',
  },
  {
    command: 'saropaLints.refresh',
    title: 'Refresh',
    description: 'Re-read cached analysis results and update all tree views.',
    category: 'Analysis',
    icon: 'refresh',
  },
  {
    command: 'saropaLints.toggleInlineAnnotations',
    title: 'Toggle Inline Annotations',
    description: 'Show or hide inline violation annotations in the editor.',
    category: 'Analysis',
    icon: 'comment',
  },
  {
    command: 'saropaLints.showOutput',
    title: 'Show Output',
    description: 'Open the Saropa Lints output channel to see diagnostic logs.',
    category: 'Analysis',
    icon: 'output',
  },
  {
    command: 'saropaLints.showRelatedRuleTelemetry',
    title: 'Show Related Rule Telemetry',
    description:
      'Open a UI panel showing related-rule interaction counters and recent event metadata.',
    category: 'Analysis',
    icon: 'graph',
  },
  {
    command: 'saropaLints.resetRelatedRuleTelemetry',
    title: 'Reset Related Rule Telemetry',
    description: 'Clear related-rule interaction counters.',
    category: 'Analysis',
    icon: 'clear-all',
  },
  {
    command: 'saropaLints.copyLatestReport',
    title: 'Copy Latest Report',
    description:
      'Copy the most recent analysis report (reports/<date>/*_saropa_lint_report.log) to the clipboard.',
    category: 'Analysis',
    icon: 'clippy',
  },
  {
    command: 'saropaLints.openLatestReport',
    title: 'Open Latest Report',
    description:
      'Open the most recent analysis report (reports/<date>/*_saropa_lint_report.log) in an editor tab.',
    category: 'Analysis',
    icon: 'file-text',
  },

  // ── Violations & Filtering ───────────────────────────────────────────────

  {
    command: 'saropaLints.focusView',
    title: 'Focus Saropa Lints Sidebar',
    description: 'Reveal the unified Saropa Lints view in the activity bar (editor dashboards, actions, status, settings, triage, help).',
    category: 'Violations & Filtering',
    icon: 'list-tree',
  },
  {
    command: 'saropaLints.focusIssues',
    title: 'Show All Violations',
    description: 'Display every violation found in the project.',
    category: 'Violations & Filtering',
    icon: 'checklist',
  },
  {
    command: 'saropaLints.focusIssuesForFile',
    title: 'Show Violations for File',
    description: 'Filter the violations view to a specific file.',
    category: 'Violations & Filtering',
    icon: 'file',
  },
  {
    command: 'saropaLints.openFileAndFocusIssues',
    title: 'Open File and Show Violations',
    description: 'Open a file in the editor and filter the violations view to it.',
    category: 'Violations & Filtering',
    icon: 'go-to-file',
    internal: true,
  },
  {
    command: 'saropaLints.fileRisk.showViolations',
    title: 'Show Violations for File (File Risk)',
    description: 'Filter the violations view to the selected file risk entry.',
    category: 'Violations & Filtering',
    icon: 'filter',
    internal: true,
  },
  {
    command: 'saropaLints.fileRisk.hideFile',
    title: 'Hide File (File Risk)',
    description: 'Suppress a file from the violations and file risk views.',
    category: 'Violations & Filtering',
    icon: 'eye-closed',
    internal: true,
  },
  {
    command: 'saropaLints.fileRisk.copyPath',
    title: 'Copy Path (File Risk)',
    description: 'Copy the relative file path from a file risk entry.',
    category: 'Violations & Filtering',
    icon: 'clippy',
    internal: true,
  },
  {
    command: 'saropaLints.focusIssuesForActiveFile',
    title: 'Show in Saropa Lints',
    description: 'Show violations for the currently open file in the sidebar.',
    category: 'Violations & Filtering',
    icon: 'file-code',
  },
  {
    command: 'saropaLints.focusIssuesWithImpactFilter',
    title: 'Show Violations by Impact',
    description: 'Filter violations by their impact level.',
    category: 'Violations & Filtering',
    icon: 'flame',
  },
  {
    command: 'saropaLints.focusIssuesWithSeverityFilter',
    title: 'Show Violations by Severity',
    description: 'Filter violations by severity (info, warning, error).',
    category: 'Violations & Filtering',
    icon: 'warning',
  },
  {
    command: 'saropaLints.focusIssuesForRules',
    title: 'Show Violations for Rules',
    description: 'Filter violations to show only specific lint rules.',
    category: 'Violations & Filtering',
    icon: 'filter',
  },
  {
    command: 'saropaLints.focusIssuesByRuleMetadata',
    title: 'Show Violations by Rule Metadata',
    description: 'Filter violations using a rule metadata query (type, tag, status, or CWE).',
    category: 'Violations & Filtering',
    icon: 'filter',
    internal: true,
  },
  {
    command: 'saropaLints.focusIssuesForOwasp',
    title: 'Focus Violations for OWASP Category',
    description: 'Filter violations by a specific OWASP security category.',
    category: 'Violations & Filtering',
    icon: 'shield',
    internal: true,
  },
  {
    command: 'saropaLints.setIssuesFilter',
    title: 'Filter by Text',
    description: 'Type a text query to filter the violations list.',
    category: 'Violations & Filtering',
    icon: 'filter',
  },
  {
    command: 'saropaLints.setIssuesFilterByType',
    title: 'Filter by Type',
    description: 'Filter violations by their diagnostic type.',
    category: 'Violations & Filtering',
    icon: 'filter',
  },
  {
    command: 'saropaLints.setIssuesFilterByRule',
    title: 'Filter by Rule',
    description: 'Pick a specific rule name to filter violations.',
    category: 'Violations & Filtering',
    icon: 'filter',
  },
  {
    command: 'saropaLints.setIssuesFilterByMetadata',
    title: 'Filter by Rule Metadata',
    description: 'Filter violations by rule type, tags, status, and CWE metadata.',
    category: 'Violations & Filtering',
    icon: 'filter',
  },
  {
    command: 'saropaLints.reviewHotspotState',
    title: 'Review Security Hotspot State',
    description: 'Set review workflow state for security hotspots (open/safe/fixed).',
    category: 'Violations & Filtering',
    icon: 'shield',
  },
  {
    command: 'saropaLints.clearIssuesFilters',
    title: 'Clear Filters',
    description: 'Remove all active violation filters.',
    category: 'Violations & Filtering',
    icon: 'clear-all',
  },
  {
    command: 'saropaLints.setGroupBy',
    title: 'Group By',
    description: 'Change how violations are grouped (by file, rule, severity, etc.).',
    category: 'Violations & Filtering',
    icon: 'list-tree',
  },
  {
    command: 'saropaLints.focusFile',
    title: 'Show Only This File',
    description: 'Temporarily restrict the violations view to a single file.',
    category: 'Violations & Filtering',
    icon: 'pinned',
    internal: true,
  },
  {
    command: 'saropaLints.clearFocusFile',
    title: 'Show All Files',
    description: 'Remove the single-file filter and show all violations again.',
    category: 'Violations & Filtering',
    icon: 'close-all',
  },
  {
    command: 'saropaLints.hideFolder',
    title: 'Hide Folder from View',
    description: 'Suppress violations from a specific folder.',
    category: 'Violations & Filtering',
    icon: 'folder',
    internal: true,
  },
  {
    command: 'saropaLints.hideFile',
    title: 'Hide File from View',
    description: 'Suppress violations from a specific file.',
    category: 'Violations & Filtering',
    icon: 'file',
    internal: true,
  },
  {
    command: 'saropaLints.hideRule',
    title: 'Hide Rule from View',
    description: 'Suppress a specific lint rule from the violations view.',
    category: 'Violations & Filtering',
    icon: 'eye-closed',
    internal: true,
  },
  {
    command: 'saropaLints.hideRuleInFile',
    title: 'Hide Rule in This File',
    description: 'Suppress a rule only in a specific file.',
    category: 'Violations & Filtering',
    icon: 'eye-closed',
    internal: true,
  },
  {
    command: 'saropaLints.hideSeverity',
    title: 'Hide This Severity',
    description: 'Suppress all violations of a given severity level.',
    category: 'Violations & Filtering',
    icon: 'eye-closed',
    internal: true,
  },
  {
    command: 'saropaLints.hideImpact',
    title: 'Hide This Impact',
    description: 'Suppress all violations of a given impact level.',
    category: 'Violations & Filtering',
    icon: 'eye-closed',
    internal: true,
  },
  {
    command: 'saropaLints.clearSuppressions',
    title: 'Clear Suppressions',
    description: 'Remove all view-level suppressions and show everything again.',
    category: 'Violations & Filtering',
    icon: 'eye',
  },
  {
    command: 'saropaLints.copyPath',
    title: 'Copy Path',
    description: 'Copy the file path of a violation to the clipboard.',
    category: 'Violations & Filtering',
    icon: 'clippy',
    internal: true,
  },
  {
    command: 'saropaLints.copyMessage',
    title: 'Copy Message',
    description: 'Copy a violation message to the clipboard.',
    category: 'Violations & Filtering',
    icon: 'clippy',
    internal: true,
  },

  // ── Rules & Fixes ────────────────────────────────────────────────────────

  {
    command: 'saropaLints.explainRule',
    title: 'Explain Rule',
    description: 'Open a detailed explanation panel for a lint rule.',
    category: 'Rules & Fixes',
    icon: 'book',
  },
  {
    command: 'saropaLints.explainRuleFromSuggestion',
    title: 'Explain Rule (Suggestion)',
    description: 'Open rule details from a related-rule suggestion action.',
    category: 'Rules & Fixes',
    icon: 'book',
    internal: true,
  },
  {
    command: 'saropaLints.applyFix',
    title: 'Apply Fix',
    description: 'Apply the suggested quick fix for a violation.',
    category: 'Rules & Fixes',
    icon: 'wrench',
    internal: true,
  },
  {
    command: 'saropaLints.fixAllInFile',
    title: 'Fix All in This File',
    description: 'Apply all available quick fixes for violations in a file.',
    category: 'Rules & Fixes',
    icon: 'wand',
    internal: true,
  },
  {
    command: 'saropaLints.disableRules',
    title: 'Disable Rule(s)',
    description: 'Turn off one or more lint rules in the project configuration.',
    category: 'Rules & Fixes',
    icon: 'circle-slash',
  },
  {
    command: 'saropaLints.enableRules',
    title: 'Enable Rule(s)',
    description: 'Turn on one or more lint rules in the project configuration.',
    category: 'Rules & Fixes',
    icon: 'check',
  },

  // ── Security Posture ─────────────────────────────────────────────────────

  {
    command: 'saropaLints.exportOwaspReport',
    title: 'Export OWASP Compliance Report',
    description: 'Generate and save an OWASP compliance report for the project.',
    category: 'Security Posture',
    icon: 'shield',
  },

  // ── Reporting & Export ───────────────────────────────────────────────────

  {
    command: 'saropaLints.issues.copyAsJson',
    title: 'Copy Violations as JSON',
    description: 'Copy the full violations tree data to the clipboard as JSON.',
    category: 'Reporting & Export',
    icon: 'clippy',
  },
  {
    command: 'saropaLints.summary.copyAsJson',
    title: 'Copy Summary as JSON',
    description: 'Copy the summary tree data to the clipboard as JSON.',
    category: 'Reporting & Export',
    icon: 'clippy',
  },
  {
    command: 'saropaLints.securityPosture.copyAsJson',
    title: 'Copy Security Posture as JSON',
    description: 'Copy the security posture tree data to the clipboard as JSON.',
    category: 'Reporting & Export',
    icon: 'clippy',
  },
  {
    command: 'saropaLints.fileRisk.copyAsJson',
    title: 'Copy File Risk as JSON',
    description: 'Copy the file risk tree data to the clipboard as JSON.',
    category: 'Reporting & Export',
    icon: 'clippy',
  },
  {
    command: 'saropaLints.suggestions.copyAsJson',
    title: 'Copy Suggestions as JSON',
    description: 'Copy the suggestions tree data to the clipboard as JSON.',
    category: 'Reporting & Export',
    icon: 'clippy',
  },

  // ── Package Vibrancy ─────────────────────────────────────────────────────

  {
    command: 'saropaLints.packageVibrancy.scan',
    title: 'Scan Packages',
    description: 'Fetch health data for all dependencies in pubspec.yaml.',
    category: 'Package Vibrancy',
    icon: 'refresh',
  },
  {
    command: 'saropaLints.packageVibrancy.rescan',
    title: 'Rescan Packages (Fresh)',
    description: 'Clear the per-package pub.dev cache and re-fetch health data — use when the report shows stale versions.',
    category: 'Package Vibrancy',
    icon: 'refresh',
  },
  {
    command: 'saropaLints.packageVibrancy.openOtherProject',
    title: 'Scan Another Project...',
    description: 'Open a pubspec.yaml from another project in a new VS Code window to run a vibrancy scan there.',
    category: 'Package Vibrancy',
    icon: 'folder-opened',
  },
  {
    command: 'saropaLints.packageVibrancy.showReport',
    title: 'Open Package Dashboard',
    description: 'Open the Package Dashboard in an editor tab with charts and dependency details.',
    category: 'Package Vibrancy',
    icon: 'graph',
  },
  {
    command: 'saropaLints.packageVibrancy.focus',
    title: 'Open Package Dashboard (compat)',
    description:
      'Backward-compatible handler for old `{viewId}.focus` calls on the removed Package Vibrancy sidebar; opens the Package Dashboard tab.',
    category: 'Package Vibrancy',
    icon: 'graph',
    internal: true,
  },
  {
    command: 'saropaLints.focusPackageVibrancyPackages',
    title: 'Focus Package Vibrancy Tree',
    description: 'Focus the Package Vibrancy sidebar tree (dependency list).',
    category: 'Package Vibrancy',
    icon: 'package',
  },
  {
    command: 'saropaLints.openProjectVibrancyReport',
    title: 'Open Code Health Dashboard',
    description:
      'Run a Code Health scan (LCOV + analyzer) using Code Health settings and open the dashboard.',
    category: 'Code Health',
    icon: 'graph',
  },
  {
    command: 'saropaLints.openProjectHealthDashboard',
    title: 'Open Saropa Project Map Dashboard',
    description:
      'Project-wide size map, dead-weight, complexity, git churn, and hot spots (size treemap + churn×complexity charts).',
    category: 'Code Health',
    icon: 'flame',
  },
  {
    command: 'saropaLints.toggleProjectMapCodeLensHeat',
    title: 'Toggle Saropa Project Map Heat CodeLens (in-editor)',
    description:
      'Turn the in-editor per-function complexity CodeLens on or off (off by default to avoid clutter).',
    category: 'Code Health',
    icon: 'flame',
  },
  {
    command: 'saropaLints.openProjectVibrancySettings',
    title: 'Open Code Health Settings',
    // Setting key prefix is still `saropaLints.projectVibrancy` from the
    // pre-rename Project Vibrancy era — stays so existing user settings.json
    // entries keep working. The Settings filter passes that exact prefix.
    description: 'Open Settings filtered to saropaLints.projectVibrancy (LCOV path and quality gates).',
    category: 'Code Health',
    icon: 'settings-gear',
  },
  {
    command: 'saropaLints.packageVibrancy.clearCache',
    title: 'Clear Cache',
    description: 'Delete cached pub.dev data so the next scan fetches fresh results.',
    category: 'Package Vibrancy',
    icon: 'trash',
  },
  {
    command: 'saropaLints.packageVibrancy.exportReport',
    title: 'Export Report',
    description: 'Save the vibrancy report to a file (HTML or JSON).',
    category: 'Package Vibrancy',
    icon: 'export',
  },
  {
    command: 'saropaLints.packageVibrancy.browseKnownIssues',
    title: 'Browse Known Issues',
    description: 'Open the known issues database for common package problems.',
    category: 'Package Vibrancy',
    icon: 'library',
  },
  {
    command: 'saropaLints.packageVibrancy.exportSbom',
    title: 'Export SBOM',
    description: 'Generate a CycloneDX Software Bill of Materials for dependencies.',
    category: 'Package Vibrancy',
    icon: 'shield',
  },
  {
    command: 'saropaLints.packageVibrancy.annotatePubspec',
    title: 'Annotate Dependencies',
    description: 'Add inline comments to pubspec.yaml showing package health info.',
    category: 'Package Vibrancy',
    icon: 'note',
  },
  {
    command: 'saropaLints.packageVibrancy.goToPackage',
    title: 'Go to pubspec.yaml',
    description: 'Jump to a package declaration in pubspec.yaml.',
    category: 'Package Vibrancy',
    icon: 'go-to-file',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.goToLine',
    title: 'Go to Line in pubspec.yaml',
    description: 'Jump to a specific line in pubspec.yaml.',
    category: 'Package Vibrancy',
    icon: 'go-to-file',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.openOnPubDev',
    title: 'Open on pub.dev',
    description: 'Open the selected package page on pub.dev in the browser.',
    category: 'Package Vibrancy',
    icon: 'link-external',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.showChangelog',
    title: 'Open Changelog on pub.dev',
    description: 'Open the package changelog on pub.dev in the browser.',
    category: 'Package Vibrancy',
    icon: 'book',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.copyAsJson',
    title: 'Copy Package as JSON',
    description: 'Copy the selected package vibrancy data to the clipboard.',
    category: 'Package Vibrancy',
    icon: 'clippy',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.upgradeAndTest',
    title: 'Upgrade & Test',
    description: 'Upgrade a dependency and run tests to verify compatibility.',
    category: 'Package Vibrancy',
    icon: 'beaker',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.suppressPackage',
    title: 'Suppress Package',
    description: 'Hide a specific package from vibrancy diagnostics.',
    category: 'Package Vibrancy',
    icon: 'eye-closed',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.unsuppressPackage',
    title: 'Unsuppress Package',
    description: 'Restore a suppressed package to vibrancy diagnostics.',
    category: 'Package Vibrancy',
    icon: 'eye',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.openUrl',
    title: 'Open Link',
    description: 'Open a URL from package metadata in the browser.',
    category: 'Package Vibrancy',
    icon: 'link-external',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.commentOutUnused',
    title: 'Comment Out Unused Dependency',
    description: 'Comment out an unused dependency in pubspec.yaml.',
    category: 'Package Vibrancy',
    icon: 'comment',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.deleteUnused',
    title: 'Delete Unused Dependency',
    description: 'Remove an unused dependency from pubspec.yaml (with backup).',
    category: 'Package Vibrancy',
    icon: 'trash',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.planUpgrades',
    title: 'Plan & Execute Upgrades',
    description: 'Interactively plan and execute dependency version upgrades.',
    category: 'Package Vibrancy',
    icon: 'rocket',
  },
  {
    command: 'saropaLints.packageVibrancy.goToOverride',
    title: 'Go to Dependency Override',
    description: 'Jump to a dependency_overrides entry in pubspec.yaml.',
    category: 'Package Vibrancy',
    icon: 'go-to-file',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.suppressPackageByName',
    title: 'Suppress Package Diagnostics',
    description: 'Type a package name to suppress its vibrancy diagnostics.',
    category: 'Package Vibrancy',
    icon: 'eye-closed',
  },
  {
    command: 'saropaLints.packageVibrancy.suppressByCategory',
    title: 'Suppress by Category',
    description: 'Suppress all vibrancy diagnostics of a given category.',
    category: 'Package Vibrancy',
    icon: 'filter',
  },
  {
    command: 'saropaLints.packageVibrancy.suppressAllProblems',
    title: 'Suppress All Unhealthy Packages',
    description: 'Suppress diagnostics for every package currently flagged.',
    category: 'Package Vibrancy',
    icon: 'eye-closed',
  },
  {
    command: 'saropaLints.packageVibrancy.unsuppressAll',
    title: 'Unsuppress All Packages',
    description: 'Restore all suppressed packages to vibrancy diagnostics.',
    category: 'Package Vibrancy',
    icon: 'eye',
  },
  {
    command: 'saropaLints.packageVibrancy.sortDependencies',
    title: 'Sort Dependencies Alphabetically',
    description: 'Reorder dependencies in pubspec.yaml alphabetically.',
    category: 'Package Vibrancy',
    icon: 'list-ordered',
  },
  {
    command: 'saropaLints.packageVibrancy.showCodeLens',
    title: 'Show Vibrancy Badges',
    description: 'Display code lens badges above dependencies in pubspec.yaml.',
    category: 'Package Vibrancy',
    icon: 'eye',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.hideCodeLens',
    title: 'Hide Vibrancy Badges',
    description: 'Remove code lens badges from pubspec.yaml.',
    category: 'Package Vibrancy',
    icon: 'eye-closed',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.toggleCodeLens',
    title: 'Toggle Badges',
    description: 'Toggle code lens vibrancy badges on or off.',
    category: 'Package Vibrancy',
    icon: 'eye',
  },
  {
    command: 'saropaLints.packageVibrancy.focusDetails',
    title: 'Focus Package Details',
    description: 'Open the package details sidebar panel.',
    category: 'Package Vibrancy',
    icon: 'preview',
  },
  {
    command: 'saropaLints.packageVibrancy.logDetails',
    title: 'Log to Output',
    description: 'Print selected package details to the output channel.',
    category: 'Package Vibrancy',
    icon: 'output',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.logAllDetails',
    title: 'Log All Package Details',
    description: 'Print all scanned package details to the output channel.',
    category: 'Package Vibrancy',
    icon: 'output',
  },
  {
    command: 'saropaLints.packageVibrancy.updateFromCodeLens',
    title: 'Update Package Version',
    description: 'Update a package version from a code lens badge click.',
    category: 'Package Vibrancy',
    icon: 'arrow-up',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.focusPackageInTree',
    title: 'Show Package in Sidebar',
    description:
      'Focus Package Vibrancy in the activity bar, reveal this dependency, and open package details when available.',
    category: 'Package Vibrancy',
    icon: 'list-tree',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.updateToLatest',
    title: 'Update to Latest',
    description: 'Update a selected dependency to its latest stable version.',
    category: 'Package Vibrancy — Updates',
    icon: 'arrow-up',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.updateAllLatest',
    title: 'Update All Dependencies (Latest)',
    description: 'Update every dependency to its latest stable version.',
    category: 'Package Vibrancy — Updates',
    icon: 'cloud-download',
  },
  {
    command: 'saropaLints.packageVibrancy.updateAllMajor',
    title: 'Update All Dependencies (Major Only)',
    description: 'Update every dependency that has a new major version available.',
    category: 'Package Vibrancy — Updates',
    icon: 'arrow-up',
  },
  {
    command: 'saropaLints.packageVibrancy.updateAllMinor',
    title: 'Update All Dependencies (Minor Only)',
    description: 'Update every dependency that has a new minor version available.',
    category: 'Package Vibrancy — Updates',
    icon: 'arrow-up',
  },
  {
    command: 'saropaLints.packageVibrancy.updateAllPatch',
    title: 'Update All Dependencies (Patch Only)',
    description: 'Update every dependency that has a new patch version available.',
    category: 'Package Vibrancy — Updates',
    icon: 'arrow-up',
  },
  {
    command: 'saropaLints.packageVibrancy.showPrereleases',
    title: 'Show Prerelease Versions',
    description: 'Include prerelease versions in CodeLens and Package Vibrancy.',
    category: 'Package Vibrancy — Updates',
    icon: 'beaker',
  },
  {
    command: 'saropaLints.packageVibrancy.hidePrereleases',
    title: 'Hide Prerelease Versions',
    description: 'Exclude prerelease versions from CodeLens and Package Vibrancy.',
    category: 'Package Vibrancy — Updates',
    icon: 'eye-closed',
  },
  {
    command: 'saropaLints.packageVibrancy.updateToPrerelease',
    title: 'Update to Prerelease',
    description: 'Update a selected dependency to its latest prerelease version.',
    category: 'Package Vibrancy — Updates',
    icon: 'beaker',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.comparePackages',
    title: 'Compare Packages',
    description: 'Open a side-by-side comparison of two packages.',
    category: 'Package Vibrancy',
    icon: 'diff',
  },
  {
    command: 'saropaLints.packageVibrancy.compareSelected',
    title: 'Compare Selected Packages',
    description: 'Compare packages after multi-selecting them in Package Vibrancy.',
    category: 'Package Vibrancy',
    icon: 'diff',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.copyHoverToClipboard',
    title: 'Copy Package Info',
    description: 'Copy package hover information to the clipboard.',
    category: 'Package Vibrancy',
    icon: 'clippy',
    internal: true,
  },
  {
    command: 'saropaLints.packageVibrancy.showPackagePanel',
    title: 'Show Package Details',
    description: 'Open the package details panel for a specific dependency.',
    category: 'Package Vibrancy',
    icon: 'preview',
  },
  {
    command: 'saropaLints.packageVibrancy.generateCiConfig',
    title: 'Generate CI Pipeline',
    description: 'Create a CI pipeline configuration for dependency monitoring.',
    category: 'Package Vibrancy',
    icon: 'server-process',
  },
  {
    command: 'saropaLints.packageVibrancy.openSourceFolder',
    title: 'Open Source Folder',
    description: 'Open the local source folder for a cached package dependency.',
    category: 'Package Vibrancy',
    icon: 'folder-opened',
    internal: true,
  },

  // ── Package Vibrancy — Filters ───────────────────────────────────────────

  {
    command: 'saropaLints.packageVibrancy.search',
    title: 'Search',
    description: 'Filter packages in Package Vibrancy by text.',
    category: 'Package Vibrancy — Filters',
    icon: 'search',
  },
  {
    command: 'saropaLints.packageVibrancy.filterBySeverity',
    title: 'Filter by Severity',
    description: 'Show only packages with a specific severity level.',
    category: 'Package Vibrancy — Filters',
    icon: 'filter',
  },
  {
    command: 'saropaLints.packageVibrancy.filterByProblemType',
    title: 'Filter by Problem Type',
    description: 'Show only packages with a specific type of problem.',
    category: 'Package Vibrancy — Filters',
    icon: 'filter',
  },
  {
    command: 'saropaLints.packageVibrancy.filterByCategory',
    title: 'Filter by Health',
    description: 'Show only packages in a specific health category.',
    category: 'Package Vibrancy — Filters',
    icon: 'filter',
  },
  {
    command: 'saropaLints.packageVibrancy.filterBySection',
    title: 'Filter by Section',
    description: 'Show only packages in a specific pubspec section.',
    category: 'Package Vibrancy — Filters',
    icon: 'filter',
  },
  {
    command: 'saropaLints.packageVibrancy.showProblemsOnly',
    title: 'Show Problems Only',
    description: 'Hide healthy packages and show only those with problems.',
    category: 'Package Vibrancy — Filters',
    icon: 'warning',
  },
  {
    command: 'saropaLints.packageVibrancy.clearFilters',
    title: 'Clear Filters',
    description: 'Remove all package vibrancy filters.',
    category: 'Package Vibrancy — Filters',
    icon: 'clear-all',
  },
  {
    command: 'saropaLints.packageVibrancy.expandAll',
    title: 'Expand All',
    description: 'Expand every row in Package Vibrancy (activity bar).',
    category: 'Package Vibrancy — Filters',
    icon: 'expand-all',
  },

  // ── Package Vibrancy — Registries ────────────────────────────────────────

  {
    command: 'saropaLints.packageVibrancy.addRegistryAuth',
    title: 'Add Registry Authentication',
    description: 'Configure credentials for a private package registry.',
    category: 'Package Vibrancy — Registries',
    icon: 'key',
  },
  {
    command: 'saropaLints.packageVibrancy.removeRegistryAuth',
    title: 'Remove Registry Authentication',
    description: 'Delete credentials for a private package registry.',
    category: 'Package Vibrancy — Registries',
    icon: 'trash',
  },
  {
    command: 'saropaLints.packageVibrancy.listRegistries',
    title: 'List Configured Registries',
    description: 'Show all configured private package registries.',
    category: 'Package Vibrancy — Registries',
    icon: 'list-unordered',
  },

  // ── TODOs & Hacks ────────────────────────────────────────────────────────

  {
    command: 'saropaLints.todosAndHacks.refresh',
    title: 'Refresh TODOs & Hacks',
    description: 'Re-scan the workspace for TODO, HACK, and FIXME comments.',
    category: 'TODOs & Hacks',
    icon: 'refresh',
  },
  {
    command: 'saropaLints.todosAndHacks.toggleGroupByTag',
    title: 'Toggle Group by Tag / Folder',
    description: 'Switch between grouping TODOs by tag type or by folder.',
    category: 'TODOs & Hacks',
    icon: 'list-tree',
  },
  {
    command: 'saropaLints.todosAndHacks.enableWorkspaceScan',
    title: 'Enable Workspace Scan',
    description: 'Enable workspace-wide scanning for TODO and HACK comments.',
    category: 'TODOs & Hacks',
    icon: 'search',
  },

  // ── Drift Advisor ────────────────────────────────────────────────────────

  {
    command: 'saropaLints.driftAdvisor.enableIntegration',
    title: 'Enable Drift Advisor',
    description: 'Turn on the Drift Advisor integration for this workspace.',
    category: 'Drift Advisor',
    icon: 'plug',
  },
  {
    command: 'saropaLints.driftAdvisor.disableIntegration',
    title: 'Disable Drift Advisor',
    description: 'Turn off the Drift Advisor integration for this workspace.',
    category: 'Drift Advisor',
    icon: 'circle-slash',
  },
  {
    command: 'saropaLints.driftAdvisor.refresh',
    title: 'Refresh Drift Advisor',
    description: 'Re-fetch drift data from the Drift Advisor service.',
    category: 'Drift Advisor',
    icon: 'refresh',
  },
  {
    command: 'saropaLints.driftAdvisor.openInBrowser',
    title: 'Open in Browser',
    description: 'Open the Drift Advisor dashboard in the default browser.',
    category: 'Drift Advisor',
    icon: 'link-external',
  },

  // ── Views & Navigation ───────────────────────────────────────────────────

  {
    command: 'saropaLints.showCommandCatalog',
    title: 'Browse All Commands',
    description: 'Open this searchable catalog of every extension command.',
    category: 'Views & Navigation',
    icon: 'list-flat',
  },
  {
    command: 'saropaLints.openWalkthrough',
    title: 'Getting Started',
    description: 'Open the guided walkthrough for Saropa Lints features.',
    category: 'Views & Navigation',
    icon: 'mortar-board',
  },
  {
    command: 'saropaLints.showAbout',
    title: 'About',
    description: 'Open the About Saropa Lints panel with version and product information.',
    category: 'Views & Navigation',
    icon: 'info',
  },
  {
    command: 'saropaLints.openHelpHub',
    title: 'Help',
    description:
      'Open walkthrough, About, command catalog, and pub.dev from one quick pick (same as sidebar Help rows).',
    category: 'Views & Navigation',
    icon: 'question',
  },
  {
    command: 'saropaLints.openPubDevSaropaLints',
    title: 'Open Package on pub.dev',
    description: 'Open the saropa_lints package page on pub.dev.',
    category: 'Views & Navigation',
    icon: 'link-external',
  },
  {
    command: 'saropaLints.toggleSidebarSection',
    title: 'Toggle Activity Bar Section',
    description: 'Show or hide a section in the Saropa Lints activity bar.',
    category: 'Views & Navigation',
    icon: 'layout',
    internal: true,
  },
];

/** Fast lookup for titles, icons, and history (see command catalog webview). */
export const catalogEntryByCommand: ReadonlyMap<string, CatalogEntry> = new Map(
  catalogEntries.map((e) => [e.command, e]),
);

/**
 * Returns catalog entries grouped by category, in the order defined by
 * {@link catalogCategoryOrder}. Categories with no entries are omitted.
 */
export function entriesByCategory(): Map<CatalogCategory, CatalogEntry[]> {
  const map = new Map<CatalogCategory, CatalogEntry[]>();

  // Seed map in display order so iteration order is deterministic.
  for (const cat of catalogCategoryOrder) {
    map.set(cat, []);
  }

  for (const entry of catalogEntries) {
    const list = map.get(entry.category);
    if (list) {
      list.push(entry);
    }
  }

  // Remove empty categories.
  for (const [cat, list] of map) {
    if (list.length === 0) {
      map.delete(cat);
    }
  }

  // Stable, predictable order within each section (title A→Z).
  for (const list of map.values()) {
    list.sort((a, b) =>
      a.title.localeCompare(b.title, 'en', { sensitivity: 'base' }),
    );
  }

  return map;
}
