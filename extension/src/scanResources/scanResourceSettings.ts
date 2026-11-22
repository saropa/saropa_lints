/**
 * Scan resource settings: performance profiles, explicit overrides, and how
 * they resolve against the machine into a concrete worker count and memory
 * budget for the Dart scan CLI (`--jobs` / `--max-memory-mb`).
 *
 * Mirrors the sizing in `lib/src/scan/scan_jobs.dart` (300 MB per syntactic
 * worker, 300 MB parent overhead, at most half of what is free) so what the
 * extension asks for and what the CLI would pick for itself agree.
 *
 * Pure: no `vscode` import. The thin config reader lives in
 * `scanResourceConfig.ts`.
 */
import type { MachineSnapshot } from './machineResources';

export type PerformanceProfile = 'gentle' | 'balanced' | 'fast';
export type BaselineMode = 'fast' | 'deep';

export const DEFAULT_PROFILE: PerformanceProfile = 'balanced';
export const DEFAULT_BASELINE_MODE: BaselineMode = 'fast';

/** Memory one syntactic scan worker is budgeted, in MB (matches the CLI). */
export const WORKER_MEMORY_MB = 300;
/** Fixed parent-process overhead, in MB (matches the CLI). */
export const PARENT_MEMORY_MB = 300;
/** Hard ceiling for any configured/derived worker count. */
export const MAX_WORKERS = 32;
/** Below this many files per worker the startup cost outweighs the gain. */
export const MIN_FILES_PER_WORKER = 50;

export interface ScanResourceSettings {
  readonly profile: PerformanceProfile;
  /** 0 = automatic (from the profile). */
  readonly maxWorkers: number;
  /** 0 = automatic (from the profile). */
  readonly maxMemoryMb: number;
  /** Run scan processes at reduced CPU priority. */
  readonly lowPriority: boolean;
  readonly baselineMode: BaselineMode;
  /** Show notifications when the scan throttles or the machine is tight. */
  readonly notifyOnPressure: boolean;
  /** Cap on non-error issues per scan; 0 = unlimited (errors are never capped). */
  readonly maxIssues: number;
}

export const DEFAULT_SETTINGS: ScanResourceSettings = {
  profile: DEFAULT_PROFILE,
  maxWorkers: 0,
  maxMemoryMb: 0,
  lowPriority: true,
  baselineMode: DEFAULT_BASELINE_MODE,
  notifyOnPressure: true,
  maxIssues: 0,
};

function toInt(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, Math.round(value)));
}

/**
 * Sanitizes raw configuration values. A hand-edited `settings.json` with a
 * string, a negative number or `NaN` degrades to the default rather than
 * breaking scanning (this runs inside save handlers).
 */
export function normalizeScanResourceSettings(raw: {
  profile?: unknown;
  maxWorkers?: unknown;
  maxMemoryMb?: unknown;
  lowPriority?: unknown;
  baselineMode?: unknown;
  notifyOnPressure?: unknown;
  maxIssues?: unknown;
}): ScanResourceSettings {
  const profile: PerformanceProfile =
    raw.profile === 'gentle' || raw.profile === 'balanced' || raw.profile === 'fast'
      ? raw.profile
      : DEFAULT_SETTINGS.profile;
  const baselineMode: BaselineMode =
    raw.baselineMode === 'deep' || raw.baselineMode === 'fast'
      ? raw.baselineMode
      : DEFAULT_SETTINGS.baselineMode;
  return {
    profile,
    maxWorkers: toInt(raw.maxWorkers, 0, MAX_WORKERS, 0),
    // 0 means automatic; any positive value below 256 MB cannot run a worker.
    maxMemoryMb: ((): number => {
      const v = toInt(raw.maxMemoryMb, 0, 1_048_576, 0);
      return v > 0 && v < 256 ? 256 : v;
    })(),
    lowPriority: typeof raw.lowPriority === 'boolean' ? raw.lowPriority : true,
    baselineMode,
    notifyOnPressure: typeof raw.notifyOnPressure === 'boolean' ? raw.notifyOnPressure : true,
    maxIssues: toInt(raw.maxIssues, 0, 10_000_000, 0),
  };
}

