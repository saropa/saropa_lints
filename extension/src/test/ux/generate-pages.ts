/**
 * UX harness page generator.
 *
 * Imports the real editor-dashboard HTML builders, feeds them representative
 * fixtures, and writes standalone HTML files (one per page x theme) that plain
 * Chromium can load. The Playwright spec then renders and audits these files.
 *
 * register-vscode-mock MUST be the first import: several builders transitively
 * import 'vscode', and the mock redirects that to the local stub so this runs
 * outside the VS Code host.
 */
import '../vibrancy/register-vscode-mock';

import * as fs from 'node:fs';
import * as path from 'node:path';

import { THEMES, wrapForHarness } from './theme-shim';
import { buildReportHtml, type ReportOptions } from '../../vibrancy/views/report-html';
import { buildPackageDetailBody } from '../../vibrancy/views/package-detail-html';
import { buildComparisonHtml } from '../../vibrancy/views/comparison-html';
import { rankPackages } from '../../vibrancy/scoring/comparison-ranker';
import { buildPackageDetailHtml } from '../../vibrancy/views/package-detail-html';
import { buildKnownIssuesHtml } from '../../vibrancy/views/known-issues-html';
import { renderViolationsDashboardHtml } from '../../views/violationsDashboardHtml';
import type { VibrancyResult, ComparisonData } from '../../vibrancy/types';
// Phase 7 additions: the three brand-new Phase 3/4/6 surfaces had zero visual-harness coverage
// before this pass (tsc + unit tests only). Home hub and Rules & Tiers are pure builders (data in,
// HTML string out) so they slot into the existing fixture pattern directly. Project Map's shell
// needs a `vscode.Webview`-shaped stub only for its `cspSource` field, and Rules & Tiers needs a
// real project root on disk (it reads pubspec.yaml / analysis_options*.yaml directly, not through
// an injectable seam) — this repo's own root satisfies that, the same way other fixtures below use
// real ranking/scoring code rather than re-mocking it.
import { buildShell, type HomeCardSummaries } from '../../views/saropaDashboardsView';
import type { HomeKpis } from '../../views/dashboardSummaries';
import { RulePacksWebviewProvider } from '../../rulePacks/rulePacksWebviewProvider';
import { buildShellHtml as buildProjectMapShellHtml, buildScanningMapPaneHtml } from '../../views/projectMapShell';
import { buildReportsTabHtml } from '../../views/projectMapReports';
import { mockWorkspaceFolders } from '../vibrancy/vscode-mock';
import type * as vscode from 'vscode';
// Style-system migration pass (plan §1.5 "one design system"): the audit report had ZERO visual
// harness coverage before this pass (only `deferredPayload.test.ts`, which tests the temp-file
// write path, never the rendered HTML). Adding it here is how this migration gets a real
// Chromium/axe-core check instead of relying on tsc + eyeballing the diff.
import { buildAuditReportHtml } from '../../audit/audit-report-html';

const OUT_DIR = path.resolve(__dirname, '../../../test-ux/.pages');

/* ---------------------------------------------------------------- fixtures */

