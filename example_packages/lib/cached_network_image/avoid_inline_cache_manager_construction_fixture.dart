// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_inline_cache_manager_construction` (WARNING).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// A held reference is the correct pattern the rule steers toward.
final DefaultCacheManager _sharedManager = DefaultCacheManager();

Object bad() {
  return CachedNetworkImage(
    imageUrl: 'https://example.com/a.jpg',
    // expect_lint: avoid_inline_cache_manager_construction
    cacheManager: DefaultCacheManager(),
  );
}

Object good() {
  // Passing the held reference must NOT trigger.
  return CachedNetworkImage(
    imageUrl: 'https://example.com/a.jpg',
    cacheManager: _sharedManager,
  );
}
