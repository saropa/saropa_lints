// ignore_for_file: unused_local_variable, avoid_hardcoded_encryption_keys
// Test fixture for avoid_hardcoded_credentials rule

void testHardcodedCredentials() {
  // BAD: Hardcoded credentials should trigger lint
  // expect_lint: avoid_hardcoded_credentials
  const password = 'secret123';

  // expect_lint: avoid_hardcoded_credentials
  const apiKey = 'sk-1234567890abcdef';

  // cspell:disable-next-line
  // expect_lint: avoid_hardcoded_credentials
  const token = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

  // expect_lint: avoid_hardcoded_credentials
  final secret = 'my_secret_key';

  // GOOD: Environment variables (should NOT trigger)
  const envPassword = String.fromEnvironment('PASSWORD');
}
