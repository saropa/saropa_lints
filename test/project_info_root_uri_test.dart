import 'dart:io';

import 'package:saropa_lints/src/init/project_info.dart';
import 'package:test/test.dart';

void main() {
  group('rootUriToPath', () {
    test('parses valid file URI to path', () {
      final path = rootUriToPath('file:///tmp/saropa_lints');
      expect(path, isNotNull);
      expect(path, endsWith('saropa_lints'));
    });

    test('returns null when Uri.tryParse fails (no throw)', () {
      expect(rootUriToPath('file://['), isNull);
    });

    test('relative dart_tool path still resolves when not file scheme', () {
      final path = rootUriToPath('../packages/saropa_lints');
      expect(path, isNotNull);
      expect(path, contains('.dart_tool'));
      expect(path, contains('packages'));
    });
  });

  group('getPackageVersion', () {
    // Regression test for the `Version: unknown` report header — the
    // analyzer-plugin isolate does not run with Directory.current set to
    // the consumer project, so the default relative
    // `File('.dart_tool/package_config.json')` lookup silently fails and
    // every report prints "Version: unknown". Passing an absolute
    // projectRoot fixes that. This test pins the fix by using saropa_lints'
    // own project root (dart test sets cwd to the project root), which
    // contains a real .dart_tool/package_config.json with a `saropa_lints`
    // entry that points back at the package itself.
    test(
      'resolves a real version string when passed an explicit projectRoot',
      () {
        final projectRoot = Directory.current.path;
        final version = getPackageVersion(projectRoot: projectRoot);
        // Version must match a semver-like triple (optionally with
        // prerelease/build suffix). 'unknown' would mean the lookup still
        // falls through — that is the silent-failure mode this test exists
        // to catch.
        expect(
          version,
          matches(RegExp(r'^\d+\.\d+\.\d+')),
          reason:
              'getPackageVersion(projectRoot:) must resolve to a real '
              'semver string. If this returns "unknown", the plugin-path '
              'report header is broken again.',
        );
      },
    );

    test('returns "unknown" without crashing for a bogus projectRoot', () {
      expect(
        getPackageVersion(projectRoot: r'd:\path\that\does\not\exist'),
        'unknown',
      );
    });
  });
}
