import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  clearProbeCache,
  parseSolverText,
  probeConstraint,
  type CommandRunner,
} from '../../compat/solverProbe';

// Real `dart pub add --dev saropa_lints:^16.7.0 --dry-run` stderr, captured
// with Dart 3.13.7 against throwaway pubspecs. Resolved from src so it works
// from out-test.
const FIX = path.resolve(__dirname, '../../../src/test/compat/fixtures');
const fixture = (name: string): string => fs.readFileSync(path.join(FIX, name), 'utf8');

describe('parseSolverText (real pub output)', () => {
  it('root pins analyzer below what saropa_lints needs', () => {
    const r = parseSolverText(fixture('pub-analyzer-pinned.stderr.txt'));
    assert.strictEqual(r.blockingPackage, 'analyzer');
    assert.match(r.reason, /depends on analyzer \^12\.1\.0/);
  });

  it('third-party dep capping a shared dependency', () => {
    const r = parseSolverText(fixture('pub-dep-needs-old-analyzer.stderr.txt'));
    assert.strictEqual(r.blockingPackage, 'objectbox_generator');
  });

  it('root pins meta below the floor', () => {
    const r = parseSolverText(fixture('pub-meta-pinned.stderr.txt'));
    assert.strictEqual(r.blockingPackage, 'meta');
  });

  it('sdk too old names the dependency that requires the newer SDK', () => {
    const r = parseSolverText(fixture('pub-sdk-too-old.stderr.txt'));
    assert.strictEqual(r.blockingPackage, 'newpkg');
    assert.match(r.reason, /requires SDK version/);
  });

  it('unrecognised text yields a reason and no blocker', () => {
    const r = parseSolverText('something odd happened');
    assert.strictEqual(r.blockingPackage, undefined);
    assert.strictEqual(r.reason, 'something odd happened');
  });
});

describe('probeConstraint', () => {
  let root: string;
  beforeEach(() => {
    clearProbeCache();
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'probe-'));
    fs.writeFileSync(path.join(root, 'pubspec.yaml'), 'name: t\n');
    fs.writeFileSync(path.join(root, 'pubspec.lock'), 'packages: {}\n');
  });
  afterEach(() => fs.rmSync(root, { recursive: true, force: true }));

  const never = (): boolean => false;
  const sdk = async (): Promise<string> => 'Dart 3.13.7';

  it('returns ok and runs the dry-run add command', async () => {
    const calls: string[][] = [];
    const runner: CommandRunner = async (_cwd, cmd, args) => {
      calls.push([cmd, ...args]);
      return { ok: true, stderr: '', stdout: 'Resolving...' };
    };
    const r = await probeConstraint(root, '^16.7.0', { runner, shouldRetryWithFlutter: never, sdkVersion: sdk });
    assert.deepStrictEqual(r, { ok: true });
    assert.deepStrictEqual(calls, [['dart', 'pub', 'add', '--dev', 'saropa_lints:^16.7.0', '--dry-run']]);
  });

  it('maps failure to blockingPackage, reason and raw', async () => {
    const raw = fixture('pub-meta-pinned.stderr.txt');
    const runner: CommandRunner = async () => ({ ok: false, stderr: raw, stdout: '' });
    const r = await probeConstraint(root, '^16.7.0', { runner, shouldRetryWithFlutter: never, sdkVersion: sdk });
    assert.strictEqual(r.ok, false);
    if (!r.ok && !r.toolError) {
      assert.strictEqual(r.blockingPackage, 'meta');
      assert.strictEqual(r.raw, raw.trim());
    }
  });

  it('retries with flutter when the retry rule says so', async () => {
    const cmds: string[] = [];
    const runner: CommandRunner = async (_c, cmd) => {
      cmds.push(cmd);
      return cmd === 'dart'
        ? { ok: false, stderr: 'Flutter SDK not found', stdout: '' }
        : { ok: true, stderr: '', stdout: '' };
    };
    const r = await probeConstraint(root, '^1.0.0', { runner, shouldRetryWithFlutter: () => true, sdkVersion: sdk });
    assert.deepStrictEqual(cmds, ['dart', 'flutter']);
    assert.strictEqual(r.ok, true);
  });

  it('caches by lock content and constraint; clear and lock change invalidate', async () => {
    let n = 0;
    const runner: CommandRunner = async () => {
      n++;
      return { ok: true, stderr: '', stdout: '' };
    };
    const deps = { runner, shouldRetryWithFlutter: never, sdkVersion: sdk };
    await probeConstraint(root, '^1.0.0', deps);
    await probeConstraint(root, '^1.0.0', deps);
    assert.strictEqual(n, 1);
    await probeConstraint(root, '^2.0.0', deps);
    assert.strictEqual(n, 2);
    fs.writeFileSync(path.join(root, 'pubspec.lock'), 'packages: {a: 1}\n');
    await probeConstraint(root, '^1.0.0', deps);
    assert.strictEqual(n, 3);
    clearProbeCache();
    await probeConstraint(root, '^1.0.0', deps);
    assert.strictEqual(n, 4);
  });

  it('does not cache a failure with no output', async () => {
    let n = 0;
    const runner: CommandRunner = async () => {
      n++;
      return { ok: false, stderr: '', stdout: '' };
    };
    const deps = { runner, shouldRetryWithFlutter: never, sdkVersion: sdk };
    await probeConstraint(root, '^1.0.0', deps);
    await probeConstraint(root, '^1.0.0', deps);
    assert.strictEqual(n, 2);
  });

  it('cache key includes the SDK version', async () => {
    let n = 0;
    const runner: CommandRunner = async () => {
      n++;
      return { ok: true, stderr: '', stdout: '' };
    };
    const base = { runner, shouldRetryWithFlutter: never };
    await probeConstraint(root, '^1.0.0', { ...base, sdkVersion: async () => 'Dart 3.9' });
    await probeConstraint(root, '^1.0.0', { ...base, sdkVersion: async () => 'Dart 3.9' });
    assert.strictEqual(n, 1);
    await probeConstraint(root, '^1.0.0', { ...base, sdkVersion: async () => 'Dart 3.13' });
    assert.strictEqual(n, 2);
  });

  it('a runner that throws is a tool error, not a solver conflict', async () => {
    const runner: CommandRunner = async () => {
      throw new Error('spawn dart ENOENT');
    };
    const r = await probeConstraint(root, '^1.0.0', { runner, shouldRetryWithFlutter: never, sdkVersion: sdk });
    assert.deepStrictEqual(r, { ok: false, toolError: true, reason: 'spawn dart ENOENT', raw: 'spawn dart ENOENT' });
  });

  it('failure text that is not solver output is a tool error and is not cached', async () => {
    let n = 0;
    const runner: CommandRunner = async () => {
      n++;
      return { ok: false, stderr: 'dart: command not found', stdout: '' };
    };
    const deps = { runner, shouldRetryWithFlutter: never, sdkVersion: sdk };
    const r = await probeConstraint(root, '^1.0.0', deps);
    assert.strictEqual(r.ok === false && r.toolError, true);
    await probeConstraint(root, '^1.0.0', deps);
    assert.strictEqual(n, 2);
  });

  it('solver text stays a conflict (toolError unset)', async () => {
    const runner: CommandRunner = async () => ({ ok: false, stderr: fixture('pub-meta-pinned.stderr.txt'), stdout: '' });
    const r = await probeConstraint(root, '^1.0.0', { runner, shouldRetryWithFlutter: never, sdkVersion: sdk });
    assert.strictEqual(r.ok === false && r.toolError, undefined);
  });
});
