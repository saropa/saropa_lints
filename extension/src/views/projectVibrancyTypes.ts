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

/**
 * One live scan event emitted by `project_vibrancy --progress` (NDJSON on
 * stderr). `phase`/`tick` drive the progress bar + current-file line; `row`
 * streams a bounded sample of problem functions into the live preview; `done`
 * signals the dashboard can flip from the scanning view to the full report.
 */
export interface VibrancyScanEvent {
  readonly event: 'meta' | 'phase' | 'tick' | 'row' | 'done';
  readonly phase?: string;
  readonly done?: number;
  readonly total?: number;
  readonly file?: string;
  readonly functions?: number;
  readonly grade?: string;
  readonly score?: number;
  readonly name?: string;
  readonly line?: number;
  readonly complexity?: number;
  readonly flags?: readonly string[];
  readonly version?: string; // engine (scanned project's saropa_lints) version, from the 'meta' event
}

/** Pause/resume/cancel handle for an in-flight streaming scan (control file backed). */
export interface VibrancyScanControl {
  pause(): void;
  resume(): void;
  cancel(): void;
}

/** Optional streaming hooks; when supplied the scan runs with `--progress`/`--control`. */
export interface VibrancyScanHandlers {
  readonly onEvent?: (event: VibrancyScanEvent) => void;
  readonly onControl?: (control: VibrancyScanControl) => void;
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
