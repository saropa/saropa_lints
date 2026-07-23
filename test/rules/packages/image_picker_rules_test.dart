import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/image_picker_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 5 image_picker lint rules (new coverage only).
///
/// The repo already ships rules for null/result handling, unbounded images,
/// and source choice; these 5 cover the remaining gaps.
///
/// Test fixtures: example_packages/lib/image_picker/*
void main() {
  group('ImagePicker Rules - Rule Instantiation', () {
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
      'ImagePickerMissingRetrieveLostDataRule',
      'image_picker_missing_retrieve_lost_data',
      () => ImagePickerMissingRetrieveLostDataRule(),
    );
    testRule(
      'ImagePickerInvalidImageQualityRule',
      'image_picker_invalid_image_quality',
      () => ImagePickerInvalidImageQualityRule(),
    );
    testRule(
      'ImagePickerCameraSourceWithoutSupportCheckRule',
      'image_picker_camera_source_without_support_check',
      () => ImagePickerCameraSourceWithoutSupportCheckRule(),
    );
    testRule(
      'ImagePickerLostDataEmptyCheckMissingRule',
      'image_picker_lost_data_empty_check_missing',
      () => ImagePickerLostDataEmptyCheckMissingRule(),
    );
    testRule(
      'ImagePickerMultiResultUncheckedEmptyRule',
      'image_picker_multi_result_unchecked_empty',
      () => ImagePickerMultiResultUncheckedEmptyRule(),
    );
  });

  group('ImagePicker Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/image_picker');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/image_picker/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
