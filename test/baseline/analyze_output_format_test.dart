// The `baseline` CLI parses `dart analyze` output. This reproduces the shape
// dartdev's `emitDefaultFormat` writes (pkg/dartdev/lib/src/commands/
// analyze.dart): severity right-aligned to 7, then
// `<location> <bullet> <message> <correction> <bullet> <code>`, with context
// messages on indented follow-on lines. It does not run `dart analyze`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/violation_parser.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

/// One diagnostic line as dartdev assembles it for a pipe.
String _line(
  String severity,
  String location,
  String message,
  String code, {
  String bullet = '-',
}) => '${severity.padLeft(7)} $bullet $location $bullet $message $bullet $code';

void main() {
  test('every diagnostic of a full report is parsed, nothing else', () {
    final output = [
      'Analyzing proj...',
      '',
      _line(
        'error',
        r'lib\a.dart:3:5',
        "Undefined name 'x'. Try correcting the name.",
        'undefined_identifier',
      ),
      // A context message: indented, dash-led, with its own location.
      r"          - The declaration of 'x' is here at lib\a.dart:9:1.",
      // Saropa messages carry a rule tag, a version tag and a correction.
      _line(
        'warning',
        'lib/b.dart:10:1',
        '[avoid_print] Output - not filterable. {v3} Use a logger instead.',
        'avoid_print',
      ),
      _line(
        'info',
        r'..\shared\c.dart:1:1',
        'Message.',
        'prefer_const_constructors',
      ),
      '',
      '3 issues found.',
    ].join(Platform.lineTerminator);

    final rows = [
      for (final v in parseDartAnalyzeHumanOutput(output))
        '${v.file}|${v.line}|${v.column}|${v.rule}',
    ];
    expect(rows, [
      r'lib\a.dart|3|5|undefined_identifier',
      'lib/b.dart|10|1|avoid_print',
      r'..\shared\c.dart|1|1|prefer_const_constructors',
    ]);
  });

  // dartdev's separator is cli_util's `Ansi.bullet`:
  // `stdout.supportsAnsiEscapes ? '•' : '-'`. The parser reads only `-`, so
  // this confirms a piped child (how the CLI runs analysis) reports false.
  test('a piped child process gets the dash separator', () async {
    final dir = Directory.systemTemp.createTempSync('saropa_ansi_');
    addTearDown(() => safeDeleteDir(dir));
    final script = File(p.join(dir.path, 'ansi.dart'))
      ..writeAsStringSync(
        "import 'dart:io';\n"
        'void main() => stdout.write(stdout.supportsAnsiEscapes);\n',
      );
    final result = await Process.run(Platform.resolvedExecutable, [
      script.path,
    ]);
    expect(result.stdout, 'false', reason: '${result.stderr}');
  });
}
