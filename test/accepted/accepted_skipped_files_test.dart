/// Which files `scan --check-accepted` adds to the scan because a list names
/// them, and which it must never read.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/accepted/accepted_findings_list.dart'
    show kAcceptedFindingsFileName;
import 'package:saropa_lints/src/accepted/accepted_findings_roots.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_skipped_files.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  late Directory dir;
  late String root;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_skipped_');
    root = dir.resolveSymbolicLinksSync();
  });

  tearDown(() => safeDeleteDir(dir));

  void write(String relative, [String text = '']) {
    File(p.join(root, relative))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  void list(String at, List<String> files) => write(
    '$at/$kAcceptedFindingsFileName',
    'version: 1\naccepted:\n'
        '${[for (final f in files) '  - rule: avoid_catch_all\n    file: $f\n    reason: ok\n'].join()}',
  );

  List<String> picked(
    String target, {
    List<String> scanned = const [],
    List<String> excludeGlobs = const [],
  }) => [
    for (final files in acceptedSkippedFiles(
      target: p.join(root, target),
      lists: AcceptedListSet(known: {'avoid_catch_all'}),
      alreadyScanned: [for (final s in scanned) p.join(root, s)],
      excludeGlobs: excludeGlobs,
    ).values)
      for (final f in files) p.relative(f, from: root).replaceAll('\\', '/'),
  ]..sort();

  test('picks only existing, unscanned Dart files of the list\'s package', () {
    write('main/pubspec.yaml', 'name: main\n');
    write('main/example/pubspec.yaml', 'name: example\n');
    write('main/lib/a.dart');
    write('main/bin/tool.dart');
    write('main/notes.txt');
    write('main/example/lib/c.dart');
    list('main', [
      'lib/a.dart',
      'bin/tool.dart',
      'bin/tool.dart',
      'lib/gone.dart',
      'notes.txt',
      // Belongs to the nested package: a problem, not a file to scan.
      'example/lib/c.dart',
    ]);

    expect(picked('main', scanned: ['main/lib/a.dart']), [
      'main/bin/tool.dart',
    ]);
    list('main/example', ['lib/c.dart']);
    expect(picked('main', scanned: ['main/lib/a.dart']), [
      'main/bin/tool.dart',
      'main/example/lib/c.dart',
    ]);
    expect(
      picked(
        'main',
        scanned: ['main/lib/a.dart'],
        excludeGlobs: ['example/**'],
      ),
      ['main/bin/tool.dart'],
    );
    // A scoped target stays scoped.
    expect(picked('main/lib'), ['main/lib/a.dart']);
  });

  test('never follows a link out of the package', () {
    write('main/pubspec.yaml', 'name: main\n');
    write('outside/secret.dart');
    list('main', ['linked/secret.dart']);
    // A junction needs no privilege on Windows; elsewhere this is a symlink.
    Link(p.join(root, 'main', 'linked')).createSync(p.join(root, 'outside'));

    expect(picked('main'), isEmpty);
  });
}
