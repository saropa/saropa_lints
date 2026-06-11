// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `require_cached_image_provider_dimensions` (WARNING).
library;

import 'package:cached_network_image/cached_network_image.dart';

void bad() {
  // expect_lint: require_cached_image_provider_dimensions
  final provider = CachedNetworkImageProvider('https://example.com/a.jpg');
}

void good() {
  // maxWidth bounds the decode, so this must NOT trigger.
  final provider = CachedNetworkImageProvider(
    'https://example.com/a.jpg',
    maxWidth: 200,
    maxHeight: 200,
  );
}
