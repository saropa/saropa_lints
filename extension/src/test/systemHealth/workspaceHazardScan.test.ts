/**
 * Tests for the workspace hazard scan: size bar, per-folder file count,
 * and exclude-pattern building. Uses a real temp directory.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  buildExcludePatterns,
  getUncoveredHazards,
  summarizeHazards,
} from '../../systemHealth/workspaceHazardScan';
import {
  clearTestConfig,
  mockWorkspaceFolders,
  setTestConfig,
} from '../vibrancy/vscode-mock';
import { invalidateProjectRoot } from '../../projectRoot';

function write(root: string, rel: string, bytes: number): void {
  const p = path.join(root, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, Buffer.alloc(bytes));
}

describe('summarizeHazards', () => {
  it('lists at most 3 entries and summarizes the rest', () => {
    const files = [1, 2, 3, 4, 5].map((n) => ({ relative: `f${n}.bin`, size: 1024 }));
    const out = summarizeHazards(files);
    assert.ok(out.includes('f3.bin'));
    assert.ok(!out.includes('f4.bin'));
    assert.ok(out.endsWith('and 2 more'));
  });

  it('names all 4 files minus the cap with "and 1 more" at the boundary', () => {
    const files = [1, 2, 3, 4].map((n) => ({ relative: `f${n}.bin`, size: 1024 }));
    const out = summarizeHazards(files);
    assert.ok(out.endsWith('and 1 more'));
    assert.ok(!out.includes('f4.bin'));
  });

  it('adds no extra entry for 3 or fewer', () => {
    const files = [1, 2, 3].map((n) => ({ relative: `f${n}.bin`, size: 1024 }));
    assert.strictEqual(summarizeHazards(files).split(', ').length, 3);
  });

  it('formats folder hazards as "dir/ (N files)"', () => {
    const out = summarizeHazards([{ relative: 'build/cache', size: 0, fileCount: 5000 }]);
    assert.strictEqual(out, 'build/cache/ (5000 files)');
  });
});

describe('buildExcludePatterns', () => {
  it('uses **/.gradle/** for files under a .gradle directory', () => {
    const out = buildExcludePatterns([
      { relative: 'android/.gradle/8.0/big.bin', size: 1 },
    ]);
    assert.deepStrictEqual(out, ['**/.gradle/**']);
  });

  it('uses <folder>/** for folder hazards and keeps ext globs / literals', () => {
    const out = buildExcludePatterns([
      { relative: 'assets/gen', size: 0, fileCount: 2000 },
      { relative: 'a/x.hprof', size: 1 },
      { relative: 'data/blob.bin', size: 1 },
    ]);
    assert.deepStrictEqual(out, ['**/*.hprof', 'assets/gen/**', 'data/blob.bin']);
  });
});

describe('getUncoveredHazards', () => {
  let root: string;
  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'hazard-'));
    mockWorkspaceFolders.value = [{ uri: { fsPath: root } }];
    invalidateProjectRoot();
    fs.writeFileSync(path.join(root, 'pubspec.yaml'), 'name: x\n');
  });
  afterEach(() => {
    clearTestConfig();
    mockWorkspaceFolders.value = undefined;
    fs.rmSync(root, { recursive: true, force: true });
    invalidateProjectRoot();
  });

  it('flags files above maxFileKb and ignores smaller ones', async () => {
    setTestConfig('saropaLints.watcherExclude', 'maxFileKb', 10);
    write(root, 'big.bin', 11 * 1024);
    write(root, 'small.bin', 5 * 1024);
    const out = await getUncoveredHazards();
    assert.deepStrictEqual(out.map((f) => f.relative), ['big.bin']);
  });

  it('does not descend into .gradle, Pods or DerivedData', async () => {
    setTestConfig('saropaLints.watcherExclude', 'maxFileKb', 1);
    write(root, '.gradle/a.bin', 4096);
    write(root, 'ios/Pods/a.bin', 4096);
    write(root, 'DerivedData/a.bin', 4096);
    assert.deepStrictEqual(await getUncoveredHazards(), []);
  });

  it('skips .claude/worktrees and .venv directories', async () => {
    setTestConfig('saropaLints.watcherExclude', 'maxFileKb', 1);
    write(root, '.claude/worktrees/agent-1/big.bin', 4096);
    write(root, 'scripts/.venv/lib/big.bin', 4096);
    write(root, '.venv/big.bin', 4096);
    assert.deepStrictEqual(await getUncoveredHazards(), []);
  });

  it('still scans other .claude subfolders', async () => {
    setTestConfig('saropaLints.watcherExclude', 'maxFileKb', 1);
    write(root, '.claude/other/big.bin', 4096);
    assert.deepStrictEqual((await getUncoveredHazards()).map((f) => f.relative), ['.claude/other/big.bin']);
  });

  it('does not scan a non-Dart workspace (no pubspec.yaml)', async () => {
    fs.rmSync(path.join(root, 'pubspec.yaml'));
    invalidateProjectRoot();
    setTestConfig('saropaLints.watcherExclude', 'maxFileKb', 1);
    write(root, 'media/clip.mp4', 4096);
    assert.deepStrictEqual(await getUncoveredHazards(), []);
  });

  it('flags a folder with too many direct files, not the root', async () => {
    setTestConfig('saropaLints.watcherExclude', 'maxFolderFiles', 3);
    for (let i = 0; i < 4; i++) write(root, `gen/f${i}.txt`, 1);
    for (let i = 0; i < 4; i++) write(root, `root${i}.txt`, 1);
    const out = await getUncoveredHazards();
    assert.strictEqual(out.length, 1);
    assert.strictEqual(out[0].relative, 'gen');
    assert.strictEqual(out[0].fileCount, 4);
  });

  it('counts direct children only', async () => {
    setTestConfig('saropaLints.watcherExclude', 'maxFolderFiles', 3);
    for (let i = 0; i < 2; i++) write(root, `p/f${i}.txt`, 1);
    for (let i = 0; i < 2; i++) write(root, `p/q/f${i}.txt`, 1);
    assert.deepStrictEqual(await getUncoveredHazards(), []);
  });

  it('skips folders already covered by watcherExclude', async () => {
    setTestConfig('saropaLints.watcherExclude', 'maxFolderFiles', 1);
    setTestConfig('files', 'watcherExclude', { 'gen/**': true });
    for (let i = 0; i < 3; i++) write(root, `gen/f${i}.txt`, 1);
    assert.deepStrictEqual(await getUncoveredHazards(), []);
  });
});

describe('isCovered globs', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { isCovered } = require('../../systemHealth/watcherExcludeHelpers');
  it('matches nested dirs for **/ and trailing **', () => {
    assert.ok(isCovered('a/b/c/x.hprof', { '**/*.hprof': true }));
    assert.ok(isCovered('x.hprof', { '**/*.hprof': true }));
    assert.ok(isCovered('a/b/build/z/y', { '**/build/**': true }));
    assert.ok(!isCovered('a/b/buildx/y', { '**/build/**': true }));
  });
});
