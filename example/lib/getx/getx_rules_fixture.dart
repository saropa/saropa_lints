// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: unused_element, avoid_print, unused_field
// Test fixture for GetX rules

// Mock GetX classes for testing (since we may not have get package)
abstract class GetxController {
  void onInit() {}
  void onReady() {}
  void onClose() {}
}

class Worker {
  void dispose() {}
}

Worker ever(dynamic rx, Function callback) => Worker();
Worker once(dynamic rx, Function callback) => Worker();
Worker debounce(dynamic rx, Function callback) => Worker();
Worker interval(dynamic rx, Function callback) => Worker();

// Test cases

// BAD: Missing super.onInit()
class BadController1 extends GetxController {
  // expect_lint: proper_getx_super_calls
  @override
  void onInit() {
    // Missing super.onInit()!
    print('init');
  }
}

// BAD: Missing super.onClose()
class BadController2 extends GetxController {
  // expect_lint: proper_getx_super_calls
  @override
  void onClose() {
    // Missing super.onClose()!
    print('close');
  }
}

// GOOD: Has super calls
class GoodController1 extends GetxController {
  @override
  void onInit() {
    super.onInit();
    print('init');
  }

  @override
  void onClose() {
    print('close');
    super.onClose();
  }
}

class WorkerTestController extends GetxController {
  late Worker _worker;
  final count = 0;

  @override
  void onInit() {
    super.onInit();

    // BAD: Worker not assigned for cleanup
    // expect_lint: always_remove_getx_listener
    ever(count, (_) => print('changed'));

    // BAD: Worker not assigned
    // expect_lint: always_remove_getx_listener
    debounce(count, (_) => print('debounced'));

    // GOOD: Worker assigned for cleanup
    _worker = ever(count, (_) => print('assigned'));
  }

  @override
  void onClose() {
    _worker.dispose();
    super.onClose();
  }
}
