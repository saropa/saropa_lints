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
