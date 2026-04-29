/** JSON payload types produced by the project_vibrancy CLI for the extension webviews. */

export interface ProjectVibrancyFunctionRow {
  readonly file: string;
  readonly name: string;
  readonly lineStart: number;
  readonly lineEnd: number;
  readonly score: number;
  readonly grade: string;
  readonly category: string;
  readonly usageCount: number;
  readonly coveragePercent: number;
  readonly complexity: number;
  readonly flags: readonly string[];
}

export interface ProjectVibrancyGateViolation {
  readonly gate?: string;
  readonly message?: string;
  readonly expected?: unknown;
  readonly actual?: unknown;
}

export interface ProjectVibrancyGates {
  readonly pass?: boolean;
  readonly violations?: readonly ProjectVibrancyGateViolation[];
}

export interface ProjectVibrancyPayload {
  readonly gates?: ProjectVibrancyGates;
  readonly summary?: {
    readonly functionCount?: number;
    readonly averageScore?: number;
    readonly averageGrade?: string;
    readonly unusedCount?: number;
    readonly uncoveredCount?: number;
    readonly stubTestedCount?: number;
    readonly suspiciousCoverageCount?: number;
    readonly testDriftCount?: number;
  };
  readonly generatedAt?: string;
  readonly determinism?: {
    readonly since?: string | null;
  };
  readonly functions?: readonly ProjectVibrancyFunctionRow[];
}
