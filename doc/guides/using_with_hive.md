# Using saropa_lints with Hive

This guide explains how saropa_lints enhances your Hive database development with specialized rules that catch common anti-patterns and security issues.

## Why This Matters

Hive is a lightweight, fast key-value database for Flutter. But it has patterns that cause **runtime errors, memory leaks, and security vulnerabilities** - your app compiles fine but fails in production.

Standard linters see valid Dart code. saropa_lints understands Hive's requirements.

## What Hive Issues Are Caught

| Issue Type | What Happens | Rule |
|------------|--------------|------|
| Missing initialization | Runtime crash | `require_hive_initialization` |
| Missing type adapter | Runtime crash | `require_hive_type_adapter` |
| Unclosed boxes | Memory/file handle leak | `require_hive_box_close` |
| Unencrypted sensitive data | Security vulnerability | `prefer_hive_encryption` |
| Hardcoded encryption key | Key extractable from APK | `require_hive_encryption_key_secure` |
| Missing adapter registration | Runtime crash | `require_type_adapter_registration` |
| Large data in regular box | Memory bloat | `prefer_lazy_box_for_large` |
| Database not closed | Resource leak | `require_hive_database_close` |
| Missing field default value | Null errors on migration | `require_hive_field_default_value` |
| Wrong adapter registration order | Runtime crash | `require_hive_adapter_registration_order` |
| Missing nested object adapter | Runtime crash | `require_hive_nested_object_adapter` |
| Duplicate box names | Data corruption | `avoid_hive_box_name_collision` |

## What saropa_lints Catches

### Missing Hive Initialization

```dart
// BAD - crashes at runtime
void main() async {
  final box = await Hive.openBox('settings');  // Hive not initialized!
  runApp(MyApp());
}

// GOOD - initialize first
void main() async {
  await Hive.initFlutter();
  final box = await Hive.openBox('settings');
  runApp(MyApp());
}
```

**Rule**: `require_hive_initialization`

### Missing Type Adapter

```dart
// BAD - runtime error when storing custom objects
class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

final box = await Hive.openBox('users');
box.put('user1', User('John', 30));  // Crash!

// GOOD - annotate with @HiveType and generate adapter
@HiveType(typeId: 0)
class User {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int age;

  User(this.name, this.age);
}

// In main()
Hive.registerAdapter(UserAdapter());
final box = await Hive.openBox<User>('users');
box.put('user1', User('John', 30));  // Works!
```

**Rule**: `require_hive_type_adapter`

### Unclosed Hive Boxes

```dart
// BAD - box never closed
class UserService {
  late Box<User> _box;

  Future<void> init() async {
    _box = await Hive.openBox<User>('users');
  }

  // Missing dispose!
}

// GOOD - close box when done
class UserService {
  late Box<User> _box;

  Future<void> init() async {
    _box = await Hive.openBox<User>('users');
  }

  Future<void> dispose() async {
    await _box.close();
  }
}
```

**Rule**: `require_hive_box_close`

### Unencrypted Sensitive Data

```dart
// BAD - sensitive data stored in plain text
final box = await Hive.openBox('secrets');
box.put('password', userPassword);  // Extractable from device!
box.put('api_token', apiToken);

// GOOD - use encrypted box for sensitive data
final key = await secureStorage.read(key: 'hive_key');
final encryptedBox = await Hive.openBox(
  'secrets',
  encryptionCipher: HiveAesCipher(base64.decode(key!)),
);
encryptedBox.put('password', userPassword);
```

**Rule**: `prefer_hive_encryption`

### Hardcoded Encryption Key

