import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/geocoding_rules.dart';

/// Tests for 8 geocoding lint rules.
///
/// Test fixtures: example_packages/lib/geocoding/*
void main() {
  group('Geocoding Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'GeocodingUncheckedFirstRule',
      'geocoding_unchecked_first',
      () => GeocodingUncheckedFirstRule(),
    );
    testRule(
      'GeocodingMissingExceptionHandlerRule',
      'geocoding_missing_exception_handler',
      () => GeocodingMissingExceptionHandlerRule(),
    );
    testRule(
      'GeocodingPreferNoResultFoundCatchRule',
      'geocoding_prefer_no_result_found_catch',
      () => GeocodingPreferNoResultFoundCatchRule(),
    );
    testRule(
      'GeocodingLocaleSetBeforeCallRule',
      'geocoding_locale_set_before_call',
      () => GeocodingLocaleSetBeforeCallRule(),
    );
    testRule(
      'GeocodingConcurrentLocaleRaceRule',
      'geocoding_concurrent_locale_race',
      () => GeocodingConcurrentLocaleRaceRule(),
    );
    testRule(
      'GeocodingMissingIsPresentCheckRule',
      'geocoding_missing_is_present_check',
      () => GeocodingMissingIsPresentCheckRule(),
    );
    testRule(
      'GeocodingCallInTextFieldListenerRule',
      'geocoding_call_in_text_field_listener',
      () => GeocodingCallInTextFieldListenerRule(),
    );
    testRule(
      'GeocodingDeprecatedLocaleParamRule',
      'geocoding_deprecated_locale_param',
      () => GeocodingDeprecatedLocaleParamRule(),
    );
  });

  group('Geocoding Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/geocoding');

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
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/geocoding/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
