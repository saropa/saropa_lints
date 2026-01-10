// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: avoid_hardcoded_credentials
// Test fixture for cryptography rules

import 'dart:math';

// Mock classes to simulate encryption libraries
class Key {
  Key.fromUtf8(String data);
  Key.fromBase64(String data);
}

class SecretKey {
  SecretKey.fromUtf8(String data);
}

class CipherKey {
  CipherKey.fromUtf8(String data);
}

void testCryptoRules() {
  // =========================================================================
  // avoid_hardcoded_encryption_keys
  // =========================================================================
  //
  // This rule ONLY flags encryption library Key constructors with string
  // literals. It does NOT flag variables just because they have "key" in
  // their name - that approach produces too many false positives.

  // BAD: Hardcoded key in encryption library constructor
  // expect_lint: avoid_hardcoded_encryption_keys
  final key1 = Key.fromUtf8('my-super-secret-key-12345');

  // expect_lint: avoid_hardcoded_encryption_keys
  final key2 = Key.fromBase64('bXktc2VjcmV0LWtleQ==');

  // expect_lint: avoid_hardcoded_encryption_keys
  final key3 = SecretKey.fromUtf8('another-hardcoded-key');

  // expect_lint: avoid_hardcoded_encryption_keys
  final key4 = CipherKey.fromUtf8('cipher-key-value-123');

  // GOOD: Key loaded from variable (not hardcoded literal)
  final keyFromEnv = const String.fromEnvironment('ENCRYPTION_KEY');
  final goodKey = Key.fromUtf8(keyFromEnv);

  // GOOD: These variables have "key" in the name but are NOT encryption keys.
  // We intentionally don't flag these - variable name matching is unreliable.
  const jsonKeyName = 'userId'; // JSON field name
  const primaryKey = 'id'; // Database key
  const keyboardShortcut = 'Ctrl+C'; // UI shortcut
  const searchKeyword = 'flutter encryption'; // Search term

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
