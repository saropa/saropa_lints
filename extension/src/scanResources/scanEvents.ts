/**
 * Parsing for the machine-readable event lines the Dart scan writes to stderr
 * under `--progress json`: `SAROPA_SCAN_EVENT {json}` (see
 * `lib/src/scan/parallel_scan_engine.dart`).
 *
 * Everything here is defensive — stderr also carries free-form human text,
 * and a future/older scan binary may emit unknown or malformed events. An
 * unrecognised line is simply ignored; it must never break a scan.
 */

export const SCAN_EVENT_PREFIX = 'SAROPA_SCAN_EVENT ';

export interface ScanStartEvent {
  readonly event: 'start';
  readonly files: number;
  readonly workers: number;
  readonly maxMemoryMb: number;
  readonly reserveMb: number;
}

export interface ScanProgressEvent {
  readonly event: 'progress';
  readonly done: number;
  readonly total: number;
  readonly workers: number;
  readonly allowed: number;
  readonly rssMb: number;
  readonly availableMb: number | null;
  readonly elapsedMs: number;
}

export interface ScanThrottleEvent {
  readonly event: 'throttle';
  readonly from: number;
  readonly to: number;
  readonly level: string;
  readonly reason: string;
}

export interface ScanSlowEvent {
  readonly event: 'slow';
  readonly file: string;
  readonly ms: number;
}

export interface ScanSkippedEvent {
  readonly event: 'skipped';
  readonly file: string;
  readonly reason: string;
}

export interface ScanAbortEvent {
  readonly event: 'abort';
  readonly reason: string;
}

export interface ScanSummary {
  readonly filesTotal: number;
  readonly filesScanned: number;
  readonly workersStarted: number;
  readonly minAllowedWorkers: number;
  readonly peakRssMb: number;
  readonly minAvailableMb: number | null;
  readonly elapsedMs: number;
  readonly aborted: boolean;
  readonly abortReason: string | null;
  readonly throttleEvents: number;
  readonly slowFiles: ReadonlyArray<{ file: string; ms: number }>;
  readonly skippedFiles: readonly string[];
}

export interface ScanSummaryEvent extends ScanSummary {
  readonly event: 'summary';
}

export type ScanEvent =
  | ScanStartEvent
  | ScanProgressEvent
  | ScanThrottleEvent
  | ScanSlowEvent
  | ScanSkippedEvent
  | ScanAbortEvent
  | ScanSummaryEvent;

const num = (v: unknown, d = 0): number => (typeof v === 'number' && Number.isFinite(v) ? v : d);
const str = (v: unknown, d = ''): string => (typeof v === 'string' ? v : d);

/** Parses one stderr line; returns undefined for anything that is not a known event. */
export function parseScanEventLine(line: string): ScanEvent | undefined {
  const at = line.indexOf(SCAN_EVENT_PREFIX);
  if (at < 0) return undefined;
  let raw: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(line.slice(at + SCAN_EVENT_PREFIX.length));
    if (parsed === null || typeof parsed !== 'object') return undefined;
    raw = parsed as Record<string, unknown>;
  } catch {
    return undefined;
  }
  switch (raw.event) {
    case 'start':
      return {
        event: 'start',
        files: num(raw.files),
        workers: num(raw.workers, 1),
        maxMemoryMb: num(raw.maxMemoryMb),
        reserveMb: num(raw.reserveMb),
      };
    case 'progress':
      return {
        event: 'progress',
        done: num(raw.done),
        total: num(raw.total),
        workers: num(raw.workers),
        allowed: num(raw.allowed),
        rssMb: num(raw.rssMb),
        availableMb: typeof raw.availableMb === 'number' ? raw.availableMb : null,
        elapsedMs: num(raw.elapsedMs),
      };
    case 'throttle':
      return {
        event: 'throttle',
        from: num(raw.from),
        to: num(raw.to),
        level: str(raw.level),
        reason: str(raw.reason),
      };
    case 'slow':
      return { event: 'slow', file: str(raw.file), ms: num(raw.ms) };
    case 'skipped':
      return { event: 'skipped', file: str(raw.file), reason: str(raw.reason) };
    case 'abort':
      return { event: 'abort', reason: str(raw.reason) };
    case 'summary': {
      const slow = Array.isArray(raw.slowFiles) ? raw.slowFiles : [];
      const skipped = Array.isArray(raw.skippedFiles) ? raw.skippedFiles : [];
      return {
        event: 'summary',
        filesTotal: num(raw.filesTotal),
        filesScanned: num(raw.filesScanned),
        workersStarted: num(raw.workersStarted),
        minAllowedWorkers: num(raw.minAllowedWorkers),
        peakRssMb: num(raw.peakRssMb),
        minAvailableMb: typeof raw.minAvailableMb === 'number' ? raw.minAvailableMb : null,
        elapsedMs: num(raw.elapsedMs),
        aborted: raw.aborted === true,
        abortReason: typeof raw.abortReason === 'string' ? raw.abortReason : null,
        throttleEvents: num(raw.throttleEvents),
        slowFiles: slow
          .filter((s): s is Record<string, unknown> => s !== null && typeof s === 'object')
          .map((s) => ({ file: str(s.file), ms: num(s.ms) })),
        skippedFiles: skipped.filter((s): s is string => typeof s === 'string'),
      };
    }
    default:
      return undefined;
  }
}

/** Splits accumulated stderr into complete lines plus the trailing partial. */
export function splitLines(buffer: string): { lines: string[]; rest: string } {
  // Progress bars use bare \r; treat it as a line break too.
  const parts = buffer.split(/\r\n|\n|\r/);
  const rest = parts.pop() ?? '';
  return { lines: parts, rest };
}
