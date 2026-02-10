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

// =============================================================================
// Security Rules (from v4.1.5)
// =============================================================================

Future<void> testSecureStorageWithoutErrorHandling() async {
  final storage = FlutterSecureStorage();
  // expect_lint: require_secure_storage_error_handling
  await storage.read(key: 'token');
}

Future<void> testSecureStorageLargeData() async {
  final storage = FlutterSecureStorage();
  // expect_lint: avoid_secure_storage_large_data
  await storage.write(key: 'data', value: jsonEncode(largeObject));
}

// GOOD: Secure storage with error handling
Future<void> testSecureStorageWithErrorHandling() async {
  final storage = FlutterSecureStorage();
  try {
    await storage.read(key: 'token');
  } catch (e) {
    print('Error: $e');
  }
}

// Mock classes
class FlutterSecureStorage {
  Future<String?> read({required String key}) async => null;
  Future<void> write({required String key, required String value}) async {}
}

String jsonEncode(Object obj) => '{}';
final Object largeObject = Object();

// =============================================================================
// Security Rules (from v4.1.7)
// =============================================================================

// BAD: Sensitive data copied to clipboard
void copySensitiveData(String password) {
  // expect_lint: avoid_sensitive_data_in_clipboard
  ClipboardDemo.setData(ClipboardDataDemo(text: password));
}

// BAD: Encryption key kept in memory
class BadEncryptionService {
  // expect_lint: avoid_encryption_key_in_memory
  String _encryptionKey = 'my-secret-key';

  void encrypt(String data) {
    // Uses _encryptionKey
  }
}

// GOOD: Key retrieved when needed, cleared after
class GoodEncryptionService {
  Future<void> encrypt(String data) async {
    final key = await getKeyFromSecureStorage();
    try {
      // Use key for encryption
    } finally {
      // Clear key reference
    }
  }

  Future<String> getKeyFromSecureStorage() async => '';
}

// Mock classes for security rules
class ClipboardDemo {
  static void setData(ClipboardDataDemo data) {}
}

class ClipboardDataDemo {
  ClipboardDataDemo({this.text});
  final String? text;
}
