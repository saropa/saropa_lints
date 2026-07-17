// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_identifier, undefined_method, undefined_function
// Compliant example for avoid_test_coupling, kept in its own file so its `main`
// does not collide with the BAD fixture's `main`.
import 'package:saropa_lints_example/flutter_mocks.dart';

// GOOD: each test is self-contained — no shared mutable state between tests.
void main() async {
  test('creates and deletes user', () async {
    final userId = await createUser('test');
    expect(userId, isNotNull);
    await deleteUser(userId);
  });
}
