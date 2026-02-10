// ignore_for_file: unused_local_variable, unused_element, unused_field
// ignore_for_file: avoid_catches_without_on_clauses, prefer_const_declarations
// Test fixture for error handling constructor rules

// =========================================================================
// avoid_exception_in_constructor
// =========================================================================
// Warns when constructors throw exceptions.
// Throwing in constructors makes error handling difficult because the
// object is never fully constructed.

// BAD: Throwing in generative constructor
class BadUserThrowsInConstructor {
  BadUserThrowsInConstructor(String email) {
    if (!_isValidEmail(email)) {
      // expect_lint: avoid_exception_in_constructor
      throw ArgumentError('Invalid email: $email');
    }
    _email = email;
  }

  late final String _email;
}

// BAD: Throwing in named constructor
class BadProductThrowsInNamedConstructor {
  BadProductThrowsInNamedConstructor.fromPrice(double price) {
    if (price < 0) {
      // expect_lint: avoid_exception_in_constructor
      throw ArgumentError('Price cannot be negative');
    }
    _price = price;
  }

  late final double _price;
}

// BAD: Multiple throws in constructor
class BadConfigThrowsMultiple {
  BadConfigThrowsMultiple(String host, int port) {
    if (host.isEmpty) {
      // expect_lint: avoid_exception_in_constructor
      throw ArgumentError('Host cannot be empty');
    }
    if (port < 0 || port > 65535) {
      // expect_lint: avoid_exception_in_constructor
      throw RangeError('Port must be between 0 and 65535');
    }
    _host = host;
    _port = port;
  }

  late final String _host;
  late final int _port;
}

// GOOD: Factory constructor can throw (creates nothing on failure)
class GoodUserWithFactory {
  GoodUserWithFactory._(this.email);
  final String email;

  factory GoodUserWithFactory(String email) {
    if (!_isValidEmail(email)) {
      throw ArgumentError('Invalid email: $email'); // OK in factory
    }
    return GoodUserWithFactory._(email);
  }
}

// GOOD: Static method that returns null on failure
class GoodUserWithTryCreate {
  GoodUserWithTryCreate._(this.email);
  final String email;

  static GoodUserWithTryCreate? tryCreate(String email) {
    if (!_isValidEmail(email)) return null;
    return GoodUserWithTryCreate._(email);
  }
}

// GOOD: Using assert for debug-only validation (not a throw expression)
class GoodUserWithAssert {
  GoodUserWithAssert(this.email) : assert(email.isNotEmpty);
  final String email;
}

// GOOD: Static method with Result-like pattern
class GoodUserWithResult {
  GoodUserWithResult._(this.email);
  final String email;

  static ({GoodUserWithResult? user, String? error}) create(String email) {
    if (!_isValidEmail(email)) {
      return (user: null, error: 'Invalid email format');
    }
    return (user: GoodUserWithResult._(email), error: null);
  }
}

// =========================================================================
// require_cache_key_determinism
// =========================================================================
// Warns when cache keys use non-deterministic values.
// Cache keys must produce the same value for the same input.

// BAD: Using DateTime.now() in cache key
void badCacheKeyWithDateTime() {
  // expect_lint: require_cache_key_determinism
  final cacheKey = 'user_${DateTime.now().millisecondsSinceEpoch}';
}

// BAD: Using hashCode in cache key (changes between runs)
void badCacheKeyWithHashCode(Object obj) {
  // expect_lint: require_cache_key_determinism
  final key = 'item_${obj.hashCode}';
}

// BAD: Using identityHashCode in cache key
void badCacheKeyWithIdentityHashCode(Object obj) {
  // expect_lint: require_cache_key_determinism
  final cacheKey = 'object_${identityHashCode(obj)}';
}

// BAD: Using random UUID in cache key
void badCacheKeyWithUuid() {
  // expect_lint: require_cache_key_determinism
  final key = 'session_${Uuid().v4()}';
}

// BAD: Using Random in cache key
void badCacheKeyWithRandom() {
  // expect_lint: require_cache_key_determinism
  final cacheKey = 'random_${Random().nextInt(1000)}';
}

// GOOD: Using stable ID in cache key
void goodCacheKeyWithId(String userId) {
  final cacheKey = 'user_$userId'; // Deterministic
}

// GOOD: Using composite stable keys
void goodCacheKeyComposite(String userId, String itemId) {
  final key = 'user_${userId}_item_$itemId'; // Deterministic
}

// GOOD: Using DateTime.now() in debugLabel (debug-only parameter)
void goodDebugLabelWithDateTime() {
  final key = GlobalKey(debugLabel: 'created_${DateTime.now()}'); // OK
}

// GOOD: Flutter widget keys are not cache keys
void goodFlutterWidgetKey() {
  final key = GlobalKey(); // Widget identity, not cache key
  final valueKey = ValueKey('some_id'); // Widget key, not cache key
  final uniqueKey = UniqueKey(); // Intentionally unique widget key
}

