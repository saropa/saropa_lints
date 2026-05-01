import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for [ProjectContext.hasNonWebPlatform] and
/// [ProjectContext.hasPointerPlatform].
///
/// Each test materializes a fresh synthetic project root in
/// `Directory.systemTemp` with a real `pubspec.yaml` and a configurable
/// set of platform directories (`web/`, `android/`, `ios/`, `macos/`,
/// `windows/`, `linux/`), then asks the predicate what the project
/// targets. The fixture is destroyed in `tearDown`, so no state leaks
/// between tests.
///
/// `_projectCache` is keyed on project root, which is unique per temp
/// directory, so cache entries can't cross tests; `ProjectContext.clearCache()`
/// in `setUp` flushes any leftovers defensively.
///
/// Companion to `test/avoid_platform_specific_imports_web_gate_test.dart`
/// which covers [ProjectContext.hasWebSupport].
///
/// Regression target: `bugs/platform_gate_missing_from_sibling_rules.md` —
/// the audit finding that 6 sibling rules had the same structural flaw
/// as the originally-reported `avoid_platform_specific_imports` rule.
void main() {
  late Directory tempRoot;

  setUp(() {
    ProjectContext.clearCache();
    tempRoot = Directory.systemTemp.createTempSync('saropa_platform_gates_');
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  /// Writes `pubspec.yaml` at the temp project root, creates each named
  /// directory in [platformDirs] at the root, and returns a path to a
  /// synthetic Dart file inside `lib/` — the shape a rule sees when
  /// inspecting a compilation unit (`context.filePath`).
  String writeProject(String pubspec, {Set<String> platformDirs = const {}}) {
    File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsStringSync(pubspec);
    for (final String dir in platformDirs) {
      Directory(p.join(tempRoot.path, dir)).createSync();
    }
    final libDir = Directory(p.join(tempRoot.path, 'lib'))
      ..createSync(recursive: true);
    final dartFile = File(p.join(libDir.path, 'main.dart'))
      ..writeAsStringSync('void main() {}\n');
    return dartFile.path;
  }

  const String flutterPubspec = '''
name: app
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: "3.13.0"
dependencies:
  flutter:
    sdk: flutter
''';

  const String pureDartPubspec = '''
name: my_library
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  meta: ^1.12.0
''';

  group('ProjectContext.hasNonWebPlatform', () {
    test('Flutter project with android/ → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'android'});
      expect(ProjectContext.hasNonWebPlatform(path), isTrue);
    });

    test('Flutter project with ios/ → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'ios'});
      expect(ProjectContext.hasNonWebPlatform(path), isTrue);
    });

    test('Flutter project with macos/ only → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'macos'});
      expect(ProjectContext.hasNonWebPlatform(path), isTrue);
    });

    test('Flutter project with windows/ only → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'windows'});
      expect(ProjectContext.hasNonWebPlatform(path), isTrue);
    });

    test('Flutter project with linux/ only → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'linux'});
      expect(ProjectContext.hasNonWebPlatform(path), isTrue);
    });

    test('Flutter project with web/ only → false (the web-only case)', () {
      // Real-world trigger for the inverse gate: a web-only Flutter
      // app should NOT be told its `dart:html` import "crashes on
      // mobile", because it can't produce a mobile build.
      final path = writeProject(flutterPubspec, platformDirs: {'web'});
      expect(
        ProjectContext.hasNonWebPlatform(path),
        isFalse,
        reason: 'Web-only project has no native platform to crash on.',
      );
    });

    test('Flutter project with no platform dirs at all → false', () {
      // Pathological but real: a Flutter package with nothing at the
      // root. Nothing indicates it can run natively, so the inverse
      // rules should be suppressed.
      final path = writeProject(flutterPubspec);
      expect(ProjectContext.hasNonWebPlatform(path), isFalse);
    });

    test('Pure Dart library with no platform dirs → true', () {
      // Library authors can't know the consumer's platform. Default
      // true so cross-platform warnings still fire.
      final path = writeProject(pureDartPubspec);
      expect(ProjectContext.hasNonWebPlatform(path), isTrue);
    });

    test('null filePath → true (unknown → strict)', () {
      expect(ProjectContext.hasNonWebPlatform(null), isTrue);
    });

    test('empty filePath → true (unknown → strict)', () {
      expect(ProjectContext.hasNonWebPlatform(''), isTrue);
    });
  });

  group('ProjectContext.hasPointerPlatform', () {
    test('Flutter project with web/ only → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'web'});
      expect(ProjectContext.hasPointerPlatform(path), isTrue);
    });

    test('Flutter project with macos/ only → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'macos'});
      expect(ProjectContext.hasPointerPlatform(path), isTrue);
    });

    test('Flutter project with windows/ only → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'windows'});
      expect(ProjectContext.hasPointerPlatform(path), isTrue);
    });

    test('Flutter project with linux/ only → true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'linux'});
      expect(ProjectContext.hasPointerPlatform(path), isTrue);
    });

    test('Flutter project with android/ only → false', () {
      // Mobile-only Flutter app. Android does NOT render a cursor by
      // default (ChromeOS / external mouse is an edge case); the
      // rule's UX guidance is irrelevant here.
      final path = writeProject(flutterPubspec, platformDirs: {'android'});
      expect(
        ProjectContext.hasPointerPlatform(path),
        isFalse,
        reason: 'Android-only app does not render a cursor by default.',
      );
    });

    test('Flutter project with ios/ only → false', () {
      // iPad Magic Keyboard + external mouse is a real case, but the
      // default render path shows no cursor. For a warning rule about
      // cursor styling, the default case dominates.
      final path = writeProject(flutterPubspec, platformDirs: {'ios'});
      expect(ProjectContext.hasPointerPlatform(path), isFalse);
    });

    test('Flutter project with android/ + ios/ → false (pure mobile)', () {
      // The pure-mobile canonical case: the rule should not fire here.
      final path = writeProject(
        flutterPubspec,
        platformDirs: {'android', 'ios'},
      );
      expect(ProjectContext.hasPointerPlatform(path), isFalse);
    });

    test('Flutter project with android/ + ios/ + macos/ → true', () {
      // Mixed-target project — macOS brings pointer-platform firing
      // back on, as it should.
      final path = writeProject(
        flutterPubspec,
        platformDirs: {'android', 'ios', 'macos'},
      );
      expect(ProjectContext.hasPointerPlatform(path), isTrue);
    });

    test('Pure Dart library → true', () {
      final path = writeProject(pureDartPubspec);
      expect(ProjectContext.hasPointerPlatform(path), isTrue);
    });

    test('null filePath → true (unknown → strict)', () {
      expect(ProjectContext.hasPointerPlatform(null), isTrue);
    });

    test('empty filePath → true (unknown → strict)', () {
      expect(ProjectContext.hasPointerPlatform(''), isTrue);
    });
  });

  group('Cross-predicate sanity', () {
    test('pure-mobile project: web false, non-web true, pointer false', () {
      // The canonical mobile-only shape. `hasWebSupport` is false (no
      // `web/`), `hasNonWebPlatform` is true (android/ios exist), and
      // `hasPointerPlatform` is false (no desktop, no web).
      final path = writeProject(
        flutterPubspec,
        platformDirs: {'android', 'ios'},
      );
      expect(ProjectContext.hasWebSupport(path), isFalse);
      expect(ProjectContext.hasNonWebPlatform(path), isTrue);
      expect(ProjectContext.hasPointerPlatform(path), isFalse);
    });

    test('web-only project: web true, non-web false, pointer true', () {
      final path = writeProject(flutterPubspec, platformDirs: {'web'});
      expect(ProjectContext.hasWebSupport(path), isTrue);
      expect(ProjectContext.hasNonWebPlatform(path), isFalse);
      expect(ProjectContext.hasPointerPlatform(path), isTrue);
    });

    test('universal project (web + desktop + mobile): all three true', () {
      final path = writeProject(
        flutterPubspec,
        platformDirs: {'web', 'android', 'ios', 'macos', 'windows', 'linux'},
      );
      expect(ProjectContext.hasWebSupport(path), isTrue);
      expect(ProjectContext.hasNonWebPlatform(path), isTrue);
      expect(ProjectContext.hasPointerPlatform(path), isTrue);
    });
  });
}
