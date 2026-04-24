import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for [ProjectContext.hasWebSupport] and the `avoid_platform_specific_imports`
/// project-level gate.
///
/// Each test materializes a synthetic project root in `Directory.systemTemp`
/// with a real `pubspec.yaml` and an optional `web/` directory, then asks
/// the web-support predicate whether that project targets the web platform.
/// The fixture is destroyed in `tearDown`, so no state leaks between tests.
///
/// The `_projectCache` is keyed on project root, which is unique per temp
/// directory, so cache entries can't cross tests; `ProjectContext.clearCache()`
/// in `setUp` flushes any leftovers defensively.
///
/// Regression target:
/// `bugs/avoid_platform_specific_imports_false_positive_non_web_project.md` —
/// the rule used to fire on every `dart:io` import regardless of whether
/// the project could produce a web build, making it pure noise in
/// mobile-only Flutter apps.
void main() {
  group('ProjectContext.hasWebSupport', () {
    late Directory tempRoot;

    setUp(() {
      ProjectContext.clearCache();
      tempRoot = Directory.systemTemp.createTempSync('saropa_web_gate_');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    /// Writes `pubspec.yaml` at the temp project root, optionally creates
    /// a `web/` directory, and returns a path to a synthetic Dart file
    /// inside `lib/` — the shape a rule sees when inspecting a compilation
    /// unit (`context.filePath`).
    String writeProject(String pubspec, {required bool withWebDir}) {
      File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsStringSync(pubspec);
      if (withWebDir) {
        Directory(p.join(tempRoot.path, 'web')).createSync();
      }
      final libDir = Directory(p.join(tempRoot.path, 'lib'))
        ..createSync(recursive: true);
      final dartFile = File(p.join(libDir.path, 'main.dart'))
        ..writeAsStringSync('void main() {}\n');
      return dartFile.path;
    }

    test('Flutter project with web/ directory → true', () {
      // Standard `flutter create --platforms=web` layout: a `web/` dir at
      // the project root is the canonical signal that the app can build
      // for the browser.
      final path = writeProject('''
name: app
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: "3.13.0"
dependencies:
  flutter:
    sdk: flutter
''', withWebDir: true);
      expect(ProjectContext.hasWebSupport(path), isTrue);
    });

    test('Flutter project WITHOUT web/ directory → false', () {
      // The real-world failing case: mobile-only Flutter app (android /
      // ios / macos, no `web/`). The rule's stated failure mode
      // ("dart:io breaks web builds") cannot occur here, so every
      // diagnostic the rule raises is noise.
      final path = writeProject('''
name: app
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: "3.13.0"
dependencies:
  flutter:
    sdk: flutter
''', withWebDir: false);
      expect(
        ProjectContext.hasWebSupport(path),
        isFalse,
        reason: 'Mobile-only Flutter project cannot emit a web build, so '
            'dart:io imports are structurally safe.',
      );
    });

    test('Pure Dart library (no flutter: block) → true even without web/',
        () {
      // Library authors can't know their caller's platforms — a
      // browser-targeting app may consume this library, so web-compat
      // warnings still apply. This branch keeps the existing behavior for
      // library code regardless of `web/` directory presence.
      final path = writeProject('''
name: my_library
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  meta: ^1.12.0
''', withWebDir: false);
      expect(ProjectContext.hasWebSupport(path), isTrue);
    });

    test('null filePath → true (unknown → assume modern / assume strict)',
        () {
      // Matches the unknown-defaults-to-true philosophy of
      // `flutterSdkAtLeast`: when the project is un-introspectable, we
      // prefer to emit the warning and let the user silence it.
      expect(ProjectContext.hasWebSupport(null), isTrue);
    });

    test('empty filePath → true (unknown → assume strict)', () {
      expect(ProjectContext.hasWebSupport(''), isTrue);
    });

    test('path with no pubspec anywhere → true (unknown → assume strict)',
        () {
      // A path that doesn't resolve to any project root. The cache lookup
      // returns null, so the predicate falls through to the default.
      final orphan = p.join(tempRoot.path, 'nowhere', 'file.dart');
      expect(ProjectContext.hasWebSupport(orphan), isTrue);
    });
  });
}
