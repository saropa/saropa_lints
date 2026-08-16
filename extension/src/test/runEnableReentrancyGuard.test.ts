/**
 * Regression: `runEnable` had no guard against concurrent invocations. Clicking
 * "Enable" more than once — plausible while `pub get` runs silently for up to
 * ~2 minutes with no visible feedback — stacked N identical "Enabling Saropa
 * Lints" progress notifications and N concurrent flows writing pubspec.yaml /
 * analysis_options.yaml and shelling out to pub get / write_config, which can
 * race on those same files.
 *
 * `runEnable` now joins a second concurrent caller onto the one already-running
 * flow instead of starting a second one. No workspace folder is configured for
 * this test — `getProjectRoot()` then returns `undefined` synchronously, so
 * `runEnable` short-circuits before any file write or process spawn, letting
 * this test pin the dedup logic without needing a real `dart`/`flutter`
 * toolchain. (`runEnable` is itself `async`, so each call returns a distinct
 * wrapper promise even when both settle from the same shared in-flight run —
 * promise identity isn't the observable signal; the error-toast count is.)
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { invalidateProjectRoot } from '../projectRoot';
import { runEnable } from '../setup';
import { messageMock, mockWorkspaceFolders, resetMocks } from './vibrancy/vscode-mock';

describe('runEnable re-entrancy guard', () => {
  beforeEach(() => {
    resetMocks();
    invalidateProjectRoot();
    mockWorkspaceFolders.value = undefined;
  });

  afterEach(() => {
    invalidateProjectRoot();
    resetMocks();
  });

  it('joins the in-flight run: two concurrent calls resolve to the same outcome', async () => {
    const [r1, r2] = await Promise.all([runEnable({} as any), runEnable({} as any)]);
    assert.strictEqual(r1, false);
    assert.strictEqual(r2, false);
  });

  it('allows a new flow to start once the previous one has settled', async () => {
    await runEnable({} as any);
    assert.strictEqual(messageMock.errors.length, 1);

    await runEnable({} as any);
    assert.strictEqual(
      messageMock.errors.length,
      2,
      'a call AFTER the previous one settled must start its own flow, not stay joined to the old one forever',
    );
  });

  it('does not stack duplicate error notifications from concurrent calls', async () => {
    await Promise.all([runEnable({} as any), runEnable({} as any), runEnable({} as any)]);

    assert.strictEqual(
      messageMock.errors.length,
      1,
      'three concurrent calls sharing one in-flight run must surface exactly one error toast, not three',
    );
  });
});
