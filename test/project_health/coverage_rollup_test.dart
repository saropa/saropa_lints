/// Tests for the lcov coverage parser.
import 'package:saropa_lints/src/cli/project_health/coverage_rollup.dart';
import 'package:test/test.dart';

void main() {
  group('parseLcov', () {
    test('computes hit/total per record', () {
      const lcov = '''
SF:lib/a.dart
DA:1,1
DA:2,0
DA:3,5
end_of_record
SF:lib/b.dart
DA:1,0
end_of_record
''';
      final cov = parseLcov(lcov, projectPath: '.');
      expect(cov['lib/a.dart'], closeTo(2 / 3, 0.001)); // lines 1 and 3 hit
      expect(cov['lib/b.dart'], 0.0);
    });

    test('records without DA lines are skipped', () {
      const lcov = 'SF:lib/empty.dart\nend_of_record\n';
      expect(parseLcov(lcov, projectPath: '.'), isEmpty);
    });

    test('final record without end_of_record is still counted', () {
      const lcov = 'SF:lib/c.dart\nDA:1,1\nDA:2,1\n';
      expect(parseLcov(lcov, projectPath: '.')['lib/c.dart'], 1.0);
    });
  });
}
