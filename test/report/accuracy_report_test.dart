// Unit tests for the accuracy-report core: marker parsing + per-rule liveness.
library;

import 'package:saropa_lints/src/report/accuracy_report.dart';
import 'package:test/test.dart';

void main() {
  group('parseExpectedLints', () {
    test('captures a marker with its 1-based line', () {
      const source = '// expect_lint: my_rule\nfinal x = bad();\n';
      expect(parseExpectedLints(source), [(rule: 'my_rule', line: 1)]);
    });

    test('comma-separated rules expand to one entry each', () {
      const source = '// expect_lint: rule_a, rule_b\nfinal x = bad();\n';
      expect(parseExpectedLints(source), [
        (rule: 'rule_a', line: 1),
        (rule: 'rule_b', line: 1),
      ]);
    });

    test('trailing marker is still captured', () {
      const source = 'final x = bad(); // expect_lint: my_rule\n';
      expect(parseExpectedLints(source), [(rule: 'my_rule', line: 1)]);
    });

    test('files without markers yield nothing', () {
      expect(parseExpectedLints('final x = ok();\n'), isEmpty);
    });
  });

  group('computeAccuracy (liveness)', () {
    test('a rule that fires somewhere in its fixture is live', () {
      // Marker on line 2, actual diagnostic on line 4 of the same file: the
      // line offset must not matter — only "fired in this file".
      final report = computeAccuracy(
        expected: const [(rule: 'r', file: 'r_fixture.dart', line: 2)],
        actual: const [(rule: 'r', file: 'r_fixture.dart', line: 4)],
        targets: const {'r': null},
      );

      final r = report.rules.single;
      expect(r.isSilent, isFalse);
      expect(r.firedFiles, {'r_fixture.dart'});
      expect(report.silentRules, isEmpty);
    });

    test('a declared rule that never fires is silent', () {
      final report = computeAccuracy(
        expected: const [(rule: 'dead', file: 'dead_fixture.dart', line: 2)],
        actual: const [],
        targets: const {'dead': null},
      );

      expect(report.rules.single.isSilent, isTrue);
      expect(report.silentRules.map((r) => r.rule), ['dead']);
    });

    test('a hit in another rule\'s fixture does not count as firing', () {
      // 'r' fired only in some other rule's fixture, never in its own.
      final report = computeAccuracy(
        expected: const [(rule: 'r', file: 'r_fixture.dart', line: 2)],
        actual: const [(rule: 'r', file: 'other_fixture.dart', line: 9)],
        targets: const {'r': null},
      );
      expect(report.rules.single.isSilent, isTrue);
    });

    test('partial firing across multiple fixtures is reported, not failed', () {
      // Declared in two fixtures, fires in only one.
      final report = computeAccuracy(
        expected: const [
          (rule: 'r', file: 'a_fixture.dart', line: 2),
          (rule: 'r', file: 'b_fixture.dart', line: 2),
        ],
        actual: const [(rule: 'r', file: 'a_fixture.dart', line: 3)],
        targets: const {'r': null},
      );

      final r = report.rules.single;
      expect(r.isSilent, isFalse);
      expect(r.silentFiles, {'b_fixture.dart'});
      expect(report.silentRules, isEmpty);
      expect(report.partiallyFiringRules.map((e) => e.rule), ['r']);
    });

    test('only rules with markers are measured', () {
      // 'noisy' fires but has no marker: it carries no ground truth.
      final report = computeAccuracy(
        expected: const [(rule: 'r', file: 'r_fixture.dart', line: 2)],
        actual: const [
          (rule: 'r', file: 'r_fixture.dart', line: 2),
          (rule: 'noisy', file: 'r_fixture.dart', line: 5),
        ],
        targets: const {'r': null, 'noisy': null},
      );
      expect(report.rules.map((e) => e.rule), ['r']);
    });
  });
}
