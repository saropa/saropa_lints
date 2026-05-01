import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for [ProjectContext.flutterSdkAtLeast]. Creates a temporary project
/// root with a synthetic `pubspec.yaml`, then asks the SDK-gate helper
/// whether the project satisfies a required `major.minor.patch`.
///
/// Each test uses a fresh temp directory so the `_projectCache` entry keyed
/// on the project root does not leak between cases. `ProjectContext.clearCache()`
/// runs in `setUp` to flush any prior entries for good measure.
void main() {
  group('ProjectContext.flutterSdkAtLeast', () {
    late Directory tempRoot;

    setUp(() {
      ProjectContext.clearCache();
      tempRoot = Directory.systemTemp.createTempSync('saropa_sdk_gate_');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    /// Writes `pubspec.yaml` at the temp project root and returns a path to
    /// a synthetic Dart file inside `lib/` — the argument shape the gate
    /// expects (rules always call with the current compilation unit's path).
    String writePubspec(String body) {
      File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsStringSync(body);
      final libDir = Directory(p.join(tempRoot.path, 'lib'))
        ..createSync(recursive: true);
      final dartFile = File(p.join(libDir.path, 'main.dart'))
        ..writeAsStringSync('void main() {}\n');
      return dartFile.path;
    }

    test('exact version "3.13.0" satisfies 3.13.0', () {
      final path = writePubspec('''
name: app
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: "3.13.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('exact version "3.10.0" does NOT satisfy 3.13.0', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "3.10.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isFalse);
    });

    test('caret "^3.13.0" satisfies 3.13.0', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "^3.13.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('caret "^3.12.0" does NOT satisfy 3.13.0', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "^3.12.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isFalse);
    });

    test('range ">=3.13.0 <4.0.0" satisfies 3.13.0', () {
      final path = writePubspec('''
name: app
environment:
  flutter: ">=3.13.0 <4.0.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('range ">=3.10.0 <4.0.0" does NOT satisfy 3.13.0', () {
      final path = writePubspec('''
name: app
environment:
  flutter: ">=3.10.0 <4.0.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isFalse);
    });

    test('major bump (4.0.0) satisfies 3.13.0', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "4.0.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('pre-release suffix "3.13.0-0.0.pre" satisfies 3.13.0', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "3.13.0-0.0.pre"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('missing environment block → assumes modern (true)', () {
      final path = writePubspec('''
name: app
''');
      expect(
        ProjectContext.flutterSdkAtLeast(path, 3, 13, 0),
        isTrue,
        reason: 'Unknown constraint must default to "true" so rules still fire',
      );
    });

    test('flutter: any → assumes modern (true)', () {
      final path = writePubspec('''
name: app
environment:
  flutter: any
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('environment block without flutter key → assumes modern (true)', () {
      final path = writePubspec('''
name: app
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('unparseable "garbage" constraint → assumes modern (true)', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "not-a-version"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('null filePath returns true (unknown → assume modern)', () {
      expect(ProjectContext.flutterSdkAtLeast(null, 3, 13, 0), isTrue);
    });

    test('empty filePath returns true (unknown → assume modern)', () {
      expect(ProjectContext.flutterSdkAtLeast('', 3, 13, 0), isTrue);
    });

    test('higher minor satisfies lower minor (3.20.0 ≥ 3.13.0)', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "3.20.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });

    test('same minor, lower patch does NOT satisfy (3.13.0 vs 3.13.5)', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "3.13.0"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 5), isFalse);
    });

    test('same minor, higher patch satisfies (3.13.5 vs 3.13.0)', () {
      final path = writePubspec('''
name: app
environment:
  flutter: "3.13.5"
''');
      expect(ProjectContext.flutterSdkAtLeast(path, 3, 13, 0), isTrue);
    });
  });
}
