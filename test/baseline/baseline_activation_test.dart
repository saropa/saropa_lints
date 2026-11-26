// Tests for where the baseline is activated and how it loads: the CLI writes a
// top-level `baseline:` section into analysis_options_custom.yaml (the only
// place the loader reads), the loader resolves the baseline file against the
// project root rather than the working directory, and the skip env var the
// CLI sets on its own `dart analyze` run is recognized.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/baseline_activation.dart';
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/native/config_loader.dart'
    show loadNativePluginConfigFromProjectRoot;
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  group('addBaselineActivation', () {
    test('appends a top-level section the loader matches', () {
      final out = addBaselineActivation('log_level: info\n', 'b.json');
      expect(out, 'log_level: info\nbaseline:\n  file: "b.json"\n');
      // Positive case for the loader's own key pattern.
      expect(RegExp(r'^baseline:\s*$', multiLine: true).hasMatch(out!), isTrue);
    });

    test('creates content for a new file and adds a missing newline', () {
      expect(
        addBaselineActivation('', 'b.json'),
        'baseline:\n  file: "b.json"\n',
      );
      expect(
        addBaselineActivation('a: 1', 'b.json'),
        'a: 1\nbaseline:\n  file: "b.json"\n',
      );
    });

    test('keeps CRLF and writes forward slashes', () {
      expect(
        addBaselineActivation('a: 1\r\n', r'sub\b.json'),
        'a: 1\r\nbaseline:\r\n  file: "sub/b.json"\r\n',
      );
    });

    test('leaves an existing top-level section alone', () {
      expect(
        addBaselineActivation('baseline:\n  file: "x.json"\n', 'b.json'),
        isNull,
      );
      expect(
        addBaselineActivation('baseline:\r\n  file: "x.json"\r\n', 'b.json'),
        isNull,
      );
    });

    test('a nested baseline key does not count as configured', () {
      expect(addBaselineActivation('foo:\n  baseline:\n', 'b.json'), isNotNull);
    });
  });

  test('hasLegacyNestedBaseline spots the old plugin-block insert', () {
    const old =
        'plugins:\n  saropa_lints:\n    baseline:\n      file: "b.json"\n';
    expect(hasLegacyNestedBaseline(old), isTrue);
    expect(hasLegacyNestedBaseline('baseline:\n  file: "b.json"\n'), isFalse);
  });

  test('isBaselineSkippedByEnv accepts 1/true and rejects 0/false/empty', () {
    expect(isBaselineSkippedByEnv({kSkipBaselineEnvVar: '1'}), isTrue);
    expect(isBaselineSkippedByEnv({kSkipBaselineEnvVar: 'TRUE'}), isTrue);
    expect(isBaselineSkippedByEnv({kSkipBaselineEnvVar: '0'}), isFalse);
    expect(isBaselineSkippedByEnv({kSkipBaselineEnvVar: 'false'}), isFalse);
    expect(isBaselineSkippedByEnv({kSkipBaselineEnvVar: ' '}), isFalse);
    expect(isBaselineSkippedByEnv(const {}), isFalse);
  });

  group('config loader', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('saropa_baseline_root_');
      BaselineManager.reset();
    });

    tearDown(() {
      BaselineManager.reset();
      safeDeleteDir(dir);
    });

    test('resolves a relative baseline file against the project root', () {
      // The test's working directory is the repo root, which has no
      // saropa_baseline.json; the old Directory.current resolution therefore
      // loaded nothing here.
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');
      File(
        p.join(dir.path, 'analysis_options.yaml'),
      ).writeAsStringSync('plugins:\n  saropa_lints:\n    version: any\n');
      File(
        p.join(dir.path, kBaselineConfigFileName),
      ).writeAsStringSync(addBaselineActivation('', 'saropa_baseline.json')!);
      File(p.join(dir.path, 'saropa_baseline.json')).writeAsStringSync(
        '{"version":1,"violations":{"lib/a.dart":{"avoid_print":[3]}}}',
      );

      loadNativePluginConfigFromProjectRoot(dir.path);

      expect(BaselineManager.baselineFile, isNotNull);
      expect(
        BaselineManager.isBaselined(
          p.join(dir.path, 'lib', 'a.dart'),
          'avoid_print',
          3,
        ),
        isTrue,
      );
      // Other lines and rules stay visible.
      expect(
        BaselineManager.isBaselined(
          p.join(dir.path, 'lib', 'a.dart'),
          'avoid_print',
          4,
        ),
        isFalse,
      );
    });
  });
}
