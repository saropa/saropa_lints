/**
 * Watches the machine while a heavy scan runs and lets the scan wait for it
 * to recover instead of pushing a struggling computer over the edge.
 *
 * Time and memory reads are injected so the waiting logic is deterministic
 * under test.
 */
import {
  classifyMachinePressure,
  readMachineSnapshot,
  type MachinePressure,
  type MachineSnapshot,
} from './machineResources';

export type RecoveryOutcome = 'recovered' | 'canceled' | 'timeout';

export interface WaitForRecoveryOptions {
  /** Snapshot source; defaults to the real machine. */
  readonly read?: () => MachineSnapshot;
  /** Polling interval in ms. */
  readonly pollMs?: number;
  /** Give up after this long and return `'timeout'`. */
  readonly maxWaitMs?: number;
  /** Return `'canceled'` as soon as this reports true. */
  readonly isCanceled?: () => boolean;
  /** Sleep implementation; defaults to `setTimeout`. */
  readonly sleep?: (ms: number) => Promise<void>;
  /** Called on every poll with the current pressure (for UI updates). */
  readonly onPoll?: (pressure: MachinePressure) => void;
  /** Reserve override (MB); defaults to 10% of RAM. */
  readonly reserveMb?: number;
}

const defaultSleep = (ms: number): Promise<void> =>
  new Promise((resolve) => {
    const t = setTimeout(resolve, ms);
    t.unref?.();
  });

/**
 * Resolves once free memory is back above the reserve (level `ok` or
 * `high` — only `critical` blocks), the caller cancels, or [maxWaitMs]
 * elapses. Checks immediately, so a healthy machine returns at once.
 */
export async function waitForRecovery(
  options: WaitForRecoveryOptions = {},
): Promise<RecoveryOutcome> {
  const read = options.read ?? readMachineSnapshot;
  const pollMs = options.pollMs ?? 2000;
  const maxWaitMs = options.maxWaitMs ?? 5 * 60_000;
  const sleep = options.sleep ?? defaultSleep;
  let waited = 0;
  for (;;) {
    if (options.isCanceled?.()) return 'canceled';
    const pressure = classifyMachinePressure(read(), options.reserveMb);
    options.onPoll?.(pressure);
    if (pressure.level !== 'critical') return 'recovered';
    if (waited >= maxWaitMs) return 'timeout';
    await sleep(pollMs);
    waited += pollMs;
  }
}
