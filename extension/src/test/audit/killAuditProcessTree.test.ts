/**
 * Tests for the cross-platform audit process tree-kill logic.
 *
 * Verifies that on POSIX platforms (non-win32), killAuditProcessTree sends
 * SIGKILL to the process GROUP (negative pid) so the dart grandchild under
 * shell:true is included — not just the shell wrapper. Falls back to the
 * shared killProcessTree helper when the group kill throws (e.g. process
 * already exited).
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';

import { killAuditProcessTree } from '../../audit/audit-command';
import * as devCliRoot from '../../views/devCliRoot';

describe('killAuditProcessTree', () => {
  let sandbox: sinon.SinonSandbox;
  let processKillStub: sinon.SinonStub;
  let killTreeStub: sinon.SinonStub;
  let originalPlatform: string;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
    processKillStub = sandbox.stub(process, 'kill');
    killTreeStub = sandbox.stub(devCliRoot, 'killProcessTree');
    // Save original platform so we can restore it.
    originalPlatform = process.platform;
  });

  afterEach(() => {
    sandbox.restore();
    // Restore original platform — Object.defineProperty is needed because
    // process.platform is a read-only property descriptor.
    Object.defineProperty(process, 'platform', { value: originalPlatform });
  });

  /** Helper to fake a ChildProcess with a known pid. */
  function fakeChild(pid: number): import('node:child_process').ChildProcess {
    return { pid } as import('node:child_process').ChildProcess;
  }

  it('sends SIGKILL to the negative pid (process group) on Linux', () => {
    // Simulate a Linux environment.
    Object.defineProperty(process, 'platform', { value: 'linux' });
    const child = fakeChild(12345);

    killAuditProcessTree(child);

    // Must kill the process GROUP: -12345, not 12345.
    assert.ok(
      processKillStub.calledOnceWith(-12345, 'SIGKILL'),
      `Expected process.kill(-12345, 'SIGKILL'), got: ${processKillStub.firstCall?.args}`,
    );
    // Should NOT fall through to the shared helper.
    assert.ok(killTreeStub.notCalled, 'killProcessTree should not be called on success');
  });

  it('sends SIGKILL to the negative pid (process group) on macOS', () => {
    // Verify darwin gets the same group-kill path as linux.
    Object.defineProperty(process, 'platform', { value: 'darwin' });
    const child = fakeChild(99999);

    killAuditProcessTree(child);

    assert.ok(processKillStub.calledOnceWith(-99999, 'SIGKILL'));
    assert.ok(killTreeStub.notCalled);
  });

  it('falls back to killProcessTree when process group kill throws on POSIX', () => {
    // Simulate the process group already being gone (throws ESRCH).
    Object.defineProperty(process, 'platform', { value: 'linux' });
    processKillStub.throws(new Error('ESRCH'));
    const child = fakeChild(42);

    killAuditProcessTree(child);

    // Should have attempted the group kill...
    assert.ok(processKillStub.calledOnceWith(-42, 'SIGKILL'));
    // ...and fallen back to the shared helper.
    assert.ok(
      killTreeStub.calledOnceWith(child),
      'Should fall back to killProcessTree when group kill fails',
    );
  });

  it('delegates directly to killProcessTree on Windows (no group kill)', () => {
    Object.defineProperty(process, 'platform', { value: 'win32' });
    const child = fakeChild(777);

    killAuditProcessTree(child);

    // process.kill should NOT be called — Windows uses taskkill /T via
    // killProcessTree instead.
    assert.ok(processKillStub.notCalled, 'process.kill should not be called on Windows');
    assert.ok(killTreeStub.calledOnceWith(child));
  });

  it('delegates to killProcessTree when child has no pid on POSIX', () => {
    // Edge case: pid is undefined (process never started successfully).
    Object.defineProperty(process, 'platform', { value: 'linux' });
    const child = fakeChild(undefined as unknown as number);

    killAuditProcessTree(child);

    // No group kill possible without a pid.
    assert.ok(processKillStub.notCalled);
    assert.ok(killTreeStub.calledOnceWith(child));
  });
});
