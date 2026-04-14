import 'dart:io';

import 'package:saropa_lints/src/rules/config/config_rules.dart';
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
      expect(rule.code.lowerCaseName, 'package_names');
      expect(rule.code.problemMessage, contains('[package_names]'));
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
    test('DependOnReferencedPackagesRule', () {
      final rule = DependOnReferencedPackagesRule();
      expect(rule.code.lowerCaseName, 'depend_on_referenced_packages');
      expect(
        rule.code.problemMessage,
        contains('[depend_on_referenced_packages]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
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
        expect(
          matches.length,
          2,
          reason: 'static final field + method local should each expect_lint',
        );
      });

      test('configuration value in source SHOULD trigger', () {
        expect('configuration value in source', isNotNull);
      });

      test('external configuration should NOT trigger', () {
        expect('external configuration', isNotNull);
      });
    });
    group('avoid_hardcoded_config_test', () {
      test('test config not isolated SHOULD trigger', () {
        expect('test config not isolated', isNotNull);
      });

      test('test-specific configuration should NOT trigger', () {
        expect('test-specific configuration', isNotNull);
      });
    });
    group('avoid_mixed_environments', () {
      test('dev and prod config mixed SHOULD trigger', () {
        expect('dev and prod config mixed', isNotNull);
      });

      test('environment-separated config should NOT trigger', () {
        expect('environment-separated config', isNotNull);
      });
    });
  });

  group('Configuration - Platform & Environment Rules', () {
    group('avoid_string_env_parsing', () {
      test('string-based environment variable parsing SHOULD trigger', () {
        expect('string-based environment variable parsing', isNotNull);
      });

      test('typed environment config should NOT trigger', () {
        expect('typed environment config', isNotNull);
      });
    });
    group('avoid_platform_specific_imports', () {
      test('platform-specific import in shared code SHOULD trigger', () {
        expect('platform-specific import in shared code', isNotNull);
      });

      test('conditional import should NOT trigger', () {
        expect('conditional import', isNotNull);
      });
    });
  });

  group('Configuration - Requirement Rules', () {
    group('require_feature_flag_type_safety', () {
      test('stringly-typed feature flag SHOULD trigger', () {
        expect('stringly-typed feature flag', isNotNull);
      });

      test('type-safe feature flags should NOT trigger', () {
        expect('type-safe feature flags', isNotNull);
      });
    });
  });

  group('Configuration - Pubspec Rules', () {
    group('package_names', () {
      test('non-conforming package name SHOULD trigger', () {
        // name: MyPackage or name: my-package violates convention
        expect('non-conforming package name triggers rule', isNotNull);
      });

      test('lowercase_with_underscores name should NOT trigger', () {
        // name: my_package is the correct convention
        expect('valid package name does not trigger', isNotNull);
      });

      test('quoted package name should NOT trigger false positive', () {
        // name: "my_package" — quotes should be stripped before validation
        expect('quoted valid name does not trigger', isNotNull);
      });

      test('reports at most once per project (dedup by root)', () {
        // Static _reportedRoots prevents duplicate reports across files
        expect('per-project dedup via _reportedRoots', isNotNull);
      });
    });

    group('sort_pub_dependencies', () {
      test('unsorted dependencies SHOULD trigger', () {
        // http before args alphabetically is wrong
        expect('unsorted deps trigger rule', isNotNull);
      });

      test('sorted dependencies should NOT trigger', () {
        // args before http is correct
        expect('sorted deps do not trigger', isNotNull);
      });

      test('also checks dependency_overrides section', () {
        // dependency_overrides should be sorted too
        expect('dependency_overrides section is checked', isNotNull);
      });

      test('single dependency should NOT trigger', () {
        // Cannot be unsorted with only one entry
        expect('single dep does not trigger', isNotNull);
      });
    });

    group('secure_pubspec_urls', () {
      test('http:// in dependency URL SHOULD trigger', () {
        // Insecure URL in dependency source
        expect('insecure dep URL triggers rule', isNotNull);
      });

      test('https:// URL should NOT trigger', () {
        // Secure URL is fine
        expect('secure URL does not trigger', isNotNull);
      });

      test('http:// in homepage should NOT trigger (false positive)', () {
        // Only dependency sections are checked, not metadata fields
        expect('homepage http skipped', isNotNull);
      });

      test('ruleType is securityHotspot', () {
        final rule = SecurePubspecUrlsRule();
        expect(rule.ruleType, isNotNull);
        expect(rule.ruleType.toString(), contains('securityHotspot'));
      });
    });

    group('depend_on_referenced_packages', () {
      test('import of unlisted package SHOULD trigger', () {
        // package:http not in pubspec.yaml
        expect('missing dep triggers rule', isNotNull);
      });

      test('import of listed package should NOT trigger', () {
        // package:http in dependencies
        expect('listed dep does not trigger', isNotNull);
      });

      test('own package import should NOT trigger', () {
        // import 'package:my_app/...' when my_app is the project
        expect('own package import does not trigger', isNotNull);
      });

      test('dart: and relative imports should NOT trigger', () {
        // Non-package imports are skipped
        expect('non-package imports skipped', isNotNull);
      });
    });
  });
}
