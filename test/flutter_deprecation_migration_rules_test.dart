import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:test/test.dart';

/// Tests for Flutter SDK deprecation migration rules.
///
/// These rules target Flutter-specific APIs and use [requiresFlutterImport].
/// Fixture-based detection tests are not possible in a Dart-only project;
/// these tests verify registration, tier, impact, and instantiation.
void main() {
  const flutterDeprecationRules = <String>{
    'avoid_removed_render_object_element_methods',
    'avoid_deprecated_animated_list_typedefs',
    'avoid_deprecated_use_material3_copy_with',
    'avoid_deprecated_on_surface_destroyed',
  };

  const rulesWithQuickFixes = <String>{
    'avoid_removed_render_object_element_methods',
    'avoid_deprecated_animated_list_typedefs',
    'avoid_deprecated_use_material3_copy_with',
    'avoid_deprecated_on_surface_destroyed',
  };

  group('tier and registry', () {
    test('all Flutter deprecation rules are in recommendedOnlyRules', () {
      for (final name in flutterDeprecationRules) {
        expect(recommendedOnlyRules.contains(name), isTrue, reason: name);
      }
    });

    test('getRulesFromRegistry resolves every rule name', () {
      final rules = getRulesFromRegistry(flutterDeprecationRules);
      expect(rules, hasLength(flutterDeprecationRules.length));
      final codes = rules.map((r) => r.code.lowerCaseName).toSet();
      expect(codes, flutterDeprecationRules);
    });

    test('rulesWithFixes includes rules that expose fixGenerators', () {
      getRulesFromRegistry(flutterDeprecationRules);
      for (final name in rulesWithQuickFixes) {
        expect(
          rulesWithFixes.contains(name),
          isTrue,
          reason: '$name should register in rulesWithFixes',
        );
      }
    });
  });

  group('LintImpact', () {
    test('high impact for removed API (RenderObjectElement)', () {
      expect(
        AvoidRemovedRenderObjectElementMethodsRule().impact,
        LintImpact.high,
      );
    });

    test('medium impact for deprecated APIs', () {
      expect(
        AvoidDeprecatedAnimatedListTypedefsRule().impact,
        LintImpact.medium,
      );
      expect(
        AvoidDeprecatedUseMaterial3CopyWithRule().impact,
        LintImpact.medium,
      );
      expect(AvoidDeprecatedOnSurfaceDestroyedRule().impact, LintImpact.medium);
    });
  });

  group('requiresFlutterImport', () {
    test('all Flutter deprecation rules require Flutter import', () {
      expect(
        AvoidRemovedRenderObjectElementMethodsRule().requiresFlutterImport,
        isTrue,
      );
      expect(
        AvoidDeprecatedAnimatedListTypedefsRule().requiresFlutterImport,
        isTrue,
      );
      expect(
        AvoidDeprecatedUseMaterial3CopyWithRule().requiresFlutterImport,
        isTrue,
      );
      expect(
        AvoidDeprecatedOnSurfaceDestroyedRule().requiresFlutterImport,
        isTrue,
      );
    });
  });

  group('requiredPatterns', () {
    test('each rule declares requiredPatterns for performance', () {
      expect(
        AvoidRemovedRenderObjectElementMethodsRule().requiredPatterns,
        isNotNull,
      );
      expect(
        AvoidDeprecatedAnimatedListTypedefsRule().requiredPatterns,
        isNotNull,
      );
      expect(
        AvoidDeprecatedUseMaterial3CopyWithRule().requiredPatterns,
        isNotNull,
      );
      expect(
        AvoidDeprecatedOnSurfaceDestroyedRule().requiredPatterns,
        isNotNull,
      );
    });
  });

  group('rule instantiation', () {
    test('AvoidRemovedRenderObjectElementMethodsRule', () {
      final rule = AvoidRemovedRenderObjectElementMethodsRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_removed_render_object_element_methods',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_render_object_element_methods]'),
      );
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidDeprecatedAnimatedListTypedefsRule', () {
      final rule = AvoidDeprecatedAnimatedListTypedefsRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_deprecated_animated_list_typedefs',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_animated_list_typedefs]'),
      );
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidDeprecatedUseMaterial3CopyWithRule', () {
      final rule = AvoidDeprecatedUseMaterial3CopyWithRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_deprecated_use_material3_copy_with',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_use_material3_copy_with]'),
      );
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidDeprecatedOnSurfaceDestroyedRule', () {
      final rule = AvoidDeprecatedOnSurfaceDestroyedRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_deprecated_on_surface_destroyed',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_on_surface_destroyed]'),
      );
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });
  });
}
