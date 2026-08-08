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

export interface FolderAnalysisCost {
  folderPath: string;
  fileCount: number;
  totalLines: number;
  totalCost: number;
  generatedFileCount: number;
  recentEditRatio: number;
  excludePattern: string;
}

export interface ExclusionRecommendation {
  pattern: string;
  reason: string;
  estimatedFilesExcluded: number;
  estimatedCostReduction: number;
  hasActiveFiles: boolean;
  priority: 'high' | 'medium' | 'low';
  isDefault: boolean;
}

export interface AnalysisOptimizerResult {
  totalFiles: number;
  totalLines: number;
  totalCost: number;
  folders: FolderAnalysisCost[];
  recommendations: ExclusionRecommendation[];
  currentExclusions: string[];
  scanTimestamp: string;
}
