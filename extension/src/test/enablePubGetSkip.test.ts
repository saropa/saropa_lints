/**
 * Enable must not re-run `pub get` when there is nothing to resolve.
 *
 * Regression for the "I cannot enable Saropa Lints after disabling" report:
 * Enable shelled out to `flutter pub get` unconditionally, which was measured
 * at 116 s on a ~60-plugin Flutter project. The progress notification ticks,
 * but two minutes of "Running pub get… (96s)" is indistinguishable from a hang,
 * so the user cancels — and Enable never completes, no matter how often it is
 * retried. saropa_lints was already resolved on disk every one of those times.
 *
 * These tests pin the decision that guards the skip: the resolve is reused only
 * when package_config.json already lists saropa_lints AND is at least as new as
 * pubspec.yaml. Any doubt falls back to running pub get, because a wrongly
 * skipped resolve would leave write_config running against a package that is
 * not on disk.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { isSaropaLintsAlreadyResolved, shouldRetryWithFlutter } from '../setup';

/** Creates a throwaway project root; caller decides which files exist in it. */
function makeProject(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-pubget-'));
}

/**
 * Writes pubspec.yaml and package_config.json with an explicit ordering:
 * `pkgConfigOffsetMs` is applied to package_config's mtime relative to
 * pubspec's, so a test can state "resolution is older than the manifest"
 * without sleeping.
 */
function seed(
  root: string,
  options: { packages: string[]; pkgConfigOffsetMs: number; lockOffsetMs?: number },
): void {
  const pubspecPath = path.join(root, 'pubspec.yaml');
  fs.writeFileSync(pubspecPath, 'name: demo\ndev_dependencies:\n  saropa_lints: ^15.0.3\n');

  const dartTool = path.join(root, '.dart_tool');
  fs.mkdirSync(dartTool, { recursive: true });
  const pkgConfigPath = path.join(dartTool, 'package_config.json');
  fs.writeFileSync(
    pkgConfigPath,
    JSON.stringify({ packages: options.packages.map((name) => ({ name })) }),
  );

  // The lock defaults to the same freshness as package_config; a test that
  // cares about a stale lock overrides it via lockOffsetMs.
  const lockPath = path.join(root, 'pubspec.lock');
  fs.writeFileSync(lockPath, 'packages:\n  saropa_lints:\n    version: "15.0.3"\n');

  const pubspecMtime = fs.statSync(pubspecPath).mtime;
  const shift = (file: string, offsetMs: number) => {
    const at = new Date(pubspecMtime.getTime() + offsetMs);
    fs.utimesSync(file, at, at);
  };
  shift(pkgConfigPath, options.pkgConfigOffsetMs);
  shift(lockPath, options.lockOffsetMs ?? options.pkgConfigOffsetMs);
}

describe('isSaropaLintsAlreadyResolved', () => {
  it('reuses the resolve when saropa_lints is listed and newer than pubspec', () => {
    const root = makeProject();
    seed(root, { packages: ['flutter', 'saropa_lints'], pkgConfigOffsetMs: 1000 });
    assert.strictEqual(isSaropaLintsAlreadyResolved(root), true);
  });

  it('runs pub get when package_config predates a pubspec edit', () => {
    // The upgrade checker, a merge, or a hand-bumped constraint all land here:
    // the manifest moved after the last resolve, so the resolve is stale.
    const root = makeProject();
    seed(root, { packages: ['flutter', 'saropa_lints'], pkgConfigOffsetMs: -5000 });
    assert.strictEqual(isSaropaLintsAlreadyResolved(root), false);
  });

  it('runs pub get when saropa_lints is absent from package_config', () => {
    const root = makeProject();
    seed(root, { packages: ['flutter'], pkgConfigOffsetMs: 1000 });
    assert.strictEqual(isSaropaLintsAlreadyResolved(root), false);
  });

  it('runs pub get when the lock is stale even though package_config is fresh', () => {
    // The constraint moved and pub has not re-locked: package_config still
    // lists saropa_lints, but at whatever version the OLD constraint chose.
    // Presence alone would wrongly report this as resolved.
    const root = makeProject();
    seed(root, {
      packages: ['flutter', 'saropa_lints'],
      pkgConfigOffsetMs: 1000,
      lockOffsetMs: -5000,
    });
    assert.strictEqual(isSaropaLintsAlreadyResolved(root), false);
  });

  it('runs pub get when there is no lock file at all', () => {
    const root = makeProject();
    seed(root, { packages: ['saropa_lints'], pkgConfigOffsetMs: 1000 });
    fs.rmSync(path.join(root, 'pubspec.lock'));
    assert.strictEqual(isSaropaLintsAlreadyResolved(root), false);
  });

  it('runs pub get when .dart_tool has never been created', () => {
    const root = makeProject();
    fs.writeFileSync(path.join(root, 'pubspec.yaml'), 'name: demo\n');
    assert.strictEqual(isSaropaLintsAlreadyResolved(root), false);
  });

  it('does not match a lookalike package name', () => {
    // "saropa_lints_extra" must not be read as saropa_lints — the check is on
    // the quoted JSON name, so a prefix match cannot smuggle a false positive.
    const root = makeProject();
    seed(root, { packages: ['saropa_lints_extra'], pkgConfigOffsetMs: 1000 });
    assert.strictEqual(isSaropaLintsAlreadyResolved(root), false);
  });
});

/**
 * The dart-first `pub get` only falls back to the slow `flutter pub get` when
 * that fallback can plausibly help. Retrying on every failure would make an
 * offline machine or a malformed pubspec fail in ~116 s instead of ~2 s — the
 * exact experience this whole change exists to eliminate.
 */
describe('shouldRetryWithFlutter', () => {
  /** Writes a pubspec that either declares Flutter via the SDK dep or does not. */
  function projectWithFlutter(declared: boolean): string {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-retry-'));
    fs.writeFileSync(
      path.join(root, 'pubspec.yaml'),
      declared
        ? 'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n'
        : 'name: demo\ndependencies:\n  http: ^1.0.0\n',
    );
    return root;
  }

  it('retries when a Flutter project fails to resolve the Flutter SDK', () => {
    const root = projectWithFlutter(true);
    const stderr = 'Because demo depends on flutter from sdk which doesn\'t exist (the Flutter SDK is not available).';
    assert.strictEqual(shouldRetryWithFlutter(root, stderr), true);
  });

  it('does not retry a Flutter project on an unrelated failure', () => {
    // Network/auth/pubspec faults reproduce identically under flutter and would
    // cost the user ~114 s of flutter_tool boot to learn nothing new.
    const root = projectWithFlutter(true);
    assert.strictEqual(
      shouldRetryWithFlutter(root, 'Got socket error trying to find package http at https://pub.dev.'),
      false,
    );
  });

  it('never retries a project that does not declare Flutter', () => {
    const root = projectWithFlutter(false);
    assert.strictEqual(shouldRetryWithFlutter(root, 'the Flutter SDK is not available'), false);
  });

  it('does not retry on empty stderr', () => {
    const root = projectWithFlutter(true);
    assert.strictEqual(shouldRetryWithFlutter(root, ''), false);
  });

  it('is case-insensitive about the SDK wording', () => {
    const root = projectWithFlutter(true);
    assert.strictEqual(shouldRetryWithFlutter(root, 'FLUTTER SDK not found'), true);
  });
});

