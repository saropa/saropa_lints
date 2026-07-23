import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/data/json_datetime_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 13 Json Datetime lint rules.
///
/// Test fixtures: example/lib/json_datetime/*
void main() {
  group('Json Datetime Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'RequireJsonDecodeTryCatchRule',
      'require_json_decode_try_catch',
      () => RequireJsonDecodeTryCatchRule(),
    );

    testRule(
      'AvoidDateTimeParseUnvalidatedRule',
      'avoid_datetime_parse_unvalidated',
      () => AvoidDateTimeParseUnvalidatedRule(),
    );

    testRule(
      'PreferTryParseForDynamicDataRule',
      'prefer_try_parse_for_dynamic_data',
      () => PreferTryParseForDynamicDataRule(),
    );

    testRule(
      'PreferDurationConstantsRule',
      'prefer_duration_constants',
      () => PreferDurationConstantsRule(),
    );

    testRule(
      'AvoidDatetimeNowInTestsRule',
      'avoid_datetime_now_in_tests',
      () => AvoidDatetimeNowInTestsRule(),
    );

    testRule(
      'AvoidNotEncodableInToJsonRule',
      'avoid_not_encodable_in_to_json',
      () => AvoidNotEncodableInToJsonRule(),
    );

    testRule(
      'RequireDateFormatSpecificationRule',
      'require_date_format_specification',
      () => RequireDateFormatSpecificationRule(),
    );

    testRule(
      'PreferIso8601DatesRule',
      'prefer_iso8601_dates',
      () => PreferIso8601DatesRule(),
    );

    testRule(
      'AvoidOptionalFieldCrashRule',
      'avoid_optional_field_crash',
      () => AvoidOptionalFieldCrashRule(),
    );

    testRule(
      'PreferExplicitJsonKeysRule',
      'prefer_explicit_json_keys',
      () => PreferExplicitJsonKeysRule(),
    );

    testRule(
      'RequireJsonSchemaValidationRule',
      'require_json_schema_validation',
      () => RequireJsonSchemaValidationRule(),
    );

    testRule(
      'PreferJsonSerializableRule',
      'prefer_json_serializable',
      () => PreferJsonSerializableRule(),
    );

    testRule(
      'RequireTimezoneDisplayRule',
      'require_timezone_display',
      () => RequireTimezoneDisplayRule(),
    );
  });

  group('Json Datetime Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/json_datetime');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/json_datetime/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
