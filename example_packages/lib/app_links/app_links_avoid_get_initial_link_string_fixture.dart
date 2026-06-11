// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `app_links_avoid_get_initial_link_string` (INFO).
library;

import 'package:app_links/app_links.dart';

Future<void> bad() async {
  final AppLinks appLinks = AppLinks();
  // expect_lint: app_links_avoid_get_initial_link_string
  final String? s = await appLinks.getInitialLinkString();
}

Future<void> good() async {
  final AppLinks appLinks = AppLinks();
  // Uri surface — must NOT trigger.
  final Uri? uri = await appLinks.getInitialLink();
}
