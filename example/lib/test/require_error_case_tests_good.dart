// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_identifier, undefined_method, undefined_class
// ignore_for_file: undefined_function, undefined_getter
// Compliant examples for require_error_case_tests, kept in their own file.
// The rule is whole-file: an error-case test anywhere clears the flag, so these
// must not share a file with the BAD (happy-path-only) fixture. The function
// names are pinned by require_error_case_tests_test.dart.
import 'package:saropa_lints_example/flutter_mocks.dart';

final email = 'test@example.com';
final name = 'example';
final password = 'secret';
final path = '/path';
dynamic service;
dynamic user;

// GOOD: Should NOT trigger — throwsA matcher detected
void _good1213_throwsA() async {
  test('login returns user', () async {
    final user = await service.login('valid@email.com', 'password');
    expect(user.name, isNotEmpty);
  });

  test('login throws on invalid credentials', () async {
    expect(
      () => service.login('invalid@email.com', 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('returns null for missing user', () async {
    final user = await service.findUser('nonexistent');
    expect(user, isNull);
  });
}

// GOOD: Should NOT trigger — 'safely' keyword in test name
// (defensive try-catch source code that never throws to caller)
void _good1213_safely() async {
  test('returns zero when unattached', () {
    expect(service.safeOffset, 0.0);
  });

  test('handles multiple positions safely', () async {
    expect(service.jumpTop(), completion(isFalse));
  });
}

// GOOD: Should NOT trigger — 'timeout' keyword in test name
void _good1213_timeout() async {
  test('completes normally', () async {
    expect(await service.fetchData(), isNotNull);
  });

  test('returns fallback on timeout', () async {
    expect(await service.fetchData(), isEmpty);
  });
}

// GOOD: Should NOT trigger — 'dispose' keyword in test name
void _good1213_dispose() async {
  test('creates controller', () {
    expect(service.controller, isNotNull);
  });

  test('returns safely after dispose', () {
    expect(service.safeOffset, 0.0);
  });
}

// GOOD: Should NOT trigger — 'default' keyword in test name
void _good1213_default() async {
  test('processes valid input', () {
    expect(service.process('hello'), isNotNull);
  });

  test('returns default when config missing', () {
    expect(service.getTheme(), equals('light'));
  });
}
