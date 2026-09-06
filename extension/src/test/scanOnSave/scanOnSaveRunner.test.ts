import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  buildScanOnSaveArgs,
  parseScanOnSaveOutput,
  armScanTimeout,
  buildScanTimeoutResult,
  createScanLifecycle,
  resolveScanTimeoutMs,
  readScanTimeoutMs,
  SCAN_TIMEOUT_DEFAULT_SECONDS,
  SCAN_TIMEOUT_MIN_SECONDS,
  SCAN_TIMEOUT_MAX_SECONDS,
} from '../../scanOnSave/scanOnSaveRunner';
import { setTestConfig, clearTestConfig } from '../vibrancy/vscode-mock';
import type { ScanOnSaveResult } from '../../scanOnSave/scanOnSaveRunner';

// Arg order matters here: parseScanArgs (the CLI's own arg parser) takes
// the first non-flag token as the project path, so a regression that
// reorders these would silently break scan-on-save without any type error.
describe('buildScanOnSaveArgs', () => {
  it('puts the project root first (parseScanArgs takes the FIRST non-flag token as path)', () => {
    const args = buildScanOnSaveArgs('D:/src/contacts', ['lib/main.dart'], 'recommended', false);
    assert.strictEqual(args[0], 'D:/src/contacts');
  });

  it('includes --tier, --files with all given paths, and --format json', () => {
    const args = buildScanOnSaveArgs('/proj', ['a.dart', 'b.dart'], 'essential', false);
    assert.deepStrictEqual(args, [
      '/proj',
      '--tier',
      'essential',
      '--files',
      'a.dart',
      'b.dart',
      '--format',
      'json',
    ]);
  });

  it('appends --resolve before --format when resolve=true (type-based rules need it)', () => {
    const args = buildScanOnSaveArgs('/proj', ['a.dart'], 'recommended', true);
    assert.ok(args.includes('--resolve'));
    assert.ok(args.indexOf('--resolve') < args.indexOf('--format'));
  });
});

// The CLI subprocess can produce empty stdout or malformed JSON on crash;
// parseScanOnSaveOutput must degrade to null rather than throwing, since
// an uncaught exception here would break the save-triggered scan silently.
describe('parseScanOnSaveOutput', () => {
  it('parses a valid payload with diagnostics', () => {
    const raw = JSON.stringify({
      version: 1,
      diagnostics: [
        { filePath: '/a.dart', line: 5, column: 3, ruleName: 'r1', severity: 'WARNING', problemMessage: 'msg' },
      ],
    });
    const parsed = parseScanOnSaveOutput(raw);
    assert.ok(parsed);
    assert.strictEqual(parsed!.diagnostics.length, 1);
    assert.strictEqual(parsed!.diagnostics[0].ruleName, 'r1');
  });

  it('parses a clean-scan payload with an empty diagnostics array', () => {
    const parsed = parseScanOnSaveOutput(JSON.stringify({ version: 1, diagnostics: [] }));
    assert.ok(parsed);
    assert.strictEqual(parsed!.diagnostics.length, 0);
  });

  it('returns null for empty stdout', () => {
    assert.strictEqual(parseScanOnSaveOutput(''), null);
  });

  it('returns null for malformed JSON instead of throwing', () => {
    assert.strictEqual(parseScanOnSaveOutput('{not json'), null);
  });

  it('returns null when diagnostics is missing/not an array', () => {
    assert.strictEqual(parseScanOnSaveOutput(JSON.stringify({ version: 1 })), null);
  });
});

describe('scan watchdog timeout', () => {
  // Pins the fix for the hung-child bug: without a watchdog, `close` never
  // fires, runScanOnSave never settles, and the controller's _scanInFlight
  // flag stays true for the rest of the session (57 scan starts, 1 completion
  // in the incident log).
  it('fires after the given delay when nothing disarms it', async () => {
    let fired = false;
    armScanTimeout(() => { fired = true; }, 5);
    await new Promise((r) => setTimeout(r, 40));
    assert.strictEqual(fired, true);
  });

  // Cancellation is deliberately NOT in this list any more: it kills the child
  // but leaves the timer armed, because a kill that fails to take effect would
  // otherwise leave the run unsettled forever. See the createScanLifecycle suite.
  it('does not fire once disarmed — the close/error settlement paths must be safe', () => {
    let fired = false;
    const disarm = armScanTimeout(() => { fired = true; }, 5);
    disarm();
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        assert.strictEqual(fired, false);
        resolve();
      }, 40);
    });
  });

  it('is idempotent to disarm twice (close after cancellation)', () => {
    const disarm = armScanTimeout(() => { /* no-op */ }, 5);
    disarm();
    disarm();
  });

  it('reports a timeout as a failed run with a user-visible message', () => {
    const result = buildScanTimeoutResult();
    assert.strictEqual(result.payload, null);
    assert.strictEqual(result.exitCode, -1);
    assert.ok((result.errorMessage ?? '').length > 0);
  });
});

