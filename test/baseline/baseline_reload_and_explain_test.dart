// Config reload keeps blame answers, legacy `only_impacts` names work through
// the real loader, and `--explain` reports each baseline setting.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/baseline_activation.dart';
import 'package:saropa_lints/src/baseline/baseline_config.dart';
import 'package:saropa_lints/src/baseline/baseline_explain.dart';
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/native/config_loader.dart'
    show loadNativePluginConfigFromProjectRoot;
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_baseline_reload_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: t\n');
  });

  tearDown(() {
    BaselineManager.reset();
    safeDeleteDir(dir);
  });

  /// Writes the temp project's custom options.
  void options(String text) =>
      File(p.join(dir.path, kBaselineConfigFileName)).writeAsStringSync(text);

  String inProject(String relative) =>
      p.join(dir.path, relative).replaceAll('\\', '/');

  test('a config reload keeps preloaded date answers', () async {
    // A tracked file of this repository, blamed read-only; every committed
    // line is older than the cutoff.
    final root = Directory.current.path.replaceAll('\\', '/');
    final file = '$root/dart_test.yaml';
    final config = BaselineConfig(date: DateTime(2100));
    BaselineManager.initialize(config, projectRoot: root);
    await BaselineManager.preloadDateBaseline(file);
    expect(BaselineManager.isBaselined(file, 'r', 1), isTrue);

    // The loader's reload, for a project without any baseline.
    loadNativePluginConfigFromProjectRoot(dir.path);
    expect(BaselineManager.isBaselined(file, 'r', 1), isFalse);

    // The loader leaves per-package lookup on for every caller, which would
    // override the direct initialize below. resetConfig drops only the
    // config, so the blame answers this test is about still survive.
    BaselineManager.resetConfig();
    BaselineManager.initialize(config, projectRoot: root);
    expect(BaselineManager.isBaselined(file, 'r', 1), isTrue);

    // A different cutoff must not read answers computed for the old one.
    BaselineManager.initialize(
      BaselineConfig(date: DateTime(2000)),
      projectRoot: root,
    );
    expect(BaselineManager.isBaselined(file, 'r', 1), isFalse);
  });

  // The bare relative path resolves against the process cwd, which can hold
  // another project's baseline; only the project root may satisfy it.
  test('a relative baseline file is not read from the cwd', () {
    // Under .dart_tool (ignored) so a relative path from the cwd reaches it
    // without changing the process-global Directory.current.
    final other = Directory('.dart_tool').createTempSync('saropa_cwd_');
    addTearDown(() => safeDeleteDir(other));
    final relative = '.dart_tool/${p.basename(other.path)}/b.json';
    File(
      relative,
    ).writeAsStringSync('{"version":1,"violations":{"lib/a.dart":{"r":[1]}}}');

    BaselineManager.initialize(
      BaselineConfig(file: relative),
      projectRoot: dir.path,
    );
    expect(BaselineManager.baselineFile, isNull);

    // An absolute path is still honored.
    BaselineManager.initialize(
      BaselineConfig(file: p.absolute(relative)),
      projectRoot: dir.path,
    );
    expect(BaselineManager.baselineFile, isNotNull);
  });

  // Each legacy name maps onto exactly one current severity.
  const legacy = <String, String>{
    'critical': 'error',
    'high': 'warning',
    'medium': 'warning',
    'low': 'info',
    'opinionated': 'info',
  };
  for (final entry in legacy.entries) {
    test('loader maps only_impacts ${entry.key} to ${entry.value}', () {
      options('baseline:\n  paths: ["lib/"]\n  only_impacts: [${entry.key}]\n');
      loadNativePluginConfigFromProjectRoot(dir.path);
      for (final impact in <String>['error', 'warning', 'info']) {
        expect(
          BaselineManager.isBaselined(
            inProject('lib/a.dart'),
            'r',
            1,
            impact: impact,
          ),
          impact == entry.value,
          reason: impact,
        );
      }
    });
  }

  group('explainBaseline', () {
    Future<String> explain([Map<String, String> env = const {}]) =>
        explainBaseline(inProject('lib/legacy/a.dart'), env);

    setUp(() {
      Directory(p.join(dir.path, 'lib', 'legacy')).createSync(recursive: true);
      File(inProject('lib/legacy/a.dart')).writeAsStringSync('void f() {}\n');
      File(inProject('b.json')).writeAsStringSync(
        '{"version":1,"violations":{"lib/legacy/a.dart":{"r":[3,1]}}}',
      );
    });

    test('names the pattern, JSON entries and severities', () async {
      options(
        'baseline:\n  file: "b.json"\n  paths: ["lib/legacy/", "x/"]\n'
        '  only_impacts: [low]\n',
      );
      final text = await explain();
      expect(text, contains('paths: matched lib/legacy/;'));
      expect(text, contains('r: line 1, 3'));
      expect(text, contains('hide only info findings'));
      expect(text, contains('date: not set.'));
    });

    test('honors the skip variable', () async {
      options('baseline:\n  file: "b.json"\n  paths: ["x/"]\n');
      final text = await explain({kSkipBaselineEnvVar: '1'});
      expect(text, contains('file: not set.'));
      expect(text, contains('paths: no pattern matches.'));
    });

    test('reports a missing JSON file and an undatable file', () async {
      options('baseline:\n  file: "gone.json"\n  date: "2025-01-15"\n');
      final text = await explain();
      expect(text, contains('gone.json was not found'));
      expect(text, contains('git blame gave no line dates'));
    });

    test('says when no baseline applies', () async {
      expect(await explain(), contains('No baseline applies'));
    });
  });
}
