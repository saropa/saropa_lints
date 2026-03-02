import 'dart:io';

import 'package:test/test.dart';

/// Regression test for handle_throwing_invocations rule.
///
/// Ensures the rule does not crash the analyzer plugin when reading
/// element metadata (MetadataImpl vs Iterable across analyzer versions).
/// See: bugs/history/rule_bugs/report_element_metadata_not_iterable_handle_throwing_invocations.md
void main() {
  test(
    'handle_throwing_invocations does not crash analyzer plugin (MetadataImpl)',
    () async {
      final repoRoot = Directory.current;
      expect(
        File(
          '${repoRoot.path}${Platform.pathSeparator}pubspec.yaml',
        ).existsSync(),
        isTrue,
        reason: 'Run tests from the saropa_lints repo root.',
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'saropa_lints_handle_throwing_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

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

      // Method invocation so the rule runs and reads element.metadata.
      await File(
        '${tempDir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
      ).writeAsString('''
void main() {
  int.parse('1');
}
''');

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

  test(
    'handle_throwing_invocations does not report when inside try/catch',
    () async {
      final repoRoot = Directory.current;
      expect(
        File(
          '${repoRoot.path}${Platform.pathSeparator}pubspec.yaml',
        ).existsSync(),
        isTrue,
        reason: 'Run tests from the saropa_lints repo root.',
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'saropa_lints_handle_throwing_try_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

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
      ).writeAsString('''
void main() {
  try {
    int.parse('1');
  } catch (_) {}
}
''');

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
        reason: 'Code in try/catch should not trigger:\n${analyze.stdout}\n${analyze.stderr}',
      );
      expect(
        '${analyze.stdout}\n${analyze.stderr}',
        isNot(contains('handle_throwing_invocations')),
        reason: 'No lint expected when call is inside try/catch',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'handle_throwing_invocations does not report on non-thrower (no false positive)',
    () async {
      final repoRoot = Directory.current;
      expect(
        File(
          '${repoRoot.path}${Platform.pathSeparator}pubspec.yaml',
        ).existsSync(),
        isTrue,
        reason: 'Run tests from the saropa_lints repo root.',
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'saropa_lints_handle_throwing_fp_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

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

      // Ordinary call (not a known thrower, no @Throws) — should not report.
      await File(
        '${tempDir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
      ).writeAsString('''
void main() {
  print('hello');
}
''');

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
