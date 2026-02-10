// Test fixture for no_magic_string_in_tests rule
// ignore_for_file: avoid_hardcoded_config, avoid_api_key_in_code
// ignore_for_file: avoid_hardcoded_credentials

void badExamples() {
  // LINT: Domain-specific strings should be named constants
  final user = User(email: 'user@example.com'); // LINT
  final url = 'https://api.example.com/users'; // LINT
  final hexColor = '7FfFfFfFfFfFfFfF'; // LINT
  final apiKey = 'sk-1234567890abcdef'; // LINT
}

void goodExamples() {
  // Named constants for domain values
  const testEmail = 'user@example.com';
  final user = User(email: testEmail);

  const apiUrl = 'https://api.example.com/users';
  final url = apiUrl;

  // Allowed short strings
  final letter = 'a'; // OK: Single letter
  final placeholder = 'foo'; // OK: Common test placeholder
  final empty = ''; // OK: Empty string
  final separator = ', '; // OK: Common punctuation

  // Test descriptions (automatically allowed)
  testFunction('validates email', () {}); // OK: Test description

  // Regex patterns (automatically detected)
  final regex = RegExp(r'\d+'); // OK: Regex pattern
  final pattern = RegExp(r'^[a-z]+$'); // OK: Regex pattern

  // Const context
  const appName = 'My Test App'; // OK: In const context
}

void testFunction(String description, void Function() callback) {
  callback();
}

class User {
  final String email;
  User({required this.email});
}
