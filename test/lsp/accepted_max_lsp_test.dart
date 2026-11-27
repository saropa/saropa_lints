/// End-to-end check of an accepted-findings `max:` through the real
/// `bin/lsp_server.dart` over JSON-RPC on stdio.
///
/// Unit tests cover `filterAcceptedByNearestRoot` in isolation; this test
/// exists because the language server is a separate process with its own
/// filter chain (`_analyzeFile`), and nothing else proved that chain applies
/// `max:` — or that a `// ignore:`d finding is dropped rather than published
/// (the resolved scan runner deliberately reports ignored findings so the
/// stale-ignore check can see them; each producer must filter them itself).
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

/// Rule the fixture triggers once per `print()` call. Proven to fire on the
/// language server's resolved runner by `baseline_date_git_test.dart`.
const _rule = 'prefer_logger_over_print';

void main() {
  late Directory dir;
  late String project;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_lsp_max_');
    // Resolve 8.3 short names / symlinks so the paths the server publishes
    // and the paths the accepted lookup walks agree.
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
    write('analysis_options.yaml', 'saropa_lints:\n  tier: pedantic\n');
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

  test('max: 1 hides the first finding and publishes the rest', () async {
    fixture(ignoreFirst: false);
    expect(await _lspRuleLines(project), [3, 4]);
  });

  test('an ignored finding is not published and does not use up max', () async {
    fixture(ignoreFirst: true);
    // Line 2 is ignored (dropped before the accepted filter, so it does not
    // count), line 3 is the one accepted, line 4 is published.
    expect(await _lspRuleLines(project), [4]);
  });
}

/// Starts the language server on [project] and returns the sorted 1-based
/// lines of the [_rule] findings it first publishes for `lib/main.dart`.
Future<List<int>> _lspRuleLines(String project) async {
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

  // LSP framing: a Content-Length header, a blank line, then the JSON body.
  void send(Map<String, Object?> message) {
    final body = utf8.encode(jsonEncode({'jsonrpc': '2.0', ...message}));
    server.stdin.add(ascii.encode('Content-Length: ${body.length}\r\n\r\n'));
    server.stdin.add(body);
  }

  // workspaceScanDelay 0 starts the startup workspace scan at once, so the
  // test needs no didOpen; scanning only lib/ keeps it fast.
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

  // latin1 keeps one char per byte so Content-Length applies to the buffer.
  final header = RegExp(r'Content-Length: (\d+)\r\n\r\n');
  var buffer = '';
  await for (final chunk in server.stdout.transform(latin1.decoder)) {
    buffer += chunk;
    for (var m = header.firstMatch(buffer); m != null;) {
      final end = m.end + int.parse(m.group(1)!);
      // Partial frame: wait for the next chunk.
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
          if ((d as Map)['code'] == _rule)
            (((d['range'] as Map)['start'] as Map)['line'] as int) + 1,
      ]..sort();
    }
  }
  fail('the language server exited without publishing diagnostics');
}
