/**
 * `runEnable`'s "Enable canceled during analysis still reported success" bug
 * (see setup.ts `runAnalysisAfterConfigChangeScoped`) traces back to whether
 * `runInWorkspaceAsync` correctly flags a canceled child process as `cancelled: true`.
 * That signal is the root of the whole cancellation-propagation chain, so it is
 * the cheapest place to pin a regression test — `runEnable`/`runAnalysisAfter-
 * ConfigChangeScoped` themselves shell out to `dart`/`flutter`, which this test
 * suite deliberately does not spawn (see scanDaemonClient.test.ts).
 *
 * Uses `process.execPath` (the test runner's own Node binary) running a
 * `setTimeout` sleep as a stand-in child process — deterministic and fast,
 * with no dependency on `dart`/`flutter` being on PATH.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { runInWorkspaceAsync } from '../setup';

/** Minimal `vscode.CancellationToken` stand-in — no mock for this exists yet. */
class FakeCancellationTokenSource {
  private listeners: Array<(e: unknown) => void> = [];
  isCancellationRequested = false;

  token = {
    isCancellationRequested: false,
    onCancellationRequested: (listener: (e: unknown) => void) => {
      this.listeners.push(listener);
      return { dispose: () => { /* no-op */ } };
    },
  };

  cancel(): void {
    this.isCancellationRequested = true;
    this.token.isCancellationRequested = true;
    for (const listener of this.listeners) listener(undefined);
  }
}

describe('runInWorkspaceAsync cancellation', () => {
  let scriptDir: string;
  let sleepScript: string;
  let exitScript: string;

  before(() => {
    // Passing the child's script inline via `-e` breaks on Windows: `shell: true`
    // concatenates args without escaping (see DEP0190), and the script's spaces/
    // parens get mangled by cmd.exe. A script file sidesteps quoting entirely —
    // the only arg on the command line is a bare path.
    scriptDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-cancel-test-'));
    sleepScript = path.join(scriptDir, 'sleep.js');
    exitScript = path.join(scriptDir, 'exit.js');
    fs.writeFileSync(sleepScript, 'setTimeout(function () {}, 5000);\n');
    fs.writeFileSync(exitScript, 'process.exit(0);\n');
  });

  after(() => {
    fs.rmSync(scriptDir, { recursive: true, force: true });
  });

  it('flags cancelled: true and kills the child when the token fires mid-run', async () => {
    const source = new FakeCancellationTokenSource();
    // `runInWorkspaceAsync` spawns with `shell: true`, which does NOT auto-quote
    // args containing spaces (e.g. `C:\Program Files\nodejs\node.exe`) — quote
    // manually, same as a real caller would need to for a spaced install path.
    const resultPromise = runInWorkspaceAsync(
      os.tmpdir(),
      `"${process.execPath}"`,
      [`"${sleepScript}"`],
      { logToOutput: false, token: source.token },
    );

    // Cancel shortly after spawn so the child is definitely running, not already exited.
    setTimeout(() => source.cancel(), 100);

    const result = await resultPromise;
    assert.strictEqual(result.cancelled, true);
    assert.strictEqual(result.ok, false);
  });

  it('flags cancelled: false when the command completes before any cancellation', async () => {
    const source = new FakeCancellationTokenSource();
    const result = await runInWorkspaceAsync(
      os.tmpdir(),
      `"${process.execPath}"`,
      [`"${exitScript}"`],
      { logToOutput: false, token: source.token },
    );

    assert.strictEqual(result.cancelled, false);
    assert.strictEqual(result.ok, true);
  });
});
