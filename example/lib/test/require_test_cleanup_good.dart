// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_identifier, undefined_method, undefined_class
// Compliant example for require_test_cleanup, kept in its own file. The rule is
// whole-file: a tearDown anywhere clears the flag, so this must not share a file
// with the BAD fixture.
import 'package:saropa_lints_example/flutter_mocks.dart';

// GOOD: created resources are removed in tearDown — should NOT trigger.
void goodTestCleanup() async {
  late File testFile;

  setUp(() {
    testFile = File('test.txt');
  });

  tearDown(() async {
    if (await testFile.exists()) {
      await testFile.delete();
    }
  });

  test('saves file', () async {
    await testFile.writeAsString('data');
    expect(await testFile.exists(), isTrue);
  });
}
