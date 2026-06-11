// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `require_cached_image_provider_error_listener` (INFO).
library;

import 'package:cached_network_image/cached_network_image.dart';

void bad() {
  // expect_lint: require_cached_image_provider_error_listener
  final provider = CachedNetworkImageProvider('https://example.com/a.jpg');
}

void good() {
  // errorListener gives the failure a logging path, so this must NOT trigger.
  final provider = CachedNetworkImageProvider(
    'https://example.com/a.jpg',
    errorListener: (Object e) {},
  );
}
