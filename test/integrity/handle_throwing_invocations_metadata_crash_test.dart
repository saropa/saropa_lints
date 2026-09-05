import 'dart:io';

import 'package:test/test.dart';

/// Deletes [dir] recursively. On Windows retries once after a short delay if deletion fails
/// (e.g. "file is being used by another process"), to avoid flaky test teardown.
Future<void> _deleteTempDir(Directory dir) async {
  if (!dir.existsSync()) return;
  try {
    await dir.delete(recursive: true);
  } catch (_) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Resolves the saropa_lints repo root by walking up from [start] until
/// a directory containing pubspec.yaml with name "saropa_lints" is found.
Directory _findRepoRoot([Directory? start]) {
  var dir = start ?? Directory.current;
  while (true) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: saropa_lints') ||
          content.contains('name: saropa_lints\n')) {
        return dir;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current;
}

/// Builds a temp consumer project (pubspec.yaml pointing at this repo via
/// path dependency + analysis_options.yaml enabling the rule) containing
/// [mainDartContent] as lib/main.dart. Shared by all three regression cases
/// below, which differ only in that content and in what they assert about
/// the resulting `dart analyze` output.
Future<Directory> _createConsumerProject(
  String tempPrefix,
  String mainDartContent,
) async {
  final repoRoot = _findRepoRoot();
  final pubspecFile = File(
    '${repoRoot.path}${Platform.pathSeparator}pubspec.yaml',
  );
  expect(
    pubspecFile.existsSync(),
    isTrue,
    reason:
        'Run tests from the saropa_lints repo (or a subdir). '
        'No pubspec.yaml with name: saropa_lints found from ${Directory.current.path}.',
  );

  final tempDir = await Directory.systemTemp.createTemp(tempPrefix);
  addTearDown(() => _deleteTempDir(tempDir));

  final repoPathForYaml = repoRoot.path.replaceAll('\\', '/');

  await Directory(
    '${tempDir.path}${Platform.pathSeparator}lib',
  ).create(recursive: true);

  await File(
    '${tempDir.path}${Platform.pathSeparator}pubspec.yaml',
  ).writeAsString('''
name: tmp_saropa_lints_consumer
publish_to: none

environment:
  sdk: ">=3.10.0 <4.0.0"

dev_dependencies:
  saropa_lints:
    path: "$repoPathForYaml"
''');

  await File(
    '${tempDir.path}${Platform.pathSeparator}analysis_options.yaml',
  ).writeAsString('''
plugins:
  saropa_lints:
    diagnostics:
      handle_throwing_invocations: true
''');

  await File(
    '${tempDir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
  ).writeAsString(mainDartContent);

  return tempDir;
}

/// Regression test for handle_throwing_invocations rule.
///
/// Ensures the rule does not crash the analyzer plugin when reading
/// element metadata (MetadataImpl vs Iterable across analyzer versions).
/// Includes non-thrower and try/catch cases to guard against false positives.
void main() {
  test(
    'handle_throwing_invocations does not crash analyzer plugin (MetadataImpl)',
    () async {
      // Method invocation so the rule runs and reads element.metadata.
      final tempDir = await _createConsumerProject(
        'saropa_lints_handle_throwing_',
        '''
void main() {
  int.parse('1');
}
''',
      );

      final pubGet = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );
      expect(
        pubGet.exitCode,
        0,
        reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
      );

      final analyze = await Process.run(
        'dart',
        ['analyze', 'lib/main.dart'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );

      final combined = '${analyze.stdout}\n${analyze.stderr}';
      expect(
        analyze.exitCode,
        isNot(4),
        reason: 'Analyzer plugin crash (exit 4):\n$combined',
      );
      expect(
        combined,
        isNot(contains('An error occurred while executing an analyzer plugin')),
        reason: 'Plugin threw:\n$combined',
      );
      expect(
        combined,
        isNot(contains("MetadataImpl' is not a subtype of type 'Iterable")),
        reason: 'Regression: MetadataImpl iteration crash:\n$combined',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('handle_throwing_invocations does not report when inside try/catch', () async {
    final tempDir = await _createConsumerProject(
      'saropa_lints_handle_throwing_try_',
      '''
void main() {
  try {
    int.parse('1');
  } catch (_) {}
}
''',
    );

    final pubGet = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: tempDir.path,
      runInShell: true,
    );
    expect(pubGet.exitCode, 0);

    final analyze = await Process.run(
      'dart',
      ['analyze', 'lib/main.dart'],
      workingDirectory: tempDir.path,
      runInShell: true,
    );

    expect(
      analyze.exitCode,
      0,
      reason:
          'Code in try/catch should not trigger:\n${analyze.stdout}\n${analyze.stderr}',
    );
    expect(
      '${analyze.stdout}\n${analyze.stderr}',
      isNot(contains('handle_throwing_invocations')),
      reason: 'No lint expected when call is inside try/catch',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'handle_throwing_invocations does not report on non-thrower (no false positive)',
    () async {
      // Ordinary call (not a known thrower, no @Throws) — should not report.
      final tempDir = await _createConsumerProject(
        'saropa_lints_handle_throwing_fp_',
        '''
void main() {
  print('hello');
}
''',
      );

      final pubGet = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );
      expect(pubGet.exitCode, 0);

      final analyze = await Process.run(
        'dart',
        ['analyze', 'lib/main.dart'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );

      expect(
        analyze.exitCode,
        isNot(4),
        reason: 'Plugin must not crash:\n${analyze.stdout}\n${analyze.stderr}',
      );
      expect(
        '${analyze.stdout}\n${analyze.stderr}',
        isNot(contains('handle_throwing_invocations')),
        reason: 'print() is not a known thrower; no lint expected',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
