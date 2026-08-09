import type {
  FileAnalysisMetrics,
  FolderAnalysisCost,
  ExclusionRow,
} from './types';

const PROTECTED_FOLDERS = new Set(['lib', 'lib/src', 'bin']);

const DEFAULT_EXCLUSION_PATTERNS: { pattern: string; reason: string }[] = [
  { pattern: '**/*.g.dart', reason: 'Code-generated build_runner output' },
  { pattern: '**/*.freezed.dart', reason: 'Freezed-generated data classes' },
  { pattern: '**/*.mocks.dart', reason: 'Mockito-generated mocks' },
  { pattern: '**/*.gr.dart', reason: 'Auto-route generated files' },
  { pattern: '**/*.chopper.dart', reason: 'Chopper-generated API clients' },
  { pattern: '**/*.graphql.dart', reason: 'GraphQL-generated types' },
  { pattern: 'build/**', reason: 'Build output directory' },
  { pattern: '.dart_tool/**', reason: 'Dart tooling cache' },
];

export function computeFileCost(m: FileAnalysisMetrics): number {
  const base = m.lineCount
    + m.classCount * 50
    + m.functionCount * 20
    + m.importCount * 10;
  const widgetMultiplier = m.hasWidgets ? 1.3 : 1.0;
  return Math.round(base * widgetMultiplier);
}

export function aggregateByFolder(
  files: FileAnalysisMetrics[],
): FolderAnalysisCost[] {
  const groups = new Map<string, FileAnalysisMetrics[]>();

  for (const f of files) {
    const parts = f.relativePath.split('/');
    const folder = parts.length <= 1
      ? '.'
      : parts.slice(0, Math.min(parts.length - 1, 2)).join('/');
    const list = groups.get(folder);
    if (list) {
      list.push(f);
    } else {
      groups.set(folder, [f]);
    }
  }

  const result: FolderAnalysisCost[] = [];
  for (const [folderPath, groupFiles] of groups) {
    let totalLines = 0;
    let totalCost = 0;
    let generatedFileCount = 0;
    let recentCount = 0;

    for (const f of groupFiles) {
      totalLines += f.lineCount;
      totalCost += computeFileCost(f);
      if (f.isGenerated) generatedFileCount++;
      if (f.daysSinceLastEdit !== undefined && f.daysSinceLastEdit <= 30) {
        recentCount++;
      }
    }

    result.push({
      folderPath,
      fileCount: groupFiles.length,
      totalLines,
      totalCost,
      generatedFileCount,
      recentEditRatio: groupFiles.length > 0 ? recentCount / groupFiles.length : 0,
      excludePattern: folderPath === '.' ? '*.dart' : `${folderPath}/**`,
    });
  }

  result.sort((a, b) => b.totalCost - a.totalCost);
  return result;
}

/**
 * Estimates how many scanned files a glob pattern would remove from analysis
 * and their combined cost. Understands the two glob shapes the optimizer
 * itself generates (`**\/*.ext` suffix globs, `dir/**` directory globs) plus
 * an exact-path fallback for arbitrary hand-written patterns (e.g. a single
 * excluded file) — good enough to size an already-applied exclusion the
 * optimizer didn't generate, without a full glob-matching dependency.
 */
export function matchExclusionPattern(
  files: FileAnalysisMetrics[],
  pattern: string,
): { filesMatched: number; costMatched: number; hasActiveFiles: boolean } {
  const suffixMatch = /^\*\*\/\*(\.[\w.]+)$/.exec(pattern);
  const dirPrefix = pattern.endsWith('/**') ? pattern.slice(0, -3) : null;

  let filesMatched = 0;
  let costMatched = 0;
  let hasActiveFiles = false;

  for (const f of files) {
    const matches = suffixMatch
      ? f.relativePath.endsWith(suffixMatch[1])
      : dirPrefix !== null
        ? f.relativePath === dirPrefix || f.relativePath.startsWith(`${dirPrefix}/`)
        : f.relativePath === pattern;
    if (matches) {
      filesMatched++;
      costMatched += computeFileCost(f);
      if (f.daysSinceLastEdit !== undefined && f.daysSinceLastEdit <= 7) {
        hasActiveFiles = true;
      }
    }
  }

  return { filesMatched, costMatched, hasActiveFiles };
}

