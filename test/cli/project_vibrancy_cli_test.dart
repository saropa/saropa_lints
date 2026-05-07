/// Integration-style tests for [runProjectVibrancy]: builds ephemeral **pubspec + lib + lcov** trees,
/// asserts JSON shape, grades, flags (`unused`, `uncovered`, …), and CLI-facing options like folder scope.
/// Uses real filesystem I/O under `Directory.systemTemp` with `setUp`/`tearDown` cleanup.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_vibrancy.dart';
import 'package:test/test.dart';

/// Entry point: `group` blocks mirror MVP scenarios (happy path, filters, edge lcov).
void main() {
  // Each scenario seeds a minimal pub package + synthetic lcov so grading stays deterministic.
  group('project vibrancy mvp', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pv_mvp_');
      Directory('${tempDir.path}/lib').createSync(recursive: true);
      File('${tempDir.path}/lib/a.dart').writeAsStringSync('''
/// demo fn
int add(int a, int b) {
  if (a > 0 && b > 0) {
    return a + b;
  }
  return a + b;
}
''');
      Directory('${tempDir.path}/coverage').createSync(recursive: true);
      File('${tempDir.path}/coverage/lcov.info').writeAsStringSync('''
SF:${tempDir.path.replaceAll('\\', '/')}/lib/a.dart
DA:2,1
DA:3,1
DA:4,1
DA:5,1
DA:6,1
end_of_record
''');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generates JSON report with function entries', () async {
      final report = await runProjectVibrancy(
        ProjectVibrancyOptions(
          projectPath: tempDir.path,
          lcovPath: '${tempDir.path}/coverage/lcov.info',
        ),
      );
      expect(report.functions, isNotEmpty);
      final json = report.toJson();
      expect(json['summary'], isA<Map<String, Object>>());
      final functions = json['functions'] as List<Object?>;
      expect(functions, isNotEmpty);
      final first = functions.first as Map<String, Object?>;
      expect(first['name'], 'add');
      expect(first['grade'], isA<String>());
    });

    test('toJsonReport produces valid JSON', () async {
      final report = await runProjectVibrancy(
        ProjectVibrancyOptions(
          projectPath: tempDir.path,
          lcovPath: '${tempDir.path}/coverage/lcov.info',
        ),
      );
      final text = toJsonReport(report);
      final decoded = jsonDecode(text) as Map<String, Object?>;
      expect(decoded.containsKey('functions'), isTrue);
    });

    test(
      'malformed LCOV DA lines are skipped without breaking coverage',
      () async {
        final libPath = '${tempDir.path.replaceAll('\\', '/')}/lib/a.dart';
        File('${tempDir.path}/coverage/lcov.info').writeAsStringSync('''
SF:$libPath
DA:2,1
DA:not_a_pair
DA:3,1
DA:4,1
DA:5,1
DA:6,1
DA:7,0
DA:8,1,too,many,commas
end_of_record
''');
        final report = await runProjectVibrancy(
          ProjectVibrancyOptions(
            projectPath: tempDir.path,
            lcovPath: '${tempDir.path}/coverage/lcov.info',
          ),
        );
        expect(report.functions, isNotEmpty);
        final add = report.functions.firstWhere((f) => f.name == 'add');
        expect(add.flags.contains('uncovered'), isFalse);
      },
    );

    test('includedFiles scope limits analysis to selected files', () async {
      File('${tempDir.path}/lib/b.dart').writeAsStringSync('''
int mul(int a, int b) => a * b;
''');
      final report = await runProjectVibrancy(
        ProjectVibrancyOptions(
          projectPath: tempDir.path,
          lcovPath: '${tempDir.path}/coverage/lcov.info',
          includedFiles: <String>{'${tempDir.path}/lib/b.dart'},
        ),
      );
      expect(report.functions, hasLength(1));
      expect(report.functions.first.name, 'mul');
    });

    test('usage counting marks called function as used', () async {
      File('${tempDir.path}/lib/c.dart').writeAsStringSync('''
int callee() => 1;
int caller() => callee();
''');
      final report = await runProjectVibrancy(
        ProjectVibrancyOptions(
          projectPath: tempDir.path,
          lcovPath: '${tempDir.path}/coverage/lcov.info',
          includedFiles: <String>{'${tempDir.path}/lib/c.dart'},
        ),
      );
      final callee = report.functions.firstWhere((f) => f.name == 'callee');
      final caller = report.functions.firstWhere((f) => f.name == 'caller');
      expect(callee.usageCount, greaterThan(0));
      expect(callee.flags.contains('unused'), isFalse);
      expect(caller.flags.contains('unused'), isTrue);
    });

    test(
      'stub_tested when only trivial tests import covered function',
      () async {
        Directory('${tempDir.path}/test').createSync(recursive: true);
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: pv_stub_pkg
environment:
  sdk: '>=3.0.0 <4.0.0'
dev_dependencies:
  test: any
''');
        File('${tempDir.path}/lib/stub_target.dart').writeAsStringSync('''
void onlyTrivialCovered() {
  final x = 1;
  if (x > 0) {
    return;
  }
}
''');
        File('${tempDir.path}/test/stub_target_test.dart').writeAsStringSync('''
import 'package:pv_stub_pkg/stub_target.dart';
import 'package:test/test.dart';

void main() {
  test('trivial', () {
    expect(1, 1);
    onlyTrivialCovered();
  });
}
''');
        final libNorm = p.normalize('${tempDir.path}/lib/stub_target.dart');
        File('${tempDir.path}/coverage/lcov.info').writeAsStringSync('''
SF:$libNorm
DA:2,1
DA:3,1
DA:4,1
DA:5,1
end_of_record
''');
        final report = await runProjectVibrancy(
          ProjectVibrancyOptions(
            projectPath: tempDir.path,
            lcovPath: '${tempDir.path}/coverage/lcov.info',
          ),
        );
        final fn = report.functions.firstWhere(
          (f) => f.name == 'onlyTrivialCovered',
        );
        expect(fn.flags, contains('stub_tested'));
      },
    );

    test(
      'suspicious_coverage when complexity high and only trivial tests',
      () async {
        Directory('${tempDir.path}/test').createSync(recursive: true);
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: pv_susp_pkg
environment:
  sdk: '>=3.0.0 <4.0.0'
dev_dependencies:
  test: any
''');
        File('${tempDir.path}/lib/susp.dart').writeAsStringSync('''
int dense(int a, int b, int c, int d) {
  if (a > 0 && b > 0) return 1;
  if (a < 0 && b < 0) return 2;
  if (c > 0 && d > 0) return 3;
  if (c < 0 && d < 0) return 4;
  if (a == c && b == d) return 5;
  if (a != b && c != d) return 6;
  if (a > b && c > d) return 7;
  if (a < b && c < d) return 8;
  if (a == 0 && b == 0) return 9;
  if (c == 0 && d == 0) return 10;
  return 0;
}
''');
        File('${tempDir.path}/test/susp_test.dart').writeAsStringSync('''
import 'package:pv_susp_pkg/susp.dart';
import 'package:test/test.dart';

void main() {
  test('trivial', () {
    expect(1, 1);
    dense(1, 1, 1, 1);
  });
}
''');
        final libNorm = p.normalize('${tempDir.path}/lib/susp.dart');
        File('${tempDir.path}/coverage/lcov.info').writeAsStringSync('''
SF:$libNorm
DA:2,1
DA:3,1
DA:4,1
DA:5,1
DA:6,1
DA:7,1
DA:8,1
DA:9,1
DA:10,1
DA:11,1
DA:12,1
DA:13,1
end_of_record
''');
        final report = await runProjectVibrancy(
          ProjectVibrancyOptions(
            projectPath: tempDir.path,
            lcovPath: '${tempDir.path}/coverage/lcov.info',
          ),
        );
        final fn = report.functions.firstWhere((f) => f.name == 'dense');
        expect(fn.complexity, greaterThanOrEqualTo(10));
        expect(fn.flags, contains('suspicious_coverage'));
      },
    );

    test('writes and reuses cache file for blame/lcov data', () async {
      final cachePath =
          '${tempDir.path}/.saropa/project-vibrancy-cache/mvp_cache.json';
      final options = ProjectVibrancyOptions(
        projectPath: tempDir.path,
        lcovPath: '${tempDir.path}/coverage/lcov.info',
        cachePath: cachePath,
      );

      final first = await runProjectVibrancy(options);
      expect(first.functions, isNotEmpty);
      final cacheFile = File(cachePath);
      expect(cacheFile.existsSync(), isTrue);
      final decoded =
          jsonDecode(cacheFile.readAsStringSync()) as Map<String, Object?>;
      expect(decoded['schemaVersion'], 1);
      expect(decoded.containsKey('blameByBlob'), isTrue);
      expect(decoded.containsKey('lcovByFingerprint'), isTrue);

      final second = await runProjectVibrancy(options);
      expect(second.functions.length, first.functions.length);
    });
  });
}
