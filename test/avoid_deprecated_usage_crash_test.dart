import 'dart:io';

import 'package:test/test.dart';

/// Regression test for the avoid_deprecated_usage rule.
///
/// Ensures the rule does not crash the analyzer plugin when walking metadata.
/// See: bugs/report_avoid_deprecated_usage_metadataimpl_not_iterable_crash.md
void main() {
  test(
    'avoid_deprecated_usage does not crash analyzer plugin (MetadataImpl)',
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
        'saropa_lints_avoid_deprecated_usage_',
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
      avoid_deprecated_usage: true
''');

      await File(
        '${tempDir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
      ).writeAsString('''
class C {
  final Object o = Object();
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
}
