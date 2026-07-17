import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/file_picker_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 6 always-on file_picker lint rules.
///
/// Test fixtures: example_packages/lib/file_picker/*
void main() {
  group('FilePicker Rules - Rule Instantiation', () {
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
      'FilePickerUncheckedNullResultRule',
      'file_picker_unchecked_null_result',
      () => FilePickerUncheckedNullResultRule(),
    );
    testRule(
      'FilePickerPathOnWebRule',
      'file_picker_path_on_web',
      () => FilePickerPathOnWebRule(),
    );
    testRule(
      'FilePickerCustomTypeMissingExtensionsRule',
      'file_picker_custom_type_missing_extensions',
      () => FilePickerCustomTypeMissingExtensionsRule(),
    );
    testRule(
      'FilePickerExtensionsWithoutCustomTypeRule',
      'file_picker_extensions_without_custom_type',
      () => FilePickerExtensionsWithoutCustomTypeRule(),
    );
    testRule(
      'FilePickerExtensionWithDotRule',
      'file_picker_extension_with_dot',
      () => FilePickerExtensionWithDotRule(),
    );
    testRule(
      'FilePickerWithDataLargeFilesRule',
      'file_picker_with_data_large_files',
      () => FilePickerWithDataLargeFilesRule(),
    );

    // ── version-gated deprecation rules (file_picker_10 / file_picker_12 packs) ──

    testRule(
      'FilePickerDeprecatedWithDataRule',
      'file_picker_deprecated_with_data',
      () => FilePickerDeprecatedWithDataRule(),
    );
    testRule(
      'FilePickerDeprecatedWithReadStreamRule',
      'file_picker_deprecated_with_read_stream',
      () => FilePickerDeprecatedWithReadStreamRule(),
    );
    testRule(
      'FilePickerDeprecatedAllowMultipleRule',
      'file_picker_deprecated_allow_multiple',
      () => FilePickerDeprecatedAllowMultipleRule(),
    );
    testRule(
      'FilePickerDeprecatedAllowCompressionRule',
      'file_picker_deprecated_allow_compression',
      () => FilePickerDeprecatedAllowCompressionRule(),
    );
  });

  group('FilePicker Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/file_picker');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/file_picker/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
