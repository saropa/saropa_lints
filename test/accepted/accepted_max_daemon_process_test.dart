/// End-to-end check of an accepted-findings `max:` through the real
/// `bin/scan_daemon.dart` process over its NDJSON stdin/stdout protocol.
///
/// Unit tests cover `filterAcceptedByNearestRoot` in isolation; this test
/// exists because the daemon is a separate process whose request handler
/// chains `filterIgnoredDiagnostics` then `filterAcceptedByNearestRoot`, and
/// nothing proved that chain end to end — in particular that a `// ignore:`d
/// finding is dropped before the accepted filter, so it neither reaches the
/// Problems panel nor uses up `max`.
@Timeout(Duration(minutes: 4))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/accepted/accepted_findings_list.dart'
    show kAcceptedFindingsFileName;
import 'package:test/test.dart';

import '../support/safe_delete.dart';

/// Rule the fixture triggers once per `print()` call (pedantic tier).
const _rule = 'prefer_logger_over_print';

void main() {
  late Directory dir;
  late String project;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_daemon_max_');
    // Resolve 8.3 short names / symlinks so the paths the daemon reports and
    // the paths the accepted lookup walks agree.
    project = dir.resolveSymbolicLinksSync();
  });

  tearDown(() => safeDeleteDir(dir));

  void write(String relative, String text) {
    final file = File(p.join(project, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  /// A package whose three print() calls sit on lines 2, 3 and 4. When
  /// [ignoreFirst] is set, line 2 carries a trailing `// ignore:`.
  void fixture({required bool ignoreFirst}) {
    write('pubspec.yaml', "name: t\nenvironment:\n  sdk: '>=3.0.0 <4.0.0'\n");
    final ignore = ignoreFirst ? ' // ignore: $_rule' : '';
    write(
      'lib/main.dart',
      "void f() {\n  print('a');$ignore\n  print('b');\n  print('c');\n}\n",
    );
    write(
      kAcceptedFindingsFileName,
      'accepted:\n'
      '  - rule: $_rule\n'
      '    file: lib/main.dart\n'
      '    reason: Test.\n'
      '    max: 1\n',
    );
  }

  test('max: 1 hides the first finding and reports the rest', () async {
    fixture(ignoreFirst: false);
    expect(await _daemonRuleLines(project), [3, 4]);
  });

  // One warm process across saves: it must see the new file text and the new
  // list on the next request, without a restart.
  test('a later save adds, removes and re-limits findings', () async {
    fixture(ignoreFirst: false);
    final list = File(p.join(project, kAcceptedFindingsFileName));
    final entry = list.readAsStringSync();
    list.deleteSync();
    final scan = await _startDaemon(project);
    expect(await scan(), [2, 3, 4]);

    // The fixture's three calls, then a fourth added in a new function.
    const base = '''
void f() {
  print('a');
  print('b');
  print('c');
}
''';
    const added = '''
void g() {
  print('d');
}
''';
    write('lib/main.dart', '$base$added');
    expect(await scan(), [2, 3, 4, 7]);

    write('lib/main.dart', base);
    expect(await scan(), [2, 3, 4]);

    list.writeAsStringSync(entry);
    expect(await scan(), [3, 4]);

    list.writeAsStringSync(entry.replaceFirst('max: 1', 'max: 2'));
    expect(await scan(), [4]);
  });

  test('an ignored finding is not reported and does not use up max', () async {
    fixture(ignoreFirst: true);
    // Line 2 is ignored (dropped before the accepted filter, so it does not
    // count), line 3 is the one accepted, line 4 reports.
    expect(await _daemonRuleLines(project), [4]);
  });
}

/// Starts the daemon on [project], sends one scan request for
/// `lib/main.dart`, and returns the sorted lines of its [_rule] findings.
Future<List<int>> _daemonRuleLines(String project) async =>
    (await _startDaemon(project))();

/// Starts one daemon on [project] and returns a function that scans
/// `lib/main.dart` again on that same process, as each save does.
Future<Future<List<int>> Function()> _startDaemon(String project) async {
  final root = Directory.current.path;
  final daemon = await Process.start(Platform.resolvedExecutable, [
    '--packages=${p.join(root, '.dart_tool', 'package_config.json')}',
    p.join(root, 'bin', 'scan_daemon.dart'),
    project,
    '--tier',
    'pedantic',
  ], workingDirectory: project);
  // Wait for the exit so Windows releases the temp project before deletion.
  addTearDown(() async {
    daemon.kill();
    await daemon.exitCode;
  });
  unawaited(daemon.stderr.drain<void>());

  // One iterator for the process's whole life: stdout can be listened to once.
  final lines = StreamIterator(
    daemon.stdout.transform(utf8.decoder).transform(const LineSplitter()),
  );

  /// The next message matching [wanted].
  Future<Map<dynamic, dynamic>> read(bool Function(Map) wanted) async {
    while (await lines.moveNext()) {
      final message = jsonDecode(lines.current) as Map;
      if (wanted(message)) return message;
    }
    fail('the scan daemon exited without answering');
  }

  // The daemon answers nothing until prewarm ends, so no request is sent
  // before `ready`.
  await read((m) => m['event'] == 'ready');
  var requests = 0;
  return () async {
    final id = '${++requests}';
    daemon.stdin.writeln(
      jsonEncode({
        'id': id,
        'files': [p.join(project, 'lib', 'main.dart')],
      }),
    );
    final message = await read((m) => m['id'] == id);
    expect(message['ok'], isTrue, reason: '$message');
    return [
      for (final d in message['diagnostics'] as List)
        if ((d as Map)['ruleName'] == _rule) d['line'] as int,
    ]..sort();
  };
}