function makeResult(
  name: string,
  score: number,
  category: VibrancyResult['category'] = 'vibrant',
  extra: Partial<VibrancyResult> = {},
): VibrancyResult {
  return {
    package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
    pubDev: {
      name,
      latestVersion: '1.4.2',
      publishedDate: '2025-06-01T00:00:00Z',
      repositoryUrl: 'https://github.com/example/' + name,
      isDiscontinued: false,
      isUnlisted: false,
      pubPoints: 140,
      publisher: 'verified.dev',
      license: 'BSD-3-Clause',
      description: 'A representative package used by the UX render harness.',
      topics: ['network', 'http'],
      dependencies: [],
    },
    github: {
      stars: 4200, openIssues: 35, closedIssuesLast90d: 80,
      mergedPrsLast90d: 40, avgCommentsPerIssue: 2.1,
      daysSinceLastUpdate: 4, daysSinceLastClose: 2, flaggedIssues: [], license: null,
    },
    knownIssue: null,
    score,
    category,
    resolutionVelocity: 60,
    engagementLevel: 50,
    popularity: 70,
    publisherTrust: 10,
    updateInfo: null,
    archiveSizeBytes: 240_000,
    codeSizeBytes: 180_000,
    folderBreakdown: null,
    maintainerQuality: null,
    maintainerQualityBonus: 0,
    bloatRating: 3,
    license: 'BSD-3-Clause',
    isUnused: false,
    fileUsages: [],
    platforms: ['android', 'ios', 'web'],
    verifiedPublisher: true,
    wasmReady: true,
    blocker: null,
    upgradeBlockStatus: 'up-to-date',
    transitiveInfo: null,
    alternatives: [],
    latestPrerelease: null,
    prereleaseTag: null,
    vulnerabilities: [],
    versionGap: null,
    overrideGap: null,
    replacementComplexity: null,
    likes: 980,
    downloadCount30Days: 1_250_000,
    reverseDependencyCount: 320,
    readme: null,
    ...extra,
  };
}

/** A populated mix across the grade spectrum so the table + cards + chart fill. */
function reportFixture(): ReportOptions {
  const results: VibrancyResult[] = [
    makeResult('http', 92, 'vibrant'),
    makeResult('provider', 81, 'vibrant'),
    makeResult('intl', 64, 'stable'),
    makeResult('flutter_svg', 48, 'outdated', { isUnused: true }),
    makeResult('old_skool', 22, 'abandoned'),
    makeResult('legacy_dep', 11, 'end-of-life'),
  ];
  return { results, overrideCount: 1, overrideNames: new Set(['intl']), pubspecUri: null, extensionVersion: '13.12.7' };
}

function makePackage(overrides: Partial<ComparisonData>): ComparisonData {
  return {
    name: 'test-pkg', vibrancyScore: 75, category: 'vibrant', latestVersion: '1.0.0',
    publishedDate: '2026-01-15', publisher: 'verified.dev', pubPoints: 130, stars: 1500,
    openIssues: 20, archiveSizeBytes: 120_000, codeSizeBytes: 90_000, bloatRating: 3,
    license: 'MIT', platforms: ['android', 'ios', 'web'], inProject: false, ...overrides,
  };
}

function comparisonFixture() {
  return rankPackages([
    makePackage({ name: 'http', vibrancyScore: 92, stars: 4200, inProject: true }),
    makePackage({ name: 'dio', vibrancyScore: 84, stars: 12000, archiveSizeBytes: 320_000 }),
    makePackage({ name: 'chopper', vibrancyScore: 61, category: 'stable', stars: 900 }),
  ]);
}

function violationsEmptyFixture() {
  return {
    exportViolations: [], totalRawAfterDisable: 0, filteredCount: 0, truncatedSource: false,
    maxSourceViolations: 4000, pageSize: 50, groupBy: 'severity' as const, textFilter: '',
    severities: ['error', 'warning', 'info'], impacts: ['error', 'warning', 'info'],
    sections: [],
    analyzerSuppressions: { total: 0, byKind: [], byRule: [], byFile: [] },
    viewSuppressions: {
      active: false, folderCount: 0, fileCount: 0, ruleCount: 0, ruleInFileEntryCount: 0,
      severityCount: 0, impactCount: 0, sampleFolders: [], sampleFiles: [], sampleRules: [],
      sampleRuleInFileLines: [],
    },
    todoHackSnapshot: { enabled: false, capped: false, todos: [], hacks: [] },
    driftAdvisorSnapshot: { integrationEnabled: false, connected: false, issues: [] as [] },
    severityCounts: { error: 0, warning: 0, info: 0 },
    impactCounts: { error: 0, warning: 0, info: 0 },
  };
}

/** Home hub fixture: a populated KPI band (not the "not scanned" empty state, which
 *  `saropaDashboardsView.test.ts` already pins) plus one representative body string per card. */
