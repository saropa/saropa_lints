/**
 * Pins the shape of the kill command `killProcessTree` issues.
 *
 * The failure this guards against is invisible at runtime: dropping `/T` (or
 * killing without the process group on POSIX) still terminates the shell
 * wrapper, so cancellation LOOKS successful while the real `dart.exe`
 * grandchild survives holding multi-GB of resolved-analysis memory. Only the
 * exact argv proves the tree is walked, so it is asserted literally.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as cp from 'node:child_process';
import { EventEmitter } from 'node:events';
import * as sinon from 'sinon';

import { buildTaskkillArgs, killProcessTree } from '../../views/devCliRoot';

/** Minimal ChildProcess stand-in: only `pid` and `kill` are touched by the helper. */
function fakeChild(pid: number | undefined): cp.ChildProcess & { killCalls: number } {
  const child = new EventEmitter() as unknown as cp.ChildProcess & { killCalls: number };
  Object.defineProperty(child, 'pid', { value: pid });
  child.killCalls = 0;
  child.kill = ((): boolean => {
    child.killCalls++;
    return true;
  }) as cp.ChildProcess['kill'];
  return child;
}

describe('buildTaskkillArgs', () => {
  it('issues /F /T /PID in that order — /T is what walks the tree to dart.exe', () => {
    assert.deepStrictEqual(buildTaskkillArgs(4321), ['/F', '/T', '/PID', '4321']);
  });

  it('stringifies the pid, because spawn argv members must be strings', () => {
    assert.strictEqual(typeof buildTaskkillArgs(7)[3], 'string');
  });
});

describe('killProcessTree', () => {
  let sandbox: sinon.SinonSandbox;
  /** Restored in afterEach — the helper branches on the real platform value. */
  const realPlatform = process.platform;

  function setPlatform(value: string): void {
    Object.defineProperty(process, 'platform', { value, configurable: true });
  }

  /**
   * Fake spawner. Node marks `child_process.spawn` non-configurable, so it
   * cannot be stubbed on the module; `killProcessTree` takes the spawner as an
   * injectable parameter for exactly this reason.
   */
  function fakeSpawner(): {
    fn: typeof cp.spawn;
    calls: Array<{ command: string; args: readonly string[] }>;
    killer: EventEmitter;
  } {
    const killer = new EventEmitter();
    const calls: Array<{ command: string; args: readonly string[] }> = [];
    const fn = ((command: string, args: readonly string[]) => {
      calls.push({ command, args });
      return killer as unknown as cp.ChildProcess;
    }) as unknown as typeof cp.spawn;
    return { fn, calls, killer };
  }

  beforeEach(() => {
    sandbox = sinon.createSandbox();
  });

  afterEach(() => {
    sandbox.restore();
    setPlatform(realPlatform);
  });

  it('spawns taskkill with the tree flags on Windows', () => {
    setPlatform('win32');
    const spawner = fakeSpawner();
    killProcessTree(fakeChild(999), spawner.fn);
    assert.strictEqual(spawner.calls.length, 1, 'exactly one taskkill spawn');
    assert.strictEqual(spawner.calls[0].command, 'taskkill');
    assert.deepStrictEqual(spawner.calls[0].args, ['/F', '/T', '/PID', '999']);
  });

  it('falls back to child.kill() when taskkill fails ASYNCHRONOUSLY', () => {
    // A failed spawn reports through an `error` event, not a throw. Before the
    // listener existed this both crashed the host (unhandled `error`) and left
    // the child alive, because the fallback below never ran.
    setPlatform('win32');
    const spawner = fakeSpawner();
    const child = fakeChild(999);
    killProcessTree(child, spawner.fn);
    assert.strictEqual(child.killCalls, 0, 'no fallback while taskkill may still work');
    spawner.killer.emit('error', new Error('ENOENT'));
    assert.strictEqual(child.killCalls, 1, 'the async failure must reach the fallback');
  });

  it('falls back to child.kill() when the taskkill spawn throws synchronously', () => {
    setPlatform('win32');
    const throwing = (() => {
      throw new Error('EINVAL');
    }) as unknown as typeof cp.spawn;
    const child = fakeChild(999);
    killProcessTree(child, throwing);
    assert.strictEqual(child.killCalls, 1);
  });

  it('signals the process GROUP on POSIX so the shell grandchild is included', () => {
    setPlatform('linux');
    const killStub = sandbox.stub(process, 'kill');
    killProcessTree(fakeChild(555));
    assert.ok(killStub.calledOnceWithExactly(-555, 'SIGKILL'), 'negative pid = whole group');
  });

  it('falls back to child.kill() when the POSIX group does not exist', () => {
    // A non-detached child shares the host group, so `-pid` names no group and
    // kill throws ESRCH. The single-process kill is the correct next best.
    setPlatform('linux');
    sandbox.stub(process, 'kill').throws(new Error('ESRCH'));
    const child = fakeChild(555);
    killProcessTree(child);
    assert.strictEqual(child.killCalls, 1);
  });

  it('does nothing when the spawn never produced a pid (Windows)', () => {
    // Targeting `undefined` would issue `taskkill /PID undefined`.
    setPlatform('win32');
    const spawner = fakeSpawner();
    const child = fakeChild(undefined);
    killProcessTree(child, spawner.fn);
    assert.strictEqual(spawner.calls.length, 0);
    assert.strictEqual(child.killCalls, 0);
  });

  it('does nothing when the spawn never produced a pid (POSIX)', () => {
    // `process.kill(NaN)` would be an error, not a no-op.
    setPlatform('linux');
    const killStub = sandbox.stub(process, 'kill');
    const child = fakeChild(undefined);
    killProcessTree(child);
    assert.ok(killStub.notCalled);
    assert.strictEqual(child.killCalls, 0);
  });
});
