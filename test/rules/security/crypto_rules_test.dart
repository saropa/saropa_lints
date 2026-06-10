import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart' show RuleType;
import 'package:saropa_lints/src/rules/security/crypto_rules.dart';
import 'package:test/test.dart';

/// Tests for 5 Cryptography lint rules.
///
/// Test fixtures: example/lib/crypto/*
// Random, hashing, and key material patterns; security-focused small cases.
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

  group('Cryptography Rules - metadata (CWE, ruleType)', () {
    test('hardcoded key rule maps to CWE-798 and vulnerability', () {
      final rule = AvoidHardcodedEncryptionKeysRule();
      expect(rule.ruleType, RuleType.vulnerability);
      expect(rule.cweIds, contains(798));
    });
    test('secure random rule maps to CWE-330', () {
      final rule = PreferSecureRandomForCryptoRule();
      expect(rule.cweIds, contains(330));
    });
    test('deprecated algorithms rule maps to CWE-327', () {
      final rule = AvoidDeprecatedCryptoAlgorithmsRule();
      expect(rule.cweIds, contains(327));
    });
    test('unique IV rule maps to CWE-329', () {
      final rule = RequireUniqueIvPerEncryptionRule();
      expect(rule.cweIds, contains(329));
    });
    test(
      'secure key generation maps to CWE-335 (predictable PRNG / key material)',
      () {
        final rule = RequireSecureKeyGenerationRule();
        expect(rule.cweIds, contains(335));
      },
    );
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
        final file = File('example/lib/crypto/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
