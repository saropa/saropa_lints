/**
 * Unit tests for {@link computeConfigSuggestions}: proactive (no violations.json)
 * detection of the hidden init step and applicable-but-disabled rule packs,
 * driven only by pubspec.yaml + analysis_options.yaml in a temp workspace.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { computeConfigSuggestions, countConfigSuggestions } from '../config/configSuggestions';

/** Creates a fresh temp workspace dir and returns its path. */
function makeWorkspace(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-cfg-'));
}

function write(root: string, name: string, content: string): void {
  fs.writeFileSync(path.join(root, name), content, 'utf-8');
}

describe('computeConfigSuggestions', () => {
  it('returns [] when saropa_lints is not a dependency', () => {
    const root = makeWorkspace();
    write(root, 'pubspec.yaml', 'name: app\ndependencies:\n  bloc: ^8.0.0\n');
    assert.deepStrictEqual(computeConfigSuggestions(root), []);
  });

  it('suggests init-missing when the dep exists but no plugin block is configured', () => {
    const root = makeWorkspace();
    write(
      root,
      'pubspec.yaml',
      'name: app\ndev_dependencies:\n  saropa_lints: ^13.0.0\n',
    );
    // analysis_options.yaml absent entirely.
    const out = computeConfigSuggestions(root);
    assert.strictEqual(out.length, 1);
    assert.strictEqual(out[0].kind, 'init-missing');
  });

  it('does not suggest init when the saropa_lints plugin block is present', () => {
    const root = makeWorkspace();
    write(root, 'pubspec.yaml', 'name: app\ndev_dependencies:\n  saropa_lints: ^13.0.0\n');
    write(
      root,
      'analysis_options.yaml',
      'plugins:\n  saropa_lints:\n    version: "13.0.0"\n',
    );
    const out = computeConfigSuggestions(root);
    assert.ok(!out.some((s) => s.kind === 'init-missing'));
  });

  it('suggests an applicable pack the user depends on but has not enabled', () => {
    const root = makeWorkspace();
    write(
      root,
      'pubspec.yaml',
      'name: app\ndependencies:\n  bloc: ^8.0.0\ndev_dependencies:\n  saropa_lints: ^13.0.0\n',
    );
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    version: "13.0.0"\n');
    const out = computeConfigSuggestions(root);
    const bloc = out.find((s) => s.kind === 'pack-available' && s.packId === 'bloc');
    assert.ok(bloc, 'expected a bloc pack-available suggestion');
    assert.ok((bloc?.ruleCount ?? 0) > 0, 'pack suggestion carries a rule count');
  });

  it('does not suggest a pack that is already enabled', () => {
    const root = makeWorkspace();
    write(
      root,
      'pubspec.yaml',
      'name: app\ndependencies:\n  bloc: ^8.0.0\ndev_dependencies:\n  saropa_lints: ^13.0.0\n',
    );
    write(
      root,
      'analysis_options.yaml',
      'plugins:\n  saropa_lints:\n    version: "13.0.0"\n    rule_packs:\n      enabled:\n        - bloc\n',
    );
    const out = computeConfigSuggestions(root);
    assert.ok(!out.some((s) => s.packId === 'bloc'));
  });

  it('countConfigSuggestions matches the array length', () => {
    const root = makeWorkspace();
    write(
      root,
      'pubspec.yaml',
      'name: app\ndependencies:\n  bloc: ^8.0.0\n  provider: ^6.0.0\ndev_dependencies:\n  saropa_lints: ^13.0.0\n',
    );
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    version: "13.0.0"\n');
    assert.strictEqual(
      countConfigSuggestions(root),
      computeConfigSuggestions(root).length,
    );
  });
});
