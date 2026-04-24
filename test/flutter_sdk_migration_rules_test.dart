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
///
/// Test fixture: example/lib/flutter_sdk_migration_rules_fixture.dart.
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
  };

  // Subset that exposes a `fixGenerators` quick fix. The remaining rules
  // intentionally have no auto-fix because the migration is semantic
  // (the developer has to choose a replacement variant).
  const rulesWithQuickFixes = <String>{
    'prefer_iterable_cast',
    'avoid_deprecated_use_inherited_media_query',
    'prefer_utf8_encode',
    'avoid_removed_appbar_backwards_compatibility',
  };

  group('flutter_sdk_migration fixture', () {
    test('fixture file exists', () {
      expect(
        File(
          'example/lib/flutter_sdk_migration_rules_fixture.dart',
        ).existsSync(),
        isTrue,
      );
    });

    test('fixture documents an expect_lint marker for every rule', () {
      final content = File(
        'example/lib/flutter_sdk_migration_rules_fixture.dart',
      ).readAsStringSync();
      for (final name in flutterSdkMigrationRuleNames) {
        expect(
          content.contains('expect_lint: $name'),
          isTrue,
          reason: 'Fixture should document a BAD case for $name',
        );
      }
    });
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
      expect(AvoidRemovedJsNumberToDartRule().impact, LintImpact.high);
    });

    test('medium impact for portability bugs and removed widget params', () {
      expect(PreferTypeSyncOverIsLinkSyncRule().impact, LintImpact.medium);
      expect(
        AvoidRemovedAppbarBackwardsCompatibilityRule().impact,
        LintImpact.medium,
      );
    });

    test('low impact for stylistic / dead-code migrations', () {
      expect(PreferIterableCastRule().impact, LintImpact.low);
      expect(PreferUtf8EncodeRule().impact, LintImpact.low);
      expect(
        AvoidDeprecatedUseInheritedMediaQueryRule().impact,
        LintImpact.low,
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
  });
}
