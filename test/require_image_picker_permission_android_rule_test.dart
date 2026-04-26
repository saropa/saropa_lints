import 'dart:io';

import 'package:saropa_lints/src/android_manifest_utils.dart';
import 'package:saropa_lints/src/rules/widget/widget_patterns_require_rules.dart';
import 'package:test/test.dart';

/// Behavioral contract for [RequireImagePickerPermissionAndroidRule] manifest
/// gating and [AndroidManifestChecker].
void main() {
  group('RequireImagePickerPermissionAndroidRule', () {
    test('rule metadata', () {
      final rule = RequireImagePickerPermissionAndroidRule();
      expect(
        rule.code.lowerCaseName,
        'require_image_picker_permission_android',
      );
      expect(rule.code.problemMessage, contains('{v4}'));
    });

    group('manifest gate (matches rule preconditions)', () {
      late Directory tempDir;
      late String projectRoot;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'require_image_picker_android_',
        );
        projectRoot = tempDir.path;
        File('$projectRoot/pubspec.yaml').writeAsStringSync('name: test_app\n');
        Directory('$projectRoot/lib').createSync(recursive: true);
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
        AndroidManifestChecker.clearCache();
      });

      test('no AndroidManifest.xml means hasManifest is false', () {
        final dartPath = '$projectRoot/lib/camera.dart';
        File(dartPath).writeAsStringSync('// stub');

        final checker = AndroidManifestChecker.forFile(dartPath);
        expect(checker, isNotNull);
        expect(checker!.hasManifest, isFalse);
      });

      test('manifest without CAMERA permission', () {
        Directory(
          '$projectRoot/android/app/src/main',
        ).createSync(recursive: true);
        File(
          '$projectRoot/android/app/src/main/AndroidManifest.xml',
        ).writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <application android:label="t" />
</manifest>
''');
        final dartPath = '$projectRoot/lib/camera.dart';
        File(dartPath).writeAsStringSync('// stub');

        final checker = AndroidManifestChecker.forFile(dartPath);
        expect(checker!.hasManifest, isTrue);
        expect(checker.hasPermission('CAMERA'), isFalse);
      });

      test('manifest with CAMERA permission', () {
        Directory(
          '$projectRoot/android/app/src/main',
        ).createSync(recursive: true);
        File(
          '$projectRoot/android/app/src/main/AndroidManifest.xml',
        ).writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <application android:label="t" />
</manifest>
''');
        final dartPath = '$projectRoot/lib/camera.dart';
        File(dartPath).writeAsStringSync('// stub');

        final checker = AndroidManifestChecker.forFile(dartPath);
        expect(checker!.hasManifest, isTrue);
        expect(checker.hasPermission('CAMERA'), isTrue);
      });
    });
  });
}
