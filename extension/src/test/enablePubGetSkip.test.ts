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
import { isSaropaLintsAlreadyResolved } from '../setup';

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
  options: { packages: string[]; pkgConfigOffsetMs: number },
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

  const pubspecMtime = fs.statSync(pubspecPath).mtime;
  const shifted = new Date(pubspecMtime.getTime() + options.pkgConfigOffsetMs);
  fs.utimesSync(pkgConfigPath, shifted, shifted);
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
