/**
 * Tests for planCheckRuns: which folders "Check Accepted Findings" scans and
 * which folder launches the CLI for each. Covers the two cases the check used
 * to skip: a workspace folder whose pubspec.yaml sits one level down, and a
 * folder whose package does not list saropa_lints itself.
 *
 * Positive cases come first so a planner that returns nothing cannot pass on
 * the rejection cases alone.
 */
import * as assert from 'node:assert';
import * as path from 'node:path';

import { planCheckRuns, type CheckRootProbes } from '../../acceptedCheckRoots';

/** Absolute, platform-native path under a fake workspace. */
const ws = (...parts: string[]): string => path.resolve('/ws', ...parts);

/**
 * Probes over a fake tree: [roots] maps a folder to its package root,
 * [deps] lists roots whose pubspec has saropa_lints, [files] holds file text.
 */
function probes(
  roots: Record<string, string | undefined>,
  deps: string[],
  files: Record<string, string> = {},
): CheckRootProbes {
  return {
    projectRootIn: (f) => roots[f],
    hasDep: (r) => deps.includes(r),
    exists: (f) => f in files,
    read: (f) => files[f],
  };
}

describe('planCheckRuns', () => {
  it('runs each folder that depends on saropa_lints from itself', () => {
    const a = ws('a');
    const b = ws('b');
    const runs = planCheckRuns([a, b], probes({ [a]: a, [b]: b }, [a, b]));
    assert.deepStrictEqual(runs, [{ host: a, target: a }, { host: b, target: b }]);
  });

  it('finds a second folder whose pubspec sits one level down', () => {
    const a = ws('a');
    const b = ws('b');
    const app = ws('b', 'app');
    const runs = planCheckRuns([a, b], probes({ [a]: a, [b]: app }, [a, app]));
    assert.deepStrictEqual(runs, [{ host: a, target: a }, { host: app, target: app }]);
  });

  it('checks a plugin-only folder by launching the CLI from a folder with the package', () => {
    const a = ws('a');
    const b = ws('b');
    const c = ws('c');
    const files = {
      [path.join(b, 'saropa_accepted.yaml')]: 'version: 1\n',
      [path.join(c, 'analysis_options.yaml')]: 'plugins:\n  saropa_lints:\n    version: any\n',
    };
    const runs = planCheckRuns([a, b, c], probes({ [a]: a, [b]: b, [c]: c }, [a], files));
    assert.deepStrictEqual(runs, [
      { host: a, target: a },
      { host: a, target: b },
      { host: a, target: c },
    ]);
  });

  it('uses the first folder with the package as host even when it is listed later', () => {
    const a = ws('a');
    const b = ws('b');
    const files = { [path.join(a, 'saropa_accepted.yaml')]: '' };
    const runs = planCheckRuns([a, b], probes({ [a]: a, [b]: b }, [b], files));
    assert.deepStrictEqual(runs, [{ host: b, target: a }, { host: b, target: b }]);
  });

  it('skips a folder that neither depends on nor uses saropa_lints', () => {
    const a = ws('a');
    const b = ws('b');
    const files = { [path.join(b, 'analysis_options.yaml')]: 'include: package:lints/recommended.yaml\n' };
    const runs = planCheckRuns([a, b], probes({ [a]: a, [b]: b }, [a], files));
    assert.deepStrictEqual(runs, [{ host: a, target: a }]);
  });

  it('drops a root inside another root and duplicate roots', () => {
    const a = ws('a');
    const inner = ws('a', 'pkg');
    const runs = planCheckRuns([a, inner, a], probes({ [a]: a, [inner]: inner }, [a, inner]));
    assert.deepStrictEqual(runs, [{ host: a, target: a }]);
  });

  it('keeps an inner package with the dependency when the outer folder will not run', () => {
    // Outer folder has a pubspec without saropa_lints and no plugin config;
    // dropping nested roots before this check used to lose `inner` entirely.
    const a = ws('a');
    const inner = ws('a', 'pkg');
    const runs = planCheckRuns([a, inner], probes({ [a]: a, [inner]: inner }, [inner]));
    assert.deepStrictEqual(runs, [{ host: inner, target: inner }]);
  });

  it('drops an inner package when the plugin-only outer folder runs, hosted by the inner one', () => {
    // The outer folder uses the plugin, so its run already covers `inner`;
    // the inner package is the only possible host.
    const a = ws('a');
    const inner = ws('a', 'pkg');
    const files = { [path.join(a, 'saropa_accepted.yaml')]: '' };
    const runs = planCheckRuns([a, inner], probes({ [a]: a, [inner]: inner }, [inner], files));
    assert.deepStrictEqual(runs, [{ host: inner, target: a }]);
  });

  it('runs a plugin-only folder whose plugin block this extension commented out', () => {
    // The language server (on by default) comments the block out.
    const a = ws('a');
    const b = ws('b');
    const disabled = [
      '# >>> saropa_lints integration turned OFF by the VS Code extension >>>',
      '# plugins:',
      '#   saropa_lints:',
      '# <<< saropa_lints end of disabled integration block <<<',
    ].join('\n');
    const files = { [path.join(b, 'analysis_options.yaml')]: disabled };
    const runs = planCheckRuns([a, b], probes({ [a]: a, [b]: b }, [a], files));
    assert.deepStrictEqual(runs, [{ host: a, target: a }, { host: a, target: b }]);
  });

  it('ignores a commented saropa_lints entry that carries no marker', () => {
    const a = ws('a');
    const b = ws('b');
    const files = { [path.join(b, 'analysis_options.yaml')]: '# plugins:\n#   saropa_lints:\n' };
    const runs = planCheckRuns([a, b], probes({ [a]: a, [b]: b }, [a], files));
    assert.deepStrictEqual(runs, [{ host: a, target: a }]);
  });

  it('returns nothing when no folder can host the CLI or none has a pubspec', () => {
    const a = ws('a');
    const files = { [path.join(a, 'saropa_accepted.yaml')]: '' };
    assert.deepStrictEqual(planCheckRuns([a], probes({ [a]: a }, [], files)), []);
    assert.deepStrictEqual(planCheckRuns([a], probes({}, [])), []);
    assert.deepStrictEqual(planCheckRuns([], probes({}, [])), []);
  });
});
