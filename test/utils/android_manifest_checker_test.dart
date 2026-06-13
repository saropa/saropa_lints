// Unit tests for AndroidManifestChecker:
//  - hasPermission must match a whole permission name, not a prefix substring
//    (READ_CONTACTS must not match READ_CONTACTS_EXTENDED).
//  - the per-project cache must invalidate when the manifest file changes
//    (a long-lived analysis-server session previously returned stale results).
library;

import 'dart:io';

import 'package:saropa_lints/src/android_manifest_utils.dart';
import 'package:test/test.dart';

void main() {
  group('AndroidManifestChecker', () {
    late Directory root;
    late File manifest;
    late String probeFile;

    void writeManifest(List<String> permissions) {
      final entries = permissions
          .map(
            (p) => '    <uses-permission android:name="android.permission.$p" />',
          )
          .join('\n');
      manifest.writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
$entries
    <application android:label="app" />
</manifest>
''');
    }

    setUp(() {
      AndroidManifestChecker.clearCache();
      root = Directory.systemTemp.createTempSync('saropa_manifest_test_');
      File('${root.path}/pubspec.yaml').writeAsStringSync('name: t\n');
      final manifestDir = Directory('${root.path}/android/app/src/main')
        ..createSync(recursive: true);
      manifest = File('${manifestDir.path}/AndroidManifest.xml');
      // A source file inside the project so _findProjectRoot walks up to root.
      final libDir = Directory('${root.path}/lib')..createSync();
      probeFile = '${libDir.path}/main.dart';
      File(probeFile).writeAsStringSync('void main() {}\n');
    });

    tearDown(() {
      AndroidManifestChecker.clearCache();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('hasPermission does not match a longer permission sharing the prefix', () {
      writeManifest(['READ_CONTACTS_EXTENDED']);
      final checker = AndroidManifestChecker.forFile(probeFile)!;
      expect(checker.hasPermission('READ_CONTACTS'), isFalse);
      expect(checker.hasPermission('READ_CONTACTS_EXTENDED'), isTrue);
    });

    test('hasPermission matches an exact permission', () {
      writeManifest(['CAMERA', 'INTERNET']);
      final checker = AndroidManifestChecker.forFile(probeFile)!;
      expect(checker.hasPermission('CAMERA'), isTrue);
      expect(checker.hasPermission('INTERNET'), isTrue);
      expect(checker.hasPermission('ACCESS_FINE_LOCATION'), isFalse);
    });

    test('cache invalidates when the manifest changes', () {
      writeManifest(['INTERNET']);
      final first = AndroidManifestChecker.forFile(probeFile)!;
      expect(first.hasPermission('CAMERA'), isFalse);

      // Add a permission (changes file size, so invalidation triggers even if
      // the mtime granularity is coarse).
      writeManifest(['INTERNET', 'CAMERA']);
      final second = AndroidManifestChecker.forFile(probeFile)!;
      expect(
        second.hasPermission('CAMERA'),
        isTrue,
        reason: 'manifest edit must be picked up, not served stale from cache',
      );
    });
  });
}
