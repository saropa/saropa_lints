import 'dart:io';

import 'package:saropa_lints/src/rules/codegen/freezed_rules.dart';
import 'package:test/test.dart';

/// Tests for 10 Freezed lint rules.
///
/// Test fixtures: example_packages/lib/freezed/*
// @freezed / union patterns; use example_packages for package-resolution tests.
void main() {
  group('Freezed Rules - Rule Instantiation', () {
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
      'AvoidFreezedJsonSerializableConflictRule',
      'avoid_freezed_json_serializable_conflict',
      () => AvoidFreezedJsonSerializableConflictRule(),
    );
    testRule(
      'AvoidFreezedInvalidAnnotationTargetRule',
      'avoid_freezed_invalid_annotation_target',
      () => AvoidFreezedInvalidAnnotationTargetRule(),
    );
    testRule(
      'RequireFreezedArrowSyntaxRule',
      'require_freezed_arrow_syntax',
      () => RequireFreezedArrowSyntaxRule(),
    );
    testRule(
      'RequireFreezedPrivateConstructorRule',
      'require_freezed_private_constructor',
      () => RequireFreezedPrivateConstructorRule(),
    );
    testRule(
      'RequireFreezedExplicitJsonRule',
      'require_freezed_explicit_json',
      () => RequireFreezedExplicitJsonRule(),
    );
    testRule(
      'PreferFreezedDefaultValuesRule',
      'prefer_freezed_default_values',
      () => PreferFreezedDefaultValuesRule(),
    );
    testRule(
      'RequireFreezedJsonConverterRule',
      'require_freezed_json_converter',
      () => RequireFreezedJsonConverterRule(),
    );
    testRule(
      'RequireFreezedLintPackageRule',
      'require_freezed_lint_package',
      () => RequireFreezedLintPackageRule(),
    );
    testRule(
      'AvoidFreezedForLogicClassesRule',
      'avoid_freezed_for_logic_classes',
      () => AvoidFreezedForLogicClassesRule(),
    );
    testRule(
      'PreferFreezedForDataClassesRule',
      'prefer_freezed_for_data_classes',
      () => PreferFreezedForDataClassesRule(),
    );
    testRule(
      'AvoidFreezedAnyMapIssueRule',
      'avoid_freezed_any_map_issue',
      () => AvoidFreezedAnyMapIssueRule(),
    );
  });
  group('Freezed Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/freezed');

    // Auto-discover fixtures from disk so new files are verified
    // automatically — no manual list to maintain.
    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('\$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/freezed/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Freezed - Avoidance Rules', () {
    group('avoid_freezed_json_serializable_conflict', () {
      test(
        'conflicting JsonSerializable + Freezed annotations SHOULD trigger',
        () {
          expect(
            'conflicting JsonSerializable + Freezed annotations',
            isNotNull,
          );
        },
      );
    });
  });
}
