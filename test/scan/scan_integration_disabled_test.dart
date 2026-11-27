/// Tests that the scan CLI treats an extension-disabled project as "off".
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

  test('detects the extension OFF marker', () {
    writeOptions(
      '# >>> saropa_lints integration turned OFF by the VS Code extension >>>\n'
      '# plugins:\n#   saropa_lints:\n',
    );
    expect(isScanIntegrationDisabled(dir.path), isTrue);
  });

  test('false for plain config and for a missing file', () {
    expect(isScanIntegrationDisabled(dir.path), isFalse);
    writeOptions('include: package:lints/recommended.yaml\n');
    expect(isScanIntegrationDisabled(dir.path), isFalse);
  });

  test('scan CLI exits 0 and prints a disabled line', () async {
    writeOptions(
      '# >>> saropa_lints integration turned OFF by the VS Code extension >>>\n',
    );
    final result = await Process.run('dart', [
      'run',
      'saropa_lints',
      'scan',
      dir.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('disabled'));
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

  test('a plain scan of a configured, disabled project is skipped', () async {
    writeDisabledProject();
    final result = await Process.run('dart', [
      'run',
      'saropa_lints',
      'scan',
      dir.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('disabled'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
