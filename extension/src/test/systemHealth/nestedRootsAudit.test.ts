import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as cp from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { applyNestedRootFix, auditNestedPackageRoots } from '../../systemHealth/nestedRootsAudit';
import { clearTestConfig, mockWorkspaceFolders, setTestConfig, messageMock, configUpdates } from '../vibrancy/vscode-mock';

function fakeContext(): { workspaceState: any; store: Map<string, unknown> } {
  const store = new Map<string, unknown>();
  return {
    store,
    workspaceState: {
      get: <T>(k: string): T | undefined => store.get(k) as T | undefined,
      update: async (k: string, v: unknown): Promise<void> => { store.set(k, v); },
    },
  };
}

describe('auditNestedPackageRoots', () => {
  let root: string;
  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-nested-audit-'));
    mockWorkspaceFolders.value = [{ uri: { fsPath: root } }];
    clearTestConfig();
    messageMock.warnings.length = 0;
  });
  afterEach(() => {
    mockWorkspaceFolders.value = undefined;
    fs.rmSync(root, { recursive: true, force: true });
  });

  function addWorktree(): void {
    fs.writeFileSync(path.join(root, '.gitignore'), 'scratch/\n');
    cp.execFileSync('git', ['init', '-q'], { cwd: root });
    const p = path.join(root, 'scratch', 'pkg');
    fs.mkdirSync(path.join(p, '.dart_tool'), { recursive: true });
    fs.writeFileSync(path.join(p, 'pubspec.yaml'), '');
    fs.writeFileSync(path.join(p, '.dart_tool', 'package_config.json'), '{}');
  }

  it('warns for an unexcluded git-ignored package root', async () => {
    addWorktree();
    await auditNestedPackageRoots(fakeContext() as any);
    assert.strictEqual(messageMock.warnings.length, 1);
    assert.ok(messageMock.warnings[0].includes('scratch/pkg'));
  });

  it('stays silent when dart.analysisExcludedFolders already has it', async () => {
    addWorktree();
    setTestConfig('dart', 'analysisExcludedFolders', ['scratch/pkg']);
    await auditNestedPackageRoots(fakeContext() as any);
    assert.strictEqual(messageMock.warnings.length, 0);
  });

  it('stays silent for a dot-folder worktree (analyzer skips dot-folders)', async () => {
    const p = path.join(root, '.claude', 'worktrees', 'a', '.dart_tool');
    fs.mkdirSync(p, { recursive: true });
    fs.writeFileSync(path.join(root, '.claude', 'worktrees', 'a', 'pubspec.yaml'), '');
    fs.writeFileSync(path.join(p, 'package_config.json'), '{}');
    await auditNestedPackageRoots(fakeContext() as any);
    assert.strictEqual(messageMock.warnings.length, 0);
  });

  it('stays silent for a plain monorepo member', async () => {
    const p = path.join(root, 'packages', 'foo');
    fs.mkdirSync(path.join(p, '.dart_tool'), { recursive: true });
    fs.writeFileSync(path.join(p, 'pubspec.yaml'), '');
    fs.writeFileSync(path.join(p, '.dart_tool', 'package_config.json'), '{}');
    await auditNestedPackageRoots(fakeContext() as any);
    assert.strictEqual(messageMock.warnings.length, 0);
  });

  it('stays silent for folders recorded as dismissed', async () => {
    addWorktree();
    const ctx = fakeContext();
    ctx.store.set('nestedPackageRoots.dismissedFolders', ['scratch/pkg']);
    await auditNestedPackageRoots(ctx as any);
    assert.strictEqual(messageMock.warnings.length, 0);
  });

  it('applyNestedRootFix writes yaml exclude, dart excluded folders and watcher excludes', async () => {
    fs.writeFileSync(path.join(root, 'analysis_options.yaml'), 'include: package:lints/recommended.yaml\n');
    setTestConfig('dart', 'analysisExcludedFolders', ['existing']);
    await applyNestedRootFix(root, [{ folder: 'scratch/pkg', contextCount: 1, packages: ['scratch/pkg'] }]);
    const yaml = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
    assert.ok(yaml.includes('scratch/pkg/**'));
    const dart = configUpdates.find(u => u.section === 'dart' && u.key === 'analysisExcludedFolders');
    assert.deepStrictEqual(dart?.value, ['existing', 'scratch/pkg']);
    const watcher = configUpdates.find(u => u.key === 'watcherExclude');
    assert.strictEqual(watcher?.value['**/scratch/pkg/**'], true);
  });
});
