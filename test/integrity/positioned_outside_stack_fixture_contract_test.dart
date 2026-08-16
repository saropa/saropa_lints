import 'dart:io';

import 'package:test/test.dart';

/// Contract: the `avoid_positioned_outside_stack` fixture declares at least one
/// BAD case (`// expect_lint:`) AND contains a custom-widget false-positive
/// guard — a user-defined widget class (not from flutter_mocks.dart) that
/// accepts a `List<Widget>` parameter, so the rule's `_isCustomFlutterWidget`
/// indeterminate path is exercised.
///
/// The resolved-rule harness cannot test this rule because the example package
/// does not depend on Flutter, so `Widget`/`StatelessWidget` resolve to
/// `InvalidType` and the type-based checks degrade. This contract test is the
/// next-best coverage: it proves the fixture is structurally complete.
void main() {
  const fixturePath =
      'example/lib/widget_layout/avoid_positioned_outside_stack_fixture.dart';

  test('fixture exists', () {
    expect(File(fixturePath).existsSync(), isTrue);
  });

  test('fixture declares expect_lint for the rule', () {
    final body = File(fixturePath).readAsStringSync();
    final pattern = RegExp(
      r'//\s*expect_lint:\s*avoid_positioned_outside_stack\b',
    );
    expect(
      pattern.hasMatch(body),
      isTrue,
      reason:
          'Fixture must declare // expect_lint: avoid_positioned_outside_stack',
    );
  });

  test('fixture defines a custom widget for the FP guard', () {
    // The fixture must define its own StatelessWidget subclass (not imported
    // from flutter_mocks.dart) so the rule's _isCustomFlutterWidget correctly
    // classifies it as a user widget and returns indeterminate.
    final body = File(fixturePath).readAsStringSync();
    expect(
      body.contains('extends StatelessWidget'),
      isTrue,
      reason:
          'Fixture must define a custom widget class for the false-positive guard',
    );
    // The custom widget must accept a List<Widget> parameter (the spread
    // pattern that triggered the original false positive).
    expect(
      body.contains('List<Widget>'),
      isTrue,
      reason:
          'Custom widget must accept List<Widget> for the backgroundLayers pattern',
    );
  });

  test('fixture contains GOOD cases that must not lint', () {
    // At minimum: direct Stack child, custom-widget parameter, helper method.
    final body = File(fixturePath).readAsStringSync();
    expect(
      body.contains('Stack('),
      isTrue,
      reason: 'Fixture must include a direct Stack parent GOOD case',
    );
    expect(
      body.contains('IndexedStack('),
      isTrue,
      reason: 'Fixture must include an IndexedStack GOOD case',
    );
  });
}
