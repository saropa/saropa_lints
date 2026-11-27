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

  test('an ignored finding is not reported and does not use up max', () async {
    fixture(ignoreFirst: true);
    // Line 2 is ignored (dropped before the accepted filter, so it does not
    // count), line 3 is the one accepted, line 4 reports.
    expect(await _daemonRuleLines(project), [4]);
  });
}

/// Starts the daemon on [project], sends one scan request for
/// `lib/main.dart`, and returns the sorted lines of its [_rule] findings.
Future<List<int>> _daemonRuleLines(String project) async {
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

  final lines = daemon.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  await for (final line in lines) {
    final message = jsonDecode(line) as Map;
    // The daemon answers nothing until prewarm ends, so the request is sent
    // only after `ready`.
    if (message['event'] == 'ready') {
      daemon.stdin.writeln(
        jsonEncode({
          'id': '1',
          'files': [p.join(project, 'lib', 'main.dart')],
        }),
      );
      continue;
    }
    if (message['id'] != '1') continue;
    expect(message['ok'], isTrue, reason: '$message');
    return [
      for (final d in message['diagnostics'] as List)
        if ((d as Map)['ruleName'] == _rule) d['line'] as int,
    ]..sort();
  }
  fail('the scan daemon exited without answering the request');
}
