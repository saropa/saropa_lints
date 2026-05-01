import 'dart:io';

import 'package:saropa_lints/src/rules/packages/equatable_rules.dart';
import 'package:test/test.dart';

/// Tests for 13 Equatable lint rules.
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
  });
  group('Equatable Rules - Fixture Verification', () {
    final fixtures = [
      'require_extend_equatable',
      'list_all_equatable_fields',
      'avoid_equatable_nested_equality',
      'prefer_equatable_mixin',
      'prefer_equatable_stringify',
      'prefer_immutable_annotation',
      'prefer_record_over_equatable',
      'avoid_mutable_field_in_equatable',
      'require_equatable_copy_with',
      'require_copy_with_null_handling',
      'require_deep_equality_collections',
      'avoid_equatable_datetime',
      'prefer_unmodifiable_collections',
      'require_equatable_props_override',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/equatable/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
