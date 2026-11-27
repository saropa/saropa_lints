import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/analyzer_compat.dart';
import 'package:saropa_lints/src/rules/packages/equatable_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';
import '../../support/resolved_rule_harness.dart';

/// Tests for 14 Equatable lint rules.
///
/// Test fixtures: example_packages/lib/equatable/*
void main() {
  group('Equatable Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'ExtendEquatableRule',
      'require_extend_equatable',
      () => ExtendEquatableRule(),
    );
    testRule(
      'ListAllEquatableFieldsRule',
      'list_all_equatable_fields',
      () => ListAllEquatableFieldsRule(),
    );
    testRule(
      'PreferEquatableMixinRule',
      'prefer_equatable_mixin',
      () => PreferEquatableMixinRule(),
    );
    testRule(
      'PreferEquatableStringifyRule',
      'prefer_equatable_stringify',
      () => PreferEquatableStringifyRule(),
    );
    testRule(
      'PreferImmutableAnnotationRule',
      'prefer_immutable_annotation',
      () => PreferImmutableAnnotationRule(),
    );
    testRule(
      'PreferRecordOverEquatableRule',
      'prefer_record_over_equatable',
      () => PreferRecordOverEquatableRule(),
    );
    testRule(
      'AvoidMutableFieldInEquatableRule',
      'avoid_mutable_field_in_equatable',
      () => AvoidMutableFieldInEquatableRule(),
    );
    testRule(
      'RequireEquatableCopyWithRule',
      'require_equatable_copy_with',
      () => RequireEquatableCopyWithRule(),
    );
    testRule(
      'RequireCopyWithNullHandlingRule',
      'require_copy_with_null_handling',
      () => RequireCopyWithNullHandlingRule(),
    );
    testRule(
      'RequireDeepEqualityCollectionsRule',
      'require_deep_equality_collections',
      () => RequireDeepEqualityCollectionsRule(),
    );
    testRule(
      'AvoidEquatableDatetimeRule',
      'avoid_equatable_datetime',
      () => AvoidEquatableDatetimeRule(),
    );
    testRule(
      'PreferUnmodifiableCollectionsRule',
      'prefer_unmodifiable_collections',
      () => PreferUnmodifiableCollectionsRule(),
    );
    testRule(
      'RequireEquatablePropsOverrideRule',
      'require_equatable_props_override',
      () => RequireEquatablePropsOverrideRule(),
    );
    testRule(
      'AvoidEquatableNestedEqualityRule',
      'avoid_equatable_nested_equality',
      () => AvoidEquatableNestedEqualityRule(),
    );
    testRule(
      'PreferSortedEquatablePropsRule',
      'prefer_sorted_equatable_props',
      () => PreferSortedEquatablePropsRule(),
    );
  });
  group('Equatable Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/equatable');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/equatable/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('require_copy_with_null_handling - clear flag guard', () {
    /// Parses a class and runs the guard check for `extra` against copyWith.
    bool guarded(String src) {
      final unit = parseString(content: src, throwIfDiagnostics: false).unit;
      final cls = unit.declarations.whereType<ClassDeclaration>().first;
      final m = cls.bodyMembers.whereType<MethodDeclaration>().first;
      final names = <String>{
        for (final p in m.parameters!.parameters)
          if (p.name?.lexeme case final String n) n,
      };
      return RequireCopyWithNullHandlingRule.hasClearFlagGuard(
        'extra',
        names,
        m.body,
      );
    }

    test('FP: noExtra flag guards ?? (no report)', () {
      expect(
        guarded('''
class A { final String? extra;
  A copyWith({String? extra, bool noExtra = false}) =>
      A(extra: noExtra ? null : (extra ?? this.extra)); }'''),
        isTrue,
      );
    });

    test('FP: clearExtra flag guards ?? (no report)', () {
      expect(
        guarded('''
class A { final String? extra;
  A copyWith({String? extra, bool clearExtra = false}) =>
      A(extra: clearExtra ? null : extra ?? this.extra); }'''),
        isTrue,
      );
    });

    test('TP: plain ?? without a flag still reports', () {
      expect(
        guarded('''
class A { final String? extra;
  A copyWith({String? extra}) => A(extra: extra ?? this.extra); }'''),
        isFalse,
      );
    });

    test('TP: unrelated bool condition does not exempt', () {
      expect(
        guarded('''
class A { final String? extra;
  A copyWith({String? extra, bool flag = false}) =>
      A(extra: flag ? null : (extra ?? this.extra)); }'''),
        isFalse,
      );
    });
  });

  group('require_copy_with_null_handling - behavior', () {
    /// Number of diagnostics the rule reports on [code] with full resolution.
    Future<int> count(String code) async =>
        (await runRuleResolved(RequireCopyWithNullHandlingRule(), code)).length;

    test('fires on ?? over a nullable field', () async {
      expect(
        await count('''
class A {
  A({this.name});
  final String? name;
  A copyWith({String? name}) => A(name: name ?? this.name);
}
'''),
        1,
      );
    });

    // Clearing one field by empty string does not help `hiddenAt`, which has
    // no empty value, so the declaration is still reported by design.
    test('fires on a clear-by-empty model', () async {
      expect(
        await count('''
class Group {
  Group({this.avatarUrl, this.hiddenAt});
  /// Null keeps the stored value; an empty string clears it.
  final String? avatarUrl;
  final DateTime? hiddenAt;
  Group copyWith({String? avatarUrl, DateTime? hiddenAt}) => Group(
        avatarUrl: avatarUrl ?? this.avatarUrl,
        hiddenAt: hiddenAt ?? this.hiddenAt,
      );
}
'''),
        1,
      );
    });

    // Nullable fields go through a wrapper; every remaining `??` targets a
    // non-nullable field, even though its parameter is nullable.
    test('silent when every ?? target field is non-nullable', () async {
      expect(
        await count('''
class Keep<T> {
  const Keep.unset();
  T? resolve(T? current) => current;
}
class Filters {
  Filters({this.text, this.limit = 1, this.unique = false});
  final String? text;
  final int limit;
  final bool unique;
  Filters copyWith({
    Keep<String> text = const Keep<String>.unset(),
    int? limit,
    bool? unique,
  }) => Filters(
        text: text.resolve(this.text),
        limit: limit ?? this.limit,
        unique: unique ?? this.unique,
      );
}
'''),
        0,
      );
    });
  });
}
