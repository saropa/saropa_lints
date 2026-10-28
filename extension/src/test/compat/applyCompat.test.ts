import '../vibrancy/register-vscode-mock';
import * as assert from 'node:assert';
import { applyCompatibility, planEdits, type ApplyDeps } from '../../compat/applyCompat';

const PUBSPEC = 'name: app\ndev_dependencies:\n  saropa_lints: ^16.0.0\n';
const OPTIONS = 'plugins:\n  saropa_lints:\n    version: "16.0.0"\n';
const paths = { pubspec: '/p/pubspec.yaml', analysisOptions: '/p/analysis_options.yaml' };
const rec = { constraint: '^16.10.0', pluginVersion: '16.10.0' };

function fake(over: Partial<ApplyDeps> = {}, initial: Record<string, string> = {}) {
  const files: Record<string, string> = {
    [paths.pubspec]: PUBSPEC,
    [paths.analysisOptions]: OPTIONS,
    ...initial,
  };
  const calls: string[] = [];
  const deps: ApplyDeps = {
    read: (f) => files[f],
    write: (f, t) => {
      files[f] = t;
    },
    resolve: async () => {
      calls.push('resolve');
      return { ok: true, stderr: '', cancelled: false };
    },
    readLockedVersion: async () => '16.10.0',
    initializeConfig: async () => {
      calls.push('init');
    },
    ...over,
  };
  return { deps, files, calls };
}

