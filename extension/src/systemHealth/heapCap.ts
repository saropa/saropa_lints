/**
 * Pure, vscode-free helpers for the Dart analysis server's VM heap cap
 * (`dart.analyzerVmAdditionalArgs` → `--old_gen_heap_size=<MB>`, see
 * `HEAP_CAP_FLAG` in `processQuery.ts`).
 *
 * Split out from the startup audit and the dashboard command so the
 * recommendation math, parsing, and scope-precedence logic are unit
 * testable without a live `vscode` host — the same separation
 * `machineDashboardData.ts` uses for the dashboard's own recommendations.
 *
 * **Why 40% / 50%:** the analysis server is one of several consumers on a
 * dev machine — the OS, VS Code itself, the Flutter daemon, and (for
 * saropa_lints workspaces) the scan daemon all need headroom at the same
 * time. Capping the analyzer at 40% of RAM leaves the other 60% for that
 * mix without the user having to reason about it; a cap above 50% is
 * flagged as too high because it leaves less than half the machine for
 * everything else, which is what caused the 2026-09 8 GB/6 GB incident.
 */
import { HEAP_CAP_FLAG } from './processQuery';

/** Bytes per megabyte (binary), matching the unit `--old_gen_heap_size` takes. */
const BYTES_PER_MB = 1024 * 1024;

/** Recommended cap as a fraction of total physical RAM. */
const RECOMMENDED_FRACTION = 0.4;
/** Cap value, as a fraction of total RAM, above which a cap is flagged "too high". */
const TOO_HIGH_FRACTION = 0.5;
/** Recommendations are rounded down to a multiple of this many MB. */
const ROUNDING_STEP_MB = 512;
/** Floor — below this, the analysis server would be too memory-starved to be useful. */
const MIN_RECOMMENDED_MB = 2048;
/** Ceiling — a bigger cap than this stops helping; old-gen GC pause times grow with heap size. */
const MAX_RECOMMENDED_MB = 8192;

/**
 * Recommend a heap cap, in MB, for a machine with `totalBytes` of physical
 * RAM: 40% of RAM, rounded down to a multiple of 512 MB, clamped to
 * [2048, 8192]. Examples: 8 GB → 3072, 16 GB → 6144, 32 GB+ → 8192.
 */
export function recommendHeapCapMb(totalBytes: number): number {
  const totalMb = totalBytes / BYTES_PER_MB;
  const raw = totalMb * RECOMMENDED_FRACTION;
  const rounded = Math.floor(raw / ROUNDING_STEP_MB) * ROUNDING_STEP_MB;
  return Math.min(MAX_RECOMMENDED_MB, Math.max(MIN_RECOMMENDED_MB, rounded));
}

/**
 * Parse the effective `--old_gen_heap_size` value, in MB, out of a
 * `dart.analyzerVmAdditionalArgs` array. If the flag appears more than
 * once (e.g. a stale copy left behind by a hand-edited settings file),
 * the last occurrence wins — that matches how the Dart VM itself resolves
 * duplicate flags. Returns `undefined` when the flag is absent or its
 * value isn't a positive number.
 */
export function parseHeapCapMb(args: readonly string[]): number | undefined {
  let result: number | undefined;
  for (const arg of args) {
    if (!arg.startsWith(HEAP_CAP_FLAG)) continue;
    const eq = arg.indexOf('=');
    if (eq === -1) continue;
    const mb = Number(arg.slice(eq + 1));
    if (Number.isFinite(mb) && mb > 0) {
      result = mb;
    }
  }
  return result;
}

/** Inputs to {@link assessHeapCap}. */
export interface HeapCapAssessmentInput {
  /** The effective cap, in MB, from {@link parseHeapCapMb}, or `undefined` if none is set. */
  capMb: number | undefined;
  /** Total physical RAM, in bytes (`os.totalmem()`). */
  totalBytes: number;
}

/**
 * `'none'` — no cap is set, so the server can grow unbounded.
 * `'tooHigh'` — a cap is set but leaves less than half the machine's RAM
 * for everything else.
 * `'ok'` — a cap is set and leaves at least half the machine's RAM free.
 */
export type HeapCapAssessment = 'none' | 'tooHigh' | 'ok';

/** Classify the current heap-cap situation for a machine. See module doc for the 40%/50% rationale. */
export function assessHeapCap(input: HeapCapAssessmentInput): HeapCapAssessment {
  if (input.capMb === undefined) return 'none';
  const totalMb = input.totalBytes / BYTES_PER_MB;
  return input.capMb > totalMb * TOO_HIGH_FRACTION ? 'tooHigh' : 'ok';
}

/**
 * Plain-object shape mirroring the parts of
 * `vscode.WorkspaceConfiguration.inspect()` that {@link pickWriteTarget}
 * needs — kept as a local interface (rather than importing the real
 * `ConfigurationInspect<T>` type) so this module stays vscode-free and
 * testable without the mock.
 */
export interface HeapCapInspectResult {
  globalValue?: readonly string[];
  workspaceValue?: readonly string[];
  workspaceFolderValue?: readonly string[];
}

/** The three scopes `dart.analyzerVmAdditionalArgs` can be written to, most to least specific. */
export type HeapCapWriteTarget = 'workspaceFolder' | 'workspace' | 'global';

/**
 * Pick the most specific scope that currently defines
 * `dart.analyzerVmAdditionalArgs`, since a more specific scope always wins
 * over a less specific one at runtime — writing to Global when a workspace
 * value already exists would silently do nothing (the original
 * `setAnalysisServerHeapCap` bug). Falls back to `'global'` when no scope
 * defines the setting, matching the command's previous default target.
 */
export function pickWriteTarget(inspectResult: HeapCapInspectResult | undefined): HeapCapWriteTarget {
  if (inspectResult?.workspaceFolderValue !== undefined) return 'workspaceFolder';
  if (inspectResult?.workspaceValue !== undefined) return 'workspace';
  return 'global';
}

/**
 * Numeric `vscode.ConfigurationTarget` value (Global=1, Workspace=2,
 * WorkspaceFolder=3) a {@link HeapCapWriteTarget} maps to. Expressed as
 * literal numbers rather than importing the real enum so this module has
 * no `vscode` dependency; callers cast the result to
 * `vscode.ConfigurationTarget` at the call site.
 */
export function writeTargetToConfigurationTargetValue(target: HeapCapWriteTarget): 1 | 2 | 3 {
  switch (target) {
    case 'workspaceFolder':
      return 3;
    case 'workspace':
      return 2;
    default:
      return 1;
  }
}

/**
 * Replace any existing `--old_gen_heap_size` flag in `currentArgs` with a
 * fresh one set to `mb`, preserving every other arg and its order. Shared
 * by the dashboard command and the startup audit's "Apply" action so both
 * write flows can never disagree about how the flag is merged.
 */
export function withHeapCap(currentArgs: readonly string[], mb: number): string[] {
  const withoutOldCap = currentArgs.filter((a) => !a.includes(HEAP_CAP_FLAG));
  return [...withoutOldCap, `${HEAP_CAP_FLAG}=${mb}`];
}
