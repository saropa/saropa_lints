import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for Dart SDK 3.4 deprecated-API migration rules.
void main() {
  const sdk34RuleNames = <String>{
    'avoid_deprecated_file_system_delete_event_is_directory',
  };

  group('dart_sdk_34 fixtures', () {
    test('BAD fixture file exists', () {
      expect(
        File('example/lib/dart_sdk_34_deprecation_fixture.dart').existsSync(),
        isTrue,
      );
    });

    test('GOOD fixture file exists (false-positive guard)', () {
      expect(
        File(
          'example/lib/dart_sdk_34_deprecation_good_fixture.dart',
        ).existsSync(),
        isTrue,
      );
    });

    test('BAD fixture lists every rule at least once via expect_lint', () {
      final content = File(
        'example/lib/dart_sdk_34_deprecation_fixture.dart',
      ).readAsStringSync();
      for (final name in sdk34RuleNames) {
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
          'example/lib/dart_sdk_34_deprecation_good_fixture.dart',
        ).readAsStringSync();
        expect(content.contains('expect_lint:'), isFalse);
      },
    );

    test('GOOD fixture defines user-defined FileSystemDeleteEvent', () {
      final content = File(
        'example/lib/dart_sdk_34_deprecation_good_fixture.dart',
      ).readAsStringSync();
      expect(content.contains('class FileSystemDeleteEvent'), isTrue);
    });
  });

  group('tier and registry', () {
    test('all SDK 3.4 rules are in recommendedOnlyRules', () {
      for (final name in sdk34RuleNames) {
        expect(recommendedOnlyRules.contains(name), isTrue, reason: name);
      }
    });

    test('getRulesFromRegistry resolves every SDK 3.4 rule name', () {
      final rules = getRulesFromRegistry(sdk34RuleNames);
      expect(rules, hasLength(sdk34RuleNames.length));
      final codes = rules.map((r) => r.code.lowerCaseName).toSet();
      expect(codes, sdk34RuleNames);
    });
  });

  group('LintImpact', () {
    test('low impact for deprecated property', () {
      expect(
        AvoidDeprecatedFileSystemDeleteEventIsDirectoryRule().impact,
        LintImpact.low,
      );
    });
  });

  group('requiredPatterns', () {
    test('each rule declares requiredPatterns for performance', () {
      expect(
        AvoidDeprecatedFileSystemDeleteEventIsDirectoryRule().requiredPatterns,
        isNotNull,
      );
    });
  });

  group('rule instantiation', () {
    test('AvoidDeprecatedFileSystemDeleteEventIsDirectoryRule', () {
      final rule = AvoidDeprecatedFileSystemDeleteEventIsDirectoryRule();
      expect(
        rule.code.lowerCaseName,
        'avoid_deprecated_file_system_delete_event_is_directory',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_file_system_delete_event_is_directory]'),
      );
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
