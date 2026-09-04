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
/// not depend on the `equatable` package, so every test source below
/// declares its own local `Equatable`/`EquatableMixin` stand-in. Those
/// stand-ins DO resolve (they are declared in the same library), and the
/// rule accepts a non-`package:equatable` element named `Equatable` only
/// when it structurally corroborates the contract with a `props` getter —
/// which the stand-ins deliberately declare. A stand-in WITHOUT `props` is
/// the false-positive case pinned by the last test in this file.
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

    // ---------------------------------------------------------------------
    // HIGH false positive: inherited manual equality was invisible because
    // _declaresOwnEqualityContract only scanned the class's OWN body
    // members. `extends` inherits implementation, so a base class that
    // hand-rolls ==/hashCode gives the subclass working value equality —
    // nothing is broken and nothing should be reported.
    // ---------------------------------------------------------------------
    test(
      'does not fire when == and hashCode are inherited from an ordinary '
      'base class',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

class BaseValue {
  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class UserId extends BaseValue implements Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );

    // The declaring ancestor may sit several levels up, so the fix must walk
    // the whole extends chain rather than checking only the direct parent.
    test(
      'does not fire when inherited == and hashCode come from a '
      'grandparent class',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

class BaseValue {
  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class MidValue extends BaseValue {}

class RegionId extends MidValue implements Equatable {
  RegionId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );

    // Mixins copy implementation in, so a mixin hand-rolling the pair is
    // just as sound a source of equality as a base class.
    test(
      'does not fire when == and hashCode are inherited from a mixin',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

mixin IdentityEquality {
  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class ShardId with IdentityEquality implements Equatable {
  ShardId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );

    // Guard against over-correcting the chain walk: Object declares == and
    // hashCode for EVERY class, so a walk that fails to stop at dart:core's
    // Object would silence the rule entirely. This is the canonical BAD
    // case with an explicit (implicit-Object) parent chain.
    test(
      'still fires when the only inherited == and hashCode come from '
      'Object',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

class PlainBase {}

class UserId extends PlainBase implements Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
''',
        );
        expect(codes, contains('avoid_implementing_value_types'));
      },
    );

    // A base class declaring only ONE half of the pair does not supply a
    // working contract, so the rule must still fire.
    test(
      'still fires when the base class declares == but not hashCode',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

class HalfBase {
  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;
}

class UserId extends HalfBase implements Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
''',
        );
        expect(codes, contains('avoid_implementing_value_types'));
      },
    );

    // `implements` inherits NO implementation, so an interface that merely
    // DECLARES ==/hashCode must not be mistaken for a working contract.
    test(
      'still fires when == and hashCode are only declared on an implemented '
      'interface',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  List<Object?> get props;
}

abstract class EqualityContract {
  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

class UserId implements EqualityContract, Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
''',
        );
        expect(codes, contains('avoid_implementing_value_types'));
      },
    );

    // ---------------------------------------------------------------------
    // MEDIUM false positive: name-only matching without library
    // qualification. A project-local `Equatable` that is NOT a value type
    // (no `props`) used to be flagged with a completely misleading
    // diagnosis. The resolved element is now the authority.
    // ---------------------------------------------------------------------
    test(
      'does not fire on a project-local interface that merely reuses the '
      'name Equatable',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
abstract class Equatable {
  bool matches(Object other);
}

class ConfigKey implements Equatable {
  ConfigKey(this.name);
  final String name;

  @override
  bool matches(Object other) => other is ConfigKey && other.name == name;
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );

    // Same for the mixin half of the name set: a local `EquatableMixin`
    // with no `props` is not the equatable package's mixin.
    test(
      'does not fire on a project-local mixin that merely reuses the name '
      'EquatableMixin',
      () async {
        final codes = await reportedRuleCodes(
          AvoidImplementingValueTypesRule(),
          '''
mixin EquatableMixin {
  bool matches(Object other);
}

class ConfigKey implements EquatableMixin {
  ConfigKey(this.name);
  final String name;

  @override
  bool matches(Object other) => other is ConfigKey && other.name == name;
}
''',
        );
        expect(codes, isNot(contains('avoid_implementing_value_types')));
      },
    );
  });
}
