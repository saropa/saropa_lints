import 'package:saropa_lints/src/rules/config/sdk_migration_batch2_rules.dart';
import 'package:saropa_lints/src/tiers.dart';
import 'package:test/test.dart';

/// Tests for 10 SDK Migration Batch 2 lint rules.
///
/// Rules:
///   - prefer_isnan_over_nan_equality (Recommended, WARNING)
///   - prefer_code_unit_at (Recommended, INFO)
///   - prefer_never_over_always_throws (Recommended, WARNING)
///   - prefer_visibility_over_opacity_zero (Recommended, INFO)
///   - avoid_platform_constructor (Recommended, WARNING)
///   - prefer_keyboard_listener_over_raw (Recommended, WARNING)
///   - avoid_extending_html_native_class (Recommended, ERROR)
///   - avoid_extending_security_context (Recommended, ERROR)
///   - avoid_deprecated_pointer_arithmetic (Recommended, WARNING)
///   - prefer_extracting_repeated_map_lookup (Recommended, INFO)
void main() {
  // ---------------------------------------------------------------------------
  // Rule Instantiation & Metadata
  // ---------------------------------------------------------------------------

  group('SDK Migration Batch 2 - Rule Instantiation', () {
    test('PreferIsNanOverNanEqualityRule instantiates correctly', () {
      final rule = PreferIsNanOverNanEqualityRule();
      expect(rule.code.lowerCaseName, 'prefer_isnan_over_nan_equality');
      expect(
        rule.code.problemMessage,
        contains('[prefer_isnan_over_nan_equality]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('nan'));
      expect(rule.fixGenerators, hasLength(1));
    });

    test('PreferCodeUnitAtRule instantiates correctly', () {
      final rule = PreferCodeUnitAtRule();
      expect(rule.code.lowerCaseName, 'prefer_code_unit_at');
      expect(rule.code.problemMessage, contains('[prefer_code_unit_at]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('codeUnits'));
      expect(rule.fixGenerators, hasLength(1));
    });

    test('PreferNeverOverAlwaysThrowsRule instantiates correctly', () {
      final rule = PreferNeverOverAlwaysThrowsRule();
      expect(rule.code.lowerCaseName, 'prefer_never_over_always_throws');
      expect(
        rule.code.problemMessage,
        contains('[prefer_never_over_always_throws]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('alwaysThrows'));
    });

    test('PreferVisibilityOverOpacityZeroRule instantiates correctly', () {
      final rule = PreferVisibilityOverOpacityZeroRule();
      expect(rule.code.lowerCaseName, 'prefer_visibility_over_opacity_zero');
      expect(
        rule.code.problemMessage,
        contains('[prefer_visibility_over_opacity_zero]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('Opacity'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('AvoidPlatformConstructorRule instantiates correctly', () {
      final rule = AvoidPlatformConstructorRule();
      expect(rule.code.lowerCaseName, 'avoid_platform_constructor');
      expect(
        rule.code.problemMessage,
        contains('[avoid_platform_constructor]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('Platform'));
    });

    test('PreferKeyboardListenerOverRawRule instantiates correctly', () {
      final rule = PreferKeyboardListenerOverRawRule();
      expect(rule.code.lowerCaseName, 'prefer_keyboard_listener_over_raw');
      expect(
        rule.code.problemMessage,
        contains('[prefer_keyboard_listener_over_raw]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('RawKeyboardListener'));
      expect(rule.requiresFlutterImport, isTrue);
      expect(rule.fixGenerators, hasLength(1));
    });

    test('AvoidExtendingHtmlNativeClassRule instantiates correctly', () {
      final rule = AvoidExtendingHtmlNativeClassRule();
      expect(rule.code.lowerCaseName, 'avoid_extending_html_native_class');
      expect(
        rule.code.problemMessage,
        contains('[avoid_extending_html_native_class]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      // Pattern filter uses specific class names, not 'extends'
      expect(rule.requiredPatterns, contains('HtmlElement'));
      expect(rule.requiredPatterns, contains('CanvasElement'));
    });

    test('AvoidExtendingSecurityContextRule instantiates correctly', () {
      final rule = AvoidExtendingSecurityContextRule();
      expect(rule.code.lowerCaseName, 'avoid_extending_security_context');
      expect(
        rule.code.problemMessage,
        contains('[avoid_extending_security_context]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('SecurityContext'));
    });

    test('AvoidDeprecatedPointerArithmeticRule instantiates correctly', () {
      final rule = AvoidDeprecatedPointerArithmeticRule();
      expect(rule.code.lowerCaseName, 'avoid_deprecated_pointer_arithmetic');
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_pointer_arithmetic]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('elementAt'));
      expect(rule.fixGenerators, hasLength(1));
    });

    test('PreferExtractingRepeatedMapLookupRule instantiates correctly', () {
      final rule = PreferExtractingRepeatedMapLookupRule();
      expect(rule.code.lowerCaseName, 'prefer_extracting_repeated_map_lookup');
      expect(
        rule.code.problemMessage,
        contains('[prefer_extracting_repeated_map_lookup]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Tier Registration
  // ---------------------------------------------------------------------------

  group('SDK Migration Batch 2 - Tier Registration', () {
    test('all 10 rules are in recommendedOnlyRules', () {
      const expected = <String>[
        'prefer_isnan_over_nan_equality',
        'prefer_code_unit_at',
        'prefer_never_over_always_throws',
        'prefer_visibility_over_opacity_zero',
        'avoid_platform_constructor',
        'prefer_keyboard_listener_over_raw',
        'avoid_extending_html_native_class',
        'avoid_extending_security_context',
        'avoid_deprecated_pointer_arithmetic',
        'prefer_extracting_repeated_map_lookup',
      ];
      for (final name in expected) {
        expect(
          recommendedOnlyRules.contains(name),
          isTrue,
          reason: '$name should be in recommendedOnlyRules',
        );
      }
    });
  });

  // Stub-only behavior tests were removed from this file. Keep metadata and
  // tier-registration checks while migrating to analyzer-backed behavior tests.
}