describe('applyCompatibility', () => {
  it('writes both files, resolves, then initializes config', async () => {
    const { deps, files, calls } = fake();
    const out = await applyCompatibility(deps, paths, rec);
    assert.deepStrictEqual(out, { status: 'applied', version: '16.10.0' });
    assert.ok(files[paths.pubspec].includes('^16.10.0'));
    assert.ok(files[paths.analysisOptions].includes('"16.10.0"'));
    assert.deepStrictEqual(calls, ['resolve', 'init']);
  });

  it('sets the plugin version to the exact locked version after resolve', async () => {
    const { deps, files } = fake({ readLockedVersion: async () => '16.9.1' });
    const out = await applyCompatibility(deps, paths, rec);
    assert.deepStrictEqual(out, { status: 'applied', version: '16.9.1' });
    assert.ok(files[paths.analysisOptions].includes('"16.9.1"'));
  });

  it('restores both files and skips init when pub get fails', async () => {
    const { deps, files, calls } = fake({
      resolve: async () => ({ ok: false, stderr: 'version solving failed', cancelled: false }),
    });
    const out = await applyCompatibility(deps, paths, rec);
    assert.deepStrictEqual(out, { status: 'failed', reason: 'version solving failed', restored: true });
    assert.strictEqual(files[paths.pubspec], PUBSPEC);
    assert.strictEqual(files[paths.analysisOptions], OPTIONS);
    assert.ok(!calls.includes('init'));
  });

  it('restores when resolve throws', async () => {
    const { deps, files } = fake({
      resolve: async () => {
        throw new Error('boom');
      },
    });
    const out = await applyCompatibility(deps, paths, rec);
    assert.strictEqual(out.status, 'failed');
    assert.strictEqual(files[paths.pubspec], PUBSPEC);
  });

  it('restores on cancel', async () => {
    const { deps, files } = fake({
      resolve: async () => ({ ok: false, stderr: '', cancelled: true }),
    });
    const out = await applyCompatibility(deps, paths, rec);
    assert.deepStrictEqual(out, { status: 'cancelled', restored: true });
    assert.strictEqual(files[paths.pubspec], PUBSPEC);
  });

  it('reports restored=false when a restore write throws', async () => {
    let n = 0;
    const { deps } = fake({
      resolve: async () => ({ ok: false, stderr: 'x', cancelled: false }),
    });
    const base = deps.write;
    deps.write = (f, t) => {
      n++;
      if (n > 2) throw new Error('disk');
      base(f, t);
    };
    const out = await applyCompatibility(deps, paths, rec);
    assert.deepStrictEqual(out, { status: 'failed', reason: 'x', restored: false });
  });

  it('returns noChange and runs nothing when the files already match', async () => {
    const { deps, calls } = fake({}, {
      [paths.pubspec]: PUBSPEC.replace('^16.0.0', '^16.10.0'),
      [paths.analysisOptions]: OPTIONS.replace('16.0.0', '16.10.0'),
    });
    assert.deepStrictEqual(await applyCompatibility(deps, paths, rec), { status: 'noChange' });
    assert.deepStrictEqual(calls, []);
  });

  it('plugin-only recommendation skips pub get', async () => {
    const { deps, calls, files } = fake();
    const out = await applyCompatibility(deps, paths, { pluginVersion: '16.10.0' });
    assert.strictEqual(out.status, 'applied');
    assert.deepStrictEqual(calls, ['init']);
    assert.strictEqual(files[paths.pubspec], PUBSPEC);
  });

  it('planEdits lists only changed files and tolerates a missing file', () => {
    const { deps } = fake({}, {});
    const edits = planEdits({ read: (f) => (f === paths.analysisOptions ? undefined : deps.read(f)) }, paths, rec);
    assert.deepStrictEqual(edits.map((e) => e.file), [paths.pubspec]);
  });

  it('restores file 1 when the second first-pass write throws', async () => {
    const { deps, files } = fake();
    const base = deps.write;
    deps.write = (f, t) => {
      if (f === paths.analysisOptions && t !== OPTIONS) throw new Error('disk full');
      base(f, t);
    };
    const out = await applyCompatibility(deps, paths, rec);
    assert.deepStrictEqual(out, { status: 'failed', reason: 'disk full', restored: true });
    assert.strictEqual(files[paths.pubspec], PUBSPEC);
    assert.strictEqual(files[paths.analysisOptions], OPTIONS);
  });

  it('restores everything when initializeConfig throws after resolve succeeds', async () => {
    const { deps, files } = fake({
      initializeConfig: async () => {
        throw new Error('init boom');
      },
    });
    const out = await applyCompatibility(deps, paths, rec);
    assert.deepStrictEqual(out, { status: 'failed', reason: 'init boom', restored: true });
    assert.strictEqual(files[paths.pubspec], PUBSPEC);
    assert.strictEqual(files[paths.analysisOptions], OPTIONS);
  });

  it('restores everything when the plugin-version write after resolve throws', async () => {
    const { deps, files } = fake({ readLockedVersion: async () => '16.9.1' });
    const base = deps.write;
    deps.write = (f, t) => {
      if (t.includes('16.9.1')) throw new Error('late write');
      base(f, t);
    };
    const out = await applyCompatibility(deps, paths, rec);
    assert.strictEqual(out.status, 'failed');
    assert.strictEqual(files[paths.pubspec], PUBSPEC);
    assert.strictEqual(files[paths.analysisOptions], OPTIONS);
  });

  it('snapshots and restores pubspec.lock when it existed', async () => {
    const lockPaths = { ...paths, lock: '/p/pubspec.lock' };
    const { deps, files } = fake(
      {
        resolve: async () => {
          files[lockPaths.lock] = 'changed by pub';
          return { ok: false, stderr: 'solve failed', cancelled: false };
        },
      },
      { [lockPaths.lock]: 'LOCK' },
    );
    const out = await applyCompatibility(deps, lockPaths, rec);
    assert.strictEqual(out.status, 'failed');
    assert.strictEqual(files[lockPaths.lock], 'LOCK');
  });

  it('does not create a lock file on restore when none existed', async () => {
    const lockPaths = { ...paths, lock: '/p/pubspec.lock' };
    const { deps, files } = fake({ resolve: async () => ({ ok: false, stderr: 'x', cancelled: false }) });
    await applyCompatibility(deps, lockPaths, rec);
    assert.strictEqual(files[lockPaths.lock], undefined);
  });
});
