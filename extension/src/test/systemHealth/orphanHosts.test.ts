/**
 * Tests for orphaned model-host detection and the reclaim safety rules.
 *
 * These pin the behavior that the 2026-09-05 incident asked for
 * (`bugs/infra_translation_engine_orphans_llama_server_processes.md`): find
 * `llama-server.exe` processes whose parent is gone, total their committed
 * memory, and never terminate anything without being told to.
 *
 * The selection function is pure, so no process table is harmed here.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  parseCimDate,
  selectOrphanedHosts,
  totalCommittedBytes,
  type HostProcessInfo,
  type OrphanSelectionInput,
} from '../../systemHealth/orphanHosts';
import { reclaimOrphans } from '../../systemHealth/orphanReclaim';

const GB = 1024 * 1024 * 1024;

/** Fixed clock so "started before the session" is unambiguous in every case. */
const SESSION_START = 1_000_000;

/** Build a candidate row; defaults describe a textbook orphan. */
function host(overrides: Partial<HostProcessInfo> = {}): HostProcessInfo {
  return {
    processId: 28040,
    parentProcessId: 9999,
    name: 'llama-server.exe',
    committedBytes: 16 * GB,
    // Comfortably before the session start, i.e. from an earlier session.
    createdAtMs: SESSION_START - 60_000,
    ...overrides,
  };
}

/** Build selection input; defaults have no live parents and nothing protected. */
function input(overrides: Partial<OrphanSelectionInput> = {}): OrphanSelectionInput {
  return {
    candidates: [host()],
    livePids: new Set<number>(),
    sessionStartMs: SESSION_START,
    protectedPids: new Set<number>(),
    ...overrides,
  };
}

describe('selectOrphanedHosts', () => {
  it('reports a model host whose parent is gone', () => {
    const orphans = selectOrphanedHosts(input());
    assert.deepStrictEqual(orphans.map((p) => p.processId), [28040]);
  });

  it('ignores a model host whose parent is still alive', () => {
    // A live parent means something still owns the process — this is the
    // running translation job, not a leak.
    const orphans = selectOrphanedHosts(input({ livePids: new Set([9999]) }));
    assert.deepStrictEqual(orphans, []);
  });

  it('sums committed memory across every orphan', () => {
    const candidates = [
      host({ processId: 1, committedBytes: 15.8 * GB }),
      host({ processId: 2, committedBytes: 11.5 * GB }),
      host({ processId: 3, committedBytes: 9.5 * GB }),
    ];
    const orphans = selectOrphanedHosts(input({ candidates }));
    assert.strictEqual(orphans.length, 3);
    // The incident total: three processes, 36.8 GB between them.
    assert.ok(Math.abs(totalCommittedBytes(orphans) / GB - 36.8) < 0.01);
  });

  it('ignores an ollama daemon that still has a live model host child', () => {
    // "No live client" — a daemon mid-serve must never be reaped, because
    // killing it is exactly what stranded the child in the first place.
    const daemon = host({ processId: 500, name: 'ollama.exe', committedBytes: GB });
    const child = host({ processId: 501, parentProcessId: 500 });
    const orphans = selectOrphanedHosts(input({ candidates: [daemon, child] }));
    assert.deepStrictEqual(orphans.map((p) => p.processId), [501]);
  });

  it('reports an ollama daemon with a dead parent and no model host beneath it', () => {
    const daemon = host({ processId: 500, name: 'ollama.exe' });
    const orphans = selectOrphanedHosts(input({ candidates: [daemon] }));
    assert.deepStrictEqual(orphans.map((p) => p.processId), [500]);
  });

  it('parses the .NET /Date(...)/ form WMI emits', () => {
    assert.strictEqual(parseCimDate('/Date(1757030400000)/'), 1757030400000);
    assert.strictEqual(parseCimDate('not a date'), 0);
  });
});

describe('selectOrphanedHosts self-protection', () => {
  it('never selects an explicitly protected PID', () => {
    // The extension host and its parent: killing either takes VS Code down.
    const orphans = selectOrphanedHosts(
      input({ protectedPids: new Set([28040]) }),
    );
    assert.deepStrictEqual(orphans, []);
  });

  it('never selects a process started at or after this session began', () => {
    // A model host this session launched cannot be an orphan of an earlier
    // one, so it is out of scope for a preflight by definition.
    const candidates = [host({ createdAtMs: SESSION_START })];
    assert.deepStrictEqual(selectOrphanedHosts(input({ candidates })), []);
  });

  it('fails closed when the start time could not be read', () => {
    // An unknown start time cannot rule out "this session spawned it", and we
    // would rather leak memory than terminate a live process.
    const candidates = [host({ createdAtMs: 0 })];
    assert.deepStrictEqual(selectOrphanedHosts(input({ candidates })), []);
  });
});

describe('reclaimOrphans', () => {
  it('kills nothing when the confirmation is declined', async () => {
    const killed: number[] = [];
    const outcome = await reclaimOrphans([host()], {
      confirm: () => Promise.resolve(false),
      kill: (pid) => {
        killed.push(pid);
        return Promise.resolve(true);
      },
    });
    assert.deepStrictEqual(killed, [], 'kill must not run without consent');
    assert.strictEqual(outcome.confirmed, false);
    assert.strictEqual(outcome.killed, 0);
  });

  it('does not even prompt when there is nothing to reclaim', async () => {
    let prompted = false;
    const outcome = await reclaimOrphans([], {
      confirm: () => {
        prompted = true;
        return Promise.resolve(true);
      },
      kill: () => Promise.resolve(true),
    });
    assert.strictEqual(prompted, false);
    assert.strictEqual(outcome.confirmed, false);
  });

  it('terminates every orphan and totals what was reclaimed once confirmed', async () => {
    const orphans = [
      host({ processId: 1, committedBytes: 2 * GB }),
      host({ processId: 2, committedBytes: 3 * GB }),
    ];
    const outcome = await reclaimOrphans(orphans, {
      confirm: () => Promise.resolve(true),
      kill: () => Promise.resolve(true),
    });
    assert.strictEqual(outcome.killed, 2);
    assert.strictEqual(outcome.failed, 0);
    assert.strictEqual(outcome.reclaimedBytes, 5 * GB);
  });

  it('counts survivors separately and excludes them from the reclaimed total', async () => {
    // A kill can fail on a process owned by another user or elevated session;
    // reporting that memory as reclaimed would be a lie the user can see in
    // Task Manager.
    const orphans = [
      host({ processId: 1, committedBytes: 2 * GB }),
      host({ processId: 2, committedBytes: 3 * GB }),
    ];
    const outcome = await reclaimOrphans(orphans, {
      confirm: () => Promise.resolve(true),
      kill: (pid) => Promise.resolve(pid === 1),
    });
    assert.strictEqual(outcome.killed, 1);
    assert.strictEqual(outcome.failed, 1);
    assert.strictEqual(outcome.reclaimedBytes, 2 * GB);
  });
});