function homeKpisFixture(): HomeKpis {
  return {
    healthScore: 82,
    issueCount: 143,
    enginesRunning: 2,
    enginesTotal: 3,
    packagesTotal: 40,
    packagesAttention: 3,
    codeHealthGrade: 'B',
    projectMapScanned: true,
  };
}

function homeCardsFixture(): HomeCardSummaries {
  return {
    findings: '<div class="summary-grid"><span class="metric">143 issues</span></div>',
    rulesAndTiers: '<div class="summary-grid"><span class="metric">Recommended tier</span></div>',
    packages: '<div class="summary-grid"><span class="metric">40 packages · 3 need attention</span></div>',
    codeHealth: '<div class="summary-grid"><span class="metric">Grade B</span></div>',
    projectMap: '<div class="summary-grid"><span class="metric">Last scanned 2h ago</span></div>',
    fullAudit: '<p class="summary-empty">Not run yet.</p>',
  };
}

/**
 * Rules & Tiers fixture. `_buildHtml()`/`_activeTab` are private — the class was designed to be
 * driven through the panel lifecycle (`openEditorPanel()` / postMessage), not rendered statically.
 * Reading them via a cast is the same escape hatch the harness already needs for any builder that
 * was not written with a pure "state in, HTML out" seam; documented here rather than silently
 * reaching past `private` with no explanation. `_buildHtml()` reads pubspec.yaml and
 * analysis_options*.yaml straight off disk via `getProjectRoot()` (no injectable data layer), so
 * the workspace-folder mock below points at THIS repo's own root — it has both files already,
 * making it a real, not fabricated, fixture (same spirit as reusing real ranking code elsewhere in
 * this file rather than re-mocking it).
 */
function buildRulesAndTiersTabHtml(tab: 'tier' | 'configFile'): string {
  const repoRoot = path.resolve(__dirname, '../../../..');
  mockWorkspaceFolders.value = [{ uri: { fsPath: repoRoot } }];
  const provider = new RulePacksWebviewProvider({ fsPath: repoRoot } as unknown as vscode.Uri);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- see doc comment above.
  (provider as any)._activeTab = tab;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- see doc comment above.
  const html: string = (provider as any)._buildHtml();
  mockWorkspaceFolders.value = undefined;
  return html;
}

/** Minimal stand-in for `vscode.Webview` — `buildShellHtml` only reads `.cspSource`. */
const FAKE_WEBVIEW = { cspSource: 'vscode-resource:' } as unknown as vscode.Webview;

/** A small populated audit JSON payload: a few diagnostics across every severity + a baseline,
 *  so the hero, chip-strip KPIs, filter chips, and severity-tinted table rows all render. */
function auditReportFixture(): Record<string, unknown> {
  const diagnostics = [
    { filePath: '/proj/lib/a.dart', line: 12, column: 3, ruleName: 'avoid_print', severity: 'warning', impact: 'medium', tier: 'recommended', problemMessage: 'Avoid print() in production code.', correctionMessage: null, baselineStatus: 'new' },
    { filePath: '/proj/lib/b.dart', line: 40, column: 1, ruleName: 'missing_doc', severity: 'info', impact: 'low', tier: 'pedantic', problemMessage: 'Public API member is missing documentation.', correctionMessage: null, baselineStatus: 'unchanged' },
    { filePath: '/proj/lib/c.dart', line: 7, column: 10, ruleName: 'unsafe_cast', severity: 'error', impact: 'critical', tier: 'essential', problemMessage: 'Unchecked cast may throw at runtime.', correctionMessage: null, baselineStatus: 'unchanged' },
  ];
  return {
    timestamp: '2026-09-04T00:00:00Z',
    diagnostics,
    summary: { totalCount: diagnostics.length },
    baseline: { comparedTo: '2026-09-01', new: 1, unchanged: 2 },
  };
}

/* ------------------------------------------------------------------- pages */

