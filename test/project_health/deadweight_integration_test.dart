/// Integration test for the dead-weight overlay against a real (temp) Dart
/// package: it must flag an unimported file and spare an imported one. Exercises
/// the actual cross_file composition, not just the per-file threading.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_health/deadweight_overlay.dart';
import 'package:test/test.dart';

void main() {
  test(
    'flags an unimported file as unused, spares an imported one',
    () async {
      final tmp = Directory.systemTemp.createTempSync('saropa_dw_int_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      Directory(p.join(tmp.path, 'lib')).createSync();
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync(
        'name: demo\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n',
      );
      File(
        p.join(tmp.path, 'lib', 'used.dart'),
      ).writeAsStringSync('int answer() => 42;\n');
      File(p.join(tmp.path, 'lib', 'main.dart')).writeAsStringSync(
        "import 'used.dart';\nvoid main() {\n  answer();\n}\n",
      );
      File(
        p.join(tmp.path, 'lib', 'orphan.dart'),
      ).writeAsStringSync('int orphan() => 0;\n');

      final dw = await loadDeadWeight(projectPath: tmp.path);
      expect(dw.unusedFiles, contains('lib/orphan.dart'));
      expect(dw.unusedFiles, isNot(contains('lib/used.dart')));
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