/** Per-profile sizing knobs. */
interface ProfileShape {
  /** Cores left free for the editor and the rest of the machine. */
  readonly spareCores: number;
  /** Upper bound on workers regardless of core count. */
  readonly workerCeiling: number;
  /** Fraction of currently free memory the scan may plan to use. */
  readonly memoryFraction: number;
}

export const PROFILE_SHAPES: Readonly<Record<PerformanceProfile, ProfileShape>> = {
  // Stays out of the way: a couple of workers, a quarter of free memory.
  gentle: { spareCores: 2, workerCeiling: 2, memoryFraction: 0.25 },
  // Recommended default: leaves a core free, half of free memory.
  balanced: { spareCores: 1, workerCeiling: 8, memoryFraction: 0.5 },
  // Finish sooner: every core but none spare, 70% of free memory.
  fast: { spareCores: 0, workerCeiling: 16, memoryFraction: 0.7 },
};

export interface ResolvedScanResources {
  /** Worker count to pass as `--jobs` (>= 1). */
  readonly jobs: number;
  /** Memory budget to pass as `--max-memory-mb`. */
  readonly maxMemoryMb: number;
  /** Which constraint decided {@link jobs}. */
  readonly limitedBy: 'setting' | 'cpu' | 'memory' | 'files' | 'ceiling';
}

/**
 * Resolves settings against the machine for a scan of [fileCount] files.
 * Always returns at least one worker and a memory budget that can hold it.
 */
export function resolveScanResources(
  settings: ScanResourceSettings,
  machine: MachineSnapshot,
  fileCount: number,
): ResolvedScanResources {
  const shape = PROFILE_SHAPES[settings.profile];

  // Memory budget: explicit setting, else a profile fraction of what is free.
  const autoMemory = Math.max(
    512,
    Math.floor(machine.freeMb * shape.memoryFraction),
  );
  const maxMemoryMb = settings.maxMemoryMb > 0 ? settings.maxMemoryMb : autoMemory;

  const candidates: Array<[ResolvedScanResources['limitedBy'], number]> = [
    ['cpu', machine.cores - shape.spareCores],
    ['ceiling', shape.workerCeiling],
    ['memory', Math.floor((maxMemoryMb - PARENT_MEMORY_MB) / WORKER_MEMORY_MB)],
    ['files', Math.floor(fileCount / MIN_FILES_PER_WORKER)],
  ];
  let best = candidates[0];
  for (const c of candidates) {
    if (c[1] < best[1]) best = c;
  }
  let jobs = Math.max(1, best[1]);
  let limitedBy = best[0];

  // An explicit worker count wins, but never beyond the hard ceiling or the
  // file count (a worker with nothing to do is pure overhead).
  if (settings.maxWorkers > 0) {
    jobs = Math.max(1, Math.min(settings.maxWorkers, MAX_WORKERS, Math.max(1, fileCount)));
    limitedBy = 'setting';
  }
  return { jobs, maxMemoryMb, limitedBy };
}

/** Rough memory the deep (type-aware daemon) scan needs, in MB. */
export const DEEP_SCAN_MEMORY_MB = 4096;
/** Measured deep-scan rate (files/second) used for time estimates. */
export const DEEP_SCAN_FILES_PER_SECOND = 3;

export interface DeepScanEstimate {
  readonly memoryMb: number;
  readonly minutes: number;
}

/** Estimates the deep scan's memory and duration for [fileCount] files. */
export function estimateDeepScan(fileCount: number): DeepScanEstimate {
  const seconds = fileCount / DEEP_SCAN_FILES_PER_SECOND;
  return {
    memoryMb: DEEP_SCAN_MEMORY_MB,
    minutes: Math.max(1, Math.round(seconds / 60)),
  };
}

/**
 * Whether the machine can host the deep scan right now: it needs its
 * estimated memory PLUS the reserve left free for everything else.
 */
export function canHostDeepScan(machine: MachineSnapshot, reserveMb: number): boolean {
  return machine.freeMb >= DEEP_SCAN_MEMORY_MB + reserveMb;
}
