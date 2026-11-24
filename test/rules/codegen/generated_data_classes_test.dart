import 'dart:io';

import 'package:saropa_lints/src/rules/codegen/generated_data_class_rules.dart';
import 'package:test/test.dart';

/// Tests for prefer_generated_data_classes (issue #415).
///
/// Behavior (fires on hand-written toJson/fromJson/==+hashCode only when a
/// generator is a dependency; silent for annotated / generated-mixin /
/// abstract / toString-only classes) was verified with the scan CLI against
/// the fixture; the example_packages project has no generator dependency so
/// the rule cannot fire there by design.
void main() {
  group('Generated data classes - Rule Instantiation', () {
    test('PreferGeneratedDataClassesRule', () {
      final rule = PreferGeneratedDataClassesRule();
      expect(rule.code.lowerCaseName, 'prefer_generated_data_classes');
      expect(
        rule.code.problemMessage,
        contains('[prefer_generated_data_classes]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('prefer_generated_data_classes fixture', () {
    final fixture = File(
      'example_packages/lib/freezed/prefer_generated_data_classes_fixture.dart',
    );

    test('fixture exists', () => expect(fixture.existsSync(), isTrue));

    test('marks both BAD classes and leaves GOOD near-misses unmarked', () {
      final text = fixture.readAsStringSync();
      expect(
        RegExp('expect_lint: prefer_generated_data_classes').allMatches(text),
        hasLength(2),
      );
      expect(text, contains('class Good415Logger'));
      expect(text, contains('abstract class Good415Contract'));
    });
  });
}
