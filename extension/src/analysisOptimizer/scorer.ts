import type {
  FileAnalysisMetrics,
  FolderAnalysisCost,
  ExclusionRecommendation,
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

function isPatternCovered(
  pattern: string,
  existing: string[],
): boolean {
  return existing.some(e => e === pattern || pattern.startsWith(e.replace('/**', '/')));
}

export function generateRecommendations(
  folders: FolderAnalysisCost[],
  files: FileAnalysisMetrics[],
  currentExclusions: string[],
): ExclusionRecommendation[] {
  const recs: ExclusionRecommendation[] = [];

  for (const def of DEFAULT_EXCLUSION_PATTERNS) {
    if (isPatternCovered(def.pattern, currentExclusions)) continue;

    const isGlob = def.pattern.startsWith('**/*.');
    const suffix = isGlob ? def.pattern.replace('**/*/','').replace('**/*.', '.') : null;
    const isDirGlob = def.pattern.endsWith('/**');
    const dirPrefix = isDirGlob ? def.pattern.replace('/**', '') : null;

    let matchCount = 0;
    let matchCost = 0;
    let hasActive = false;

    for (const f of files) {
      const matches = suffix
        ? f.relativePath.endsWith(suffix)
        : dirPrefix
          ? f.relativePath.startsWith(dirPrefix + '/')
          : false;
      if (matches) {
        matchCount++;
        matchCost += computeFileCost(f);
        if (f.daysSinceLastEdit !== undefined && f.daysSinceLastEdit <= 7) {
          hasActive = true;
        }
      }
    }

    if (matchCount > 0) {
      recs.push({
        pattern: def.pattern,
        reason: def.reason,
        estimatedFilesExcluded: matchCount,
        estimatedCostReduction: matchCost,
        hasActiveFiles: hasActive,
        priority: 'high',
        isDefault: true,
      });
    }
  }

  for (const folder of folders) {
    if (PROTECTED_FOLDERS.has(folder.folderPath)) continue;
    if (isPatternCovered(folder.excludePattern, currentExclusions)) continue;
    if (recs.some(r => r.pattern === folder.excludePattern)) continue;
    if (folder.fileCount < 3) continue;

    const isInactive = folder.recentEditRatio < 0.1;
    const isMostlyGenerated = folder.generatedFileCount / folder.fileCount > 0.5;

    if (!isInactive && !isMostlyGenerated) continue;

    recs.push({
      pattern: folder.excludePattern,
      reason: isMostlyGenerated
        ? `${folder.generatedFileCount}/${folder.fileCount} files are generated code`
        : `${Math.round((1 - folder.recentEditRatio) * 100)}% of files have no recent edits`,
      estimatedFilesExcluded: folder.fileCount,
      estimatedCostReduction: folder.totalCost,
      hasActiveFiles: folder.recentEditRatio > 0,
      priority: isMostlyGenerated ? 'high' : isInactive ? 'medium' : 'low',
      isDefault: false,
    });
  }

  recs.sort((a, b) => {
    const pri = { high: 0, medium: 1, low: 2 };
    if (pri[a.priority] !== pri[b.priority]) return pri[a.priority] - pri[b.priority];
    return b.estimatedCostReduction - a.estimatedCostReduction;
  });

  return recs;
}
