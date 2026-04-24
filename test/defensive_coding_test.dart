// Defensive coding: parameter validation, null/empty handling, and edge cases.

import 'dart:io' show Directory;

import 'package:saropa_lints/src/baseline/baseline_config.dart';
import 'package:saropa_lints/src/baseline/baseline_file.dart';
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/baseline/baseline_paths.dart';
import 'package:saropa_lints/src/banned_usage_config.dart';
import 'package:saropa_lints/src/comment_utils.dart';
import 'package:saropa_lints/src/ignore_utils.dart';
import 'package:saropa_lints/src/project_context.dart';
import 'package:test/test.dart';

void main() {
  group('normalizePath', () {
    test('returns empty string for null', () {
      expect(normalizePath(null), '');
    });
    test('returns empty string for empty', () {
      expect(normalizePath(''), '');
    });
    test('normalizes backslashes', () {
      expect(normalizePath(r'foo\bar.dart'), 'foo/bar.dart');
    });
    test('preserves forward slashes', () {
      expect(normalizePath('foo/bar.dart'), 'foo/bar.dart');
    });
  });

  group('BloomFilter', () {
    test('add(null) and add("") do not throw', () {
      final b = BloomFilter();
      b.add(null);
      b.add('');
    });
    test('mightContain(null) and mightContain("") return false', () {
      final b = BloomFilter();
      expect(b.mightContain(null), isFalse);
      expect(b.mightContain(''), isFalse);
    });
    test('addAllTokens(null) does not throw', () {
      final b = BloomFilter();
      b.addAllTokens(null);
    });
    test('negative bitSize falls back to default', () {
      final b = BloomFilter(-1);
      b.add('x');
      expect(b.mightContain('x'), isTrue);
    });
    test('zero bitSize falls back to default', () {
      final b = BloomFilter(0);
      b.add('y');
      expect(b.mightContain('y'), isTrue);
    });
  });

  group('ProjectContext', () {
    test('findProjectRoot(null) returns null', () {
      expect(ProjectContext.findProjectRoot(null), isNull);
    });
    test('findProjectRoot("") returns null', () {
      expect(ProjectContext.findProjectRoot(''), isNull);
    });
    test('getPackageName(null) returns empty string', () {
      expect(ProjectContext.getPackageName(null), '');
    });
    test('getPackageName("") returns empty string', () {
      expect(ProjectContext.getPackageName(''), '');
    });
    test('getProjectInfo(null) returns null', () {
      expect(ProjectContext.getProjectInfo(null), isNull);
    });
    test('getProjectInfo("") returns null', () {
      expect(ProjectContext.getProjectInfo(''), isNull);
    });
    test('hasDependency(null, "x") returns false', () {
      expect(ProjectContext.hasDependency(null, 'x'), isFalse);
    });
    test('hasDependency("path", null) returns false', () {
      expect(ProjectContext.hasDependency('path', null), isFalse);
    });
    test('hasDependency("", "x") returns false', () {
      expect(ProjectContext.hasDependency('', 'x'), isFalse);
    });

    // Regression test for the silent "always empty" dependency parser bug: the
    // pubspec parser's dep regex previously lacked `multiLine: true`, so `^`
    // anchored only at position 0 of the string and `allMatches` returned zero
    // hits on any pubspec that started with `name:` (i.e. every pubspec). That
    // caused `hasDependency(...)` to return `false` for every query on every
    // project, silently turning `saropa_depend_on_referenced_packages` (and
    // every other rule that skips itself when a package IS declared) into a
    // false-positive firehose. This test locks in real positive results so the
    // regex cannot regress to the broken state without a loud red test.
    //
    // The test uses this repo's own pubspec — the test runner's working dir
    // is the project root, so `pubspec.yaml` in `.` is saropa_lints' own
    // pubspec, which lists `analyzer`, `path`, and `test` among its deps.
    // (We don't pin `flutter` because saropa_lints is a pure Dart package.)
    test('hasDependency resolves real package names from pubspec', () {
      // `findProjectRoot` walks up from a given FILE path looking for a
      // sibling `pubspec.yaml`. It needs an absolute path to walk — a bare
      // relative filename has no parent chain to traverse. `Directory.current`
      // resolves to the project root when `dart test` runs, so anchoring the
      // probe at `<cwd>/pubspec.yaml` gives us a real file the helper can
      // walk back from.
      ProjectContext.clearCache();
      final probe = '${Directory.current.path}/pubspec.yaml';
      expect(
        ProjectContext.hasDependency(probe, 'analyzer'),
        isTrue,
        reason:
            'saropa_lints pubspec declares `analyzer` as a direct dep — if this fails, the dep regex is broken again.',
      );
      expect(
        ProjectContext.hasDependency(probe, 'path'),
        isTrue,
        reason: 'saropa_lints declares `path:` under dependencies.',
      );
      expect(
        ProjectContext.hasDependency(probe, 'test'),
        isTrue,
        reason:
            'saropa_lints declares `test:` under dev_dependencies — the parser is deliberately over-inclusive across both sections.',
      );
      expect(
        ProjectContext.hasDependency(probe, 'definitely_not_a_real_package'),
        isFalse,
        reason:
            'Sanity: arbitrary strings must not resolve to true, otherwise the parser is eating the whole file.',
      );
    });

    test('getPackageName resolves the project name from pubspec', () {
      ProjectContext.clearCache();
      final probe = '${Directory.current.path}/pubspec.yaml';
      final root = ProjectContext.findProjectRoot(probe);
      expect(root, isNotNull);
      expect(
        ProjectContext.getPackageName(root),
        'saropa_lints',
        reason:
            'The `name:` field at the top of saropa_lints pubspec.yaml must parse back verbatim — if this breaks, the `skip own-package import` guard in `saropa_depend_on_referenced_packages` stops working.',
      );
    });
  });

  group('BaselineConfig', () {
    test('fromYaml(null) returns default config', () {
      final c = BaselineConfig.fromYaml(null);
      expect(c.file, isNull);
      expect(c.date, isNull);
      expect(c.paths, isEmpty);
      expect(c.onlyImpacts, isEmpty);
    });
    test('fromYaml(non-Map) returns default config', () {
      final c = BaselineConfig.fromYaml('string');
      expect(c.paths, isEmpty);
    });
    test('shouldBaselineImpact(null) returns false', () {
      const c = BaselineConfig();
      expect(c.shouldBaselineImpact(null), isFalse);
    });
    test('shouldBaselineImpact("") returns false', () {
      const c = BaselineConfig();
      expect(c.shouldBaselineImpact(''), isFalse);
    });
  });

  group('BaselineFile', () {
    test('load(null) returns null', () {
      expect(BaselineFile.load(null), isNull);
    });
    test('load("") returns null', () {
      expect(BaselineFile.load(''), isNull);
    });
    test('load("nonexistent_path_xyz") returns null', () {
      expect(BaselineFile.load('nonexistent_path_xyz'), isNull);
    });
    test('fromJson(null) returns empty baseline', () {
      final b = BaselineFile.fromJson(null);
      expect(b.violations, isEmpty);
      expect(b.generated, isNotNull);
    });
    test('fromJson with version > current returns empty baseline', () {
      final b = BaselineFile.fromJson({'version': 99});
      expect(b.violations, isEmpty);
    });
    test('isBaselined with null filePath returns false', () {
      final b = BaselineFile(violations: {});
      expect(b.isBaselined(null, 'rule', 1), isFalse);
    });
    test('isBaselined with null ruleName returns false', () {
      final b = BaselineFile(violations: {});
      expect(b.isBaselined('lib/foo.dart', null, 1), isFalse);
    });
    test('isBaselined with line < 1 returns false', () {
      final b = BaselineFile(
        violations: {
          'lib/foo.dart': {
            'r': [1],
          },
        },
      );
      expect(b.isBaselined('lib/foo.dart', 'r', 0), isFalse);
      expect(b.isBaselined('lib/foo.dart', 'r', -1), isFalse);
    });
    test('save(null) does not throw', () {
      final b = BaselineFile(violations: {});
      b.save(null);
    });
    test('save("") does not throw', () {
      final b = BaselineFile(violations: {});
      b.save('');
    });
  });

  group('BaselineManager', () {
    setUp(() => BaselineManager.reset());

    test('isBaselined with null filePath returns false', () async {
      expect(BaselineManager.isBaselined(null, 'rule', 1), isFalse);
      expect(await BaselineManager.isBaselinedAsync(null, 'rule', 1), isFalse);
    });
    test('isBaselined with null ruleName returns false', () async {
      expect(BaselineManager.isBaselined('f', null, 1), isFalse);
      expect(await BaselineManager.isBaselinedAsync('f', null, 1), isFalse);
    });
    test('isBaselined with line < 1 returns false', () async {
      expect(BaselineManager.isBaselined('f', 'r', 0), isFalse);
      expect(await BaselineManager.isBaselinedAsync('f', 'r', 0), isFalse);
    });
    test('preloadDateBaseline(null) does not throw', () async {
      await BaselineManager.preloadDateBaseline(null);
    });
    test('preloadDateBaseline("") does not throw', () async {
      await BaselineManager.preloadDateBaseline('');
    });
    test('findProjectRoot(null) returns null', () {
      expect(BaselineManager.findProjectRoot(null), isNull);
    });
  });

  group('BaselinePaths', () {
    test('BaselinePaths(null) has no patterns', () {
      final p = BaselinePaths(null);
      expect(p.hasPatterns, isFalse);
      expect(p.matches('lib/foo.dart'), isFalse);
    });
    test('matches(null) returns false', () {
      final p = BaselinePaths(['lib/']);
      expect(p.matches(null), isFalse);
    });
    test('matches("") returns false', () {
      final p = BaselinePaths(['lib/']);
      expect(p.matches(''), isFalse);
    });
  });

  group('IgnoreUtils', () {
    test('toHyphenated(null) returns empty string', () {
      expect(IgnoreUtils.toHyphenated(null), '');
    });
    test('isIgnoredForFile(null, "r") returns false', () {
      expect(IgnoreUtils.isIgnoredForFile(null, 'r'), isFalse);
    });
    test('isIgnoredForFile("content", null) returns false', () {
      expect(IgnoreUtils.isIgnoredForFile('content', null), isFalse);
    });
    test('isIgnoredForFile("", "r") returns false', () {
      expect(IgnoreUtils.isIgnoredForFile('', 'r'), isFalse);
    });
  });

  group('CommentPatterns', () {
    test('isLikelyCode(null) returns false', () {
      expect(CommentPatterns.isLikelyCode(null), isFalse);
    });
    test('isSpecialMarker(null) returns false', () {
      expect(CommentPatterns.isSpecialMarker(null), isFalse);
    });
    test('startsWithLowercase(null) returns false', () {
      expect(CommentPatterns.startsWithLowercase(null), isFalse);
    });
  });

  group('BannedUsageEntry', () {
    test('matchesName(null) returns false', () {
      const e = BannedUsageEntry(identifier: 'print', reason: 'Use Logger');
      expect(e.matchesName(null), isFalse);
    });
    test('matchesName("print") returns true', () {
      const e = BannedUsageEntry(identifier: 'print', reason: 'Use Logger');
      expect(e.matchesName('print'), isTrue);
    });
  });
}
