import * as assert from 'assert';
import * as cp from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { computeFileMetrics, filterGitFileList, isInDotFolder, listDartFilesViaGit, parseNestedRepoRoots } from '../../analysisOptimizer/scanner';

// computeFileMetrics drives the exclude-pattern cost estimates shown in
// the Analysis Optimizer panel, so its widget/async/generated heuristics
// need explicit positive AND negative cases — a false positive here would
// misclassify ordinary data classes as expensive widget files.
describe('scanner computeFileMetrics', () => {
  it('counts imports, classes, and lines', () => {
    const content = `import 'package:flutter/material.dart';
import 'dart:async';

class Foo {
  void bar() {}
}
`;
    const m = computeFileMetrics(content, 'lib/foo.dart');
    assert.strictEqual(m.importCount, 2);
    assert.strictEqual(m.classCount, 1);
    assert.strictEqual(m.lineCount, content.split('\n').length);
  });

  it('detects widgets and async code', () => {
    const content = `class MyWidget extends StatelessWidget {
  Future<void> load() async {}
}
`;
    const m = computeFileMetrics(content, 'lib/my_widget.dart');
    assert.strictEqual(m.hasWidgets, true);
    assert.strictEqual(m.hasAsyncCode, true);
  });

  it('detects StatefulWidget classes', () => {
    const content = `class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}
`;
    const m = computeFileMetrics(content, 'lib/my_page.dart');
    assert.strictEqual(m.hasWidgets, true);
  });

  it('detects ConsumerWidget classes with a build(BuildContext) method', () => {
    const content = `class MyConsumer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container();
  }
}
`;
    const m = computeFileMetrics(content, 'lib/my_consumer.dart');
    assert.strictEqual(m.hasWidgets, true);
  });

  it('does not flag plain data classes as widgets or async', () => {
    const content = `class Point {
  final int x;
  final int y;
  Point(this.x, this.y);
}
`;
    const m = computeFileMetrics(content, 'lib/point.dart');
    assert.strictEqual(m.hasWidgets, false);
    assert.strictEqual(m.hasAsyncCode, false);
  });

  it('flags generated-file suffixes', () => {
    assert.strictEqual(computeFileMetrics('', 'lib/model.g.dart').isGenerated, true);
    assert.strictEqual(computeFileMetrics('', 'lib/model.freezed.dart').isGenerated, true);
    assert.strictEqual(computeFileMetrics('', 'lib/model.mocks.dart').isGenerated, true);
    assert.strictEqual(computeFileMetrics('', 'lib/model.dart').isGenerated, false);
  });
});

// isInDotFolder mirrors the Dart analyzer's context-root exclusion so the
// Optimizer's cost estimates and exclusion suggestions match what the
// analysis server actually analyzes.
describe('scanner isInDotFolder', () => {
  it('flags files under agent-tool worktree dot-folders', () => {
    assert.strictEqual(isInDotFolder('.claude/worktrees/a/lib/x.dart'), true);
  });

  it('flags files under nested dot-folders like ios/.symlinks', () => {
    assert.strictEqual(isInDotFolder('ios/.symlinks/plugins/p/lib/x.dart'), true);
  });

  it('does not flag ordinary paths', () => {
    assert.strictEqual(isInDotFolder('lib/src/x.dart'), false);
  });

  it('flags a dot-prefixed file basename', () => {
    assert.strictEqual(isInDotFolder('lib/.hidden.dart'), true);
  });

  it('does not flag a file whose name merely contains dots', () => {
    assert.strictEqual(isInDotFolder('lib/foo.bar.dart'), false);
  });
});

describe('filterGitFileList', () => {
  it('filters dot-folders, build, non-dart, duplicates and files.exclude', () => {
    const out = ['lib/a.dart', 'lib/a.dart', '.claude/w/b.dart', 'build/c.dart', 'pkg/build/d.dart',
      'lib/readme.md', 'gen/e.dart', 'lib/x.g.dart', ''].join('\0');
    assert.deepStrictEqual(
      filterGitFileList(out, { 'gen': true, '**/*.g.dart': false, '**/off': false }),
      ['lib/a.dart', 'lib/x.g.dart'],
    );
    assert.deepStrictEqual(filterGitFileList(out, { '**/*.g.dart': true, gen: true }), ['lib/a.dart']);
  });
});

