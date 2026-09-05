import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

import '../../support/safe_delete.dart';

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
/// Regression targets:
/// - `bugs/avoid_platform_specific_imports_false_positive_non_web_project.md` —
///   the rule used to fire on every `dart:io` import regardless of whether
///   the project could produce a web build, making it pure noise in
///   mobile-only Flutter apps.
/// - `plans/history/2026.04/2026.04.26/prefer_foundation_platform_check_false_positive_mobile_only_no_web_dir.md` —
///   `prefer_foundation_platform_check` uses the same [ProjectContext.hasWebSupport]
///   gate as `avoid_platform_specific_imports` (see sibling rules in `platform_rules.dart`).
/// - `plans/history/2026.04/2026.04.26/avoid_platform_specific_imports_false_positive_mobile_only_no_web_dir.md` —
///   gate must run in AST callbacks so [context.filePath] is non-empty (registration
///   time path was empty, so `hasWebSupport` always defaulted to strict / web-capable).
void main() {
  group('ProjectContext.hasWebSupport', () {
    late Directory tempRoot;

    setUp(() {
      ProjectContext.clearCache();
      tempRoot = Directory.systemTemp.createTempSync('saropa_web_gate_');
    });

    // Retry-tolerant cleanup: Windows file handles can linger after tests
    tearDown(() => safeDeleteDir(tempRoot));

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
        reason:
            'Mobile-only Flutter project cannot emit a web build, so '
            'dart:io imports are structurally safe.',
      );
    });

    test('Pure Dart library (no flutter: block) → true even without web/', () {
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

    test('null filePath → true (unknown → assume modern / assume strict)', () {
      // Matches the unknown-defaults-to-true philosophy of
      // `flutterSdkAtLeast`: when the project is un-introspectable, we
      // prefer to emit the warning and let the user silence it.
      expect(ProjectContext.hasWebSupport(null), isTrue);
    });

    test('empty filePath → true (unknown → assume strict)', () {
      // Rules must not rely on this alone during plugin registration, when the
      // compilation unit path is often still empty — see archived bug report
      // in plans/history/2026.04/2026.04.26/.
      expect(ProjectContext.hasWebSupport(''), isTrue);
    });

    test('path with no pubspec anywhere → true (unknown → assume strict)', () {
      // A path that doesn't resolve to any project root. The cache lookup
      // returns null, so the predicate falls through to the default.
      final orphan = p.join(tempRoot.path, 'nowhere', 'file.dart');
      expect(ProjectContext.hasWebSupport(orphan), isTrue);
    });
  });

  /// Tests for [ProjectContext.isCliOrToolPackage] — the guard that fixes
  /// bugs/avoid_platform_specific_imports_false_positive_analyzer_plugin.md
  /// (46 false positives on saropa_lints' own `dart:io` imports, which are
  /// legitimate: saropa_lints is a CLI tool and analyzer plugin, never a
  /// web-targeting package).
  group('ProjectContext.isCliOrToolPackage', () {
    late Directory tempRoot;

    setUp(() {
      ProjectContext.clearCache();
      tempRoot = Directory.systemTemp.createTempSync('saropa_cli_pkg_gate_');
    });

    tearDown(() => safeDeleteDir(tempRoot));

    String writeProject(String pubspec) {
      File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsStringSync(pubspec);
      final libDir = Directory(p.join(tempRoot.path, 'lib'))
        ..createSync(recursive: true);
      final dartFile = File(p.join(libDir.path, 'main.dart'))
        ..writeAsStringSync('void main() {}\n');
      return dartFile.path;
    }

    test('pubspec with executables: section → true', () {
      // The `executables:` section is what `dart run <pkg>:<name>` uses to
      // find CLI entrypoints — its presence is a direct declaration that
      // this package ships command-line tools, matching saropa_lints'
      // own pubspec.yaml.
      final path = writeProject('''
name: my_cli_tool
environment:
  sdk: ">=3.0.0 <4.0.0"
executables:
  my_cli_tool: my_cli_tool
''');
      expect(ProjectContext.isCliOrToolPackage(path), isTrue);
    });

    test('pubspec depending on custom_lint_builder → true', () {
      // custom_lint_builder is the SDK used to author a custom_lint plugin
      // — such a package runs inside the analysis server process, never
      // in a browser, so dart:io is safe regardless of web-support gate.
      final path = writeProject('''
name: my_plugin
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  custom_lint_builder: ^0.6.0
''');
      expect(ProjectContext.isCliOrToolPackage(path), isTrue);
    });

    test('pubspec depending on analyzer_plugin → true', () {
      // analyzer_plugin is the SDK saropa_lints itself depends on to
      // implement the native analyzer-plugin protocol — the exact
      // scenario in the bug report (analyzer plugin package flagged for
      // its own required dart:io import).
      final path = writeProject('''
name: my_analyzer_plugin
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  analyzer_plugin: ^0.14.0
''');
      expect(ProjectContext.isCliOrToolPackage(path), isTrue);
    });

    test('plain multi-platform package with no CLI/plugin signal → false', () {
      // The rule must still fire for its intended case: a shared library
      // or app with no CLI/plugin markers, where a stray dart:io import
      // really would break a web build.
      final path = writeProject('''
name: my_shared_lib
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  meta: ^1.12.0
''');
      expect(ProjectContext.isCliOrToolPackage(path), isFalse);
    });

    test('null filePath → false (unknown → do not suppress rules)', () {
      // Unlike hasWebSupport's "unknown → true / assume strict" default,
      // isCliOrToolPackage defaults to false on an unreadable project: not
      // knowing whether a package is a CLI tool must not silently disable
      // otherwise-applicable rules.
      expect(ProjectContext.isCliOrToolPackage(null), isFalse);
    });
  });

  /// Tests for [ProjectContext.isInShortLivedToolDirectory] — the per-file
  /// complement to [ProjectContext.isCliOrToolPackage]. A `tool/` script can
  /// live inside an otherwise browser-facing app package that carries none
  /// of the whole-package CLI/plugin signals, so the path-based check is
  /// needed in addition to the pubspec-based one.
  group('ProjectContext.isInShortLivedToolDirectory', () {
    test('file under bin/ → true', () {
      expect(
        ProjectContext.isInShortLivedToolDirectory('/repo/bin/main.dart'),
        isTrue,
      );
    });

    test('file under tool/ → true', () {
      expect(
        ProjectContext.isInShortLivedToolDirectory('/repo/tool/generate.dart'),
        isTrue,
      );
    });

    test('Windows-style backslash path under tool/ → true', () {
      // Path separators must be normalized — Windows callers pass
      // backslash paths, and a naive '/tool/' substring check would miss
      // them entirely.
      expect(
        ProjectContext.isInShortLivedToolDirectory(
          r'D:\repo\tool\generate.dart',
        ),
        isTrue,
      );
    });

    test('file under lib/ → false', () {
      expect(
        ProjectContext.isInShortLivedToolDirectory('/repo/lib/main.dart'),
        isFalse,
      );
    });

    test('null filePath → false', () {
      expect(ProjectContext.isInShortLivedToolDirectory(null), isFalse);
    });
  });
}