describe('createScanLifecycle', () => {
  /** Records what the lifecycle settles with and how often the child was killed. */
  function makeLifecycle(timeoutMs: number) {
    const state: { result?: ScanOnSaveResult; settles: number; kills: number } = {
      settles: 0,
      kills: 0,
    };
    const lifecycle = createScanLifecycle(
      (r) => { state.result = r; state.settles++; },
      () => { state.kills++; },
      timeoutMs,
    );
    return { lifecycle, state };
  }

  it('still settles a cancelled run whose kill never produces a close event', async () => {
    // The load-bearing regression pin. `killProcessTree` is fire-and-forget on Windows and
    // no-ops entirely when `child.pid` is undefined, so a cancellation can leave a live child
    // that never emits `close`. Disarming the watchdog on cancel (the previous behavior) left
    // the promise pending forever and wedged `_scanInFlight` for the rest of the session.
    const { lifecycle, state } = makeLifecycle(5);
    lifecycle.requestCancel();
    assert.strictEqual(state.kills, 1, 'cancellation must kill the child');
    assert.strictEqual(state.settles, 0, 'a kill request alone must not settle the run');
    await new Promise((r) => setTimeout(r, 40));
    assert.strictEqual(state.settles, 1, 'the watchdog must still settle a failed kill');
    assert.strictEqual(state.result?.exitCode, -1);
    assert.ok((state.result?.errorMessage ?? '').length > 0);
  });

  it('reports the run as cancelled once cancellation was requested', () => {
    const { lifecycle } = makeLifecycle(5);
    assert.strictEqual(lifecycle.wasCancelled(), false);
    lifecycle.requestCancel();
    assert.strictEqual(lifecycle.wasCancelled(), true);
  });

  it('settles exactly once — a late close after a timeout is ignored', async () => {
    const { lifecycle, state } = makeLifecycle(5);
    await new Promise((r) => setTimeout(r, 40));
    assert.strictEqual(state.settles, 1, 'the watchdog settled the run');
    lifecycle.settle({ payload: null, exitCode: 0 });
    assert.strictEqual(state.settles, 1, 'a late close must not resolve a second time');
  });

  it('disarms the watchdog when (and only when) the run settles', async () => {
    const { lifecycle, state } = makeLifecycle(5);
    lifecycle.settle({ payload: { version: 1, diagnostics: [] }, exitCode: 0 });
    assert.strictEqual(state.settles, 1);
    await new Promise((r) => setTimeout(r, 40));
    assert.strictEqual(state.settles, 1, 'the timer must not fire after settlement');
    assert.strictEqual(state.kills, 0, 'a normally settled run kills nothing');
  });

  it('disposes the cancellation subscription exactly once, at settlement', async () => {
    const { lifecycle, state } = makeLifecycle(5);
    let disposals = 0;
    lifecycle.subscription = { dispose: () => { disposals++; } };
    lifecycle.requestCancel();
    assert.strictEqual(disposals, 0, 'cancellation is not settlement');
    await new Promise((r) => setTimeout(r, 40));
    assert.strictEqual(state.settles, 1);
    assert.strictEqual(disposals, 1, 'settlement disposes the subscription');
  });
});

/**
 * The scan timeout stopped being an unmeasured constant and became the
 * `saropaLints.scanOnSave.timeoutSeconds` setting. Two properties matter and
 * neither is enforceable by the type system: the configured value must
 * actually reach the watchdog, and an unusable value must be clamped rather
 * than trusted — a 5-second timeout would kill every healthy cold run, and a
 * 10-hour one would restore the permanent-hang bug the watchdog prevents.
 */
describe('resolveScanTimeoutMs', () => {
  it('honors an in-range configured value', () => {
    assert.strictEqual(resolveScanTimeoutMs(240), 240_000);
  });

  it('clamps a too-small value up to the floor instead of trusting it', () => {
    assert.strictEqual(resolveScanTimeoutMs(5), SCAN_TIMEOUT_MIN_SECONDS * 1000);
  });

  it('clamps a too-large value down to the ceiling instead of trusting it', () => {
    assert.strictEqual(resolveScanTimeoutMs(36_000), SCAN_TIMEOUT_MAX_SECONDS * 1000);
  });

  it('accepts the exact boundary values unchanged', () => {
    assert.strictEqual(resolveScanTimeoutMs(SCAN_TIMEOUT_MIN_SECONDS), 30_000);
    assert.strictEqual(resolveScanTimeoutMs(SCAN_TIMEOUT_MAX_SECONDS), 1_800_000);
  });

  it('falls back to the default for a missing or non-numeric setting', () => {
    // A hand-edited settings.json can put a string or null here; degrading to
    // the default keeps scan-on-save working rather than throwing on save.
    const expected = SCAN_TIMEOUT_DEFAULT_SECONDS * 1000;
    assert.strictEqual(resolveScanTimeoutMs(undefined), expected);
    assert.strictEqual(resolveScanTimeoutMs('180'), expected);
    assert.strictEqual(resolveScanTimeoutMs(Number.NaN), expected);
    assert.strictEqual(resolveScanTimeoutMs(Number.POSITIVE_INFINITY), expected);
  });

  it('pins the documented default so a silent edit of it fails here', () => {
    assert.strictEqual(SCAN_TIMEOUT_DEFAULT_SECONDS, 180);
  });
});

describe('readScanTimeoutMs', () => {
  afterEach(() => {
    clearTestConfig();
  });

  it('reads saropaLints.scanOnSave.timeoutSeconds from settings', () => {
    setTestConfig('saropaLints', 'scanOnSave.timeoutSeconds', 300);
    assert.strictEqual(readScanTimeoutMs(), 300_000);
  });

  it('clamps what settings returns, so an out-of-range value never reaches the watchdog', () => {
    setTestConfig('saropaLints', 'scanOnSave.timeoutSeconds', 1);
    assert.strictEqual(readScanTimeoutMs(), SCAN_TIMEOUT_MIN_SECONDS * 1000);
  });

  it('uses the default when the setting is unset', () => {
    assert.strictEqual(readScanTimeoutMs(), SCAN_TIMEOUT_DEFAULT_SECONDS * 1000);
  });
});
