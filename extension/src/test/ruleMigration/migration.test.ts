import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as path from 'node:path';
import { applyRuleMigration } from '../../ruleMigration/applyMigration';
import { compareVersions, filterBySince, loadRenames, parsePackageRoot, parseRegistry } from '../../ruleMigration/registry';
import { buildRenameMap } from '../../ruleMigration/rewriters';
import { packageRoots, scanWorkspace, type ScanDeps } from '../../ruleMigration/scanner';

const REG = JSON.stringify({
  version: 1,
  renames: [
    { old: 'foo', new: 'foo_extended', since: '17.0.0', note: 'n' },
    { old: 'gone', new: null, since: '17.1.0' },
    { old: 'older', new: 'older2', since: '16.0.0' },
    { old: 'future', new: 'future2', since: '18.0.0' },
    { old: 7, since: '1.0.0', new: 'x' },
  ],
});

describe('registry', () => {
  it('compares versions', () => {
    assert.strictEqual(compareVersions('16.7.0', '17.0.0'), -1);
    assert.strictEqual(compareVersions('17.0.0-beta.1', '17.0.0'), 0);
    assert.ok(Number.isNaN(compareVersions('x', '1.0.0')));
  });
  it('parses and drops malformed entries', () => {
    assert.strictEqual(parseRegistry(REG).length, 4);
    assert.deepStrictEqual(parseRegistry('{"version":2,"renames":[]}'), []);
    assert.deepStrictEqual(parseRegistry('nope'), []);
  });
  it('filters previous < since <= current', () => {
    const names = filterBySince(parseRegistry(REG), '16.7.0', '17.1.0').map((e) => e.old);
    assert.deepStrictEqual(names, ['foo', 'gone']);
    assert.deepStrictEqual(filterBySince(parseRegistry(REG), undefined, '17.0.0').map((e) => e.old), ['foo', 'older']);
  });
  it('resolves the package root and loads the file', () => {
    const cfg = JSON.stringify({ packages: [{ name: 'saropa_lints', rootUri: '../../pkg/saropa_lints' }] });
    const dartTool = path.join('/proj', '.dart_tool');
    const root = path.resolve(dartTool, '../../pkg/saropa_lints');
    assert.strictEqual(parsePackageRoot(cfg, dartTool, 'saropa_lints'), root);
    const files = new Map<string, string>([
      [path.join(dartTool, 'package_config.json'), cfg],
      [path.join(root, 'lib', 'src', 'config', 'rule_renames.json'), REG],
    ]);
    const io = { read: (f: string) => files.get(f) };
    assert.strictEqual(loadRenames(io, '/proj', '16.7.0', '17.0.0').length, 1);
    assert.deepStrictEqual(loadRenames({ read: () => undefined }, '/proj', undefined, '17.0.0'), []);
    files.delete(path.join(root, 'lib', 'src', 'config', 'rule_renames.json'));
    assert.deepStrictEqual(loadRenames(io, '/proj', undefined, '17.0.0'), []);
  });
});

describe('scanWorkspace', () => {
  const renames = buildRenameMap([{ old: 'foo', new: 'foo_extended', since: '17.0.0' }]);
  const files = new Map<string, string>([
    ['/w/lib/a.dart', '// ignore: saropa_lints/foo\n'],
    ['/w/lib/b.dart', 'void main() {}\n'],
    ['/w/lib/a.g.dart', '// ignore: saropa_lints/foo\n'],
    ['/w/analysis_options.yaml', 'plugins:\n  saropa_lints:\n    diagnostics:\n      foo: true\n'],
    ['/w/saropa_baseline.json', '{bad foo'],
    ['/w/pkgs/x/lib/c.dart', '// ignore: saropa_lints/foo\n'],
  ]);
  const deps: ScanDeps = {
    findFiles: async (root, glob) => {
      const pat = glob.replace('**/', '');
      const match = (f: string): boolean => {
        const base = path.basename(f);
        if (pat === '*.dart') return base.endsWith('.dart');
        if (pat === '*baseline*.json') return base.includes('baseline') && base.endsWith('.json');
        return base === pat;
      };
      return [...files.keys()].filter((f) => f.startsWith(root + '/') && match(f));
    },
    read: (f) => files.get(f),
  };
  it('changes matching files, skips generated and unparseable, honors nested roots', async () => {
    const res = await scanWorkspace(deps, [
      { root: '/w', renames },
      { root: '/w/pkgs/x', renames: buildRenameMap([]) },
    ]);
    const names = res.changes.map((c) => c.file).sort();
    assert.deepStrictEqual(names, ['/w/analysis_options.yaml', '/w/lib/a.dart']);
    assert.deepStrictEqual(res.skipped.map((s) => s.reason).sort(), ['generated', 'unparseable']);
  });
  it('scans a nested package with its own renames', async () => {
    const res = await scanWorkspace(deps, [
      { root: '/w', renames },
      { root: '/w/pkgs/x', renames },
    ]);
    assert.ok(res.changes.some((c) => c.file === '/w/pkgs/x/lib/c.dart'));
  });
  it('packageRoots joins nested dirs', () => {
    assert.deepStrictEqual(packageRoots('/w', () => ['pkgs/x']), ['/w', path.join('/w', 'pkgs/x')]);
  });
});

describe('applyRuleMigration', () => {
  const changes = [
    { file: '/a', before: 'a0', after: 'a1', hits: 1, findings: [] },
    { file: '/b', before: 'b0', after: 'b1', hits: 2, findings: [] },
  ];
  it('writes all files then initializes', async () => {
    const disk = new Map<string, string>();
    let init = 0;
    const r = await applyRuleMigration({ write: (f, t) => void disk.set(f, t), initializeConfig: async () => void init++ }, changes);
    assert.strictEqual(r.status, 'applied');
    assert.strictEqual(r.hits, 3);
    assert.strictEqual(init, 1);
    assert.strictEqual(disk.get('/b'), 'b1');
  });
  it('restores every snapshot when initializeConfig throws', async () => {
    const disk = new Map<string, string>([['/a', 'a0'], ['/b', 'b0']]);
    const r = await applyRuleMigration(
      { write: (f, t) => void disk.set(f, t), initializeConfig: async () => { throw new Error('boom'); } },
      changes,
    );
    assert.strictEqual(r.status, 'failed');
    assert.strictEqual(r.reason, 'boom');
    assert.strictEqual(r.restored, true);
    assert.deepStrictEqual([...disk.values()], ['a0', 'b0']);
  });
  it('restores when a write throws midway', async () => {
    const disk = new Map<string, string>([['/a', 'a0'], ['/b', 'b0']]);
    let n = 0;
    const r = await applyRuleMigration(
      { write: (f, t) => { if (t === 'b1') throw new Error('disk'); disk.set(f, t); n++; }, initializeConfig: async () => {} },
      changes,
    );
    assert.strictEqual(r.status, 'failed');
    assert.strictEqual(disk.get('/a'), 'a0');
    assert.ok(n >= 2);
  });
  it('reports noChange', async () => {
    const r = await applyRuleMigration({ write: () => {}, initializeConfig: async () => {} }, []);
    assert.strictEqual(r.status, 'noChange');
  });
});
