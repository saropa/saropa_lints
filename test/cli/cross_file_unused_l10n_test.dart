import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_unused_l10n.dart';
import 'package:test/test.dart';

void main() {
  test('malformed ARB JSON does not throw and yields no keys from that file',
      () async {
    final root = Directory.systemTemp.createTempSync('saropa_l10n_');
    try {
      final l10nDir = Directory(p.join(root.path, 'lib', 'l10n'));
      l10nDir.createSync(recursive: true);
      File(p.join(l10nDir.path, 'app_en.arb')).writeAsStringSync('{ not valid json');

      final r = await analyzeUnusedL10n(projectPath: root.path);
      expect(r.unusedKeys, isEmpty);
      expect(r.arbPaths, isNotEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('valid ARB key used in lib is not reported unused', () async {
    final root = Directory.systemTemp.createTempSync('saropa_l10n_');
    try {
      final l10nDir = Directory(p.join(root.path, 'lib', 'l10n'));
      l10nDir.createSync(recursive: true);
      File(p.join(l10nDir.path, 'app_en.arb'))
          .writeAsStringSync('{"helloWorld": "Hello"}');
      final libDir = Directory(p.join(root.path, 'lib'));
      libDir.createSync(recursive: true);
      File(p.join(libDir.path, 'main.dart')).writeAsStringSync(
        'void main() { final _ = helloWorld; }',
      );

      final r = await analyzeUnusedL10n(projectPath: root.path);
      expect(r.unusedKeys, isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });
}
