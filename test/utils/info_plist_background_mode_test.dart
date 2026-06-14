// Regression tests for InfoPlistChecker background-mode detection. The two
// checks previously tested `<key>UIBackgroundModes</key>` and `>audio</string>`
// as independent substrings of the whole plist, so a plist that declared
// background `location` only — but contained an unrelated `<string>audio</string>`
// elsewhere — wrongly reported audio as configured. The fix inspects membership
// within the UIBackgroundModes array.
library;

import 'dart:io';

import 'package:saropa_lints/src/info_plist_utils.dart';
import 'package:test/test.dart';

void main() {
  group('InfoPlistChecker background modes', () {
    late Directory tempDir;
    late String projectRoot;
    late String dartPath;

    void writePlist(String body) {
      File('$projectRoot/ios/Runner/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
$body
</dict>
</plist>
''');
    }

    setUp(() {
      InfoPlistChecker.clearCache();
      tempDir = Directory.systemTemp.createTempSync('info_plist_bgmode_');
      projectRoot = tempDir.path;
      File('$projectRoot/pubspec.yaml').writeAsStringSync('name: test_app\n');
      Directory('$projectRoot/ios/Runner').createSync(recursive: true);
      Directory('$projectRoot/lib').createSync(recursive: true);
      dartPath = '$projectRoot/lib/main.dart';
      File(dartPath).writeAsStringSync('// stub');
    });

    tearDown(() {
      InfoPlistChecker.clearCache();
      tempDir.deleteSync(recursive: true);
    });

    test(
      'location-only modes with an unrelated audio string is NOT audio-configured',
      () {
        // The UIBackgroundModes array has only `location`; the `audio` string
        // belongs to an unrelated key (the old code matched it as a substring).
        writePlist('''
  <key>UIBackgroundModes</key>
  <array>
    <string>location</string>
  </array>
  <key>SomeOtherSetting</key>
  <string>audio</string>
''');
        final checker = InfoPlistChecker.forFile(dartPath)!;
        expect(checker.hasIosBackgroundLocationConfigured, isTrue);
        expect(checker.hasIosBackgroundAudioConfigured, isFalse);
      },
    );

    test('audio in the UIBackgroundModes array is audio-configured', () {
      writePlist('''
  <key>UIBackgroundModes</key>
  <array>
    <string>audio</string>
    <string>location</string>
  </array>
''');
      final checker = InfoPlistChecker.forFile(dartPath)!;
      expect(checker.hasIosBackgroundAudioConfigured, isTrue);
      expect(checker.hasIosBackgroundLocationConfigured, isTrue);
    });

    test('no UIBackgroundModes key means not configured', () {
      writePlist('''
  <key>CFBundleName</key>
  <string>app</string>
''');
      final checker = InfoPlistChecker.forFile(dartPath)!;
      expect(checker.hasIosBackgroundAudioConfigured, isFalse);
      expect(checker.hasIosBackgroundLocationConfigured, isFalse);
    });
  });
}
