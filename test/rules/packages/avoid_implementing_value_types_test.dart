import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/avoid_implementing_value_types_rules.dart';

import '../../support/resolved_rule_harness.dart';

/// Tests for AvoidImplementingValueTypesRule.
///
/// The firing tests below exercise the rule class directly via the
/// resolved-rule harness, which runs a single rule against inline source
/// without depending on lib/saropa_lints.dart or lib/src/tiers.dart.
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

    // Regression test for the headline resolved-supertype walk
    // (_implementsValueEqualityType iterating allSupertypes): the fixture's
    // OrderId/BaseId pair exercised this but was never covered by a unit
    // test (Finish Report Issue #2), so a future analyzer upgrade changing
    // InterfaceType.element semantics would regress silently.
    test(
      'fires on implements of a class that itself extends Equatable '
      '(indirect supertype)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

abstract class BaseId extends Equatable {}

class OrderId implements BaseId {
  OrderId(this.raw);
  final String raw;

  @override
  List<Object?> get props => [raw];
}
''',
        );
        expect(codes, contains('avoid_implementing_value_types'));
      },
    );

    // Regression test for Finish Report Issue #1: a class that gets real
    // equality from `with EquatableMixin` but separately `implements` an
    // Equatable-derived marker/contract interface (the Dart 3 "interface
    // class" idiom) must not be flagged — the implements clause did not
    // cause the identity-equality footgun here.
    test(
      'does not fire when equality comes from a mixin and implements '
      'targets an Equatable-derived marker interface',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

mixin EquatableMixin {
  List<Object?> get props;
}

abstract class ValueObject extends Equatable {}

class Money with EquatableMixin implements ValueObject {
  Money(this.cents);
  final int cents;

  @override
  List<Object?> get props => [cents];
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );

    // Regression test for the second half of Issue #1: `extends Equatable`
    // (real equality) plus a redundant `implements` of a derived marker
    // interface on top of it must also not be flagged.
    test(
      'does not fire when equality comes from extends Equatable and '
      'implements targets a derived marker interface',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

abstract class ValueObject extends Equatable {}

class Money extends Equatable implements ValueObject {
  Money(this.cents);
  final int cents;

  @override
  List<Object?> get props => [cents];
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );
  });
}
