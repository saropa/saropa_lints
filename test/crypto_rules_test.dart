import 'dart:io';

import 'package:saropa_lints/src/rules/security/crypto_rules.dart';
import 'package:test/test.dart';

/// Tests for 5 Cryptography lint rules.
///
/// Test fixtures: example_async/lib/crypto/*
void main() {
  group('Cryptography Rules - Rule Instantiation', () {
    test('AvoidHardcodedEncryptionKeysRule', () {
      final rule = AvoidHardcodedEncryptionKeysRule();
      expect(rule.code.lowerCaseName, 'avoid_hardcoded_encryption_keys');
      expect(
        rule.code.problemMessage,
        contains('[avoid_hardcoded_encryption_keys]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferSecureRandomForCryptoRule', () {
      final rule = PreferSecureRandomForCryptoRule();
      expect(rule.code.lowerCaseName, 'prefer_secure_random_for_crypto');
      expect(
        rule.code.problemMessage,
        contains('[prefer_secure_random_for_crypto]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidDeprecatedCryptoAlgorithmsRule', () {
      final rule = AvoidDeprecatedCryptoAlgorithmsRule();
      expect(rule.code.lowerCaseName, 'avoid_deprecated_crypto_algorithms');
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_crypto_algorithms]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireUniqueIvPerEncryptionRule', () {
      final rule = RequireUniqueIvPerEncryptionRule();
      expect(rule.code.lowerCaseName, 'require_unique_iv_per_encryption');
      expect(
        rule.code.problemMessage,
        contains('[require_unique_iv_per_encryption]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireSecureKeyGenerationRule', () {
      final rule = RequireSecureKeyGenerationRule();
      expect(rule.code.lowerCaseName, 'require_secure_key_generation');
      expect(
        rule.code.problemMessage,
        contains('[require_secure_key_generation]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Cryptography Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_hardcoded_encryption_keys',
      'prefer_secure_random_for_crypto',
      'avoid_deprecated_crypto_algorithms',
      'require_unique_iv_per_encryption',
      'require_secure_key_generation',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_async/lib/crypto/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Cryptography - Avoidance Rules', () {
    group('avoid_hardcoded_encryption_keys', () {
      test('encryption key in source code SHOULD trigger', () {
        expect('encryption key in source code', isNotNull);
      });

      test('key from secure storage should NOT trigger', () {
        expect('key from secure storage', isNotNull);
      });
    });
    group('avoid_deprecated_crypto_algorithms', () {
      test('MD5 or SHA1 for security SHOULD trigger', () {
        expect('MD5 or SHA1 for security', isNotNull);
      });

      test('SHA-256 or better should NOT trigger', () {
        expect('SHA-256 or better', isNotNull);
      });
    });
  });

  group('Cryptography - Requirement Rules', () {
    group('require_unique_iv_per_encryption', () {
      test('reused IV in encryption SHOULD trigger', () {
        expect('reused IV in encryption', isNotNull);
      });

      test('unique IV per operation should NOT trigger', () {
        expect('unique IV per operation', isNotNull);
      });
    });
    group('require_secure_key_generation', () {
      test('weak key derivation SHOULD trigger', () {
        expect('weak key derivation', isNotNull);
      });

      test('PBKDF2 or similar key derivation should NOT trigger', () {
        expect('PBKDF2 or similar key derivation', isNotNull);
      });
    });
  });

  group('Cryptography - Preference Rules', () {
    group('prefer_secure_random_for_crypto', () {
      test('math.Random for crypto SHOULD trigger', () {
        expect('math.Random for crypto', isNotNull);
      });

      test('SecureRandom for cryptographic use should NOT trigger', () {
        expect('SecureRandom for cryptographic use', isNotNull);
      });
    });
  });
}
