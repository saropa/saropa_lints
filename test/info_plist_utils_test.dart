import 'dart:io';

import 'package:saropa_lints/src/info_plist_utils.dart';
import 'package:test/test.dart';

void main() {
  group('InfoPlistChecker', () {
    late Directory tempDir;
    late String projectRoot;

    setUp(() {
      // Create a temporary project structure for testing.
      tempDir = Directory.systemTemp.createTempSync('info_plist_test_');
      projectRoot = tempDir.path;

      // Create pubspec.yaml to mark project root.
      File('$projectRoot/pubspec.yaml').writeAsStringSync('name: test_app\n');

      // Create ios/Runner directory structure.
      Directory('$projectRoot/ios/Runner').createSync(recursive: true);

      // Create lib directory for test files.
      Directory('$projectRoot/lib').createSync(recursive: true);
    });

    tearDown(() {
      // Clean up temp directory.
      tempDir.deleteSync(recursive: true);

      // Clear the cache between tests.
      InfoPlistChecker.clearCache();
    });

    test('returns null when no pubspec.yaml exists', () {
      final checker = InfoPlistChecker.forFile('/nonexistent/path/file.dart');
      expect(checker, isNull);
    });

    test('hasInfoPlist returns false when Info.plist does not exist', () {
      final testFile = '$projectRoot/lib/test.dart';
      File(testFile).writeAsStringSync('// test file');

      final checker = InfoPlistChecker.forFile(testFile);
      expect(checker, isNotNull);
      expect(checker!.hasInfoPlist, isFalse);
    });

    test('hasInfoPlist returns true when Info.plist exists', () {
      // Create Info.plist.
      final plistPath = '$projectRoot/ios/Runner/Info.plist';
      File(plistPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>NSCameraUsageDescription</key>
  <string>We need camera access</string>
</dict>
</plist>
''');

      final testFile = '$projectRoot/lib/test.dart';
      File(testFile).writeAsStringSync('// test file');

      final checker = InfoPlistChecker.forFile(testFile);
      expect(checker, isNotNull);
      expect(checker!.hasInfoPlist, isTrue);
    });

    test('hasKey returns true when key exists in Info.plist', () {
      final plistPath = '$projectRoot/ios/Runner/Info.plist';
      File(plistPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>NSCameraUsageDescription</key>
  <string>We need camera access</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>We need microphone access</string>
</dict>
</plist>
''');

      final testFile = '$projectRoot/lib/test.dart';
      File(testFile).writeAsStringSync('// test file');

      final checker = InfoPlistChecker.forFile(testFile);
      expect(checker!.hasKey('NSCameraUsageDescription'), isTrue);
      expect(checker.hasKey('NSMicrophoneUsageDescription'), isTrue);
    });

    test('hasKey returns false when key is missing from Info.plist', () {
      final plistPath = '$projectRoot/ios/Runner/Info.plist';
      File(plistPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>NSCameraUsageDescription</key>
  <string>We need camera access</string>
</dict>
</plist>
''');

      final testFile = '$projectRoot/lib/test.dart';
      File(testFile).writeAsStringSync('// test file');

      final checker = InfoPlistChecker.forFile(testFile);
      expect(checker!.hasKey('NSCameraUsageDescription'), isTrue);
      expect(checker.hasKey('NSMicrophoneUsageDescription'), isFalse);
    });

    test('hasKey returns true when Info.plist does not exist (cannot verify)',
        () {
      // When Info.plist doesn't exist, we can't verify, so we assume OK.
      final testFile = '$projectRoot/lib/test.dart';
      File(testFile).writeAsStringSync('// test file');

      final checker = InfoPlistChecker.forFile(testFile);
      expect(checker!.hasInfoPlist, isFalse);
      // Should return true because we can't verify.
      expect(checker.hasKey('NSCameraUsageDescription'), isTrue);
    });

    test('getMissingKeys returns empty list when all keys present', () {
      final plistPath = '$projectRoot/ios/Runner/Info.plist';
      File(plistPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>NSCameraUsageDescription</key>
  <string>Camera</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Microphone</string>
</dict>
</plist>
''');

      final testFile = '$projectRoot/lib/test.dart';
      File(testFile).writeAsStringSync('// test file');

      final checker = InfoPlistChecker.forFile(testFile);
      final missing = checker!.getMissingKeys([
        'NSCameraUsageDescription',
        'NSMicrophoneUsageDescription',
      ]);
      expect(missing, isEmpty);
    });

    test('getMissingKeys returns list of missing keys', () {
      final plistPath = '$projectRoot/ios/Runner/Info.plist';
      File(plistPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>NSCameraUsageDescription</key>
  <string>Camera</string>
</dict>
</plist>
''');

      final testFile = '$projectRoot/lib/test.dart';
      File(testFile).writeAsStringSync('// test file');

      final checker = InfoPlistChecker.forFile(testFile);
      final missing = checker!.getMissingKeys([
        'NSCameraUsageDescription',
        'NSMicrophoneUsageDescription',
        'NSSpeechRecognitionUsageDescription',
      ]);
      expect(missing, hasLength(2));
      expect(missing, contains('NSMicrophoneUsageDescription'));
      expect(missing, contains('NSSpeechRecognitionUsageDescription'));
    });

    test('caches results per project', () {
      final plistPath = '$projectRoot/ios/Runner/Info.plist';
      File(plistPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>NSCameraUsageDescription</key>
  <string>Camera</string>
</dict>
</plist>
''');

      final testFile1 = '$projectRoot/lib/test1.dart';
      final testFile2 = '$projectRoot/lib/test2.dart';
      File(testFile1).writeAsStringSync('// test file 1');
      File(testFile2).writeAsStringSync('// test file 2');

      final checker1 = InfoPlistChecker.forFile(testFile1);
      final checker2 = InfoPlistChecker.forFile(testFile2);

      // Should return the same cached instance.
      expect(identical(checker1, checker2), isTrue);
    });
  });

  group('IosPermissionMapping', () {
    test('getRequiredKeys returns correct keys for SpeechToText', () {
      final keys = IosPermissionMapping.getRequiredKeys('SpeechToText');
      expect(keys, isNotNull);
      expect(keys, contains('NSSpeechRecognitionUsageDescription'));
      expect(keys, contains('NSMicrophoneUsageDescription'));
    });

    test(
        'getRequiredKeys returns null for ImagePicker (handled by smart detection)',
        () {
      // ImagePicker is intentionally NOT in typeToKeys because the rule uses
      // smart method-level detection to check the actual ImageSource
      // (gallery vs camera) and only require the relevant permission.
      final keys = IosPermissionMapping.getRequiredKeys('ImagePicker');
      expect(keys, isNull);
    });

    test('getRequiredKeys returns null for unknown type', () {
      final keys = IosPermissionMapping.getRequiredKeys('UnknownType');
      expect(keys, isNull);
    });

    test('getRequiredKeysDescription returns formatted string', () {
      final desc =
          IosPermissionMapping.getRequiredKeysDescription('SpeechToText');
      expect(desc, contains('NSSpeechRecognitionUsageDescription'));
      expect(desc, contains('+'));
      expect(desc, contains('NSMicrophoneUsageDescription'));
    });
  });
}