const PRIORITY_RANK = { high: 0, medium: 1, low: 2 } as const;

/**
 * Builds the unified exclusions table: every pattern the optimizer would
 * recommend (default generated-code/build patterns plus folder-based
 * candidates), each tagged with whether it's already applied, PLUS any
 * currently-applied pattern that doesn't match a generated candidate at all
 * (a hand-added entry in analysis_options.yaml) so nothing in the file is
 * hidden from the table.
 */
export function buildExclusionRows(
  folders: FolderAnalysisCost[],
  files: FileAnalysisMetrics[],
  currentExclusions: string[],
): ExclusionRow[] {
  const appliedSet = new Set(currentExclusions);
  const rows: ExclusionRow[] = [];
  const seenPatterns = new Set<string>();

  for (const def of DEFAULT_EXCLUSION_PATTERNS) {
    const { filesMatched, costMatched, hasActiveFiles } = matchExclusionPattern(files, def.pattern);
    const isApplied = appliedSet.has(def.pattern);
    if (filesMatched === 0 && !isApplied) continue;

    seenPatterns.add(def.pattern);
    rows.push({
      pattern: def.pattern,
      reason: def.reason,
      estimatedFilesExcluded: filesMatched,
      estimatedCostReduction: costMatched,
      hasActiveFiles,
      priority: 'high',
      isDefault: true,
      isApplied,
    });
  }

  for (const folder of folders) {
    if (PROTECTED_FOLDERS.has(folder.folderPath)) continue;
    if (seenPatterns.has(folder.excludePattern)) continue;
    if (folder.fileCount < 3) continue;

    const isApplied = appliedSet.has(folder.excludePattern);
    const isInactive = folder.recentEditRatio < 0.1;
    const isMostlyGenerated = folder.generatedFileCount / folder.fileCount > 0.5;

    if (!isApplied && !isInactive && !isMostlyGenerated) continue;

    seenPatterns.add(folder.excludePattern);
    rows.push({
      pattern: folder.excludePattern,
      reason: isMostlyGenerated
        ? `${folder.generatedFileCount}/${folder.fileCount} files are generated code`
        : `${Math.round((1 - folder.recentEditRatio) * 100)}% of files have no recent edits`,
      estimatedFilesExcluded: folder.fileCount,
      estimatedCostReduction: folder.totalCost,
      hasActiveFiles: folder.recentEditRatio > 0,
      priority: isMostlyGenerated ? 'high' : isInactive ? 'medium' : 'low',
      isDefault: false,
      isApplied,
    });
  }

  // Any applied pattern that isn't one of the optimizer's own generated
  // candidates (a hand-added entry in analysis_options.yaml) still belongs
  // in the table — the consolidated view must never hide an existing
  // exclusion just because the optimizer didn't think to suggest it.
  for (const pattern of currentExclusions) {
    if (seenPatterns.has(pattern)) continue;
    seenPatterns.add(pattern);
    const { filesMatched, costMatched, hasActiveFiles } = matchExclusionPattern(files, pattern);
    rows.push({
      pattern,
      reason: 'Existing exclusion in analysis_options.yaml',
      estimatedFilesExcluded: filesMatched,
      estimatedCostReduction: costMatched,
      hasActiveFiles,
      priority: 'low',
      isDefault: false,
      isApplied: true,
    });
  }

  rows.sort((a, b) => {
    if (a.isApplied !== b.isApplied) return a.isApplied ? 1 : -1;
    if (PRIORITY_RANK[a.priority] !== PRIORITY_RANK[b.priority]) {
      return PRIORITY_RANK[a.priority] - PRIORITY_RANK[b.priority];
    }
    return b.estimatedCostReduction - a.estimatedCostReduction;
  });

  return rows;
}
