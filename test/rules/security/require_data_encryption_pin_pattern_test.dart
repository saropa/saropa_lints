import 'package:test/test.dart';

/// Mirrors [RequireDataEncryptionRule] pin detection; keep pattern in sync with
/// `_pinKeywordPattern` in security_auth_storage_rules.dart.
final RegExp _pinKeywordPattern = RegExp(r'(?<![a-zA-Z])pin');

/// Mirrors `_argumentEncryptionSignalPatterns` in security_auth_storage_rules.dart.
final List<RegExp> _argumentEncryptionSignalPatterns = <RegExp>[
  RegExp(r'\bsecure\b'),
  RegExp(r'\bencrypt\b'),
  RegExp(r'\bencryptedbox\b'),
  RegExp(r'\bencrypted\w*'),
  RegExp(r'\bcipher\w*'),
  RegExp(r'\baes\w*'),
  RegExp(r'encrypted\('),
];

bool _argsHaveEncryptionSignal(String argsSource) {
  final String lower = argsSource.toLowerCase();
  return _argumentEncryptionSignalPatterns.any((RegExp p) => p.hasMatch(lower));
}

void main() {
  group('require_data_encryption pin keyword guard', () {
    test('does not match pin inside OwaspMapping / mapping (regression)', () {
      const args =
          'projectroot: projectroot, data: x, owasplookup: const <string, owaspmapping>{}';
      expect(_pinKeywordPattern.hasMatch(args), isFalse);
    });

    test('does not match pin inside shopping (embedded p-p-i-n)', () {
      expect(_pinKeywordPattern.hasMatch('label: shopping_cart'), isFalse);
    });

    test('matches standalone pin token (before state)', () {
      expect(_pinKeywordPattern.hasMatch('pin: value'), isTrue);
      expect(_pinKeywordPattern.hasMatch('named: pin, value: 1'), isTrue);
    });

    test(
      'does not match userpin / camelCase without delimiter (after state)',
      () {
        expect(_pinKeywordPattern.hasMatch('userpin: 1'), isFalse);
        expect(_pinKeywordPattern.hasMatch('mypincode: 1'), isFalse);
      },
    );

    test('matches pin after non-letter delimiter', () {
      expect(_pinKeywordPattern.hasMatch(r'x.pin: 1'), isTrue);
      expect(_pinKeywordPattern.hasMatch('user_pin: 1'), isTrue);
      expect(_pinKeywordPattern.hasMatch('(pin)'), isTrue);
    });

    test(
      'matches pin at start of argument text (pinCode-style identifiers)',
      () {
        expect(_pinKeywordPattern.hasMatch('pincode: x'), isTrue);
      },
    );

    // -- Edge-case documentation: accepted trade-offs --

    test('matches pin-prefix words like pineapple (accepted trade-off)', () {
      // Words starting with "pin" match because no lookahead is used — this is
      // tolerated so genuine fields like pinCode / pinNumber are caught.
      expect(_pinKeywordPattern.hasMatch('label: pineapple'), isTrue);
      expect(_pinKeywordPattern.hasMatch('label: pinball'), isTrue);
    });

    test('does not match words with pin embedded after a letter', () {
      // opinion = o-p-i-n → 'pin' at offset 1 is preceded by 'o' (letter).
      // spinning = …p-p-i-n → preceded by 'p' (letter).
      expect(_pinKeywordPattern.hasMatch('opinion: value'), isFalse);
      expect(_pinKeywordPattern.hasMatch('spinning: value'), isFalse);
    });

    test('matches pin preceded by digit (digit is not a letter)', () {
      expect(_pinKeywordPattern.hasMatch('code1234pin: x'), isTrue);
    });
  });

  group('require_data_encryption argument encryption signal', () {
    test('matches Drift-style companion with encrypted* value', () {
      const args =
          '_driftlikecompanion(privatekey: _driftvalue(encryptedprivatekey), publickey: _driftvalue(""))';
      expect(_argsHaveEncryptionSignal(args), isTrue);
    });

    test('matches …encrypted( method name on arg text', () {
      expect(
        _argsHaveEncryptionSignal(
          '_driftlikecompanion(privatekey: _driftvalue(tofirebaseencrypted(x)))',
        ),
        isTrue,
      );
    });

    test('matches cipher* and aes* identifiers', () {
      expect(
        _argsHaveEncryptionSignal('x(ciphertext, y)'),
        isTrue,
      );
      expect(
        _argsHaveEncryptionSignal('token: value(aesencodedtoken)'),
        isTrue,
      );
    });

    test('does not match unencrypted as a single identifier (no false escape)', () {
      expect(
        _argsHaveEncryptionSignal('privatekey: value(unencrypted)'),
        isFalse,
      );
    });

    test('matches secure/encrypt in args (symmetric with receiver check)', () {
      expect(_argsHaveEncryptionSignal('key: x, value: secure'), isTrue);
    });
  });
}