```dart
// BAD - key can be extracted from APK
final cipher = HiveAesCipher(
  base64.decode('hardcodedKeyHere=='),  // Visible in binary!
);

// BAD - list literal is also hardcoded
final cipher = HiveAesCipher([1, 2, 3, 4, 5, 6, 7, 8, ...]);

// GOOD - store key securely
final keyString = await FlutterSecureStorage().read(key: 'hive_key');
if (keyString == null) {
  // Generate and store new key
  final newKey = Hive.generateSecureKey();
  await FlutterSecureStorage().write(
    key: 'hive_key',
    value: base64.encode(newKey),
  );
  keyString = base64.encode(newKey);
}
final cipher = HiveAesCipher(base64.decode(keyString));
```

**Rule**: `require_hive_encryption_key_secure`

### Large Data in Regular Box

```dart
// BAD - loads ALL products into memory at open time
final box = await Hive.openBox<Product>('products');
final product = box.get('id123');

// GOOD - lazy box only loads requested items
final box = await Hive.openLazyBox<Product>('products');
final product = await box.get('id123');  // Note: async
```

**Rule**: `prefer_lazy_box_for_large`

### Missing Field Default Value

```dart
// BAD - new field without default value breaks existing data
@HiveType(typeId: 0)
class User {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int age;

  @HiveField(2)  // Added later - existing data doesn't have this!
  final String email;

  User(this.name, this.age, this.email);
}

// GOOD - provide default value for new fields
@HiveType(typeId: 0)
class User {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int age;

  @HiveField(2, defaultValue: '')  // Safe for existing data
  final String email;

  User(this.name, this.age, this.email);
}
```

**Rule**: `require_hive_field_default_value`

### Wrong Adapter Registration Order

```dart
// BAD - Address adapter registered after User adapter
@HiveType(typeId: 0)
class Address {
  @HiveField(0)
  final String street;
  Address(this.street);
}

@HiveType(typeId: 1)
class User {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final Address address;  // Nested type

  User(this.name, this.address);
}

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(UserAdapter());    // Wrong order!
  Hive.registerAdapter(AddressAdapter()); // Should be first
}

// GOOD - register nested type adapters first
void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(AddressAdapter()); // Nested type first
  Hive.registerAdapter(UserAdapter());    // Parent type after
}
```

**Rule**: `require_hive_adapter_registration_order`

### Missing Nested Object Adapter

```dart
// BAD - Address is used in User but not marked as @HiveType
class Address {
  final String street;
  final String city;
  Address(this.street, this.city);
}

@HiveType(typeId: 0)
class User {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final Address address;  // Runtime crash - no adapter!

  User(this.name, this.address);
}

// GOOD - all nested objects have @HiveType
@HiveType(typeId: 0)
class Address {
  @HiveField(0)
  final String street;

  @HiveField(1)
  final String city;

  Address(this.street, this.city);
}

@HiveType(typeId: 1)
class User {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final Address address;  // Works - Address has adapter

  User(this.name, this.address);
}
```

**Rule**: `require_hive_nested_object_adapter`

### Box Name Collision

```dart
// BAD - same box name for different types
final userBox = await Hive.openBox<User>('data');
final settingsBox = await Hive.openBox<Settings>('data');  // Collision!

// BAD - inconsistent generic type for same box name
final box1 = await Hive.openBox<User>('users');
final box2 = await Hive.openBox('users');  // Missing generic - returns dynamic

// GOOD - unique box names per type
final userBox = await Hive.openBox<User>('users');
final settingsBox = await Hive.openBox<Settings>('settings');

// GOOD - consistent generic types
final box1 = await Hive.openBox<User>('users');
final box2 = Hive.box<User>('users');  // Same type
```

**Rule**: `avoid_hive_box_name_collision`

## Recommended Setup

### 1. Update pubspec.yaml

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.0.0  # For encryption keys

dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.0.0
  hive_generator: ^2.0.1
  build_runner: ^2.4.0
```

### 2. Update analysis_options.yaml

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  saropa_lints:
    tier: recommended  # essential | recommended | professional | comprehensive | insanity
```

### 3. Run the linter

```bash
dart run custom_lint
```

## Rule Summary

