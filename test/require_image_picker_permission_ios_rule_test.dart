import 'dart:io';

import 'package:saropa_lints/src/info_plist_utils.dart';
import 'package:saropa_lints/src/rules/widget/widget_patterns_require_rules.dart';
import 'package:test/test.dart';

/// Behavioral contract for [RequireImagePickerPermissionIosRule] plist gating.
///
/// The rule reports only when [InfoPlistChecker.getMissingKeys] lists
/// `NSCameraUsageDescription` for the analyzed file’s project — exercised
/// here with the same temp layout the checker uses in production.
void main() {
  group('RequireImagePickerPermissionIosRule', () {
    test('rule metadata', () {
      final rule = RequireImagePickerPermissionIosRule();
      expect(rule.code.lowerCaseName, 'require_image_picker_permission_ios');
      expect(rule.code.problemMessage, contains('{v5}'));
    });

    group('plist gate (matches rule preconditions)', () {
      late Directory tempDir;
      late String projectRoot;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'require_image_picker_ios_',
        );
        projectRoot = tempDir.path;
        File('$projectRoot/pubspec.yaml').writeAsStringSync('name: test_app\n');
        Directory('$projectRoot/ios/Runner').createSync(recursive: true);
        Directory('$projectRoot/lib').createSync(recursive: true);
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
        InfoPlistChecker.clearCache();
      });

      test('no Info.plist means no missing keys (rule stays silent)', () {
        final dartPath = '$projectRoot/lib/camera.dart';
        File(dartPath).writeAsStringSync('// stub');

        final checker = InfoPlistChecker.forFile(dartPath);
        expect(checker, isNotNull);
        expect(checker!.getMissingKeys(['NSCameraUsageDescription']), isEmpty);
      });

      test('plist with NSCameraUsageDescription means no missing keys', () {
        File('$projectRoot/ios/Runner/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>NSCameraUsageDescription</key>
  <string>Camera</string>
</dict>
</plist>
''');
        final dartPath = '$projectRoot/lib/camera.dart';
        File(dartPath).writeAsStringSync('// stub');

        final checker = InfoPlistChecker.forFile(dartPath);
        expect(checker!.getMissingKeys(['NSCameraUsageDescription']), isEmpty);
      });

      test('plist without NSCameraUsageDescription lists missing key', () {
        File('$projectRoot/ios/Runner/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.example</string>
</dict>
</plist>
''');
        final dartPath = '$projectRoot/lib/camera.dart';
        File(dartPath).writeAsStringSync('// stub');

        final checker = InfoPlistChecker.forFile(dartPath);
        expect(checker!.getMissingKeys(['NSCameraUsageDescription']), [
          'NSCameraUsageDescription',
        ]);
      });
    });
  });
}
