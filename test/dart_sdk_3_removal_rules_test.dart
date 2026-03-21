import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:test/test.dart';

/// Tests for Dart SDK 3.0 removed-API migration rules.
///
/// **Registry:** rules must appear in [recommendedOnlyRules] and
/// [_ruleFactories] (via [getRulesFromRegistry]).
///
/// **False-positive contract (documented):** user-defined types named like
/// removed SDK APIs (`CastError`, `DeferredLibrary`, `Provisional`, `Metrics`,
/// `NetworkInterface`, `HasNextIterator`, …) are not reported when resolution
/// binds to the user's library. See `example/lib/dart_sdk_3_removal_good_fixture.dart`.
void main() {
  const sdk30RuleNames = <String>{
    'avoid_deprecated_list_constructor',
    'avoid_removed_proxy_annotation',
    'avoid_removed_provisional_annotation',
    'avoid_deprecated_expires_getter',
    'avoid_removed_cast_error',
    'avoid_removed_fall_through_error',
    'avoid_removed_abstract_class_instantiation_error',
    'avoid_removed_cyclic_initialization_error',
    'avoid_removed_nosuchmethoderror_default_constructor',
    'avoid_removed_bidirectional_iterator',
    'avoid_removed_deferred_library',
    'avoid_deprecated_has_next_iterator',
    'avoid_removed_max_user_tags_constant',
    'avoid_removed_dart_developer_metrics',
    'avoid_deprecated_network_interface_list_supported',
  };

  const rulesWithQuickFixes = <String>{
    'avoid_deprecated_list_constructor',
    'avoid_removed_proxy_annotation',
    'avoid_removed_provisional_annotation',
    'avoid_deprecated_expires_getter',
    'avoid_removed_cast_error',
    'avoid_removed_max_user_tags_constant',
  };

  group('dart_sdk_3_removal fixtures', () {
    test('BAD fixture file exists', () {
      expect(
        File('example/lib/dart_sdk_3_removal_fixture.dart').existsSync(),
        isTrue,
      );
    });

    test('GOOD fixture file exists (false-positive guard)', () {
      expect(
        File('example/lib/dart_sdk_3_removal_good_fixture.dart').existsSync(),
        isTrue,
      );
    });

    test('BAD fixture lists every rule at least once via expect_lint', () {
      final content = File(
        'example/lib/dart_sdk_3_removal_fixture.dart',
      ).readAsStringSync();
      for (final name in sdk30RuleNames) {
        expect(
          content.contains('expect_lint: $name'),
          isTrue,
          reason: 'Fixture should document a BAD case for $name',
        );
      }
    });

    test(
      'GOOD fixture has no expect_lint markers (false-positive guard contract)',
      () {
        final content = File(
          'example/lib/dart_sdk_3_removal_good_fixture.dart',
        ).readAsStringSync();
        expect(content.contains('expect_lint:'), isFalse);
        for (final name in sdk30RuleNames) {
          expect(
            content.contains('expect_lint: $name'),
            isFalse,
            reason: 'Good fixture must not simulate a violation for $name',
          );
        }
      },
    );

    test(
      'GOOD fixture defines user SDK-namesake types (Metrics, NetworkInterface, …)',
      () {
        final content = File(
          'example/lib/dart_sdk_3_removal_good_fixture.dart',
        ).readAsStringSync();
        expect(content.contains('class Metrics'), isTrue);
        expect(content.contains('class Metric'), isTrue);
        expect(content.contains('class Counter'), isTrue);
        expect(content.contains('class Gauge'), isTrue);
        expect(content.contains('class NetworkInterface'), isTrue);
        expect(content.contains('class HasNextIterator'), isTrue);
      },
    );
  });

  group('tier and registry', () {
    test('all SDK 3.0 rules are in recommendedOnlyRules', () {
      for (final name in sdk30RuleNames) {
        expect(recommendedOnlyRules.contains(name), isTrue, reason: name);
      }
    });

    test('getRulesFromRegistry resolves every SDK 3.0 rule name', () {
      final rules = getRulesFromRegistry(sdk30RuleNames);
      expect(rules, hasLength(sdk30RuleNames.length));
      final codes = rules.map((r) => r.code.lowerCaseName).toSet();
      expect(codes, sdk30RuleNames);
    });

    test('rulesWithFixes includes rules that expose fixGenerators', () {
      getRulesFromRegistry(sdk30RuleNames);
      for (final name in rulesWithQuickFixes) {
        expect(
          rulesWithFixes.contains(name),
          isTrue,
          reason: '$name should register in rulesWithFixes',
        );
      }
    });
  });

  group('LintImpact (compile-failure vs cleanup)', () {
    test('high impact for hard SDK breaks', () {
      expect(AvoidDeprecatedListConstructorRule().impact, LintImpact.high);
      expect(AvoidRemovedCastErrorRule().impact, LintImpact.high);
      expect(
        AvoidRemovedNoSuchMethodErrorDefaultConstructorRule().impact,
        LintImpact.high,
      );
      expect(AvoidRemovedDeferredLibraryRule().impact, LintImpact.high);
      expect(AvoidRemovedMaxUserTagsConstantRule().impact, LintImpact.high);
      expect(AvoidRemovedDartDeveloperMetricsRule().impact, LintImpact.high);
    });

    test('medium impact for removed error types / BidirectionalIterator', () {
      expect(AvoidRemovedFallThroughErrorRule().impact, LintImpact.medium);
      expect(
        AvoidRemovedAbstractClassInstantiationErrorRule().impact,
        LintImpact.medium,
      );
      expect(
        AvoidRemovedCyclicInitializationErrorRule().impact,
        LintImpact.medium,
      );
      expect(AvoidRemovedBidirectionalIteratorRule().impact, LintImpact.medium);
      expect(AvoidDeprecatedHasNextIteratorRule().impact, LintImpact.medium);
    });

    test('low impact for no-op annotations and Deprecated.expires', () {
      expect(AvoidRemovedProxyAnnotationRule().impact, LintImpact.low);
      expect(AvoidRemovedProvisionalAnnotationRule().impact, LintImpact.low);
      expect(AvoidDeprecatedExpiresGetterRule().impact, LintImpact.low);
      expect(
        AvoidDeprecatedNetworkInterfaceListSupportedRule().impact,
        LintImpact.low,
      );
    });
  });

  group('requiredPatterns (file-level skip)', () {
    test('each rule declares requiredPatterns for performance', () {
      expect(AvoidDeprecatedListConstructorRule().requiredPatterns, isNotNull);
      expect(AvoidRemovedProxyAnnotationRule().requiredPatterns, isNotNull);
      expect(
        AvoidRemovedProvisionalAnnotationRule().requiredPatterns,
        isNotNull,
      );
      expect(AvoidDeprecatedExpiresGetterRule().requiredPatterns, isNotNull);
      expect(AvoidRemovedCastErrorRule().requiredPatterns, isNotNull);
      expect(AvoidRemovedFallThroughErrorRule().requiredPatterns, isNotNull);
      expect(
        AvoidRemovedAbstractClassInstantiationErrorRule().requiredPatterns,
        isNotNull,
      );
      expect(
        AvoidRemovedCyclicInitializationErrorRule().requiredPatterns,
        isNotNull,
      );
      expect(
        AvoidRemovedNoSuchMethodErrorDefaultConstructorRule().requiredPatterns,
        isNotNull,
      );
      expect(
        AvoidRemovedBidirectionalIteratorRule().requiredPatterns,
        isNotNull,
      );
      expect(AvoidRemovedDeferredLibraryRule().requiredPatterns, isNotNull);
      expect(AvoidDeprecatedHasNextIteratorRule().requiredPatterns, isNotNull);
      expect(AvoidRemovedMaxUserTagsConstantRule().requiredPatterns, isNotNull);
      expect(
        AvoidRemovedDartDeveloperMetricsRule().requiredPatterns,
        isNotNull,
      );
      expect(
        AvoidDeprecatedNetworkInterfaceListSupportedRule().requiredPatterns,
        isNotNull,
      );
    });

    test('List rule pattern targets ctor call, not List.from', () {
      final p = AvoidDeprecatedListConstructorRule().requiredPatterns!;
      expect(p, contains('List('));
      expect(p.any((s) => s.contains('from')), isFalse);
    });
  });

  group('rule instantiation', () {
    test('AvoidDeprecatedListConstructorRule', () {
      final rule = AvoidDeprecatedListConstructorRule();
      expect(rule.code.name.toLowerCase(), 'avoid_deprecated_list_constructor');
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_list_constructor]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(120));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidRemovedProxyAnnotationRule', () {
      final rule = AvoidRemovedProxyAnnotationRule();
      expect(rule.code.name.toLowerCase(), 'avoid_removed_proxy_annotation');
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_proxy_annotation]'),
      );
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidRemovedProvisionalAnnotationRule', () {
      final rule = AvoidRemovedProvisionalAnnotationRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_removed_provisional_annotation',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_provisional_annotation]'),
      );
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidDeprecatedExpiresGetterRule', () {
      final rule = AvoidDeprecatedExpiresGetterRule();
      expect(rule.code.name.toLowerCase(), 'avoid_deprecated_expires_getter');
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_expires_getter]'),
      );
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidRemovedCastErrorRule', () {
      final rule = AvoidRemovedCastErrorRule();
      expect(rule.code.name.toLowerCase(), 'avoid_removed_cast_error');
      expect(rule.code.problemMessage, contains('[avoid_removed_cast_error]'));
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidRemovedFallThroughErrorRule', () {
      final rule = AvoidRemovedFallThroughErrorRule();
      expect(rule.code.name.toLowerCase(), 'avoid_removed_fall_through_error');
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_fall_through_error]'),
      );
    });

    test('AvoidRemovedAbstractClassInstantiationErrorRule', () {
      final rule = AvoidRemovedAbstractClassInstantiationErrorRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_removed_abstract_class_instantiation_error',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_abstract_class_instantiation_error]'),
      );
    });

    test('AvoidRemovedCyclicInitializationErrorRule', () {
      final rule = AvoidRemovedCyclicInitializationErrorRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_removed_cyclic_initialization_error',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_cyclic_initialization_error]'),
      );
    });

    test('AvoidRemovedNoSuchMethodErrorDefaultConstructorRule', () {
      final rule = AvoidRemovedNoSuchMethodErrorDefaultConstructorRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_removed_nosuchmethoderror_default_constructor',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_nosuchmethoderror_default_constructor]'),
      );
    });

    test('AvoidRemovedBidirectionalIteratorRule', () {
      final rule = AvoidRemovedBidirectionalIteratorRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_removed_bidirectional_iterator',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_bidirectional_iterator]'),
      );
    });

    test('AvoidRemovedDeferredLibraryRule', () {
      final rule = AvoidRemovedDeferredLibraryRule();
      expect(rule.code.name.toLowerCase(), 'avoid_removed_deferred_library');
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_deferred_library]'),
      );
    });

    test('AvoidDeprecatedHasNextIteratorRule', () {
      final rule = AvoidDeprecatedHasNextIteratorRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_deprecated_has_next_iterator',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_has_next_iterator]'),
      );
    });

    test('AvoidRemovedMaxUserTagsConstantRule', () {
      final rule = AvoidRemovedMaxUserTagsConstantRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_removed_max_user_tags_constant',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_max_user_tags_constant]'),
      );
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('AvoidRemovedDartDeveloperMetricsRule', () {
      final rule = AvoidRemovedDartDeveloperMetricsRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_removed_dart_developer_metrics',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_removed_dart_developer_metrics]'),
      );
    });

    test('AvoidDeprecatedNetworkInterfaceListSupportedRule', () {
      final rule = AvoidDeprecatedNetworkInterfaceListSupportedRule();
      expect(
        rule.code.name.toLowerCase(),
        'avoid_deprecated_network_interface_list_supported',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_network_interface_list_supported]'),
      );
    });
  });
}
