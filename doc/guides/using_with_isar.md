# Using saropa_lints with Isar

This guide explains how saropa_lints enhances your Isar database development with specialized rules that catch data corruption patterns.

## Why This Matters

Isar is a fast NoSQL database for Flutter. But it has subtle patterns that cause **silent data corruption** - your app compiles and runs, but data gets corrupted when you modify your schema.

Standard linters see valid Dart code. saropa_lints understands Isar's serialization behavior.

## What saropa_lints Catches

### Enum Fields Cause Data Corruption

This is the most critical Isar issue. When you store enums directly, schema changes corrupt existing data:

```dart
// BAD - data corruption on schema changes
@collection
class User {
  Id id = Isar.autoIncrement;
  String name = '';
  CountryEnum country = CountryEnum.usa;  // DANGER!
}

enum CountryEnum { usa, canada, mexico }
```

**What goes wrong:**
1. User saves `country = CountryEnum.canada` (stored as index `1`)
2. You add a new country: `enum CountryEnum { usa, uk, canada, mexico }`
3. Now `uk` is index `1`, but existing data still has `1` stored
4. User's country silently changes from Canada to UK

```dart
// GOOD - store as string, immune to enum reordering
@collection
class User {
  Id id = Isar.autoIncrement;
  String name = '';

  String countryCode = 'usa';  // Store string representation

  @ignore
  CountryEnum get country => CountryEnum.values.firstWhere(
    (e) => e.name == countryCode,
    orElse: () => CountryEnum.usa,
  );

  set country(CountryEnum value) => countryCode = value.name;
}
```

**Rule**: `avoid_isar_enum_field`

### Database Connection Leaks

```dart
// BAD - database never closed
class UserRepository {
  Isar? _isar;

  Future<void> init() async {
    _isar = await Isar.open([UserSchema]);
  }

  // Missing close()!
}

// GOOD - proper lifecycle management
class UserRepository {
  Isar? _isar;

  Future<void> init() async {
    _isar = await Isar.open([UserSchema]);
  }

  Future<void> dispose() async {
    await _isar?.close();
  }
}
```

**Rule**: `require_database_close`

## Recommended Setup

### 1. Update pubspec.yaml

```yaml
dependencies:
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0

dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
  isar_generator: ^3.1.0
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
| `avoid_isar_enum_field` | essential | Enum fields that corrupt on schema changes |
| `require_database_close` | recommended | Unclosed database connections |
| `avoid_cached_isar_stream` | professional | Caching Isar query streams (runtime crash risk); quick fix to inline offending stream |

## Safe Enum Patterns

### Pattern 1: String Storage with Getter/Setter

```dart
@collection
class Settings {
  Id id = Isar.autoIncrement;

  // Store as string
  String themeCode = 'light';

  // Convenient typed access
  @ignore
  ThemeMode get theme => ThemeMode.values.firstWhere(
    (e) => e.name == themeCode,
    orElse: () => ThemeMode.light,
  );

  set theme(ThemeMode value) => themeCode = value.name;
}
```

### Pattern 2: Int with Explicit Mapping

```dart
@collection
class Order {
  Id id = Isar.autoIncrement;

  // Store explicit int values
  int statusCode = 0;

  @ignore
  OrderStatus get status => OrderStatus.fromCode(statusCode);

  set status(OrderStatus value) => statusCode = value.code;
}

enum OrderStatus {
  pending(0),
  processing(1),
  shipped(2),
  delivered(3),
  cancelled(100);  // Use large gaps for future additions

  const OrderStatus(this.code);
  final int code;

  static OrderStatus fromCode(int code) {
    return OrderStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => OrderStatus.pending,
    );
  }
}
```

### Pattern 3: Embedded Object for Complex Enums

```dart
@collection
class Product {
  Id id = Isar.autoIncrement;
  String name = '';

  // Use embedded object for complex enum data
  CategoryData category = CategoryData();
}

@embedded
class CategoryData {
  String code = '';
  String displayName = '';

  @ignore
  ProductCategory get category => ProductCategory.fromCode(code);
}
```

## Common Patterns

### Repository Pattern with Proper Lifecycle

```dart
class IsarDatabase {
  static Isar? _instance;

  static Future<Isar> getInstance() async {
    return _instance ??= await Isar.open(
      [UserSchema, SettingsSchema, OrderSchema],
      directory: await getApplicationDocumentsDirectory().then((d) => d.path),
    );
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}

// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarDatabase.getInstance();

  runApp(const MyApp());
@override
void dispose() {
  IsarDatabase.close();
  super.dispose();
}
```

### Batch Operations

```dart
// GOOD - batch writes in single transaction
Future<void> importUsers(List<User> users) async {
  final isar = await IsarDatabase.getInstance();
  await isar.writeTxn(() async {
    await isar.users.putAll(users);
  });
}

// BAD - individual writes (slow, more failure points)
Future<void> importUsers(List<User> users) async {
  final isar = await IsarDatabase.getInstance();
  for (final user in users) {
    await isar.writeTxn(() async {
      await isar.users.put(user);
    });
  }
}
```

**Rule**: `prefer_batch_database_operations`

## Migration Considerations

If you already have enum fields in production:

1. **Create a migration** to convert existing data
2. **Add the string field** alongside the enum field temporarily
3. **Migrate data** in a version check
4. **Remove the enum field** in a future release

```dart
@collection
class User {
  Id id = Isar.autoIncrement;

  @Deprecated('Use countryCode instead')
  CountryEnum? legacyCountry;  // Keep for migration

  String countryCode = '';  // New field

  static Future<void> migrate(Isar isar) async {
    final users = await isar.users.where().findAll();
    for (final user in users) {
      if (user.countryCode.isEmpty && user.legacyCountry != null) {
        user.countryCode = user.legacyCountry!.name;
      }
    }
    await isar.writeTxn(() => isar.users.putAll(users));
  }
}
```

## Contributing

Have ideas for more Isar rules? Found a pattern we should catch? Contributions are welcome!

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines on adding new rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)
- [Isar Documentation](https://isar.dev/)

---

Questions about Isar rules? Open an issue - we're happy to help.
