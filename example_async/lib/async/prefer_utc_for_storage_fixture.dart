// ignore_for_file: unused_local_variable, avoid_print
// Test fixture for prefer_utc_for_storage rule

// Mock classes for testing
class Database {
  Future<void> insert(Map<String, dynamic> data) async {}
  Future<void> update(Map<String, dynamic> data) async {}
  Future<void> save(Map<String, dynamic> data) async {}
}

class SharedPreferences {
  Future<bool> setString(String key, String value) async => true;
}

class Cache {
  void put(String key, dynamic value) {}
  void cache(String key, dynamic value) {}
  void persist(String key, dynamic value) {}
}

void testPreferUtcForStorage() async {
  final db = Database();
  final prefs = SharedPreferences();
  final cache = Cache();
  final now = DateTime.now();
  final createdAt = DateTime.now();

  // =========================================================================
  // BAD: DateTime serialized without UTC conversion in storage contexts
  // =========================================================================

  // Database insert
  // expect_lint: prefer_utc_for_storage
  await db.insert({'timestamp': DateTime.now().toIso8601String()});

  // Database update
  // expect_lint: prefer_utc_for_storage
  await db.update({'modified': now.toIso8601String()});

  // Database save
  // expect_lint: prefer_utc_for_storage
  await db.save({'created': createdAt.toIso8601String()});

  // SharedPreferences
  // expect_lint: prefer_utc_for_storage
  await prefs.setString('lastSync', DateTime.now().toIso8601String());

  // Cache operations
  // expect_lint: prefer_utc_for_storage
  cache.put('timestamp', now.toIso8601String());

  // expect_lint: prefer_utc_for_storage
  cache.cache('expires', DateTime.now().toIso8601String());

  // expect_lint: prefer_utc_for_storage
  cache.persist('saved', now.toIso8601String());

  // Milliseconds epoch
  // expect_lint: prefer_utc_for_storage
  await db.insert({'epoch': DateTime.now().millisecondsSinceEpoch});

  // Microseconds epoch
  // expect_lint: prefer_utc_for_storage
  await db.insert({'microEpoch': DateTime.now().microsecondsSinceEpoch});

  // =========================================================================
  // GOOD: DateTime converted to UTC before storage
  // =========================================================================

  // Database with UTC
  await db.insert({'timestamp': DateTime.now().toUtc().toIso8601String()});

  // Variable with UTC
  await db.update({'modified': now.toUtc().toIso8601String()});

  // SharedPreferences with UTC
  await prefs.setString('lastSync', DateTime.now().toUtc().toIso8601String());

  // Cache with UTC
  cache.put('timestamp', now.toUtc().toIso8601String());

  // Epoch with UTC
  await db.insert({'epoch': DateTime.now().toUtc().millisecondsSinceEpoch});

  // Already UTC DateTime
  final utcNow = DateTime.now().toUtc();
  await db.insert({'timestamp': utcNow.toIso8601String()});

  // DateTime.utc constructor
  final utcDate = DateTime.utc(2024, 1, 15);
  await db.insert({'timestamp': utcDate.toIso8601String()});

  // =========================================================================
  // GOOD: DateTime serialization outside storage context (no lint)
  // =========================================================================

  // Logging - not storage
  print('Current time: ${DateTime.now().toIso8601String()}');

  // Display formatting - not storage
  final displayTime = DateTime.now().toIso8601String();

  // Local variable - not in storage context
  final timestamp = now.toIso8601String();
}

// Test toJson serialization context
class UserModel {
  final String name;
  final DateTime createdAt;

  UserModel(this.name, this.createdAt);

  // BAD: toJson without UTC
  Map<String, dynamic> toJsonBad() {
    return {
      'name': name,
      // expect_lint: prefer_utc_for_storage
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // GOOD: toJson with UTC
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  // BAD: toMap without UTC
  Map<String, dynamic> toMapBad() {
    return {
      'name': name,
      // expect_lint: prefer_utc_for_storage
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // GOOD: toMap with UTC
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}

// Test serialize context
class DataSerializer {
  // BAD: serialize without UTC
  String serializeBad(DateTime date) {
    // expect_lint: prefer_utc_for_storage
    return serialize(date.toIso8601String());
  }

  // GOOD: serialize with UTC
  String serializeGood(DateTime date) {
    return serialize(date.toUtc().toIso8601String());
  }

  String serialize(String data) => data;
}

// Test encode context
class JsonEncoder {
  // BAD: encode without UTC
  String encodeBad(DateTime date) {
    // expect_lint: prefer_utc_for_storage
    return encode({'date': date.toIso8601String()});
  }

  // GOOD: encode with UTC
  String encodeGood(DateTime date) {
    return encode({'date': date.toUtc().toIso8601String()});
  }

  String encode(Map<String, dynamic> data) => data.toString();
}
