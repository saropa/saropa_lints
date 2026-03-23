import 'package:saropa_lints/src/rules/config/flutter_test_window_deprecation_utils.dart';
import 'package:test/test.dart';

/// Unit tests for [isFlutterTestPackageUri] (package boundary for
/// `avoid_deprecated_flutter_test_window`). Element-level predicates require
/// a resolved `package:flutter_test` SDK and are covered by the rule's
/// element-resolution design doc and integration analysis in Flutter apps.
void main() {
  group('isFlutterTestPackageUri', () {
    test('true for package:flutter_test root and src paths', () {
      expect(
        isFlutterTestPackageUri(
          Uri.parse('package:flutter_test/flutter_test.dart'),
        ),
        isTrue,
      );
      expect(
        isFlutterTestPackageUri(
          Uri.parse('package:flutter_test/src/window.dart'),
        ),
        isTrue,
      );
    });

    test('false for package:flutter and dart:', () {
      expect(
        isFlutterTestPackageUri(Uri.parse('package:flutter/widgets.dart')),
        isFalse,
      );
      expect(isFlutterTestPackageUri(Uri.parse('dart:ui')), isFalse);
      expect(isFlutterTestPackageUri(Uri.parse('dart:core')), isFalse);
    });

    test('false for null and non-package schemes', () {
      expect(isFlutterTestPackageUri(null), isFalse);
      expect(isFlutterTestPackageUri(Uri.parse('file:///x.dart')), isFalse);
      expect(isFlutterTestPackageUri(Uri.parse('https://x/y')), isFalse);
    });

    test('false for package name that only starts with flutter_test', () {
      expect(
        isFlutterTestPackageUri(
          Uri.parse('package:flutter_test_extra/foo.dart'),
        ),
        isFalse,
      );
    });
  });

  group('isFlutterTestSdkTestWindowElement (null / unresolved)', () {
    test('null element is not SDK TestWindow', () {
      expect(isFlutterTestSdkTestWindowElement(null), isFalse);
    });
  });

  group(
    'isFlutterTestSdkTestWidgetsFlutterBindingWindowGetter (null / unresolved)',
    () {
      test('null element is not binding window getter', () {
        expect(
          isFlutterTestSdkTestWidgetsFlutterBindingWindowGetter(null),
          isFalse,
        );
      });
    },
  );
}
