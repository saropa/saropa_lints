import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for the Flutter / Dart SDK migration rules in
/// `lib/src/rules/config/flutter_sdk_migration_rules.dart`.
///
/// Rules covered (with originating plan numbers):
///   - prefer_iterable_cast (#024, INFO)
///   - avoid_deprecated_use_inherited_media_query (#043, WARNING)
///   - prefer_utf8_encode (#050, INFO)
///   - avoid_removed_appbar_backwards_compatibility (#055, WARNING)
///   - prefer_type_sync_over_is_link_sync (#079, WARNING)
///   - avoid_removed_js_number_to_dart (#090, WARNING)
///   - prefer_scrollbar_theme_of (#067, INFO)
///   - avoid_legacy_jsboolean_return_assumptions (#091, WARNING)
///   - prefer_string_for_typeof_equals (#092, WARNING)
///   - prefer_int_for_jsarray_with_length (#093, WARNING)
///
/// Test fixtures:
///   - example/lib/flutter_sdk_migration_rules_fixture.dart
///   - example/lib/flutter_sdk_js_interop_migration_fixture.dart (#091–#093)
///
/// **Coverage contract:** every rule listed here is registered in
/// [recommendedOnlyRules], resolves through [getRulesFromRegistry], declares a
/// non-null `requiredPatterns` (file-level skip optimization), tags its
/// problemMessage with `[rule_name]`, and exposes a `correctionMessage` so the
/// IDE can surface the suggested migration even when no quick fix exists.
void main() {
  // Rule names emitted as LintCodes by flutter_sdk_migration_rules.dart.
  const flutterSdkMigrationRuleNames = <String>{
    'prefer_iterable_cast',
    'avoid_deprecated_use_inherited_media_query',
    'prefer_utf8_encode',
    'avoid_removed_appbar_backwards_compatibility',
    'prefer_type_sync_over_is_link_sync',
    'avoid_removed_js_number_to_dart',
    'prefer_scrollbar_theme_of',
    'avoid_legacy_jsboolean_return_assumptions',
    'prefer_string_for_typeof_equals',
    'prefer_int_for_jsarray_with_length',
  };

  // Subset that exposes a `fixGenerators` quick fix. The remaining rules
  // intentionally have no auto-fix because the migration is semantic
  // (the developer has to choose a replacement variant).
  const rulesWithQuickFixes = <String>{
    'prefer_iterable_cast',
    'avoid_deprecated_use_inherited_media_query',
    'prefer_utf8_encode',
    'avoid_removed_appbar_backwards_compatibility',
    'prefer_scrollbar_theme_of',
  };

  const _flutterSdkMigrationFixturePaths = <String>[
    'example/lib/flutter_sdk_migration_rules_fixture.dart',
    'example/lib/flutter_sdk_js_interop_migration_fixture.dart',
  ];

  group('flutter_sdk_migration fixture', () {
    test('fixture files exist', () {
      for (final path in _flutterSdkMigrationFixturePaths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('fixtures document an expect_lint marker for every rule', () {
      final merged = _flutterSdkMigrationFixturePaths
          .map((p) => File(p).readAsStringSync())
          .join('\n');
      for (final name in flutterSdkMigrationRuleNames) {
        expect(
          merged.contains('expect_lint: $name'),
          isTrue,
          reason: 'Fixtures should document a BAD case for $name',
        );
      }
    });

    test(
      'prefer_scrollbar_theme_of keeps user-defined Theme.of false-positive guard',
      () {
        final fixture = File(
          'example/lib/flutter_sdk_migration_rules_fixture.dart',
        ).readAsStringSync();

        expect(
          fixture.contains('_UserTheme.of(context).scrollbarTheme'),
          isTrue,
          reason:
              'Fixture should retain a non-Flutter Theme.of(...).scrollbarTheme '
              'example that must remain a GOOD case.',
        );
      },
    );
  });

  group('tier and registry', () {
    test('all rules are in recommendedOnlyRules', () {
      for (final name in flutterSdkMigrationRuleNames) {
        expect(recommendedOnlyRules.contains(name), isTrue, reason: name);
      }
    });

    test('getRulesFromRegistry resolves every rule name', () {
      final rules = getRulesFromRegistry(flutterSdkMigrationRuleNames);
      expect(rules, hasLength(flutterSdkMigrationRuleNames.length));
      final codes = rules.map((r) => r.code.lowerCaseName).toSet();
      expect(codes, flutterSdkMigrationRuleNames);
    });

    test('rulesWithFixes includes rules that expose fixGenerators', () {
      // Force registry initialization so rulesWithFixes is populated.
      getRulesFromRegistry(flutterSdkMigrationRuleNames);
      for (final name in rulesWithQuickFixes) {
        expect(
          rulesWithFixes.contains(name),
          isTrue,
          reason: '$name should register in rulesWithFixes',
        );
      }
    });
  });

  group('LintImpact (severity-of-bug heuristic)', () {
    test('high impact for hard SDK breaks (removed APIs)', () {
      // JSNumber.toDart was removed — calling sites fail to compile on 3.2+.
      expect(AvoidRemovedJsNumberToDartRule().impact, LintImpact.warning);
    });

    test('medium impact for portability bugs and removed widget params', () {
      expect(PreferTypeSyncOverIsLinkSyncRule().impact, LintImpact.warning);
      expect(
        AvoidRemovedAppbarBackwardsCompatibilityRule().impact,
        LintImpact.warning,
      );
      expect(
        AvoidLegacyJsBooleanReturnAssumptionsRule().impact,
        LintImpact.warning,
      );
      expect(PreferStringForTypeofEqualsRule().impact, LintImpact.warning);
      expect(PreferIntForJsarrayWithLengthRule().impact, LintImpact.warning);
    });

    test('low impact for stylistic / dead-code migrations', () {
      expect(PreferIterableCastRule().impact, LintImpact.info);
      expect(PreferUtf8EncodeRule().impact, LintImpact.info);
      expect(PreferScrollbarThemeOfRule().impact, LintImpact.info);
      expect(
        AvoidDeprecatedUseInheritedMediaQueryRule().impact,
        LintImpact.info,
      );
    });
  });

  group('requiredPatterns (file-level skip optimization)', () {
    test('every rule declares requiredPatterns', () {
      expect(PreferIterableCastRule().requiredPatterns, isNotNull);
      expect(
        AvoidDeprecatedUseInheritedMediaQueryRule().requiredPatterns,
        isNotNull,
      );
      expect(PreferUtf8EncodeRule().requiredPatterns, isNotNull);
      expect(
        AvoidRemovedAppbarBackwardsCompatibilityRule().requiredPatterns,
        isNotNull,
      );
      expect(PreferTypeSyncOverIsLinkSyncRule().requiredPatterns, isNotNull);
      expect(AvoidRemovedJsNumberToDartRule().requiredPatterns, isNotNull);
      expect(PreferScrollbarThemeOfRule().requiredPatterns, isNotNull);
      expect(
        AvoidLegacyJsBooleanReturnAssumptionsRule().requiredPatterns,
        isNotNull,
      );
      expect(PreferStringForTypeofEqualsRule().requiredPatterns, isNotNull);
      expect(PreferIntForJsarrayWithLengthRule().requiredPatterns, isNotNull);
    });

    test('patterns are specific enough to skip irrelevant files', () {
      // Each rule's pattern must include the API token it cares about so
      // files not containing that token are short-circuited before AST walk.
      expect(PreferIterableCastRule().requiredPatterns, contains('castFrom'));
      expect(
        AvoidDeprecatedUseInheritedMediaQueryRule().requiredPatterns,
        contains('useInheritedMediaQuery'),
      );
      expect(
        AvoidRemovedAppbarBackwardsCompatibilityRule().requiredPatterns,
        contains('backwardsCompatibility'),
      );
      expect(
        PreferTypeSyncOverIsLinkSyncRule().requiredPatterns,
        contains('isLinkSync'),
      );
      expect(
        AvoidRemovedJsNumberToDartRule().requiredPatterns,
        contains('toDart'),
      );
      expect(
        PreferScrollbarThemeOfRule().requiredPatterns,
        contains('scrollbarTheme'),
      );
      expect(
        AvoidLegacyJsBooleanReturnAssumptionsRule().requiredPatterns,
        contains('typeofEquals'),
      );
      expect(
        AvoidLegacyJsBooleanReturnAssumptionsRule().requiredPatterns,
        contains('instanceof'),
      );
      expect(
        PreferStringForTypeofEqualsRule().requiredPatterns,
        contains('typeofEquals'),
      );
      expect(
        PreferIntForJsarrayWithLengthRule().requiredPatterns,
        contains('withLength'),
      );
    });
  });

  group('Flutter SDK Migration Rules - Rule Instantiation', () {
    test('PreferIterableCastRule', () {
      final rule = PreferIterableCastRule();
      expect(rule.code.lowerCaseName, 'prefer_iterable_cast');
      expect(rule.code.problemMessage, contains('[prefer_iterable_cast]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidDeprecatedUseInheritedMediaQueryRule', () {
      final rule = AvoidDeprecatedUseInheritedMediaQueryRule();
      expect(
        rule.code.lowerCaseName,
        'avoid_deprecated_use_inherited_media_query',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_use_inherited_media_query]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('PreferUtf8EncodeRule', () {
      final rule = PreferUtf8EncodeRule();
      expect(rule.code.lowerCaseName, 'prefer_utf8_encode');
      expect(rule.code.problemMessage, contains('[prefer_utf8_encode]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidRemovedAppbarBackwardsCompatibilityRule', () {
      final rule = AvoidRemovedAppbarBackwardsCompatibilityRule();
      expect(
        rule.code.lowerCaseName,
        'avoid_removed_appbar_backwards_compatibility',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_appbar_backwards_compatibility]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('PreferTypeSyncOverIsLinkSyncRule', () {
      final rule = PreferTypeSyncOverIsLinkSyncRule();
      expect(rule.code.lowerCaseName, 'prefer_type_sync_over_is_link_sync');
      expect(
        rule.code.problemMessage,
        contains('[prefer_type_sync_over_is_link_sync]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('AvoidRemovedJsNumberToDartRule', () {
      final rule = AvoidRemovedJsNumberToDartRule();
      expect(rule.code.lowerCaseName, 'avoid_removed_js_number_to_dart');
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_js_number_to_dart]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferScrollbarThemeOfRule', () {
      final rule = PreferScrollbarThemeOfRule();
      expect(rule.code.lowerCaseName, 'prefer_scrollbar_theme_of');
      expect(rule.code.problemMessage, contains('[prefer_scrollbar_theme_of]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('AvoidLegacyJsBooleanReturnAssumptionsRule', () {
      final rule = AvoidLegacyJsBooleanReturnAssumptionsRule();
      expect(
        rule.code.lowerCaseName,
        'avoid_legacy_jsboolean_return_assumptions',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_legacy_jsboolean_return_assumptions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferStringForTypeofEqualsRule', () {
      final rule = PreferStringForTypeofEqualsRule();
      expect(rule.code.lowerCaseName, 'prefer_string_for_typeof_equals');
      expect(
        rule.code.problemMessage,
        contains('[prefer_string_for_typeof_equals]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferIntForJsarrayWithLengthRule', () {
      final rule = PreferIntForJsarrayWithLengthRule();
      expect(rule.code.lowerCaseName, 'prefer_int_for_jsarray_with_length');
      expect(
        rule.code.problemMessage,
        contains('[prefer_int_for_jsarray_with_length]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
