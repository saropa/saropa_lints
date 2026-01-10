// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: avoid_hardcoded_credentials
// Test fixture for cryptography rules

import 'dart:math';

void testCryptoRules() {
  // =========================================================================
  // avoid_hardcoded_encryption_keys
  // =========================================================================

  // BAD: Hardcoded encryption key
  // expect_lint: avoid_hardcoded_encryption_keys
  const encryptionKey = 'my-super-secret-key-12345';

  // expect_lint: avoid_hardcoded_encryption_keys
  final secretKey = 'another-secret-key-value';

  // GOOD: Key loaded from environment
  const envKey = String.fromEnvironment('ENCRYPTION_KEY');

  // =========================================================================
  // prefer_secure_random_for_crypto
  // =========================================================================

  // BAD: Using Random() for crypto purposes
  void generateIv() {
    // expect_lint: prefer_secure_random_for_crypto
    final random = Random();
    final iv = List.generate(16, (_) => random.nextInt(256));
  }

  // GOOD: Using Random.secure()
  void generateSecureIv() {
    final random = Random.secure();
    final iv = List.generate(16, (_) => random.nextInt(256));
  }

  // =========================================================================
  // avoid_deprecated_crypto_algorithms
  // =========================================================================

  // BAD: Using deprecated algorithms (simulated)
  void useDeprecatedCrypto() {
    // These would trigger if using crypto package:
    // md5.convert(...)
    // sha1.convert(...)
  }

  // GOOD: Using modern algorithms
  void useModernCrypto() {
    // sha256.convert(...)
    // sha512.convert(...)
  }

  // =========================================================================
  // require_unique_iv_per_encryption
  // =========================================================================

  // These should NOT trigger (false positive exclusions):
  void falsePositiveIvNames() {
    // Variable names containing "iv" that are NOT IVs
    final activity = 'user_action'; // "actIVity" - not an IV
    final privateName = 'secret'; // "prIVate" - not an IV
    final derivative = 42.0; // "derIVative" - not an IV
    final archives = <String>[]; // "archIVes" - not an IV
    final festival = 'holiday'; // "festIVal" - not an IV
  }
}
