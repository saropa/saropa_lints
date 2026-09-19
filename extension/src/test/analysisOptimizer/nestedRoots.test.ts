import '../vibrancy/register-vscode-mock';
import * as assert from 'assert';
import * as cp from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  discoverNestedPackageGroups,
  findNestedPubspecDirs,
  findUnexcludedNestedGroups,
  groupNestedPackages,
} from '../../analysisOptimizer/nestedRoots';
import { buildScanExcludeGlob, queryGitIgnoredDirs } from '../../analysisOptimizer/scanner';

function touch(root: string, rel: string): void {
  const p = path.join(root, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, '');
}

describe('groupNestedPackages', () => {
  it('never reports dot-folder paths (analyzer skips them)', () => {
    assert.deepStrictEqual(groupNestedPackages(['.claude/worktrees/a'], () => true), []);
  });

  it('ignores a non-ignored monorepo member', () => {
    assert.deepStrictEqual(groupNestedPackages(['packages/foo'], () => false), []);
  });

  it('flags a git-ignored context root', () => {
    const g = groupNestedPackages(['packages/foo'], p => p === 'packages/foo');
    assert.deepStrictEqual(g.map(x => x.folder), ['packages/foo']);
  });
});

describe('findUnexcludedNestedGroups', () => {
  const groups = [{ folder: 'scratch/pkg', contextCount: 3, packages: [] as string[] }];

  it('reports a group with no exclusion', () => {
    assert.strictEqual(findUnexcludedNestedGroups(groups, [], []).length, 1);
  });
  it('is satisfied by dart.analysisExcludedFolders', () => {
    assert.strictEqual(findUnexcludedNestedGroups(groups, [], ['scratch/pkg']).length, 0);
    assert.strictEqual(findUnexcludedNestedGroups(groups, [], ['scratch/pkg/']).length, 0);
  });
  it('is satisfied by an analysis_options exclude', () => {
    assert.strictEqual(findUnexcludedNestedGroups(groups, ['scratch/pkg/**'], []).length, 0);
  });
});

describe('discoverNestedPackageGroups (filesystem)', () => {
  let root: string;
  beforeEach(() => { root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-nested-')); });
  afterEach(() => { fs.rmSync(root, { recursive: true, force: true }); });

  it('requires package_config.json/BUILD.gn and skips dot-folders', () => {
    touch(root, 'pubspec.yaml');
    touch(root, 'packages/foo/pubspec.yaml');
    touch(root, 'packages/foo/.dart_tool/package_config.json');
    touch(root, 'packages/bare/pubspec.yaml');
    touch(root, 'gn/pkg/pubspec.yaml');
    touch(root, 'gn/pkg/BUILD.gn');
    touch(root, '.claude/worktrees/a/pubspec.yaml');
    touch(root, '.claude/worktrees/a/.dart_tool/package_config.json');
    touch(root, 'ios/.symlinks/plugins/p/pubspec.yaml');
    assert.deepStrictEqual(findNestedPubspecDirs(root).sort(), ['gn/pkg', 'packages/foo']);
    // Not a git repo / nothing ignored: no legitimate-member nagging.
    assert.deepStrictEqual(discoverNestedPackageGroups(root), []);
  });

  it('flags a gitignored context root and honors ignored dirs in the scan glob', function () {
    try { cp.execFileSync('git', ['init', '-q'], { cwd: root }); } catch { this.skip(); }
    fs.writeFileSync(path.join(root, '.gitignore'), 'scratch/\n');
    touch(root, 'scratch/pkg/pubspec.yaml');
    touch(root, 'scratch/pkg/.dart_tool/package_config.json');
    touch(root, 'packages/foo/pubspec.yaml');
    touch(root, 'packages/foo/.dart_tool/package_config.json');
    const groups = discoverNestedPackageGroups(root);
    assert.deepStrictEqual(groups.map(g => g.folder), ['scratch/pkg']);
    assert.deepStrictEqual(queryGitIgnoredDirs(root), ['scratch']);
  });
});

describe('buildScanExcludeGlob', () => {
  it('always excludes build and dot-folders', () => {
    assert.strictEqual(buildScanExcludeGlob(undefined, []), '{**/build/**,**/.*/**}');
  });
  it('merges enabled files.exclude entries and ignored dirs', () => {
    const g = buildScanExcludeGlob({ '**/gen/**': true, '**/off/**': false }, ['scratch']);
    assert.strictEqual(g, '{**/build/**,**/.*/**,**/gen/**,scratch/**}');
  });
});
