/**
 * The reclaim flow for orphaned model hosts, expressed without any `vscode`
 * dependency so the safety rule it enforces can be unit tested.
 *
 * That rule is the whole reason this is a separate module: terminating a
 * process is destructive and irreversible, so reclaiming must never happen as
 * a side effect of the preflight noticing something. The confirmation and the
 * killing are injected, and {@link reclaimOrphans} guarantees that not a
 * single kill is attempted unless the confirmation resolved true.
 */

import type { HostProcessInfo } from './orphanHosts';

/** Injected effects, so a test can assert on refusal without touching the OS. */
export interface ReclaimDeps {
  /** Presents the destructive action to the user; resolves true only on explicit consent. */
  confirm: (orphans: readonly HostProcessInfo[]) => Promise<boolean>;
  /** Terminates one process tree; resolves true when the process is gone. */
  kill: (pid: number) => Promise<boolean>;
}

/** Outcome of a reclaim attempt, enough to render every result message. */
export interface ReclaimOutcome {
  /** False when the user declined — no kill was attempted. */
  confirmed: boolean;
  /** Number of process trees successfully terminated. */
  killed: number;
  /** Number that survived (usually a permissions failure). */
  failed: number;
  /** Commit charge of the processes that were actually terminated. */
  reclaimedBytes: number;
}

/** Outcome used for both "nothing to do" and "user said no" — neither killed anything. */
function declined(): ReclaimOutcome {
  return { confirmed: false, killed: 0, failed: 0, reclaimedBytes: 0 };
}

/**
 * Ask, then — only if asked and answered yes — terminate.
 *
 * Kills run sequentially rather than in parallel because terminating a daemon
 * can take its child with it; a parallel run would then report the child as a
 * failure when it was in fact already reclaimed.
 */
export async function reclaimOrphans(
  orphans: readonly HostProcessInfo[],
  deps: ReclaimDeps,
): Promise<ReclaimOutcome> {
  // An empty list must not raise a confirmation prompt at all — a modal that
  // asks permission to kill nothing trains users to click through modals.
  if (orphans.length === 0) return declined();

  const confirmed = await deps.confirm(orphans);
  if (!confirmed) return declined();

  let killed = 0;
  let failed = 0;
  let reclaimedBytes = 0;
  for (const p of orphans) {
    if (await deps.kill(p.processId)) {
      killed++;
      reclaimedBytes += p.committedBytes;
    } else {
      failed++;
    }
  }
  return { confirmed: true, killed, failed, reclaimedBytes };
}