describe('scanner git discovery (real repo)', () => {
  let gitOk = true;
  try { cp.execFileSync('git', ['--version'], { stdio: 'ignore' }); } catch { gitOk = false; }
  (gitOk ? it : it.skip)('respects .gitignore and includes untracked files', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'scan-git-'));
    try {
      const w = (p: string): void => {
        fs.mkdirSync(path.dirname(path.join(root, p)), { recursive: true });
        fs.writeFileSync(path.join(root, p), 'void main() {}\n');
      };
      cp.execFileSync('git', ['init', '-q'], { cwd: root });
      fs.writeFileSync(path.join(root, '.gitignore'), '*.g.dart\nscratch/\n');
      w('lib/a.dart'); w('lib/a.g.dart'); w('scratch/s.dart'); w('lib/new.dart'); w('.claude/w/z.dart');
      const out = cp.execFileSync('git',
        ['ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', '*.dart'],
        { cwd: root, encoding: 'utf8' });
      assert.deepStrictEqual(filterGitFileList(out, undefined).sort(), ['lib/a.dart', 'lib/new.dart']);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  (gitOk ? it : it.skip)('includes nested repos and submodules', async function () {
    this.timeout(30000);
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'scan-nest-'));
    const git = (cwd: string, ...a: string[]): void => {
      cp.execFileSync('git', ['-c', 'user.email=t@t', '-c', 'user.name=t',
        '-c', 'protocol.file.allow=always', ...a], { cwd, stdio: 'ignore' });
    };
    const w = (base: string, p: string): void => {
      fs.mkdirSync(path.dirname(path.join(base, p)), { recursive: true });
      fs.writeFileSync(path.join(base, p), 'void main() {}\n');
    };
    try {
      const sub = path.join(root, 'subsrc');
      fs.mkdirSync(sub);
      git(sub, 'init', '-q'); w(sub, 'lib/s.dart'); git(sub, 'add', '-A'); git(sub, 'commit', '-qm', 'i');
      const main = path.join(root, 'main');
      fs.mkdirSync(main);
      git(main, 'init', '-q');
      fs.writeFileSync(path.join(main, '.gitignore'), '*.g.dart\n');
      w(main, 'lib/a.dart');
      git(main, 'add', '-A'); git(main, 'commit', '-qm', 'i');
      let submoduleOk = true;
      try { git(main, 'submodule', 'add', sub, 'packages/sm'); } catch { submoduleOk = false; }
      // untracked nested repo
      const nest = path.join(main, 'nested/inner');
      fs.mkdirSync(nest, { recursive: true });
      git(nest, 'init', '-q');
      fs.writeFileSync(path.join(nest, '.gitignore'), '*.g.dart\n');
      w(nest, 'lib/n.dart'); w(nest, 'lib/n.g.dart'); w(nest, '.hidden/h.dart');
      // untracked parent dir (collapsed by --directory) hiding a repo two levels down
      const hidden = path.join(main, 'vendor/deep/clone');
      fs.mkdirSync(hidden, { recursive: true });
      git(hidden, 'init', '-q');
      w(hidden, 'lib/v.dart'); w(main, 'vendor/deep/notes.txt');
      const out = await listDartFilesViaGit(main);
      assert.ok(out !== undefined);
      const got = filterGitFileList(out!, undefined).sort();
      const want = ['lib/a.dart', 'nested/inner/lib/n.dart', 'vendor/deep/clone/lib/v.dart'];
      if (submoduleOk) want.push('packages/sm/lib/s.dart');
      assert.deepStrictEqual(got, want.sort());
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('parseNestedRepoRoots reads gitlinks and untracked dirs', () => {
    const stage = '100644 abc 0\tlib/a.dart\x00160000 def 0\tpackages/sm\0';
    assert.deepStrictEqual(parseNestedRepoRoots(stage, 'x.dart\0nested/inner/\0').sort(),
      ['nested/inner', 'packages/sm']);
  });
});
