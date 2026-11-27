/// `scan --check-accepted` run as a real process on throwaway packages, the
/// way the extension's "Check Accepted Findings" runs it.
///
/// The unit tests judge hand-built findings; this one exists to prove the whole
/// chain (config, resolved scan, per-package lists, JSON file, exit code),
/// including nested packages, a package that only uses the plugin, and a plugin
/// block the extension commented out for the language server.
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/accepted/accepted_findings_list.dart'
    show kAcceptedFindingsFileName;
import 'package:saropa_lints/src/init/config_writer.dart'
    show wrapPluginsYamlAsDisabled;
import 'package:test/test.dart';

import '../support/safe_delete.dart';

const _options =
    'plugins:\n'
    '  saropa_lints:\n'
    '    diagnostics:\n'
    '      avoid_catch_all: true\n'
    '      avoid_print_error: true\n';

/// Two bare catches that print: `avoid_catch_all` and `avoid_print_error`.
const _source = '''
void first() {
  try {
    print('first');
  } catch (e) {
    print(e);
  }
}
''';

/// A list entry whose file does not exist.
const _goneEntry =
    '  - rule: avoid_catch_all\n'
    '    file: lib/gone.dart\n'
    '    reason: file does not exist\n';

void main() {
  late Directory dir;
  late String root;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_check_cli_');
    // Resolve 8.3 short names so scanned and listed paths agree.
    root = dir.resolveSymbolicLinksSync();
  });

  tearDown(() => safeDeleteDir(dir));

  void write(String relative, String text) {
    File(p.join(root, relative))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  /// A package at [at] with one source file per name in [sources].
  void package(String at, List<String> sources, {String? options}) {
    final name = p.basename(at);
    write(
      '$at/pubspec.yaml',
      "name: $name\nenvironment:\n  sdk: '>=3.0.0 <4.0.0'\n",
    );
    if (options != null) write('$at/analysis_options.yaml', options);
    for (final s in sources) {
      write('$at/lib/$s', _source);
    }
  }

  void list(String at, String entries) => write(
    '$at/$kAcceptedFindingsFileName',
    'version: 1\naccepted:\n$entries',
  );

  /// Runs the check on [at]; returns the exit code and the JSON report.
  Future<(int, Map<String, dynamic>)> check(
    String at, [
    List<String> extra = const [],
  ]) async {
    final repo = Directory.current.path;
    final out = p.join(root, 'check.json');
    final result = await Process.run(Platform.resolvedExecutable, [
      '--packages=${p.join(repo, '.dart_tool', 'package_config.json')}',
      p.join(repo, 'bin', 'scan.dart'),
      p.join(root, at),
      '--check-accepted',
      '--format',
      'json',
      '--json-file-path',
      out,
      '-q',
      ...extra,
    ]);
    final file = File(out);
    expect(file.existsSync(), isTrue, reason: '${result.stderr}');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    file.deleteSync();
    return (result.exitCode, json);
  }

  Map<String, dynamic> summary(Map<String, dynamic> json) =>
      json['summary'] as Map<String, dynamic>;

  test('no list, then a clean list, then stale and invalid entries', () async {
    package('main', ['a.dart', 'b.dart'], options: _options);
    write('main/lib/clean.dart', 'void nothing() {}\n');

    var (code, json) = await check('main');
    expect(code, 0);
    expect(json['lists'], isEmpty);

    list(
      'main',
      '  - rule: avoid_catch_all\n    file: lib/b.dart\n    reason: ok\n',
    );
    (code, json) = await check('main');
    expect(code, 0);
    expect(summary(json), containsPair('entryCount', 1));
    expect(summary(json), containsPair('stale', 0));
    expect(summary(json), containsPair('problemCount', 0));

    // Lines 3, 6, 9 and 12 of the file start the four entries.
    list(
      'main',
      '  - rule: avoid_print_error\n    file: lib/a.dart\n'
          '    reason: still matches\n'
          '  - rule: avoid_catch_all\n    file: lib/clean.dart\n'
          '    reason: nothing found there\n'
          '$_goneEntry'
          '  - rule: avoid_catch_all\n    file: lib/b.dart\n',
    );
    (code, json) = await check('main');
    expect(code, 1);
    expect(summary(json), containsPair('entryCount', 3));
    expect(summary(json), containsPair('stale', 2));
    expect(summary(json), containsPair('problemCount', 1));
    final only = (json['lists'] as List).single as Map<String, dynamic>;
    expect(
      [for (final e in only['entries'] as List) '${e['line']} ${e['state']}'],
      ['3 active', '6 staleNoFinding', '9 staleFileMissing'],
    );
    expect((only['problems'] as List).single['line'], 12);
  });

  test('judges nested, one-level-down and plugin-only lists', () async {
    package('main', ['a.dart'], options: _options);
    package('main/example', ['c.dart']);
    package('second/app', ['d.dart'], options: _options);
    package('plugin_only', ['e.dart'], options: _options);
    String live(String file) =>
        '  - rule: avoid_catch_all\n    file: lib/$file\n    reason: ok\n';
    list('main', '${live('a.dart')}$_goneEntry');
    list('main/example', '${live('c.dart')}$_goneEntry');
    list('second/app', '${live('d.dart')}$_goneEntry');
    list('plugin_only', _goneEntry);

    var lists = 0;
    var stale = 0;
    var active = 0;
    var notChecked = 0;
    var invalid = 0;
    // The extension's runs: one per workspace package root; the nested
    // example package is covered by the run on its enclosing folder.
    for (final target in ['main', 'second/app', 'plugin_only']) {
      final (code, json) = await check(target);
      expect(code, 1, reason: target);
      lists += summary(json)['listCount'] as int;
      stale += summary(json)['stale'] as int;
      active += summary(json)['active'] as int;
      notChecked += summary(json)['notChecked'] as int;
      invalid += summary(json)['problemCount'] as int;
    }
    // The run on `main` also scans the `main/example/` file its list names,
    // although a normal scan skips example folders.
    expect((lists, stale, active, notChecked, invalid), (4, 4, 3, 0, 0));
  });

  test('judges entries on files a normal scan skips', () async {
    package(
      'main',
      ['a.dart'],
      options:
          '${_options}analyzer:\n'
          '  exclude:\n    - example/**\n',
    );
    package('main/example', ['c.dart']);
    write('main/examples/demo.dart', _source);
    write('main/example/lib/clean.dart', 'void nothing() {}\n');
    String entry(String file) =>
        '  - rule: avoid_catch_all\n    file: $file\n    reason: ok\n';
    list('main', entry('examples/demo.dart'));
    list('main/example', '${entry('lib/c.dart')}${entry('lib/clean.dart')}');

    var (code, json) = await check('main');
    expect(code, 1);
    expect(summary(json), containsPair('active', 2));
    expect(summary(json), containsPair('stale', 1));
    expect(summary(json), containsPair('notChecked', 0));

    // The user's own globs still apply: those entries stay unjudged.
    (code, json) = await check('main', ['--exclude-globs', 'example/**']);
    expect(code, 0, reason: '$json');
    expect(summary(json), containsPair('active', 1));
    expect(summary(json), containsPair('notChecked', 2));
  });

  test('uses a nested package\'s own config for its skipped files', () async {
    package('main', ['a.dart'], options: _options);
    package(
      'main/example',
      ['c.dart'],
      options:
          'plugins:\n  saropa_lints:\n    diagnostics:\n'
          '      avoid_print_error: true\n',
    );
    // `avoid_catch_all` does not run under the example's config, so the entry
    // is unjudged rather than stale or active.
    list(
      'main/example',
      '  - rule: avoid_catch_all\n    file: lib/c.dart\n    reason: ok\n',
    );
    final (code, json) = await check('main');
    expect(code, 0, reason: '$json');
    expect(summary(json), containsPair('notChecked', 1));
  });

  test('still checks when the plugin block is commented out', () async {
    package('main', ['a.dart'], options: wrapPluginsYamlAsDisabled(_options));
    list(
      'main',
      '  - rule: avoid_catch_all\n    file: lib/a.dart\n    reason: ok\n',
    );
    final (code, json) = await check('main');
    expect(code, 0, reason: '$json');
    expect(summary(json), containsPair('active', 1));
  });
}
