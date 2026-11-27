// `baseline: date:` against a real temporary git repository: what is hidden,
// what must still report, caching, and config reloads.
@Timeout(Duration(minutes: 4))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/baseline_activation.dart';
import 'package:saropa_lints/src/baseline/baseline_config.dart';
import 'package:saropa_lints/src/baseline/baseline_date.dart';
import 'package:saropa_lints/src/baseline/baseline_explain.dart';
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/native/config_loader.dart'
    show loadNativePluginConfigFromProjectRoot;
import 'package:test/test.dart';

import '../support/safe_delete.dart';
import '../support/temp_git.dart';

/// Between the old commits and the "recent" ones.
final DateTime _cutoff = DateTime(2022);

void main() {
  late Directory dir;
  late String repo;

  String at(String relative) => p.join(repo, relative);

  void write(String relative, String text) {
    final file = File(at(relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  void git(List<String> args) => tempGit(repo, args);

  void commit(String message, {String date = kOldCommitDate}) =>
      tempCommit(repo, message, date: date);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_baseline_date_');
    repo = dir.path;
    git(['init', '-q']);
    write('pubspec.yaml', 'name: t\n');
    write('lib/a.dart', 'one\ntwo\nthree\n');
    commit('old');
    BaselineManager.reset();
  });

  tearDown(() {
    BaselineManager.reset();
    safeDeleteDir(dir);
  });

  void useDate([DateTime? cutoff]) => BaselineManager.initialize(
    BaselineConfig(date: cutoff ?? _cutoff),
    projectRoot: repo,
  );

  /// Asked synchronously, with nothing preloaded: the first-analysis case.
  bool hidden(String relative, int line, {String? content}) =>
      BaselineManager.isBaselined(at(relative), 'r', line, content: content);

  group('what is hidden', () {
    // Porcelain prints a commit's date once; every later line of that commit
    // must still be dated.
    test('every old line, without any preload', () {
      useDate();
      for (var line = 1; line <= 3; line++) {
        expect(hidden('lib/a.dart', line), isTrue, reason: 'line $line');
      }
      expect(hidden('lib/a.dart', 4), isFalse);
    });

    test('lines committed after the date still report', () {
      write('lib/a.dart', 'one\nchanged\nthree\n');
      commit('recent', date: '2024-01-01T12:00:00');
      useDate();
      expect(hidden('lib/a.dart', 1), isTrue);
      expect(hidden('lib/a.dart', 2), isFalse);
      expect(hidden('lib/a.dart', 3), isTrue);
    });

    // A future cutoff proves "uncommitted" is not judged by its timestamp.
    test('uncommitted lines report even with a future date', () {
      write('lib/a.dart', 'one\nedited\nthree\n');
      useDate(DateTime(2100));
      expect(hidden('lib/a.dart', 1), isTrue);
      expect(hidden('lib/a.dart', 2), isFalse);
    });

    test('untracked and staged-only files report', () {
      write('lib/new.dart', 'x\n');
      useDate(DateTime(2100));
      expect(hidden('lib/new.dart', 1), isFalse);
      BaselineManager.reset();
      git(['add', 'lib/new.dart']);
      useDate(DateTime(2100));
      expect(hidden('lib/new.dart', 1), isFalse);
    });

    test('an unsaved buffer is mapped by its own lines', () {
      useDate();
      const buffer = 'inserted\none\ntwo\nthree\n';
      expect(hidden('lib/a.dart', 1, content: buffer), isFalse);
      expect(hidden('lib/a.dart', 2, content: buffer), isTrue);
      expect(hidden('lib/a.dart', 4, content: buffer), isTrue);
    });

    test('a file name with shell characters is blamed literally', () {
      write('lib/a & b.dart', 'x\n');
      commit('odd name');
      useDate();
      expect(hidden('lib/a & b.dart', 1), isTrue);
    });
  });

  group('safe failures', () {
    test('no repository reports', () {
      final outside = Directory.systemTemp.createTempSync('saropa_norepo_');
      addTearDown(() => safeDeleteDir(outside));
      final file = p.join(outside.path, 'a.dart');
      File(file).writeAsStringSync('x\n');
      expect(BaselineDate(DateTime(2100)).isLineOld(file, 1), isFalse);
    });

    test('missing git reports and does not throw', () {
      final date = BaselineDate(DateTime(2100), gitPath: 'saropa-no-such-git');
      expect(date.isLineOld(at('lib/a.dart'), 1), isFalse);
      expect(date.isLineOld(at('pubspec.yaml'), 1), isFalse);
    });

    test('a missing file reports', () {
      useDate();
      expect(hidden('lib/none.dart', 1), isFalse);
    });
  });

  group('cache', () {
    // With the repository gone, only cached answers can still say "old".
    test('one blame per content, including across reloads', () {
      useDate();
      expect(hidden('lib/a.dart', 1), isTrue);
      safeDeleteDir(Directory(at('.git')));
      expect(hidden('lib/a.dart', 2), isTrue);
      for (var i = 0; i < 3; i++) {
        BaselineManager.resetConfig();
        expect(hidden('lib/a.dart', 1), isFalse, reason: 'no config');
        useDate();
        expect(hidden('lib/a.dart', 1), isTrue, reason: 'reload $i');
      }
      // New content cannot reuse the old line map.
      write('lib/a.dart', 'zero\none\n');
      expect(hidden('lib/a.dart', 2), isFalse);
    });

    test('repeated loader reloads follow an edited date', () {
      void configure(String day) {
        write(kBaselineConfigFileName, 'baseline:\n  date: "$day"\n');
        loadNativePluginConfigFromProjectRoot(repo);
      }

      for (var i = 0; i < 3; i++) {
        configure('2022-01-01');
        expect(hidden('lib/a.dart', 1), isTrue, reason: 'pass $i');
        configure('2010-01-01');
        expect(hidden('lib/a.dart', 1), isFalse, reason: 'pass $i');
      }
      File(at(kBaselineConfigFileName)).deleteSync();
      loadNativePluginConfigFromProjectRoot(repo);
      expect(hidden('lib/a.dart', 1), isFalse);
    });

    // The plugin's mode: each file's own package picks the date.
    test('per-project dates survive repeated re-enabling', () {
      write('other/pubspec.yaml', 'name: o\n');
      write('other/lib/b.dart', 'x\n');
      commit('other');
      var otherDate = DateTime(2010);
      BaselineConfig reader(String root) =>
          BaselineConfig(date: p.equals(root, repo) ? _cutoff : otherDate);

      for (var i = 0; i < 3; i++) {
        BaselineManager.resetConfig();
        BaselineManager.enablePerRoot(reader);
        expect(hidden('lib/a.dart', 1), isTrue, reason: 'pass $i');
        expect(hidden('other/lib/b.dart', 1), isFalse, reason: 'pass $i');
      }
      otherDate = _cutoff;
      BaselineManager.enablePerRoot(reader);
      expect(hidden('other/lib/b.dart', 1), isTrue);
    });
  });

  test('the skip variable keeps the date in force', () {
    final config = baselineConfigFromContent(
      'baseline:\n  file: "b.json"\n  date: "2022-01-01"\n',
      {kSkipBaselineEnvVar: '1'},
    );
    expect(config?.file, isNull);
    BaselineManager.initialize(config!, projectRoot: repo);
    expect(hidden('lib/a.dart', 1), isTrue);
  });

  test('--explain counts the lines the date hides', () async {
    write(kBaselineConfigFileName, 'baseline:\n  date: "2022-01-01"\n');
    final text = await explainBaseline(at('lib/a.dart'), const {});
    expect(text, contains('findings on 3 line(s)'));
    expect(text, isNot(contains('does not currently hide')));
  });

  // The whole path in a child process: loader, rules, reporter, git. Both the
  // syntactic scan and the resolved one (the language server's runner).
  for (final resolve in [false, true]) {
    test('scan hides old findings only (resolve: $resolve)', () async {
      const body = "void old() {\n  print('old');\n}\n";
      write('pubspec.yaml', "name: t\nenvironment:\n  sdk: '>=3.0.0 <4.0.0'\n");
      write('lib/main.dart', body);
      commit('main');
      write('lib/main.dart', "${body}void added() {\n  print('new');\n}\n");
      write(kBaselineConfigFileName, 'baseline:\n  date: "2022-01-01"\n');

      final root = Directory.current.path;
      // Lines of the print() finding that `scan` reports in lib/main.dart.
      Future<List<Object?>> printLines() async {
        final result = await Process.run(Platform.resolvedExecutable, [
          '--packages=${p.join(root, '.dart_tool', 'package_config.json')}',
          p.join(root, 'bin', 'scan.dart'),
          repo,
          '--tier',
          'pedantic',
          '--format',
          'json',
          if (resolve) '--resolve',
        ]);
        final out = '${result.stdout}';
        expect(out, contains('{'), reason: '${result.stderr}');
        final json = jsonDecode(out.substring(out.indexOf('{'))) as Map;
        return [
          for (final d in json['diagnostics'] as List)
            if ((d as Map)['filePath'].toString().endsWith('main.dart') &&
                d['ruleName'] == 'prefer_logger_over_print')
              d['line'],
        ];
      }

      expect(await printLines(), [5]);
      // Control: without the baseline the old line is a finding too.
      File(at(kBaselineConfigFileName)).deleteSync();
      expect(await printLines(), [2, 5]);
    });
  }

  // Regression: `scan .` loaded no configuration at all, because the project
  // root lookup never examined `.` itself, so no baseline applied.
  for (final target in ['.', 'lib/..']) {
    test(
      'a relative target applies date and file baselines: $target',
      () async {
        const body = "void old() {\n  print('old');\n}\n";
        write(
          'pubspec.yaml',
          "name: t\nenvironment:\n  sdk: '>=3.0.0 <4.0.0'\n",
        );
        write('lib/main.dart', body);
        commit('main');
        // Line 5 stays a finding; line 8 is hidden only by the baseline file.
        write(
          'lib/main.dart',
          "${body}void added() {\n  print('new');\n}\n"
              "void listed() {\n  print('listed');\n}\n",
        );
        write(
          kBaselineConfigFileName,
          'baseline:\n  date: "2022-01-01"\n  file: "saropa_baseline.json"\n',
        );
        write(
          'saropa_baseline.json',
          jsonEncode({
            'version': 1,
            'generated': '2022-01-01T00:00:00Z',
            'violations': {
              'lib/main.dart': {
                'prefer_logger_over_print': [8],
              },
            },
          }),
        );

        final root = Directory.current.path;
        final result = await Process.run(Platform.resolvedExecutable, [
          '--packages=${p.join(root, '.dart_tool', 'package_config.json')}',
          p.join(root, 'bin', 'scan.dart'),
          target,
          '--tier',
          'pedantic',
          '--format',
          'json',
        ], workingDirectory: repo);
        final out = '${result.stdout}';
        expect(out, contains('{'), reason: '${result.stderr}');
        final json = jsonDecode(out.substring(out.indexOf('{'))) as Map;
        expect(
          [
            for (final d in json['diagnostics'] as List)
              if ((d as Map)['ruleName'] == 'prefer_logger_over_print')
                d['line'],
          ],
          [5],
        );
      },
    );
  }

  // The real `bin/lsp_server.dart` over JSON-RPC: its startup workspace scan
  // must publish the new finding and not the old one.
  test('the language server hides old findings only', () async {
    const body = "void old() {\n  print('old');\n}\n";
    write('pubspec.yaml', "name: t\nenvironment:\n  sdk: '>=3.0.0 <4.0.0'\n");
    write('analysis_options.yaml', 'saropa_lints:\n  tier: pedantic\n');
    write('lib/main.dart', body);
    commit('main');
    write('lib/main.dart', "${body}void added() {\n  print('new');\n}\n");
    write(kBaselineConfigFileName, 'baseline:\n  date: "2022-01-01"\n');

    expect(await _lspPrintLines(repo), [5]);
  });
}

/// Starts the language server on [project] and returns the (1-based) lines of
/// the print() findings it first publishes for `lib/main.dart`.
Future<List<int>> _lspPrintLines(String project) async {
  final root = Directory.current.path;
  final server = await Process.start(Platform.resolvedExecutable, [
    '--packages=${p.join(root, '.dart_tool', 'package_config.json')}',
    p.join(root, 'bin', 'lsp_server.dart'),
  ], workingDirectory: project);
  // Wait for the exit so Windows releases the temp project before deletion.
  addTearDown(() async {
    server.kill();
    await server.exitCode;
  });
  unawaited(server.stderr.drain<void>());

  void send(Map<String, Object?> message) {
    final body = utf8.encode(jsonEncode({'jsonrpc': '2.0', ...message}));
    server.stdin.add(ascii.encode('Content-Length: ${body.length}\r\n\r\n'));
    server.stdin.add(body);
  }

  send({
    'id': 1,
    'method': 'initialize',
    'params': {
      'rootUri': Uri.directory(project).toString(),
      'initializationOptions': {
        'workspaceScanDelay': 0,
        'scanDirectories': ['lib'],
      },
    },
  });
  send({'method': 'initialized', 'params': <String, Object?>{}});

  // Frames are `Content-Length` headers followed by that many bytes; latin1
  // keeps one char per byte so lengths apply to the buffer directly.
  final header = RegExp(r'Content-Length: (\d+)\r\n\r\n');
  var buffer = '';
  await for (final chunk in server.stdout.transform(latin1.decoder)) {
    buffer += chunk;
    for (var m = header.firstMatch(buffer); m != null;) {
      final end = m.end + int.parse(m.group(1)!);
      if (buffer.length < end) break;
      final text = utf8.decode(latin1.encode(buffer.substring(m.end, end)));
      buffer = buffer.substring(end);
      m = header.firstMatch(buffer);
      final message = jsonDecode(text) as Map;
      if (message['method'] != 'textDocument/publishDiagnostics') continue;
      final params = message['params'] as Map;
      if (!params['uri'].toString().endsWith('main.dart')) continue;
      return [
        for (final d in params['diagnostics'] as List)
          if ((d as Map)['code'] == 'prefer_logger_over_print')
            (((d['range'] as Map)['start'] as Map)['line'] as int) + 1,
      ];
    }
  }
  fail('the language server exited without publishing diagnostics');
}
