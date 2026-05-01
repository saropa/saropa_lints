import 'dart:io';

import 'package:saropa_lints/src/rules/config/config_rules.dart';
import 'package:saropa_lints/src/rules/config/repo_integrity_rules.dart';
import 'package:test/test.dart';

/// Tests for 11 Configuration lint rules.
///
/// Test fixtures: example/lib/config/*
void main() {
  group('Configuration Rules - Rule Instantiation', () {
    test('AvoidHardcodedConfigRule', () {
      final rule = AvoidHardcodedConfigRule();
      expect(rule.code.lowerCaseName, 'avoid_hardcoded_config');
      expect(rule.code.problemMessage, contains('[avoid_hardcoded_config]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidHardcodedConfigTestRule', () {
      final rule = AvoidHardcodedConfigTestRule();
      expect(rule.code.lowerCaseName, 'avoid_hardcoded_config_test');
      expect(
        rule.code.problemMessage,
        contains('[avoid_hardcoded_config_test]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidMixedEnvironmentsRule', () {
      final rule = AvoidMixedEnvironmentsRule();
      expect(rule.code.lowerCaseName, 'avoid_mixed_environments');
      expect(rule.code.problemMessage, contains('[avoid_mixed_environments]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireFeatureFlagTypeSafetyRule', () {
      final rule = RequireFeatureFlagTypeSafetyRule();
      expect(rule.code.lowerCaseName, 'require_feature_flag_type_safety');
      expect(
        rule.code.problemMessage,
        contains('[require_feature_flag_type_safety]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidStringEnvParsingRule', () {
      final rule = AvoidStringEnvParsingRule();
      expect(rule.code.lowerCaseName, 'avoid_string_env_parsing');
      expect(rule.code.problemMessage, contains('[avoid_string_env_parsing]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidPlatformSpecificImportsRule', () {
      final rule = AvoidPlatformSpecificImportsRule();
      expect(rule.code.lowerCaseName, 'avoid_platform_specific_imports');
      expect(
        rule.code.problemMessage,
        contains('[avoid_platform_specific_imports]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferSemverVersionRule', () {
      final rule = PreferSemverVersionRule();
      expect(rule.code.lowerCaseName, 'prefer_semver_version');
      expect(rule.code.problemMessage, contains('[prefer_semver_version]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferCompileTimeConfigRule', () {
      final rule = PreferCompileTimeConfigRule();
      expect(rule.code.lowerCaseName, 'prefer_compile_time_config');
      expect(
        rule.code.problemMessage,
        contains('[prefer_compile_time_config]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferFlavorConfigurationRule', () {
      final rule = PreferFlavorConfigurationRule();
      expect(rule.code.lowerCaseName, 'prefer_flavor_configuration');
      expect(
        rule.code.problemMessage,
        contains('[prefer_flavor_configuration]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PackageNamesRule', () {
      final rule = PackageNamesRule();
      expect(rule.code.lowerCaseName, 'pubspec_package_name_convention');
      expect(
        rule.code.problemMessage,
        contains('[pubspec_package_name_convention]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('SortPubDependenciesRule', () {
      final rule = SortPubDependenciesRule();
      expect(rule.code.lowerCaseName, 'sort_pub_dependencies');
      expect(rule.code.problemMessage, contains('[sort_pub_dependencies]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('SecurePubspecUrlsRule', () {
      final rule = SecurePubspecUrlsRule();
      expect(rule.code.lowerCaseName, 'secure_pubspec_urls');
      expect(rule.code.problemMessage, contains('[secure_pubspec_urls]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireEnvFileGitignoreRule', () {
      final rule = RequireEnvFileGitignoreRule();
      expect(rule.code.lowerCaseName, 'require_env_file_gitignore');
      expect(
        rule.code.problemMessage,
        contains('[require_env_file_gitignore]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    // `DependOnReferencedPackagesRule` / `saropa_depend_on_referenced_packages`
    // was REMOVED. Delegated to the Dart SDK's built-in lint of the same
    // base name, shipped via `package:lints/core.yaml` — saropa's
    // homegrown parser kept mis-parsing real-world pubspecs and firing on
    // legitimate imports. No replacement test: there is no replacement
    // rule in this plugin.
  });

  group('Configuration Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_hardcoded_config',
      'avoid_hardcoded_config_test',
      'avoid_mixed_environments',
      'require_feature_flag_type_safety',
      'avoid_string_env_parsing',
      'avoid_platform_specific_imports',
      'prefer_compile_time_config',
      'prefer_flavor_configuration',
      'prefer_semver_version',
      'require_env_file_gitignore',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/config/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Configuration - Avoidance Rules', () {
    group('avoid_hardcoded_config', () {
      test('fixture: static const and top-level const have no expect_lint', () {
        final content = File(
          'example/lib/config/avoid_hardcoded_config_fixture.dart',
        ).readAsStringSync();
        expect(
          content.contains('cdnBaseUrl'),
          isTrue,
          reason: 'GOOD: static const URL',
        );
        expect(
          content.contains('kTopLevelApiUrl'),
          isTrue,
          reason: 'GOOD: top-level const URL',
        );
        for (final line in content.split('\n')) {
          if (line.contains('cdnBaseUrl') ||
              line.contains('kTopLevelApiUrl') ||
              line.contains('queryParamLimit') ||
              line.contains('packageVersion')) {
            expect(
              line.contains('expect_lint:'),
              isFalse,
              reason:
                  'Named compile-time constants must not be marked BAD: $line',
            );
          }
        }
      });

      test('fixture: exactly two BAD sites with expect_lint', () {
        final content = File(
          'example/lib/config/avoid_hardcoded_config_fixture.dart',
        ).readAsStringSync();
        final matches = RegExp(
          r'// expect_lint: avoid_hardcoded_config',
        ).allMatches(content);
        // Fix: hasLength matcher yields clearer failure message than raw count.
        expect(
          matches,
          hasLength(2),
          reason: 'static final field + method local should each expect_lint',
        );
      });
    });
  });

  group('Configuration - Pubspec Rules', () {
    group('secure_pubspec_urls', () {
      test('ruleType is securityHotspot', () {
        final rule = SecurePubspecUrlsRule();
        expect(rule.ruleType, isNotNull);
        expect(rule.ruleType.toString(), contains('securityHotspot'));
      });

      test('metadata includes CWE-494', () {
        final rule = SecurePubspecUrlsRule();
        expect(rule.cweIds, contains(494));
      });
    });

    // saropa_depend_on_referenced_packages placeholder group removed along
    // with the rule. See the Rule Instantiation group above for the removal
    // rationale.
  });
}
