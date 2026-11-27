// End-to-end checks that need a separate process: the loader reading the real
// SAROPA_LINTS_SKIP_BASELINE variable, and `bin/baseline.dart` itself.
//
// `dart analyze` is never run: the CLI's `dart` call is answered by a stub
// script placed in the temp project and first on PATH.
@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/baseline_activation.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

/// Absolute so child processes resolve packages from any working directory.
final String _repo = Directory.current.path;
final String _packages =
    '--packages=${p.join(_repo, '.dart_tool', 'package_config.json')}';

void main() {
  late Directory dir;
  late String project;

  /// Writes [text] to [relative] inside the temp project.
  void write(String relative, String text) {
    final file = File(p.join(project, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_baseline_cli_');
    project = p.join(dir.path, 'proj');
    write('pubspec.yaml', 'name: proj\n');
    write('lib/a.dart', 'void main() {}\n');
    // The stub records the variable it was given, then prints one finding in
    // the `dart analyze` human format.
    const finding = 'info - lib/a.dart:1:1 - Message. - avoid_print';
    if (Platform.isWindows) {
      write(
        'dart.bat',
        '@echo off\r\n'
            'echo [%SAROPA_LINTS_SKIP_BASELINE%]> env_seen.txt\r\n'
            'echo   $finding\r\n',
      );
    } else {
      write(
        'dart',
        '#!/bin/sh\n'
            'echo "[\$SAROPA_LINTS_SKIP_BASELINE]" > env_seen.txt\n'
            'echo "  $finding"\n',
      );
      Process.runSync('chmod', ['+x', p.join(project, 'dart')]);
    }
  });

  tearDown(() => safeDeleteDir(dir));

  /// Runs `bin/baseline.dart` from the temp parent with the stub on PATH.
  Future<ProcessResult> cli(List<String> args) {
    // Reuse the parent's own spelling (`Path` on Windows) to avoid two keys.
    final key = Platform.environment.keys.firstWhere(
      (k) => k.toUpperCase() == 'PATH',
      orElse: () => 'PATH',
    );
    final separator = Platform.isWindows ? ';' : ':';
    return Process.run(
      Platform.resolvedExecutable,
      [_packages, p.join(_repo, 'bin', 'baseline.dart'), ...args],
      workingDirectory: dir.path,
      environment: {key: '$project$separator${Platform.environment[key]}'},
    );
  }

  test('positional path: writes, activates and sets the skip var', () async {
    final result = await cli(['proj']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
      File(p.join(project, 'env_seen.txt')).readAsStringSync().trim(),
      '[1]',
    );
    final json = jsonDecode(
      File(p.join(project, 'saropa_baseline.json')).readAsStringSync(),
    );
    expect(((json as Map)['violations'] as Map).keys, ['lib/a.dart']);
    expect(
      File(p.join(project, kBaselineConfigFileName)).readAsStringSync(),
      contains('file: "saropa_baseline.json"'),
    );
    // Nothing lands in the caller's directory.
    expect(
      File(p.join(dir.path, 'saropa_baseline.json')).existsSync(),
      isFalse,
    );

    final explain = await cli(['proj', '--explain', 'lib/a.dart']);
    expect(explain.exitCode, 0, reason: '${explain.stderr}');
    expect(explain.stdout, contains('avoid_print: line 1'));
  });

  test('--explain reports a missing file', () async {
    final result = await cli(['proj', '--explain', 'lib/none.dart']);
    expect(result.exitCode, 66);
    expect(result.stderr, contains('file not found'));
  });

  test('the loader reads the real skip variable', () async {
    write(
      kBaselineConfigFileName,
      'baseline:\n  file: "b.json"\n  paths: ["lib/legacy/"]\n',
    );
    write('b.json', '{"version":1,"violations":{"lib/a.dart":{"r":[1]}}}');
    // A real child process: Platform.environment cannot be changed in-process.
    final script = File(p.join(dir.path, 'probe.dart'))
      ..writeAsStringSync(r'''
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/native/config_loader.dart';

void main(List<String> args) {
  final root = args.single;
  loadNativePluginConfigFromProjectRoot(root);
  final json = BaselineManager.isBaselined('$root/lib/a.dart', 'r', 1);
  final path = BaselineManager.isBaselined('$root/lib/legacy/x.dart', 'r', 1);
  print('json=$json path=$path');
}
''');
    Future<String> probe(String value) async {
      final result = await Process.run(
        Platform.resolvedExecutable,
        [_packages, script.path, project.replaceAll('\\', '/')],
        environment: {kSkipBaselineEnvVar: value},
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return '${result.stdout}';
    }

    expect(await probe('0'), contains('json=true path=true'));
    expect(await probe('1'), contains('json=false path=true'));
  });
}
