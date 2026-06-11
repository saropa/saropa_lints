// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `app_links_uncaught_stream_error` (INFO).
library;

import 'package:app_links/app_links.dart';

void bad() {
  final AppLinks appLinks = AppLinks();
  // expect_lint: app_links_uncaught_stream_error
  appLinks.uriLinkStream.listen((Uri uri) {});
}

void good() {
  final AppLinks appLinks = AppLinks();
  // onError: present — must NOT trigger.
  appLinks.uriLinkStream.listen(
    (Uri uri) {},
    onError: (Object error, StackTrace stack) {},
  );
}
