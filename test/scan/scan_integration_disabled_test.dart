/// Tests how the scan CLI treats a commented-out plugin block: skipped when
/// saropa_lints is switched off, scanned when only the plugin is replaced.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/scan.dart';
import 'package:saropa_lints/src/init/config_writer.dart'
    show wrapPluginsYamlAsDisabled;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('scan_disabled_'));
  tearDown(() => dir.deleteSync(recursive: true));

  void writeOptions(String content) => File(
    p.join(dir.path, 'analysis_options.yaml'),
  ).writeAsStringSync(content);

  /// Writes [content] to [relative] under [root] (default: the temp project).
  void writeFile(String relative, String content, [String? root]) {
    File(p.join(root ?? dir.path, relative))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  const marker =
      '# >>> saropa_lints integration turned OFF by the VS Code extension >>>\n';
  final settings = p.join('.vscode', 'settings.json');
  final claim = p.join('.dart_tool', 'saropa_lints', 'plugin_ownership.json');

  test('the marker alone does not mean "off"', () {
    writeOptions('$marker# plugins:\n#   saropa_lints:\n');
    expect(hasCommentedOutPluginBlock(dir.path), isTrue);
    expect(isScanIntegrationDisabled(dir.path), isFalse);
  });

  test('false for plain config and for a missing file', () {
    writeFile(settings, '{"saropaLints.enabled": false}');
    expect(isScanIntegrationDisabled(dir.path), isFalse);
    writeOptions('include: package:lints/recommended.yaml\n');
    expect(isScanIntegrationDisabled(dir.path), isFalse);
  });

  test('off when the settings file turns the master switch off', () {
    writeOptions(marker);
    writeFile(
      settings,
      '{\n  "url": "http://x", // note\n  "saropaLints.enabled": false,\n}\n',
    );
    expect(isScanIntegrationDisabled(dir.path), isTrue);
  });

  test('a commented-out setting is ignored', () {
    writeOptions(marker);
    writeFile(
      settings,
      '{\n  // "saropaLints.enabled": false\n'
      '  /* "saropaLints.enabled": false */\n}\n',
    );
    expect(isScanIntegrationDisabled(dir.path), isFalse);
  });

  test('reads the settings file one folder above the project', () {
    final app = p.join(dir.path, 'app');
    writeFile('analysis_options.yaml', marker, app);
    writeFile(settings, '{"saropaLints.enabled": false}');
    expect(isScanIntegrationDisabled(app), isTrue);
  });

  test('off when the extension owns the disable, unless re-enabled', () {
    writeOptions(marker);
    writeFile(claim, '{"disabledByExtension": true}');
    expect(isScanIntegrationDisabled(dir.path), isTrue);
    writeFile(settings, '{"saropaLints.enabled": true}');
    expect(isScanIntegrationDisabled(dir.path), isFalse);
  });

  test('a damaged ownership file is no claim', () {
    writeOptions(marker);
    writeFile(claim, '{');
    expect(isScanIntegrationDisabled(dir.path), isFalse);
  });

  /// Runs the real CLI on the temp project.
  Future<ProcessResult> scan([List<String> extra = const []]) =>
      Process.run('dart', ['run', 'saropa_lints', 'scan', dir.path, ...extra]);

  test('a block with no rule settings is skipped', () async {
    writeOptions(marker);
    final result = await scan();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('holds no rule settings; scan skipped'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  /// A project as the extension leaves it with the language server on: the
  /// whole plugin block, rule list included, commented out between markers.
  void writeDisabledProject() {
    writeOptions(
      wrapPluginsYamlAsDisabled(
        'plugins:\n'
        '  saropa_lints:\n'
        '    diagnostics:\n'
        '      avoid_print_error: true',
      ),
    );
    File(
      p.join(dir.path, 'pubspec.yaml'),
    ).writeAsStringSync("name: t\nenvironment:\n  sdk: '>=3.0.0 <4.0.0'\n");
    File(p.join(dir.path, 'lib', 'a.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        'void f() {\n  try {\n  } catch (e) {\n    print(e);\n  }\n}\n',
      );
    File(p.join(dir.path, 'saropa_accepted.yaml')).writeAsStringSync(
      'version: 1\naccepted:\n'
      '  - rule: avoid_print_error\n'
      '    file: lib/a.dart\n'
      '    reason: test\n',
    );
  }

  test('reads the rule list from the commented-out block', () {
    writeDisabledProject();
    expect(
      loadScanConfig(dir.path)?.enabledRules,
      contains('avoid_print_error'),
    );
  });

  // Regression: with the language server on (the default) the check printed
  // "scan skipped", exited 0 and wrote no result file.
  test('--check-accepted runs on a disabled plugin block', () async {
    writeDisabledProject();
    final json = p.join(dir.path, 'out.json');
    final result = await Process.run('dart', [
      'run',
      'saropa_lints',
      'scan',
      dir.path,
      '--check-accepted',
      '--format',
      'json',
      '--json-file-path',
      json,
    ]);
    final log = '${result.stdout}${result.stderr}';
    expect(result.exitCode, 0, reason: log);
    expect(File(json).existsSync(), isTrue, reason: log);
    // The entry matched a finding, so the configured rule really ran.
    expect(
      File(json).readAsStringSync(),
      matches(RegExp(r'"hiddenTotal":\s*1')),
      reason: log,
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  // The stale-ignore modes used to print "scan skipped" here because their
  // scan reported live ignores as stale. Now evidence-gated, they run: the
  // live comment is kept and only the dead one is reported.
  test('--find-stale-ignores runs on a disabled plugin block', () async {
    writeDisabledProject();
    File(p.join(dir.path, 'lib', 'a.dart')).writeAsStringSync(
      'void f() {\n'
      '  try {\n'
      '  } catch (e) {\n'
      '    // ignore: avoid_print_error\n'
      '    print(e);\n'
      '  }\n'
      '  // ignore: avoid_print_error\n'
      '  int x = 1;\n'
      '}\n',
    );
    final json = p.join(dir.path, 'stale.json');
    final result = await Process.run('dart', [
      'run',
      'saropa_lints',
      'scan',
      dir.path,
      '--find-stale-ignores',
      '--format',
      'json',
      '--json-file-path',
      json,
    ]);
    final log = '${result.stdout}${result.stderr}';
    // Exit 1 = stale comments found (the dead one), not a failure.
    expect(result.exitCode, 1, reason: log);
    final out = File(json).readAsStringSync();
    expect(out, matches(RegExp(r'"totalCount":\s*1')), reason: log);
    expect(out, matches(RegExp(r'"commentLine":\s*7')), reason: log);
  }, timeout: const Timeout(Duration(minutes: 3)));

  // The language server case: nothing records "off", so the scan runs with
  // the commented-out rule list.
  test('a plain scan uses the commented-out rule settings', () async {
    writeDisabledProject();
    File(p.join(dir.path, 'saropa_accepted.yaml')).deleteSync();
    final json = p.join(dir.path, 'plain.json');
    final result = await scan(['--format', 'json', '--json-file-path', json]);
    final log = '${result.stdout}${result.stderr}';
    // Exit 1 = findings reported.
    expect(result.exitCode, 1, reason: log);
    expect(result.stdout, isNot(contains('scan skipped')), reason: log);
    expect(File(json).readAsStringSync(), contains('avoid_print_error'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a plain scan of a switched-off project is skipped', () async {
    writeDisabledProject();
    writeFile(settings, '{"saropaLints.enabled": false}');
    final result = await scan();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('turned off for this project'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