const PAGES: Array<{ name: string; html: () => string }> = [
  { name: 'package-dashboard', html: () => buildReportHtml(reportFixture()) },
  // Master-detail: the dashboard with the docked pane populated, simulating the
  // host round-trip (selection -> rendered detail injected into the pane).
  {
    name: 'package-dashboard-detail',
    html: () => {
      const detail = buildPackageDetailBody(makeResult('http', 92), [], null, undefined, { paneMode: true });
      return buildReportHtml(reportFixture())
        .replace('tabindex="-1" hidden>', 'tabindex="-1">')
        .replace('<div id="detail-pane-body"></div>', `<div id="detail-pane-body">${detail}</div>`);
    },
  },
  { name: 'comparison', html: () => buildComparisonHtml(comparisonFixture()) },
  { name: 'package-detail', html: () => buildPackageDetailHtml(makeResult('http', 92), [], null) },
  { name: 'known-issues', html: () => buildKnownIssuesHtml() },
  { name: 'findings-empty', html: () => renderViolationsDashboardHtml(violationsEmptyFixture()) },
  // Phase 7: previously-uncovered Phase 3/4/6 surfaces (see the import comment above).
  { name: 'home-hub', html: () => buildShell('vscode-resource:', homeKpisFixture(), homeCardsFixture()) },
  { name: 'rules-and-tiers-tier', html: () => buildRulesAndTiersTabHtml('tier') },
  { name: 'rules-and-tiers-config-file', html: () => buildRulesAndTiersTabHtml('configFile') },
  {
    name: 'project-map-scanning',
    html: () => buildProjectMapShellHtml(FAKE_WEBVIEW, buildScanningMapPaneHtml(), buildReportsTabHtml()),
  },
  // Same document, but with the Reports tab flipped active (mirrors the package-dashboard-detail
  // trick above) — otherwise the Reports pane sits behind `hidden` and never gets measured for
  // overflow/contrast, defeating the point of adding it as a fixture.
  {
    name: 'project-map-reports',
    html: () =>
      buildProjectMapShellHtml(FAKE_WEBVIEW, buildScanningMapPaneHtml(), buildReportsTabHtml())
        .replace('id="pmTabBtnMap" data-tab="map" role="tab" aria-selected="true"', 'id="pmTabBtnMap" data-tab="map" role="tab" aria-selected="false"')
        .replace('id="pmTabBtnReports" data-tab="reports" role="tab" aria-selected="false"', 'id="pmTabBtnReports" data-tab="reports" role="tab" aria-selected="true"')
        .replace('id="pmTabMap" class="pm-tab-panel"', 'id="pmTabMap" class="pm-tab-panel" hidden')
        .replace('id="pmTabReports" class="pm-tab-panel" role="tabpanel" aria-labelledby="pmTabBtnReports" hidden', 'id="pmTabReports" class="pm-tab-panel" role="tabpanel" aria-labelledby="pmTabBtnReports"'),
  },
  // Style-system migration: first-ever visual-harness coverage for the Full Audit report, now
  // rebuilt on the canonical chrome (dash-hero/chip-strip/toolbar-band/dash-table) — see the
  // import comment above.
  {
    name: 'audit-report',
    html: () =>
      buildAuditReportHtml(auditReportFixture(), {
        webview: FAKE_WEBVIEW,
        root: '/proj',
        deferredUri: null,
        serializedDiagnostics: null,
      }),
  },
];

function main(): void {
  fs.rmSync(OUT_DIR, { recursive: true, force: true });
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const manifest: Array<{ name: string; theme: string; file: string }> = [];
  for (const page of PAGES) {
    let base: string;
    try {
      base = page.html();
    } catch (err) {
      console.error(`FAILED to build ${page.name}:`, err);
      throw err;
    }
    for (const theme of THEMES) {
      const file = `${page.name}.${theme}.html`;
      fs.writeFileSync(path.join(OUT_DIR, file), wrapForHarness(base, theme), 'utf8');
      manifest.push({ name: page.name, theme, file });
    }
  }
  fs.writeFileSync(path.join(OUT_DIR, 'manifest.json'), JSON.stringify(manifest, null, 2), 'utf8');
  console.log(`Generated ${manifest.length} pages in ${OUT_DIR}`);
}

main();
