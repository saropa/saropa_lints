import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/ui/internationalization_rules.dart';

/// Tests for 26 Internationalization lint rules.
///
/// Test fixtures: example/lib/internationalization/*
// intl, ARB, and plural/gender rules with small example messages.
void main() {
  group('Internationalization Rules - Rule Instantiation', () {
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
      'AvoidHardcodedStringsInUiRule',
      'avoid_hardcoded_strings_in_ui',
      () => AvoidHardcodedStringsInUiRule(),
    );

    testRule(
      'RequireLocaleAwareFormattingRule',
      'require_locale_aware_formatting',
      () => RequireLocaleAwareFormattingRule(),
    );

    testRule(
      'RequireDirectionalWidgetsRule',
      'require_directional_widgets',
      () => RequireDirectionalWidgetsRule(),
    );

    testRule(
      'RequirePluralHandlingRule',
      'require_plural_handling',
      () => RequirePluralHandlingRule(),
    );

    testRule(
      'AvoidHardcodedLocaleRule',
      'avoid_hardcoded_locale',
      () => AvoidHardcodedLocaleRule(),
    );

    testRule(
      'AvoidStringConcatenationInUiRule',
      'avoid_string_concatenation_in_ui',
      () => AvoidStringConcatenationInUiRule(),
    );

    testRule(
      'AvoidTextInImagesRule',
      'avoid_text_in_images',
      () => AvoidTextInImagesRule(),
    );

    testRule(
      'AvoidHardcodedAppNameRule',
      'avoid_hardcoded_app_name',
      () => AvoidHardcodedAppNameRule(),
    );

    testRule(
      'PreferDateFormatRule',
      'prefer_date_format',
      () => PreferDateFormatRule(),
    );

    testRule(
      'PreferIntlNameRule',
      'prefer_intl_name',
      () => PreferIntlNameRule(),
    );

    testRule(
      'PreferProvidingIntlDescriptionRule',
      'prefer_providing_intl_description',
      () => PreferProvidingIntlDescriptionRule(),
    );

    testRule(
      'PreferProvidingIntlExamplesRule',
      'prefer_providing_intl_examples',
      () => PreferProvidingIntlExamplesRule(),
    );

    testRule(
      'RequireIntlLocaleInitializationRule',
      'require_intl_locale_initialization',
      () => RequireIntlLocaleInitializationRule(),
    );

    testRule(
      'RequireIntlDateFormatLocaleRule',
      'require_intl_date_format_locale',
      () => RequireIntlDateFormatLocaleRule(),
    );

    testRule(
      'RequireNumberFormatLocaleRule',
      'require_number_format_locale',
      () => RequireNumberFormatLocaleRule(),
    );

    testRule(
      'AvoidManualDateFormattingRule',
      'avoid_manual_date_formatting',
      () => AvoidManualDateFormattingRule(),
    );

    testRule(
      'RequireIntlCurrencyFormatRule',
      'require_intl_currency_format',
      () => RequireIntlCurrencyFormatRule(),
    );

    testRule(
      'RequireIntlPluralRulesRule',
      'require_intl_plural_rules',
      () => RequireIntlPluralRulesRule(),
    );

    testRule(
      'RequireIntlArgsMatchRule',
      'require_intl_args_match',
      () => RequireIntlArgsMatchRule(),
    );

    testRule(
      'AvoidStringConcatenationForL10nRule',
      'avoid_string_concatenation_for_l10n',
      () => AvoidStringConcatenationForL10nRule(),
    );

    testRule(
      'PreferNumberFormatRule',
      'prefer_number_format',
      () => PreferNumberFormatRule(),
    );

    testRule(
      'ProvideCorrectIntlArgsRule',
      'provide_correct_intl_args',
      () => ProvideCorrectIntlArgsRule(),
    );

    testRule(
      'AvoidStringConcatenationL10nRule',
      'avoid_string_concatenation_l10n',
      () => AvoidStringConcatenationL10nRule(),
    );

    testRule(
      'PreferIntlMessageDescriptionRule',
      'prefer_intl_message_description',
      () => PreferIntlMessageDescriptionRule(),
    );

    testRule(
      'AvoidHardcodedLocaleStringsRule',
      'avoid_hardcoded_locale_strings',
      () => AvoidHardcodedLocaleStringsRule(),
    );

    testRule(
      'RequireRtlLayoutSupportRule',
      'require_rtl_layout_support',
      () => RequireRtlLayoutSupportRule(),
    );
  });

  group('Internationalization Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_hardcoded_strings_in_ui',
      'require_locale_aware_formatting',
      'require_directional_widgets',
      'require_plural_handling',
      'avoid_hardcoded_locale',
      'avoid_string_concatenation_in_ui',
      'avoid_text_in_images',
      'avoid_hardcoded_app_name',
      'prefer_date_format',
      'prefer_intl_name',
      'prefer_providing_intl_description',
      'prefer_providing_intl_examples',
      'require_intl_locale_initialization',
      'require_intl_date_format_locale',
      'require_number_format_locale',
      'avoid_manual_date_formatting',
      'require_intl_currency_format',
      'require_intl_plural_rules',
      'require_intl_args_match',
      'avoid_string_concatenation_for_l10n',
      'prefer_number_format',
      'provide_correct_intl_args',
      'avoid_string_concatenation_l10n',
      'prefer_intl_message_description',
      'avoid_hardcoded_locale_strings',
      'require_rtl_layout_support',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/internationalization/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
