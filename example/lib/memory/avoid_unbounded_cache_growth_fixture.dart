// ignore_for_file: unused_field, unused_element
// Test fixture for avoid_unbounded_cache_growth rule

import 'dart:typed_data';

// =============================================================================
// BAD: In-memory cache without bounds - should trigger
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
// GOOD: Enum-keyed maps - inherently bounded - should NOT trigger
// =============================================================================

enum PanelEnum { actionIcons, activity, address, email, phone }

enum DetailPanelsEnum {
  actionIcons,
  activity,
  address,
  email,
  phone,
  notes,
  tags,
}

// OK: Enum keys cap the map at enum.values.length entries maximum
class EnumKeyedCache {
  final Map<PanelEnum, String> _cache = {
    PanelEnum.actionIcons: 'icons',
    PanelEnum.activity: 'activity',
  };

  String? get(PanelEnum key) => _cache[key];
}

// OK: Singleton with enum keys and getter-only access
class PanelKeyCache {
  factory PanelKeyCache() => _instance;
  PanelKeyCache._internal();
  static final PanelKeyCache _instance = PanelKeyCache._internal();

  final Map<PanelEnum, int> _keys = {
    PanelEnum.actionIcons: 1,
    PanelEnum.activity: 2,
    PanelEnum.address: 3,
    PanelEnum.email: 4,
    PanelEnum.phone: 5,
  };

  Map<PanelEnum, int> get keys => _keys;
}

// OK: Using Type suffix (common enum naming convention)
enum SettingsType { general, privacy, notifications, appearance }

class SettingsTypeCache {
  final Map<SettingsType, String> _cache = {};

  String? get(SettingsType key) => _cache[key];
}

// OK: Using Kind suffix (common enum naming convention)
enum MessageKind { text, image, video, audio }

class MessageKindCache {
  final Map<MessageKind, int> _countCache = {};

  int? getCount(MessageKind kind) => _countCache[kind];
}

// OK: Using Status suffix (common enum naming convention)
enum TaskStatus { pending, inProgress, completed, canceled }

class TaskStatusCache {
  final Map<TaskStatus, List<String>> _taskCache = {};

  List<String>? getTasks(TaskStatus status) => _taskCache[status];
}

// =============================================================================
// BAD: Simple cache service (matches BadCacheService pattern exactly)
// =============================================================================

// expect_lint: avoid_unbounded_cache_growth
class SimpleCacheService {
  final Map<String, Object> _cache = {};

  void set(String key, Object value) {
    _cache[key] = value;
  }
}

// =============================================================================
// GOOD: Immutable caches (no mutation methods) - should NOT trigger
// =============================================================================

// OK: Final map with no methods that add entries
class ReadOnlyCache {
  final Map<String, String> _cache = {
    'key1': 'value1',
    'key2': 'value2',
  };

  String? get(String key) => _cache[key];
  bool contains(String key) => _cache.containsKey(key);
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

// Test: Copy of ImageCache at end of file to check if position matters
// expect_lint: avoid_unbounded_cache_growth
class ImageCache2 {
  final Map<String, Object> _cache = {};

  void cache(String url, Object data) {
    _cache[url] = data;
  }

  Object? get(String url) => _cache[url];
}

// Exact copy of BadCacheService from async fixture - should trigger
// expect_lint: avoid_unbounded_cache_growth
class BadCacheServiceCopy {
  final Map<String, Object> _cache = {};

  void set(String key, Object value) {
    _cache[key] = value;
  }
}
