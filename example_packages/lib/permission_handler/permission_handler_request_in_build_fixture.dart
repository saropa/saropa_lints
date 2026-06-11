// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `permission_handler_request_in_build` (ERROR).
library;

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

class BadWidget extends StatelessWidget {
  const BadWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: permission_handler_request_in_build
    Permission.camera.request();
    return const SizedBox();
  }
}

class GoodWidget extends StatelessWidget {
  const GoodWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Request lives in a callback, not executed synchronously by build.
    return GestureDetector(
      onTap: () => Permission.camera.request(),
      child: const SizedBox(),
    );
  }
}
