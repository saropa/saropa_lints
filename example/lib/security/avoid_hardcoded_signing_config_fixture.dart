// ignore_for_file: unused_local_variable, avoid_hardcoded_credentials
// Test fixture for avoid_hardcoded_signing_config rule (OWASP M7)

import 'dart:io';

// =============================================================================
// avoid_hardcoded_signing_config - String literals
// =============================================================================

void testKeystorePaths() {
  // BAD: Hardcoded keystore path
  // expect_lint: avoid_hardcoded_signing_config
  const path = 'app/release.keystore';

  // BAD: JKS file reference
  // expect_lint: avoid_hardcoded_signing_config
  const jks = 'upload-key.jks';

  // BAD: key.properties reference
  // expect_lint: avoid_hardcoded_signing_config
  const props = 'key.properties';
}

void testSigningConfigStrings() {
  // BAD: Signing config in string literal
  // expect_lint: avoid_hardcoded_signing_config
  final config = 'signingConfig { release }';
}

// =============================================================================
// avoid_hardcoded_signing_config - Variable names
// =============================================================================

void testSigningVariableNames() {
  // BAD: Variable name contains 'keystore'
  // expect_lint: avoid_hardcoded_signing_config
  const keystorePath = '/path/to/release.keystore';

  // BAD: Variable name contains 'keyalias'
  // expect_lint: avoid_hardcoded_signing_config
  const keyAlias = 'upload';

  // BAD: Variable name contains 'signingconfig'
  // expect_lint: avoid_hardcoded_signing_config
  const signingConfig = 'release';
}

// =============================================================================
// GOOD: Should NOT trigger
// =============================================================================

// GOOD: Environment variables (no string literal initializer)
void testEnvironmentVariables() {
  final keystorePath = Platform.environment['KEYSTORE_PATH'];
  final keyAlias = Platform.environment['KEY_ALIAS'];
}

// GOOD: Non-signing variable names
void testNonSigningVariables() {
  const databaseStore = 'myapp.db';
  const cacheStore = 'cache';
  const aliasName = 'John';
}
