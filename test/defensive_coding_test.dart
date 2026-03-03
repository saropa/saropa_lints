// Defensive coding: parameter validation, null/empty handling, and edge cases.

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
      final b = BaselineFile(violations: {'lib/foo.dart': {'r': [1]}});
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
      const e = BannedUsageEntry(
        identifier: 'print',
        reason: 'Use Logger',
      );
      expect(e.matchesName(null), isFalse);
    });
    test('matchesName("print") returns true', () {
      const e = BannedUsageEntry(
        identifier: 'print',
        reason: 'Use Logger',
      );
      expect(e.matchesName('print'), isTrue);
    });
  });
}
