import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/avoid_implementing_value_types_rules.dart';

import '../../support/resolved_rule_harness.dart';

/// Tests for AvoidImplementingValueTypesRule.
///
/// The rule is not yet wired into the global tier registry (a separate
/// process handles the three-way registration centrally to avoid merge
/// conflicts across parallel rule-authoring agents). The firing tests below
/// therefore exercise the rule class directly via the resolved-rule
/// harness, which runs a single rule against inline source without
/// depending on lib/saropa_lints.dart or lib/src/tiers.dart.
///
/// The example package (which the harness resolves fixtures against) does
/// not depend on the `equatable` package, so `Equatable` resolves to an
/// unresolved/invalid type here. Detection still fires because the rule's
/// fast path matches the exact `implements` clause name lexeme
/// ('Equatable'/'EquatableMixin') before falling back to resolved-type
/// supertype walking for indirect cases.
void main() {
  group('Avoid Implementing Value Types Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(
          rule.code.problemMessage,
          contains('[$codeName]'),
          reason: 'problem message must start with [$codeName] prefix',
        );
        expect(
          rule.code.problemMessage.length,
          greaterThan(200),
          reason: 'problem message must be >200 chars',
        );
        expect(
          rule.code.correctionMessage,
          isNotNull,
          reason: 'correctionMessage must be provided',
        );
      });
    }

    testRule(
      'AvoidImplementingValueTypesRule',
      'avoid_implementing_value_types',
      () => AvoidImplementingValueTypesRule(),
    );
  });

  group('avoid_implementing_value_types - firing', () {
    test('fires on implements Equatable without == or hashCode', () async {
      final codes = await reportedRuleCodes(
        AvoidImplementingValueTypesRule(),
        '''
abstract class Equatable {
  List<Object?> get props;
}

class UserId implements Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
''',
      );
      expect(codes, contains('avoid_implementing_value_types'));
    });

    test('does not fire on extends Equatable', () async {
      final codes = await reportedRuleCodes(
        AvoidImplementingValueTypesRule(),
        '''
abstract class Equatable {
  List<Object?> get props;
}

class UserId extends Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
''',
      );
      expect(codes, isNot(contains('avoid_implementing_value_types')));
    });

    test(
      'does not fire when class redeclares its own == and hashCode',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

class UserId implements Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];

  @override
  bool operator ==(Object other) =>
      other is UserId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );

    test(
      'does not fire on implements of an unrelated interface (near miss)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
class UserId implements Comparable<UserId> {
  UserId(this.value);
  final String value;

  @override
  int compareTo(UserId other) => value.compareTo(other.value);
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );
  });
}
