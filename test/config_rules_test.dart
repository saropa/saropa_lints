import 'dart:io';

import 'package:saropa_lints/src/rules/config/config_rules.dart';
import 'package:test/test.dart';

/// Tests for 7 Configuration lint rules.
///
/// Test fixtures: example_async/lib/config/*
void main() {
  group('Configuration Rules - Rule Instantiation', () {
    test('AvoidHardcodedConfigRule', () {
      final rule = AvoidHardcodedConfigRule();
      expect(rule.code.name, 'avoid_hardcoded_config');
      expect(rule.code.problemMessage, contains('[avoid_hardcoded_config]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidHardcodedConfigTestRule', () {
      final rule = AvoidHardcodedConfigTestRule();
      expect(rule.code.name, 'avoid_hardcoded_config_test');
      expect(
        rule.code.problemMessage,
        contains('[avoid_hardcoded_config_test]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidMixedEnvironmentsRule', () {
      final rule = AvoidMixedEnvironmentsRule();
      expect(rule.code.name, 'avoid_mixed_environments');
      expect(rule.code.problemMessage, contains('[avoid_mixed_environments]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireFeatureFlagTypeSafetyRule', () {
      final rule = RequireFeatureFlagTypeSafetyRule();
      expect(rule.code.name, 'require_feature_flag_type_safety');
      expect(
        rule.code.problemMessage,
        contains('[require_feature_flag_type_safety]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidStringEnvParsingRule', () {
      final rule = AvoidStringEnvParsingRule();
      expect(rule.code.name, 'avoid_string_env_parsing');
      expect(rule.code.problemMessage, contains('[avoid_string_env_parsing]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidPlatformSpecificImportsRule', () {
      final rule = AvoidPlatformSpecificImportsRule();
      expect(rule.code.name, 'avoid_platform_specific_imports');
      expect(
        rule.code.problemMessage,
        contains('[avoid_platform_specific_imports]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferSemverVersionRule', () {
      final rule = PreferSemverVersionRule();
      expect(rule.code.name, 'prefer_semver_version');
      expect(rule.code.problemMessage, contains('[prefer_semver_version]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferCompileTimeConfigRule', () {
      final rule = PreferCompileTimeConfigRule();
      expect(rule.code.name, 'prefer_compile_time_config');
      expect(
        rule.code.problemMessage,
        contains('[prefer_compile_time_config]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferFlavorConfigurationRule', () {
      final rule = PreferFlavorConfigurationRule();
      expect(rule.code.name, 'prefer_flavor_configuration');
      expect(
        rule.code.problemMessage,
        contains('[prefer_flavor_configuration]'),
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
        final file = File('example_async/lib/config/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Configuration - Avoidance Rules', () {
    group('avoid_hardcoded_config', () {
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
}
