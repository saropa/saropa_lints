// Tests for where the baseline is activated and how it loads: the CLI writes a
// top-level `baseline:` section into analysis_options_custom.yaml (the only
// place the loader reads), the loader resolves the baseline file against the
// project root rather than the working directory, and the skip env var the
// CLI sets on its own `dart analyze` run is recognized.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/baseline_activation.dart';
import 'package:saropa_lints/src/baseline/baseline_cli_args.dart';
import 'package:saropa_lints/src/baseline/baseline_config.dart';
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/project_context.dart' show ProjectContext;
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

    test('leaves a section that already names the file alone', () {
      expect(
        addBaselineActivation('baseline:\n  file: "b.json"\n', 'b.json'),
        isNull,
      );
      expect(
        addBaselineActivation('baseline:\r\n  file: b.json # x\r\n', 'b.json'),
        isNull,
      );
      expect(
        addBaselineActivation(
          'baseline:\n  file: "./sub\\b.json"\n',
          'sub/b.json',
        ),
        isNull,
      );
    });

    // Assertion updated: an existing section naming another file used to be
    // left alone (null), so the JSON just written was never referenced.
    test('repoints a section that names a different file', () {
      expect(
        addBaselineActivation('baseline:\n  file: "x.json"\n', 'b.json'),
        'baseline:\n  file: "b.json"\n',
      );
      expect(
        addBaselineActivation('baseline:\r\n  file: "x.json"\r\n', 'b.json'),
        'baseline:\r\n  file: "b.json"\r\n',
      );
    });

    test('a nested baseline key does not count as configured', () {
      expect(addBaselineActivation('foo:\n  baseline:\n', 'b.json'), isNotNull);
    });
  });

  group('planBaselineActivation', () {
    test('adds file: to a section without one, keeping other keys', () {
      const existing =
          'a: 1\nbaseline:\n    date: "2025-01-15"\n    paths:\n'
          '      - lib/old/\nmax_issues: 5\n';
      final plan = planBaselineActivation(existing, 'b.json');
      expect(plan.kind, BaselineActivationKind.fileAdded);
      expect(
        plan.text,
        'a: 1\nbaseline:\n    file: "b.json"\n    date: "2025-01-15"\n'
        '    paths:\n      - lib/old/\nmax_issues: 5\n',
      );
      expect(plan.fileLine, 'file: "b.json"');
    });

    test('replacing reports the old and new line', () {
      final plan = planBaselineActivation(
        'baseline:\n  file: old.json # legacy\n  date: 2025-01-01\n',
        'b.json',
      );
      expect(plan.kind, BaselineActivationKind.fileReplaced);
      expect(plan.text, 'baseline:\n  file: "b.json"\n  date: 2025-01-01\n');
      expect(plan.previousFileLine, 'file: old.json # legacy');
      final message = describeBaselineActivation(plan, kBaselineConfigFileName);
      expect(message, contains('file: old.json # legacy'));
      expect(message, contains('file: "b.json"'));
    });

    test("a file: key after the section ends is not the section's", () {
      final plan = planBaselineActivation(
        'baseline:\n  date: 2025-01-01\nother:\n  file: x.json\n',
        'b.json',
      );
      expect(plan.kind, BaselineActivationKind.fileAdded);
      expect(
        plan.text,
        'baseline:\n  file: "b.json"\n  date: 2025-01-01\n'
        'other:\n  file: x.json\n',
      );
    });

    test('every kind has a message naming the file', () {
      final kinds = <BaselineActivationKind>{};
      for (final existing in <String>[
        '',
        'baseline:\n  date: 2025-01-01\n',
        'baseline:\n  file: x.json\n',
        'baseline:\n  file: b.json\n',
      ]) {
        final plan = planBaselineActivation(existing, 'b.json');
        kinds.add(plan.kind);
        expect(
          describeBaselineActivation(plan, kBaselineConfigFileName),
          contains(kBaselineConfigFileName),
        );
      }
      expect(kinds, BaselineActivationKind.values.toSet());
    });
  });

  group('baselineWorkingDir', () {
    // Regression: argument 0 was excluded because -1 + 1 == 0 when no
    // `-o` was given, so `baseline ./my_project` ran on the current dir.
    test('takes the first positional argument, including argument 0', () {
      expect(baselineWorkingDir(<String>['./my_project']), './my_project');
      expect(
        baselineWorkingDir(<String>['./my_project', '--update']),
        './my_project',
      );
      expect(baselineWorkingDir(<String>['--dry-run', 'app']), 'app');
    });

    test('skips option values and defaults to the current directory', () {
      expect(baselineWorkingDir(<String>['-o', 'b.json']), '.');
      expect(baselineWorkingDir(<String>['--output', 'b.json', 'app']), 'app');
      expect(baselineWorkingDir(<String>['app', '-o', 'app']), 'app');
      expect(baselineWorkingDir(const <String>[]), '.');
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

  // The skip variable drops the JSON only; `date:` / `paths:` stay active.
  test('baselineConfigForEnv removes only the file under the skip var', () {
    final config = BaselineConfig(
      file: 'b.json',
      date: DateTime(2025),
      paths: const <String>['lib/legacy/'],
      onlyImpacts: const <String>['info'],
    );
    final skipped = baselineConfigForEnv(config, {kSkipBaselineEnvVar: '1'});
    expect(skipped.file, isNull);
    expect(skipped.date, DateTime(2025));
    expect(skipped.paths, <String>['lib/legacy/']);
    expect(skipped.onlyImpacts, <String>['info']);
    expect(skipped.isEnabled, isTrue);
    expect(baselineConfigForEnv(config, const {}).file, 'b.json');
  });

  // The loader and the CLI must agree on what counts as the section header.
  test('a header with a trailing comment is one section, not two', () {
    final plan = planBaselineActivation(
      'baseline:  # legacy\n  date: 2025-01-01\n',
      'b.json',
    );
    expect(plan.kind, BaselineActivationKind.fileAdded);
    expect(
      plan.text,
      'baseline:  # legacy\n  file: "b.json"\n  date: 2025-01-01\n',
    );
  });

  // One analysis server hosts several projects: each file must be checked
  // against its own project's baseline, never another project's.
  group('per-root baseline', () {
    late Directory dir;

    /// Reader equivalent to the loader's, for the two paths used here.
    BaselineConfig? reader(String root) {
      final marker = File(p.join(root, 'paths.txt'));
      if (!marker.existsSync()) return null;
      return BaselineConfig(paths: <String>[marker.readAsStringSync()]);
    }

    /// Creates a package at [name], baselining [pattern] when given.
    String package(String name, [String? pattern]) {
      final root = p.join(dir.path, name);
      Directory(p.join(root, 'lib')).createSync(recursive: true);
      File(p.join(root, 'pubspec.yaml')).writeAsStringSync('name: x\n');
      if (pattern != null) {
        File(p.join(root, 'paths.txt')).writeAsStringSync(pattern);
      }
      return root;
    }

    bool baselined(String root, String file) =>
        BaselineManager.isBaselined(p.join(root, 'lib', file), 'r', 1);

    setUp(() {
      dir = Directory.systemTemp.createTempSync('saropa_baseline_roots_');
      BaselineManager.reset();
      ProjectContext.clearCache();
    });

    tearDown(() {
      BaselineManager.reset();
      safeDeleteDir(dir);
    });

    test('each project uses its own section, in any order', () {
      final a = package('a', 'lib/a.dart');
      final b = package('b', 'lib/b.dart');
      final none = package('none');
      BaselineManager.enablePerRoot(reader);
      expect(BaselineManager.isEnabled, isTrue);
      expect(baselined(b, 'b.dart'), isTrue);
      expect(baselined(a, 'a.dart'), isTrue);
      expect(baselined(a, 'b.dart'), isFalse);
      expect(baselined(b, 'a.dart'), isFalse);
      expect(baselined(none, 'a.dart'), isFalse);
    });

    test('a nested package without a section inherits its parent', () {
      final outer = package('outer', 'example/lib/a.dart');
      final example = package('outer/example');
      BaselineManager.enablePerRoot(reader);
      expect(baselined(example, 'a.dart'), isTrue);
      expect(baselined(outer, 'a.dart'), isFalse);
    });
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
