// Regression/behavior tests for avoid_equals_and_hash_code_on_mutable_classes.
//
// The rule is not yet wired into the global tier registry (a separate
// process handles the three-way registration centrally to avoid merge
// conflicts across parallel rule-authoring agents). This test therefore
// exercises the rule class directly via the resolved-rule harness, which
// runs a single rule against inline source without depending on
// lib/saropa_lints.dart or lib/src/tiers.dart.
library;

import 'package:saropa_lints/src/rules/core/avoid_equals_and_hash_code_on_mutable_classes_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('avoid_equals_and_hash_code_on_mutable_classes', () {
    test(
      'fires on a mutable field referenced by == and hashCode',
      () async {
        final codes = await reportedRuleCodes(
          AvoidEqualsAndHashCodeOnMutableClassesRule(),
          '''
class Point {
  Point(this.x, this.y);
  int x;
  int y;

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
''',
        );
        expect(
          codes,
          contains('avoid_equals_and_hash_code_on_mutable_classes'),
        );
      },
    );

    test('flags each mutable field, one diagnostic per field', () async {
      final diags = await runRuleResolved(
        AvoidEqualsAndHashCodeOnMutableClassesRule(),
        '''
class Point {
  Point(this.x, this.y);
  int x;
  int y;

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
''',
      );
      final ownRule = diags.where(
        (d) => d.ruleName == 'avoid_equals_and_hash_code_on_mutable_classes',
      );
      // x is declared on line 3, y on line 4.
      expect(ownRule.map((d) => d.line), containsAll(<int>[3, 4]));
      expect(ownRule.length, 2);
    });

    test('does NOT fire when all fields are final (GOOD)', () async {
      final codes = await reportedRuleCodes(
        AvoidEqualsAndHashCodeOnMutableClassesRule(),
        '''
class ImmutablePoint {
  const ImmutablePoint(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is ImmutablePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
''',
      );
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire when the class has a mutable field but no '
      'hand-written == / hashCode (near-miss control)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidEqualsAndHashCodeOnMutableClassesRule(),
          '''
class PlainMutableCounter {
  PlainMutableCounter(this.count);
  int count;
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire on a class extending a local Equatable stand-in — '
      'already covered by avoid_mutable_field_in_equatable',
      () async {
        final codes = await reportedRuleCodes(
          AvoidEqualsAndHashCodeOnMutableClassesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

class EquatablePoint extends Equatable {
  EquatablePoint(this.x, this.y);
  int x;
  int y;

  @override
  List<Object?> get props => <Object?>[x, y];

  @override
  bool operator ==(Object other) =>
      other is EquatablePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when only == is overridden without hashCode',
      () async {
        final codes = await reportedRuleCodes(
          AvoidEqualsAndHashCodeOnMutableClassesRule(),
          '''
class HalfOverridden {
  HalfOverridden(this.x);
  int x;

  @override
  bool operator ==(Object other) => other is HalfOverridden && other.x == x;
}
''',
        );
        expect(codes, isEmpty);
      },
    );
  });
}
