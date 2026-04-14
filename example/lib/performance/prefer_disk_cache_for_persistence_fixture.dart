// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_disk_cache_for_persistence` lint rule.

// BAD: In-memory cache for persistent data
// expect_lint: prefer_disk_cache_for_persistence
final badCache = <String, String>{};

// GOOD: Disk-backed cache for persistence
// final goodCache = FlutterCacheManager();

void main() {}
