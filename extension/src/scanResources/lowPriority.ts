/**
 * Runs scan processes at reduced CPU priority so a long scan never makes the
 * editor stutter. A `dart` scan with several worker isolates can otherwise
 * occupy every core at normal priority.
 *
 * POSIX: wrap the command in `nice -n 10`. (`os.setPriority(pid)` is not
 * enough there — Linux applies it to a single thread, not the process.)
 * Windows: raise nothing at spawn; {@link applyWindowsPriority} lowers the
 * process class right after spawn, which Windows applies to the whole process.
 *
 * Pure apart from the optional `exists` probe so it is unit-testable.
 */
import * as fs from 'node:fs';
import * as os from 'node:os';

export interface SpawnSpec {
  readonly command: string;
  readonly args: readonly string[];
}

const NICE_LEVEL = '10';
const NICE_CANDIDATES = ['/usr/bin/nice', '/bin/nice'];

/** Wraps [command] with `nice` on POSIX when [enabled] and `nice` exists. */
export function lowPrioritySpec(
  command: string,
  args: readonly string[],
  enabled: boolean,
  platform: NodeJS.Platform = process.platform,
  exists: (path: string) => boolean = fs.existsSync,
): SpawnSpec {
  if (!enabled || platform === 'win32') return { command, args };
  const nice = NICE_CANDIDATES.find((p) => exists(p));
  if (!nice) return { command, args };
  return { command: nice, args: ['-n', NICE_LEVEL, command, ...args] };
}

/**
 * Lowers an already-spawned process on Windows. Best-effort: failure (no
 * permission, process already gone) is ignored — priority is a courtesy.
 */
export function applyWindowsPriority(
  pid: number | undefined,
  enabled: boolean,
  platform: NodeJS.Platform = process.platform,
): void {
  if (!enabled || platform !== 'win32' || pid === undefined) return;
  try {
    os.setPriority(pid, os.constants.priority.PRIORITY_BELOW_NORMAL);
  } catch {
    // Ignored on purpose.
  }
}
