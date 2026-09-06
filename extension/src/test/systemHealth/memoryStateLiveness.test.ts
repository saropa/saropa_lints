/**
 * Regression tests for
 * `bugs/infra_extension_shows_stale_memory_state_when_plugin_disabled.md`.
 *
 * The defect: the extension read `memory_state.json` and rendered it in the
 * status bar without ever asking whether the state was live. In the reported
 * incident the status bar showed "Rules paused (8425 MB)" from a file written
 * days earlier, while the plugin was commented out of `analysis_options.yaml`
 * and was not running at all — sending the user to investigate a problem that
 * did not exist.
 *
 * These tests pin the gate: stale or orphaned state must publish nothing,
 * fresh state from an enrolled plugin must publish, and both liveness
 * conditions must be independently required.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  MemoryPressureWatcher,
  isMemoryStateLive,
  type MemoryPressureState,
} from '../../systemHealth/memoryPressureWatcher';

/** A hard-limit-tripped state — the exact shape that produced "Rules paused". */
const PAUSED_STATE: MemoryPressureState = {
  shedLevel: 0,
  rssMb: 8425,
  softLimitMb: 2867,
  hardLimitMb: 4096,
  softLimitTripped: true,
  hardLimitTripped: true,
  shedRuleCount: 0,
  shedEnabled: true,
  timestamp: '2026-09-01T00:00:00Z',
};

/** An `analysis_options.yaml` that enrols the plugin via the include shape. */
const ENROLLED_YAML = 'include: package:saropa_lints/tiers/recommended.yaml\n';

/** The explicit enrolment shape — a top-level plugins block with the nested key. */
const ENROLLED_PLUGINS_BLOCK_YAML = 'plugins:\n  saropa_lints:\n    tier: recommended\n';

/**
 * The reported configuration: the enrolment is present but commented out, so
 * no plugin is loaded. This is the incident's actual input.
 */
const DISABLED_YAML =
  '# plugins:\n#   saropa_lints:\n#     tier: recommended\nanalyzer:\n  exclude:\n    - build/**\n';

/** Roots created per test, torn down afterward. */
const createdRoots: string[] = [];

/**
 * Build a throwaway project root containing the given analysis_options.yaml
 * and, optionally, a memory_state.json with a chosen modification time.
 * Real files are used deliberately — the gate reads mtime off the filesystem,
 * so a mocked fs would not exercise the thing that broke.
 */
function makeRoot(optionsYaml: string | null, stateMtimeMs: number | null): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-memstate-'));
  createdRoots.push(root);
  if (optionsYaml !== null) {
    fs.writeFileSync(path.join(root, 'analysis_options.yaml'), optionsYaml, 'utf8');
  }
  if (stateMtimeMs !== null) {
    const dataDir = path.join(root, 'reports', '.saropa_lints');
    fs.mkdirSync(dataDir, { recursive: true });
    const stateFile = path.join(dataDir, 'memory_state.json');
    fs.writeFileSync(stateFile, JSON.stringify(PAUSED_STATE), 'utf8');
    // utimes takes seconds; set atime and mtime together so the gate sees
    // exactly the age this test intends rather than "just now".
    const seconds = stateMtimeMs / 1000;
    fs.utimesSync(stateFile, seconds, seconds);
  }
  return root;
}

/** Sentinel for "the watcher never invoked its listener at all". */
const NOTHING = 'nothing';

/**
 * Start a watcher against [root] with an explicit session boundary and return
 * whatever it published on its initial read. `start()` performs that read
 * synchronously before arming fs.watch, so no waiting is needed.
 */
function initialPublish(
  root: string,
  sessionStartMs: number,
): MemoryPressureState | null | typeof NOTHING {
  const watcher = new MemoryPressureWatcher(sessionStartMs);
  let published: MemoryPressureState | null | typeof NOTHING = NOTHING;
  watcher.onStateChange((state) => {
    published = state;
  });
  try {
    watcher.start(root);
  } finally {
    watcher.dispose();
  }
  return published;
}

const HOUR_MS = 60 * 60 * 1000;

