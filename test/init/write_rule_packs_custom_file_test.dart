/// Tests for [writeRulePacksToCustomFile]: block write, replace, clear,
/// and section-boundary safety (the regex must not eat adjacent sections).
library;

import 'dart:io';

import 'package:saropa_lints/src/config/analysis_options_rule_packs.dart';
import 'package:saropa_lints/src/init/custom_overrides_core.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  group('writeRulePacksToCustomFile', () {
    late Directory dir;
    late File customFile;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('rule_packs_custom_test');
      customFile = File(
        '${dir.path}${Platform.pathSeparator}analysis_options_custom.yaml',
      );
    });

    tearDown(() => safeDeleteDir(dir));

    /// Helper: write the standard template file (matches buildMinimalConfig).
    void writeTemplate() {
      customFile.writeAsStringSync(
        buildMinimalConfig(tiers.defaultPlatforms, {}),
      );
    }

    test('writes packs into a fresh template file', () {
      writeTemplate();
      writeRulePacksToCustomFile(customFile, ['drift', 'collection_compat']);
      final content = customFile.readAsStringSync();

      // Packs present and sorted.
      final packs = parseRulePacksEnabledList(content);
      expect(packs, ['collection_compat', 'drift']);

      // Template comments removed.
      expect(content.contains('# RULE PACKS'), isFalse);
    });

    test('preserves PLATFORM SETTINGS section when writing packs', () {
      writeTemplate();
      writeRulePacksToCustomFile(customFile, ['drift']);
      final content = customFile.readAsStringSync();

      // The platform section header must survive.
      expect(content.contains('# PLATFORM SETTINGS'), isTrue);
      expect(content.contains('platforms:'), isTrue);
    });

    test('preserves PLATFORM SETTINGS section when replacing packs', () {
      writeTemplate();
      // Write initial packs.
      writeRulePacksToCustomFile(customFile, ['drift']);
      // Replace with different packs.
      writeRulePacksToCustomFile(customFile, ['collection_compat']);
      final content = customFile.readAsStringSync();

      final packs = parseRulePacksEnabledList(content);
      expect(packs, ['collection_compat']);
      expect(content.contains('# PLATFORM SETTINGS'), isTrue);
    });

    test('clears packs when passed an empty list', () {
      writeTemplate();
      writeRulePacksToCustomFile(customFile, ['drift']);
      // Now clear.
      writeRulePacksToCustomFile(customFile, []);
      final content = customFile.readAsStringSync();

      // No rule_packs block remains.
      expect(content.contains('rule_packs:'), isFalse);
      // Platform section still intact.
      expect(content.contains('# PLATFORM SETTINGS'), isTrue);
      expect(content.contains('platforms:'), isTrue);
    });

    test('preserves RULE OVERRIDES section', () {
      writeTemplate();
      writeRulePacksToCustomFile(customFile, ['drift']);
      final content = customFile.readAsStringSync();

      expect(content.contains('# RULE OVERRIDES'), isTrue);
    });

    test('writes packs into a file with no template comments', () {
      // Bare custom file with only platform settings — no RULE PACKS template.
      customFile.writeAsStringSync('''
# PLATFORM SETTINGS
platforms:
  android: true
  ios: true
''');
      writeRulePacksToCustomFile(customFile, ['drift']);
      final content = customFile.readAsStringSync();

      final packs = parseRulePacksEnabledList(content);
      expect(packs, ['drift']);
      // rule_packs appears before platforms.
      final packPos = content.indexOf('rule_packs:');
      final platformPos = content.indexOf('platforms:');
      expect(packPos, lessThan(platformPos));
    });

    test('writes packs into an empty file', () {
      customFile.writeAsStringSync('');
      writeRulePacksToCustomFile(customFile, ['drift']);
      final content = customFile.readAsStringSync();

      final packs = parseRulePacksEnabledList(content);
      expect(packs, ['drift']);
    });

    test('creates file if it does not exist', () {
      expect(customFile.existsSync(), isFalse);
      writeRulePacksToCustomFile(customFile, ['drift']);
      expect(customFile.existsSync(), isTrue);

      final packs = parseRulePacksEnabledList(customFile.readAsStringSync());
      expect(packs, ['drift']);
    });

    test('handles CRLF line endings without corruption', () {
      // Simulate a Windows-edited file with \r\n line endings.
      customFile.writeAsStringSync(
        '# PLATFORM SETTINGS\r\nplatforms:\r\n  android: true\r\n',
      );
      writeRulePacksToCustomFile(customFile, ['drift']);
      final content = customFile.readAsStringSync();

      // Packs written correctly.
      final packs = parseRulePacksEnabledList(content);
      expect(packs, ['drift']);
      // Platform section preserved.
      expect(content.contains('platforms:'), isTrue);
      expect(content.contains('android: true'), isTrue);
    });
  });
}