| Rule | Tier | What It Catches |
|------|------|-----------------|
| `require_hive_initialization` | essential | openBox without init check |
| `require_hive_type_adapter` | essential | Custom objects without @HiveType |
| `require_hive_box_close` | essential | Boxes opened but never closed |
| `prefer_hive_encryption` | recommended | Sensitive data in plain text |
| `require_hive_encryption_key_secure` | essential | Hardcoded encryption keys |
| `require_type_adapter_registration` | recommended | Typed box without adapter registration |
| `prefer_lazy_box_for_large` | recommended | Large collections in regular boxes |
| `require_hive_database_close` | recommended | Database connections not closed |
| `require_hive_field_default_value` | recommended | New @HiveField without defaultValue |
| `require_hive_adapter_registration_order` | essential | Nested adapters registered after parent |
| `require_hive_nested_object_adapter` | essential | Nested objects missing @HiveType |
| `avoid_hive_box_name_collision` | essential | Same box name used for different types |

## Common Patterns

### Proper Hive Initialization

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register ALL adapters before opening boxes
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(SettingsAdapter());
  Hive.registerAdapter(CacheItemAdapter());

  // Open boxes
  await Hive.openBox<User>('users');
  await Hive.openBox<Settings>('settings');

  runApp(const MyApp());
}
```

### Secure Encryption Key Management

```dart
class HiveEncryption {
  static const _keyName = 'hive_encryption_key';
  static final _secureStorage = FlutterSecureStorage();

  static Future<List<int>> getOrCreateKey() async {
    final existingKey = await _secureStorage.read(key: _keyName);

    if (existingKey != null) {
      return base64.decode(existingKey);
    }

    // Generate new key
    final newKey = Hive.generateSecureKey();
    await _secureStorage.write(
      key: _keyName,
      value: base64.encode(newKey),
    );
    return newKey;
  }

  static Future<Box<T>> openEncryptedBox<T>(String name) async {
    final key = await getOrCreateKey();
    return Hive.openBox<T>(
      name,
      encryptionCipher: HiveAesCipher(key),
    );
  }
}

// Usage
final secretsBox = await HiveEncryption.openEncryptedBox<String>('secrets');
```

### @HiveField Index Best Practices

```dart
@HiveType(typeId: 0)
class User {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  // IMPORTANT: Never reuse deleted field indices!
  // If you remove a field, skip its index forever

  // @HiveField(3) - DELETED, never reuse
  // @HiveField(4) - DELETED, never reuse

  @HiveField(5)  // New field uses next available
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });
}
```

### Box Lifecycle in Flutter Widget

```dart
class UserListScreen extends StatefulWidget {
  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late Box<User> _userBox;

  @override
  void initState() {
    super.initState();
    _userBox = Hive.box<User>('users');  // Already opened in main
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _userBox.listenable(),
      builder: (context, Box<User> box, _) {
        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final user = box.getAt(index);
            return ListTile(title: Text(user?.name ?? ''));
          },
        );
      },
    );
  }

  // Don't close box here - it's shared app-wide
}
```

## Migration from SharedPreferences

If migrating from SharedPreferences to Hive:

```dart
class MigrationService {
  static Future<void> migrateFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final box = await Hive.openBox('settings');

    // Check if already migrated
    if (box.get('migrated') == true) return;

    // Migrate values
    final theme = prefs.getString('theme');
    if (theme != null) {
      box.put('theme', theme);
    }

    final language = prefs.getString('language');
    if (language != null) {
      box.put('language', language);
    }

    // Mark as migrated
    box.put('migrated', true);

    // Optionally clear SharedPreferences
    // await prefs.clear();
  }
}
```

## Contributing

Have ideas for more Hive rules? Found a pattern we should catch? Contributions are welcome!

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines on adding new rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)
- [Hive Documentation](https://pub.dev/packages/hive)

---

Questions about Hive rules? Open an issue - we're happy to help.