afterEach(() => {
  for (const root of createdRoots.splice(0)) {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

describe('isMemoryStateLive — both conditions are independently required', () => {
  it('accepts state written after the session start by an enrolled plugin', () => {
    assert.strictEqual(
      isMemoryStateLive({
        writtenAtMs: 2_000,
        sessionStartMs: 1_000,
        pluginEnrolled: true,
      }),
      true,
    );
  });

  it('rejects state written before the session start (orphaned by a dead plugin)', () => {
    assert.strictEqual(
      isMemoryStateLive({
        writtenAtMs: 500,
        sessionStartMs: 1_000,
        pluginEnrolled: true,
      }),
      false,
    );
  });

  it('rejects fresh state when the plugin is not enrolled', () => {
    // Freshness alone must not be enough — this is the reported incident with
    // a file that happens to have been touched recently.
    assert.strictEqual(
      isMemoryStateLive({
        writtenAtMs: 2_000,
        sessionStartMs: 1_000,
        pluginEnrolled: false,
      }),
      false,
    );
  });

  it('rejects state whose write time could not be determined', () => {
    assert.strictEqual(
      isMemoryStateLive({
        writtenAtMs: null,
        sessionStartMs: 1_000,
        pluginEnrolled: true,
      }),
      false,
    );
  });

  it('accepts state written exactly at the session boundary', () => {
    // The boundary is inclusive: a plugin that writes in the same millisecond
    // the session starts is live, and excluding it would be an off-by-one that
    // hides real state.
    assert.strictEqual(
      isMemoryStateLive({
        writtenAtMs: 1_000,
        sessionStartMs: 1_000,
        pluginEnrolled: true,
      }),
      true,
    );
  });
});

describe('MemoryPressureWatcher — stale state never reaches the status bar', () => {
  it('publishes nothing for a day-old state file from a disabled plugin', () => {
    // The exact reported incident: "Rules paused (8425 MB)" surviving a
    // commented-out plugins block.
    const now = Date.now();
    const root = makeRoot(DISABLED_YAML, now - 24 * HOUR_MS);
    assert.strictEqual(initialPublish(root, now - HOUR_MS), NOTHING);
  });

  it('publishes nothing when the plugin is enrolled but the file predates the session', () => {
    // Enrolled-but-dead: crashed isolate, or an analysis server that never
    // started. Enrolment alone must not be enough to trust the file.
    const now = Date.now();
    const root = makeRoot(ENROLLED_YAML, now - 24 * HOUR_MS);
    assert.strictEqual(initialPublish(root, now - HOUR_MS), NOTHING);
  });

  it('publishes nothing for fresh state when the plugin is not enrolled', () => {
    const now = Date.now();
    const root = makeRoot(DISABLED_YAML, now);
    assert.strictEqual(initialPublish(root, now - HOUR_MS), NOTHING);
  });

  it('publishes nothing when analysis_options.yaml is missing entirely', () => {
    const now = Date.now();
    const root = makeRoot(null, now);
    assert.strictEqual(initialPublish(root, now - HOUR_MS), NOTHING);
  });

  it('publishes nothing when no state file exists at all', () => {
    const now = Date.now();
    const root = makeRoot(ENROLLED_YAML, null);
    assert.strictEqual(initialPublish(root, now - HOUR_MS), NOTHING);
  });

  it('publishes fresh state written by an enrolled plugin', () => {
    // The gate must not be so conservative that it hides real pressure.
    const now = Date.now();
    const root = makeRoot(ENROLLED_YAML, now);
    const published = initialPublish(root, now - HOUR_MS);
    assert.notStrictEqual(published, NOTHING);
    assert.ok(published, 'expected live state to be published');
    assert.strictEqual((published as MemoryPressureState).rssMb, 8425);
    assert.strictEqual((published as MemoryPressureState).hardLimitTripped, true);
  });

  it('accepts the explicit plugins: block enrolment shape as well as include:', () => {
    const now = Date.now();
    const root = makeRoot(ENROLLED_PLUGINS_BLOCK_YAML, now);
    const published = initialPublish(root, now - HOUR_MS);
    assert.notStrictEqual(published, NOTHING);
    assert.ok(published, 'expected live state for the plugins-block shape');
  });
});
