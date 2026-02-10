// Test fixture for false positive prevention rules
// ignore_for_file: unused_local_variable, unused_element, prefer_const_declarations
// ignore_for_file: avoid_print_in_release, prefer_no_commented_out_code

// =============================================================================
// prefer_correct_package_name
// =============================================================================

// This rule checks library directive names - tested via separate files
// since library directives must be at the top of a file.

// =============================================================================
// avoid_getx_build_context_bypass - FALSE POSITIVES
// =============================================================================

/// These should NOT trigger avoid_getx_build_context_bypass

// 1. Not Get.context - different prefix
class UserContext {
  String? context;
  void use() => print(context);
}

// 2. Context used normally (no Get prefix)
void normalContextUsage(dynamic context) {
  print(context);
}

// 3. Other Get.x methods (not context)
class GetxUsage {
  void example() {
    // These should NOT trigger (only Get.context and Get.overlayContext)
    // Get.to(page);
    // Get.snackbar('title', 'message');
    // Get.find<Service>();
  }
}

// =============================================================================
// avoid_permission_handler_null_safety - FALSE POSITIVES
// =============================================================================

/// These should NOT trigger avoid_permission_handler_null_safety

// 1. User-defined class named PermissionHandler (different package)
class PermissionHandler {
  // Custom class, NOT from permission_handler package
  void checkStatus() {}
}

// 2. Similar method names on unrelated classes
class MyPermissionService {
  void checkPermissionStatus() {} // OK - not on PermissionHandler target
}

// 3. Normal Permission usage (modern API)
class ModernPermissionUsage {
  // Permission.camera.status  -- modern API, should NOT trigger
  // Permission.camera.request()  -- modern API, should NOT trigger
}

// =============================================================================
// avoid_retaining_disposed_widgets - FALSE POSITIVES
// =============================================================================

/// These should NOT trigger avoid_retaining_disposed_widgets

// 1. Plain data class (no widget references)
class UserService {
  String? name;
  int? age;
  void Function()? onUpdate;
}

// 2. Class with callback (not widget reference)
class NotificationService {
  void Function(String)? onMessage;
  Future<void> Function()? onRefresh;
}

// 3. Class ending with "Widget" but not extending Widget
// (should NOT trigger due to exact-match extends-clause check)
class PaymentWidget {
  String? paymentId;
}

// =============================================================================
// require_secure_key_generation - FALSE POSITIVES
// =============================================================================

/// These should NOT trigger require_secure_key_generation

// 1. Key.fromSecureRandom is the correct way
// final key = Key.fromSecureRandom(32);

// 2. Non-encryption Key class
class Key {
  Key(this.value);
  final String value;
  static Key fromLength(int n) => Key('x' * n);
}

// 3. Regular list usage (not inside Key constructor)
void normalListUsage() {
  final data = List.filled(16, 0);
  print(data);
}

// =============================================================================
// require_hive_web_subdirectory - FALSE POSITIVES
// =============================================================================

/// These should NOT trigger require_hive_web_subdirectory

// 1. initFlutter with subdirectory (correct usage)
class CorrectHiveInit {
  Future<void> init() async {
    // Hive.initFlutter('my_app_data');  -- has subDir, OK
  }
}

// 2. Regular Hive.init (not initFlutter)
class RegularHiveInit {
  Future<void> init() async {
    // Hive.init('/path/to/dir');  -- init() not initFlutter(), different API
  }
}

// 3. initFlutter on non-Hive class
class NotHive {
  void initFlutter() {} // Different class, should NOT trigger
}
