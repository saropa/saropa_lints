/**
 * Single-flight regression for the Code Health Dashboard scan.
 *
 * Without an in-flight guard, every invocation of `openProjectVibrancyReport`
 * spawns a fresh `dart run saropa_lints:project_vibrancy` — a full-project AST
 * walk. Rapid repeat invocations (sidebar item, rescan button, command palette)
 * pile parallel dart processes that pin CPU and stack uncancellable progress
 * notifications. This test pins the guard so the regression cannot return
 * silently.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';

import * as projectRoot from '../../projectRoot';
import * as cliRunner from '../../views/projectVibrancyCliRunner';
import { openProjectVibrancyReport } from '../../views/projectVibrancyReportView';

interface Deferred<T> {
  promise: Promise<T>;
  resolve(value: T): void;
}

function createDeferred<T>(): Deferred<T> {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

describe('openProjectVibrancyReport inflight guard', () => {
  let sandbox: sinon.SinonSandbox;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
    sandbox.stub(projectRoot, 'getProjectRoot').returns('/repo');
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('coalesces concurrent invocations into a single dart scan', async () => {
    const deferred = createDeferred<cliRunner.ProjectVibrancyScanResult>();
    // Stub via the module namespace — named imports under the project's
    // CommonJS test build still resolve through the export object, so this
    // stub IS visible to projectVibrancyReportView's call site.
    const scanStub = sandbox
      .stub(cliRunner, 'runProjectVibrancyScan')
      .returns(deferred.promise);

    // Fire two invocations back-to-back without awaiting the first — the
    // realistic "user spam-clicks rescan" shape.
    const first = openProjectVibrancyReport();
    const second = openProjectVibrancyReport();

    // Second call must reuse the in-flight promise rather than spawning a
    // second dart process.
    assert.strictEqual(scanStub.callCount, 1, 'expected exactly one scan during overlap');

    deferred.resolve({ payload: null, rawStdout: '', exitCode: 0 });
    await Promise.all([first, second]);

    // After the in-flight scan completes, a fresh invocation MUST be allowed
    // — the guard is single-flight, not single-shot. This catches the
    // accidental "permanent lockout" failure mode where the inflight handle
    // is never cleared.
    const thirdDeferred = createDeferred<cliRunner.ProjectVibrancyScanResult>();
    scanStub.returns(thirdDeferred.promise);
    const third = openProjectVibrancyReport();
    assert.strictEqual(scanStub.callCount, 2, 'a post-completion call must start a new scan');
    thirdDeferred.resolve({ payload: null, rawStdout: '', exitCode: 0 });
    await third;
  });
});
