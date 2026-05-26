import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// `require_https_only` must not fire when the string is a prose mention of
/// the `http://` scheme (bare scheme, or whitespace immediately after the
/// scheme) rather than a URL being requested. The trigger was a Korean
/// i18n string in a generated Flutter localization file:
/// `'http:// 또는 https:// URL만 지원됩니다.'`
///
/// The implementation predicate is private
/// (`_isHttpSchemeMention` in `security_network_input_rules.dart`).
/// This local copy mirrors the predicate so the contract is independently
/// verified — keep the two in sync.
void main() {
  const ruleName = 'require_https_only';
  const fixturePath = 'example/lib/security/require_https_only_fixture.dart';

  /// Mirrors `RequireHttpsOnlyRule._isHttpSchemeMention`. If you change
  /// one, change the other — the test is the contract.
  bool isSchemeMention(String value) {
    if (value == 'http://') return true;
    if (value.length <= 7) return false;
    final code = value.codeUnitAt(7);
    return code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D;
  }

  group('require_https_only scheme-mention carve-out', () {
    test('rule is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('fixture exists and contains the prose-mention section', () {
      final file = File(fixturePath);
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('HttpSchemeProseMentions'));
      // Korean i18n string that triggered the rule fix.
      expect(content, contains('http:// 또는 https://'));
      // English prose listing both schemes.
      expect(content, contains('http:// or https://'));
    });

    // -- Positive: prose mentions should be recognized --

    test('bare scheme is recognized as prose mention', () {
      expect(isSchemeMention('http://'), isTrue);
    });

    test('space after scheme is recognized as prose mention', () {
      expect(isSchemeMention('http:// or https:// URLs are supported.'), isTrue);
    });

    test('non-ASCII text after space is recognized (Korean i18n)', () {
      // The trigger case verbatim.
      expect(isSchemeMention('http:// 또는 https:// URL만 지원됩니다.'), isTrue);
    });

    test('tab after scheme is recognized as prose mention', () {
      expect(isSchemeMention('http://\tor https://'), isTrue);
    });

    test('newline after scheme is recognized as prose mention', () {
      expect(isSchemeMention('http://\nsecond line'), isTrue);
    });

    test('carriage return after scheme is recognized as prose mention', () {
      expect(isSchemeMention('http://\rsecond line'), isTrue);
    });

    // -- Negative: real URLs must still fire --

    test('real URL with host is NOT a prose mention (still fires)', () {
      expect(isSchemeMention('http://example.com'), isFalse);
    });

    test('URL with path is NOT a prose mention (still fires)', () {
      expect(isSchemeMention('http://api.example.com/v1/users'), isFalse);
    });

    test('URL with port is NOT a prose mention (still fires)', () {
      expect(isSchemeMention('http://example.com:8080'), isFalse);
    });

    test('URL with IPv6 bracket is NOT a prose mention', () {
      // `[` is not whitespace — must still fire (rule's localhost carve-out
      // handles `[::1]` separately).
      expect(isSchemeMention('http://[2001:db8::1]/path'), isFalse);
    });

    test('URL with subdomain hyphen is NOT a prose mention', () {
      expect(isSchemeMention('http://api-staging.example.com'), isFalse);
    });

    test('non-http string is NOT a prose mention', () {
      // Predicate is only consulted when value already startsWith `http://`,
      // but the early-out branch is still worth pinning.
      expect(isSchemeMention('https://example.com'), isFalse);
      expect(isSchemeMention('plain string'), isFalse);
      expect(isSchemeMention(''), isFalse);
    });
  });
}
