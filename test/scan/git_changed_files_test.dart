/// Tests for [gitChangedDartFiles], the file list behind `audit --since`.
///
/// Runs against a real git repository in a temp directory: what matters is
/// what git prints, and in particular that a project in a subdirectory of the
/// repository (a monorepo package) gets its own changed files back, at paths
/// that exist.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/scan/git_changed_files.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void _git(String cwd, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void _write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

void main() {
  late Directory repo;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('saropa_git_changed_');
    final root = repo.path;
    _git(root, ['init', '-q', '--initial-branch=main']);
    _git(root, ['config', 'user.email', 't@example.com']);
    _git(root, ['config', 'user.name', 'T']);
    _git(root, ['config', 'commit.gpgsign', 'false']);
    _write(p.join(root, 'packages/app/lib/a.dart'), '// a\n');
    _write(p.join(root, 'tool/b.dart'), '// b\n');
    _git(root, ['add', '.']);
    _git(root, ['commit', '-q', '-m', 'base']);
    _git(root, ['tag', 'base']);
    _write(p.join(root, 'packages/app/lib/a.dart'), '// a2\n');
    _write(p.join(root, 'packages/app/lib/new.dart'), '// new\n');
    _write(p.join(root, 'tool/b.dart'), '// b2\n');
    _write(p.join(root, 'packages/app/README.md'), 'not dart\n');
    _git(root, ['add', '.']);
    _git(root, ['commit', '-q', '-m', 'change']);
  });

  tearDown(() => safeDeleteDir(repo));

  test('from the repository root, lists every changed Dart file', () {
    final files = gitChangedDartFiles(repo.path, 'base');
    expect(files.map((f) => p.relative(f, from: repo.path)).toSet(), {
      'packages/app/lib/a.dart',
      'packages/app/lib/new.dart',
      'tool/b.dart',
    });
  });

  test('from a subdirectory, lists only its files, at paths that exist', () {
    final app = p.join(repo.path, 'packages', 'app');
    final files = gitChangedDartFiles(app, 'base');
    expect(files.map((f) => p.relative(f, from: app)).toSet(), {
      'lib/a.dart',
      'lib/new.dart',
    });
    for (final file in files) {
      expect(File(file).existsSync(), isTrue, reason: file);
    }
  });

  test('an unknown ref yields an empty list', () {
    expect(gitChangedDartFiles(repo.path, 'no-such-ref'), isEmpty);
  });
}
