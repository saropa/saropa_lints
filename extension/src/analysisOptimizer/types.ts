// Per-file metrics computed by scanner.ts and used to score how expensive
// a folder is to keep in the analyzer's active set.
export interface FileAnalysisMetrics {
  relativePath: string;
  lineCount: number;
  classCount: number;
  functionCount: number;
  importCount: number;
  hasWidgets: boolean;
  hasAsyncCode: boolean;
  isGenerated: boolean;
  daysSinceLastEdit?: number;
}

// Aggregated cost for one folder, used to rank exclude-pattern candidates
// by how much analyzer load they'd remove.
export interface FolderAnalysisCost {
  folderPath: string;
  fileCount: number;
  totalLines: number;
  totalCost: number;
  generatedFileCount: number;
  recentEditRatio: number;
  excludePattern: string;
}

// A single proposed (or already-applied) exclude pattern row shown in the
// Analysis Optimizer panel's recommendations table.
export interface ExclusionRow {
  pattern: string;
  reason: string;
  estimatedFilesExcluded: number;
  estimatedCostReduction: number;
  hasActiveFiles: boolean;
  priority: 'high' | 'medium' | 'low';
  isDefault: boolean;
  isApplied: boolean;
}

// Full scan result rendered by the panel: totals plus per-folder costs
// and the derived exclusion recommendations.
export interface AnalysisOptimizerResult {
  totalFiles: number;
  totalLines: number;
  totalCost: number;
  folders: FolderAnalysisCost[];
  exclusions: ExclusionRow[];
  scanTimestamp: string;
}
