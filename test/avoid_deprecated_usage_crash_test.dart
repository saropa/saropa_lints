import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('avoid_deprecated_usage', () {
    late Directory _workspaceRoot;
    late Directory _consumerDir;

    String _p(String relative) {
      return '${_consumerDir.path}${Platform.pathSeparator}$relative';
    }

    bool _hasPluginCrashMessage(String output) {
      return output.contains(
            'An error occurred while executing an analyzer plugin',
          ) ||
          output.contains("MetadataImpl' is not a subtype of type 'Iterable");
    }

    bool _containsRuleCode(String output) =>
        output.contains('avoid_deprecated_usage');

    Future<ProcessResult> _runAnalyze(String relativePath) async {
      return await Process.run(
        'dart',
        ['analyze', relativePath],
        workingDirectory: _consumerDir.path,
        runInShell: true,
      );
    }

    Future<void> _writeConsumerFile(
      String relativePath,
      String contents,
    ) async {
      final file = File(_p(relativePath));
      await file.parent.create(recursive: true);
      await file.writeAsString(contents);
    }

    setUpAll(() async {
      final repoRoot = Directory.current;
      expect(
        File(
          '${repoRoot.path}${Platform.pathSeparator}pubspec.yaml',
        ).existsSync(),
        isTrue,
        reason: 'Run tests from the saropa_lints repo root.',
      );

      _workspaceRoot = await Directory.systemTemp.createTemp(
        'saropa_lints_avoid_deprecated_usage_',
      );
      _consumerDir = Directory(
        '${_workspaceRoot.path}${Platform.pathSeparator}consumer',
      );
      final deprecatedPkgDir = Directory(
        '${_workspaceRoot.path}${Platform.pathSeparator}deprecated_pkg',
      );

      final repoPathForYaml = repoRoot.path.replaceAll('\\', '/');
      final workspacePathForYaml = _workspaceRoot.path.replaceAll('\\', '/');

      await Directory(
        '${deprecatedPkgDir.path}${Platform.pathSeparator}lib',
      ).create(recursive: true);
      await File(
        '${deprecatedPkgDir.path}${Platform.pathSeparator}pubspec.yaml',
      ).writeAsString('''
name: deprecated_pkg
publish_to: none

environment:
  sdk: ">=3.10.0 <4.0.0"
''');
      await File(
        '${deprecatedPkgDir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}deprecated_pkg.dart',
      ).writeAsString('''
library deprecated_pkg;

@Deprecated('Use newFn instead.')
void oldFn() {}

void newFn() {}

class Holder {
  @Deprecated('Use newValue instead.')
  int get oldValue => 1;

  int get newValue => 2;
}

@Deprecated('Use NewClass instead.')
class OldClass {
  const OldClass();
}

class NewClass {
  const NewClass();
}
''');

      await Directory(
        '${_consumerDir.path}${Platform.pathSeparator}lib',
      ).create(recursive: true);
      await File(
        '${_consumerDir.path}${Platform.pathSeparator}pubspec.yaml',
      ).writeAsString('''
name: tmp_saropa_lints_consumer
publish_to: none

environment:
  sdk: ">=3.10.0 <4.0.0"

dependencies:
  deprecated_pkg:
    path: "$workspacePathForYaml/deprecated_pkg"

dev_dependencies:
  saropa_lints:
    path: "$repoPathForYaml"
''');

      await File(
        '${_consumerDir.path}${Platform.pathSeparator}analysis_options.yaml',
      ).writeAsString('''
analyzer:
  errors:
    deprecated_member_use: ignore
    deprecated_member_use_from_same_package: ignore

plugins:
  saropa_lints:
    diagnostics:
      avoid_deprecated_usage: true
''');

      final pubGet = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: _consumerDir.path,
        runInShell: true,
      );
      expect(
        pubGet.exitCode,
        0,
        reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
      );
    });

    tearDownAll(() async {
      if (_workspaceRoot.existsSync()) {
        await _workspaceRoot.delete(recursive: true);
      }
    });

    test(
      'does not crash analyzer plugin on non-deprecated code',
      () async {
        await _writeConsumerFile('lib/non_deprecated.dart', '''
class C {
  final Object o = Object();
}
''');

        final result = await _runAnalyze('lib/non_deprecated.dart');
        final output = '${result.stdout}\n${result.stderr}';

        expect(
          result.exitCode,
          isNot(4),
          reason: 'Analyzer plugin crash:\n$output',
        );
        expect(_hasPluginCrashMessage(output), isFalse, reason: output);
        expect(_containsRuleCode(output), isFalse, reason: output);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'reports deprecated APIs from another package (method, property, ctor)',
      () async {
        await _writeConsumerFile('lib/external_deprecated.dart', '''
import 'package:deprecated_pkg/deprecated_pkg.dart';

void f() {
  oldFn(); // expect_lint: avoid_deprecated_usage
  final v = Holder().oldValue; // expect_lint: avoid_deprecated_usage
  const OldClass(); // expect_lint: avoid_deprecated_usage
}
''');

        final result = await _runAnalyze('lib/external_deprecated.dart');
        final output = '${result.stdout}\n${result.stderr}';

        expect(
          result.exitCode,
          isNot(4),
          reason: 'Analyzer plugin crash:\n$output',
        );
        expect(_hasPluginCrashMessage(output), isFalse, reason: output);
        expect(_containsRuleCode(output), isTrue, reason: output);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'does not report deprecated APIs from the same package',
      () async {
        await _writeConsumerFile('lib/same_package_deprecated.dart', '''
@Deprecated('Use NewLocal instead.')
class OldLocal {
  const OldLocal();
}

class NewLocal {
  const NewLocal();
}

void f() {
  const OldLocal();
}
''');

        final result = await _runAnalyze('lib/same_package_deprecated.dart');
        final output = '${result.stdout}\n${result.stderr}';

        expect(
          result.exitCode,
          isNot(4),
          reason: 'Analyzer plugin crash:\n$output',
        );
        expect(_hasPluginCrashMessage(output), isFalse, reason: output);
        expect(_containsRuleCode(output), isFalse, reason: output);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('skips generated files', () async {
      await _writeConsumerFile('lib/generated.g.dart', '''
import 'package:deprecated_pkg/deprecated_pkg.dart';

void f() {
  oldFn();
  const OldClass();
  final v = Holder().oldValue;
}
''');

      final result = await _runAnalyze('lib/generated.g.dart');
      final output = '${result.stdout}\n${result.stderr}';

      expect(
        result.exitCode,
        isNot(4),
        reason: 'Analyzer plugin crash:\n$output',
      );
      expect(_hasPluginCrashMessage(output), isFalse, reason: output);
      expect(_containsRuleCode(output), isFalse, reason: output);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
