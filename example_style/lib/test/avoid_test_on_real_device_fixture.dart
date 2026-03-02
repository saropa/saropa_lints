// ignore_for_file: unused_element
// Test fixture for: avoid_test_on_real_device
// BAD: test name suggests real device
// expect_lint: avoid_test_on_real_device
void main() {
  test('runs on real device', () {});
  testWidgets('real_device integration', (t) async {});

  // GOOD: no real device in name
  test('validates order flow', () {});
  testWidgets('renders list', (t) async {});
}

void test(String name, void Function() fn) {}
void testWidgets(String name, void Function(dynamic) fn) {}