// GOOD: Constructor with deterministic key and metadata DateTime.now()
void goodConstructorWithMetadataTimestamp(String userId) {
  final cacheKey = MockCacheEntry(
    key: userId,
    value: 'some_value',
    createdAt: DateTime.now(), // Metadata — should NOT trigger
  );
}

// GOOD: Constructor with multiple metadata timestamps
void goodConstructorWithMultipleMetadata(String userId) {
  final cacheKey = MockCacheEntry(
    key: userId,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(), // Both are metadata — should NOT trigger
  );
}

// BAD: Constructor where the key argument itself is non-deterministic
void badConstructorWithNonDeterministicKey() {
  // expect_lint: require_cache_key_determinism
  final cacheKey = MockCacheEntry(
    key: 'user_${DateTime.now().millisecondsSinceEpoch}',
    value: 'some_value',
  );
}

// GOOD: Variable not ending with 'key' — Check 1 should skip entirely
void goodCacheEntryNotNamedKey() {
  final cacheEntry = MockCacheEntry(
    key: 'stable_key',
    createdAt: DateTime.now(), // Should NOT trigger — variable isn't *key
  );
}

// =========================================================================
// require_permission_permanent_denial_handling
// =========================================================================
// Warns when permission denials aren't handled with settings redirect.
// When permissions are permanently denied, apps should guide users to settings.

// BAD: Permission request without permanent denial handling
Future<void> badPermissionRequestNoHandling() async {
  // expect_lint: require_permission_permanent_denial_handling
  final status = await Permission.camera.request();
  if (status.isDenied) {
    // Just giving up - user is stuck!
  }
}

// BAD: Only checking isDenied (not isPermanentlyDenied)
Future<void> badPermissionOnlyDeniedCheck() async {
  // expect_lint: require_permission_permanent_denial_handling
  final status = await Permission.location.request();
  if (status.isDenied) {
    showMessage('Permission denied');
  } else if (status.isGranted) {
    accessLocation();
  }
  // Missing isPermanentlyDenied handling!
}

// BAD: Multiple permission requests without permanent denial handling
Future<void> badMultiplePermissions() async {
  // expect_lint: require_permission_permanent_denial_handling
  final camera = await Permission.camera.request();
  // expect_lint: require_permission_permanent_denial_handling
  final microphone = await Permission.microphone.request();
  // No permanent denial handling for either!
}

// GOOD: Handling permanent denial with openAppSettings
Future<void> goodPermissionWithSettingsRedirect() async {
  final status = await Permission.camera.request();
  if (status.isPermanentlyDenied) {
    await openAppSettings(); // Guide user to enable manually
  } else if (status.isDenied) {
    showMessage('Camera permission is required');
  }
}

// GOOD: Comprehensive permission handling
Future<bool> goodPermissionComprehensive() async {
  var status = await Permission.camera.status;

  if (status.isDenied) {
    status = await Permission.camera.request();
  }

  if (status.isGranted) {
    return true;
  }

  if (status.isPermanentlyDenied) {
    final opened = await openAppSettings();
    if (opened) {
      showMessage('Please enable camera permission in settings');
    }
    return false;
  }

  return false;
}

// GOOD: Using a permission helper with built-in permanent denial handling
Future<void> goodPermissionWithHelper() async {
  final granted = await requestPermissionWithSettings(Permission.storage);
  if (!granted) {
    showMessage('Storage permission required');
  }
}

// =========================================================================
// Helper mocks
// =========================================================================

bool _isValidEmail(String email) => email.contains('@');

void showMessage(String message) {}

void accessLocation() {}

Future<bool> requestPermissionWithSettings(dynamic permission) async => true;

Future<bool> openAppSettings() async => true;

// Mock Permission class
class Permission {
  static const camera = Permission._('camera');
  static const location = Permission._('location');
  static const microphone = Permission._('microphone');
  static const storage = Permission._('storage');

  const Permission._(this.name);
  final String name;

  Future<PermissionStatus> get status async => PermissionStatus.denied;
  Future<PermissionStatus> request() async => PermissionStatus.denied;
}

// Mock PermissionStatus
class PermissionStatus {
  const PermissionStatus._(this._value);
  final int _value;

  static const denied = PermissionStatus._(0);
  static const granted = PermissionStatus._(1);
  static const permanentlyDenied = PermissionStatus._(2);

  bool get isDenied => _value == 0;
  bool get isGranted => _value == 1;
  bool get isPermanentlyDenied => _value == 2;
}

// Mock GlobalKey
class GlobalKey {
  GlobalKey({this.debugLabel});
  final String? debugLabel;
}

// Mock ValueKey
class ValueKey<T> {
  const ValueKey(this.value);
  final T value;
}

// Mock UniqueKey
class UniqueKey {}

// Mock Uuid
class Uuid {
  String v4() => 'mock-uuid';
}

// Mock Random
class Random {
  int nextInt(int max) => 0;
}

// Mock MockCacheEntry for constructor-based cache key tests
class MockCacheEntry {
  MockCacheEntry({
    required this.key,
    this.value,
    this.createdAt,
    this.updatedAt,
    this.ttl,
  });
  final String key;
  final String? value;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? ttl;
}
