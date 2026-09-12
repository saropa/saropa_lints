import 'package:saropa_lints/src/banned_usage_config.dart';
import 'package:test/test.dart';

/// Unit tests for [loadBannedUsageConfig], the line-based parser that reads
/// the `banned_usage: entries:` section of `analysis_options_custom.yaml`.
void main() {
  group('loadBannedUsageConfig', () {
    test('null content produces no entries (no-op default)', () {
      loadBannedUsageConfig(null);
      expect(bannedUsageEntries, isEmpty);
    });

    test('content with no matching section produces no entries', () {
      loadBannedUsageConfig('some_other_key: true\n');
      expect(bannedUsageEntries, isEmpty);
    });

    test('parses an entry with an explicit reason', () {
      loadBannedUsageConfig('''
banned_usage:
  entries:
    - identifier: 'print'
      reason: 'Use Logger instead'
''');
      expect(bannedUsageEntries, hasLength(1));
      expect(bannedUsageEntries.first.identifier, 'print');
      expect(bannedUsageEntries.first.reason, 'Use Logger instead');
    });

    test('an entry without a reason gets the default reason', () {
      loadBannedUsageConfig('''
banned_usage:
  entries:
    - identifier: 'print'
''');
      expect(bannedUsageEntries, hasLength(1));
      expect(
        bannedUsageEntries.first.reason,
        'Banned by project configuration.',
      );
    });

    test('parses multiple entries', () {
      loadBannedUsageConfig('''
banned_usage:
  entries:
    - identifier: 'print'
      reason: 'Use Logger instead'
    - identifier: 'debugPrint'
      reason: 'Use Logger instead'
''');
      expect(bannedUsageEntries, hasLength(2));
      expect(bannedUsageEntries[1].identifier, 'debugPrint');
    });

    test('an entries list under a later top-level section is not adopted', () {
      loadBannedUsageConfig('''
banned_usage:
  enabled: true
some_other_rule:
  entries:
    - identifier: 'leakedSymbol'
      reason: 'Belongs to another section'
''');
      expect(bannedUsageEntries, isEmpty);
    });

    test('entries from a later top-level section are not appended', () {
      loadBannedUsageConfig('''
banned_usage:
  entries:
    - identifier: 'mySymbol'
      reason: 'Mine'
some_other_rule:
  entries:
    - identifier: 'leakedSymbol'
      reason: 'Belongs to another section'
''');
      expect(bannedUsageEntries, hasLength(1));
      expect(bannedUsageEntries.first.identifier, 'mySymbol');
    });

    test('blank lines and comments inside the section do not end it', () {
      loadBannedUsageConfig('''
banned_usage:
  entries:
    # project bans

    - identifier: 'print'
      reason: 'Use Logger instead'
''');
      expect(bannedUsageEntries, hasLength(1));
      expect(bannedUsageEntries.first.identifier, 'print');
    });

    test('a stale global list is reset when called again with no section', () {
      loadBannedUsageConfig('''
banned_usage:
  entries:
    - identifier: 'print'
      reason: 'Use Logger instead'
''');
      expect(bannedUsageEntries, hasLength(1));

      loadBannedUsageConfig('unrelated: true\n');
      expect(bannedUsageEntries, isEmpty);
    });
  });
}
