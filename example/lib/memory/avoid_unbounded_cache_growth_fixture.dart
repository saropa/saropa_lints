// ignore_for_file: unused_field, unused_element
// Test fixture for avoid_unbounded_cache_growth rule

import 'dart:typed_data';

// =============================================================================
// BAD: In-memory cache without size limit - should trigger
// =============================================================================

// expect_lint: avoid_unbounded_cache_growth
class ImageCache {
  final Map<String, Uint8List> _cache = {};

  void cache(String url, Uint8List data) {
    _cache[url] = data;
  }

  Uint8List? get(String url) => _cache[url];
}

// expect_lint: avoid_unbounded_cache_growth
class MemoizedCalculator {
  final Map<int, int> _memo = {};

  int fibonacci(int n) {
    if (n <= 1) return n;
    return _memo[n] ??= fibonacci(n - 1) + fibonacci(n - 2);
  }
}

// =============================================================================
// GOOD: In-memory cache WITH size limit - should NOT trigger
// =============================================================================

// OK: Has maxSize limit
class BoundedImageCache {
  final Map<String, Uint8List> _cache = {};
  static const int maxSize = 100;

  void cache(String url, Uint8List data) {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = data;
  }
}

// OK: Has capacity limit
class CapacityCache {
  final Map<String, String> _cache = {};
  final int capacity = 50;

  void add(String key, String value) {
    if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}

// OK: Uses LRU eviction
class LruCache {
  final Map<String, dynamic> _cache = {};

  void evict(String key) {
    _cache.remove(key);
  }
}

// =============================================================================
// GOOD: Database models - should NOT trigger (false positive fix)
// =============================================================================

// OK: Isar database model with @collection annotation
@collection()
class ContactImportCacheDBModel {
  late int id;
  late String name;
  late String email;

  // These methods use Map<String, dynamic> for serialization, not caching
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }

  static ContactImportCacheDBModel fromMap(Map<String, dynamic> map) {
    return ContactImportCacheDBModel()
      ..id = map['id'] as int
      ..name = map['name'] as String
      ..email = map['email'] as String;
  }
}

// OK: Hive database model with @HiveType annotation
@HiveType(typeId: 1)
class UserCacheHiveModel {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String username;

  Map<String, dynamic> toJson() => {'id': id, 'username': username};
}

// OK: Floor database model with @Entity annotation
@Entity(tableName: 'cache_entries')
class CacheEntryFloorModel {
  @PrimaryKey(autoGenerate: true)
  int? id;

  String? key;
  String? value;

  Map<String, dynamic> toMap() => {'key': key, 'value': value};
}

// =============================================================================
// Dummy annotations for testing (simulating real ORM annotations)
// =============================================================================

class collection {
  const collection();
}

class HiveType {
  final int typeId;
  const HiveType({required this.typeId});
}

class HiveField {
  final int index;
  const HiveField(this.index);
}

class Entity {
  final String? tableName;
  const Entity({this.tableName});
}

class PrimaryKey {
  final bool autoGenerate;
  const PrimaryKey({this.autoGenerate = false});
}
