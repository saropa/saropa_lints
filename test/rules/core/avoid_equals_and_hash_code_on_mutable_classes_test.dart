// Regression/behavior tests for avoid_equals_and_hash_code_on_mutable_classes.
//
// The rule IS registered in all three required places (lib/saropa_lints.dart,
// lib/src/tiers.dart `essentialRules`, lib/src/rules/all_rules.dart) and
// documented in CHANGELOG.md as part of the 19-rule quick-win batch. This
// test still exercises the rule class directly via the resolved-rule
// harness rather than through the full plugin, since that harness runs a
// single rule against inline source without needing a real analysis
// context/project — faster and more isolated than a full-plugin test.
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

    // Asymmetric counterpart to the "only ==" case above: only hashCode is
    // overridden, == is left as the default Object identity comparison. The
    // rule requires BOTH members to be hand-written, so this must be silent.
    test(
      'does NOT fire when only hashCode is overridden without ==',
      () async {
        final codes = await reportedRuleCodes(
          AvoidEqualsAndHashCodeOnMutableClassesRule(),
          '''
class HalfOverriddenHash {
  HalfOverriddenHash(this.x);
  int x;

  @override
  int get hashCode => x.hashCode;
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    // `late final` fields report isFinal == true, so they must be treated
    // the same as an ordinary `final` field and never flagged as mutable.
    test('does NOT fire on late final fields (GOOD)', () async {
      final codes = await reportedRuleCodes(
        AvoidEqualsAndHashCodeOnMutableClassesRule(),
        '''
class LateFinalPoint {
  LateFinalPoint(int x, int y) {
    this.x = x;
    this.y = y;
  }
  late final int x;
  late final int y;

  @override
  bool operator ==(Object other) =>
      other is LateFinalPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
''',
      );
      expect(codes, isEmpty);
    });

    // Mirrors the fixture's MutableUser case: one final field alongside one
    // mutable field, both referenced by == / hashCode. Only the mutable
    // field should be flagged, pinned at the unit-test level (previously
    // only exercised via the fixture, per the finish-report opportunity).
    test(
      'fires only on the mutable field when mixed with a final field',
      () async {
        final diags = await runRuleResolved(
          AvoidEqualsAndHashCodeOnMutableClassesRule(),
          '''
class MutableUser {
  MutableUser({required this.name, required this.email});
  final String name;
  String email;

  @override
  bool operator ==(Object other) =>
      other is MutableUser && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(name, email);
}
''',
        );
        final ownRule = diags.where(
          (d) => d.ruleName == 'avoid_equals_and_hash_code_on_mutable_classes',
        );
        // Only `email` (line 4) is mutable; `name` (line 3) is final.
        expect(ownRule.map((d) => d.line).toList(), <int>[4]);
      },
    );

    // The `with` clause loop must scan every mixin, not just the first —
    // regression test pinning that EquatableMixin is still recognized when
    // it is not the first mixin listed.
    test(
      'does NOT fire when EquatableMixin is not the first mixin',
      () async {
        final codes = await reportedRuleCodes(
          AvoidEqualsAndHashCodeOnMutableClassesRule(),
          '''
mixin Loggable {}

abstract class EquatableMixin {
  List<Object?> get props;
}

class MultiMixinPoint with Loggable, EquatableMixin {
  MultiMixinPoint(this.x, this.y);
  int x;
  int y;

  List<Object?> get props => <Object?>[x, y];

  @override
  bool operator ==(Object other) =>
      other is MultiMixinPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    // Known limitation (documented on _extendsOrMixesInEquatable): the
    // Equatable check only inspects the direct extends/with clause, not
    // `implements`. A class satisfying the Equatable interface via
    // `implements` is therefore NOT recognized as Equatable-covered and
    // this rule still fires — pinning the current (accepted) behavior so a
    // future change to widen the check is a deliberate, visible diff here.
    test(
      'fires on a class using "implements Equatable" (documented false '
      'negative in the Equatable-skip, not widened by this rule)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidEqualsAndHashCodeOnMutableClassesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

class ImplementsEquatablePoint implements Equatable {
  ImplementsEquatablePoint(this.x, this.y);
  int x;
  int y;

  @override
  List<Object?> get props => <Object?>[x, y];

  @override
  bool operator ==(Object other) =>
      other is ImplementsEquatablePoint && other.x == x && other.y == y;

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
  });
}
