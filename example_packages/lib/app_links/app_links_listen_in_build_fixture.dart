// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `app_links_listen_in_build` (WARNING).
library;

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

class _BadWidget extends StatelessWidget {
  _BadWidget();

  final AppLinks _appLinks = AppLinks();

  @override
  Widget build(BuildContext context) {
    // expect_lint: app_links_listen_in_build
    _appLinks.uriLinkStream.listen((Uri uri) {});
    return const SizedBox();
  }
}

class _GoodWidget extends StatefulWidget {
  const _GoodWidget();

  @override
  State<_GoodWidget> createState() => _GoodWidgetState();
}

class _GoodWidgetState extends State<_GoodWidget> {
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    // Subscribed once outside build() — must NOT trigger.
    _appLinks.uriLinkStream.listen((Uri uri) {});
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
