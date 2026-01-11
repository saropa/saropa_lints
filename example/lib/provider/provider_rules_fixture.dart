// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: unused_element, avoid_print
// Test fixture for Provider package rules

import '../flutter_mocks.dart';

// Mock service classes for testing
class AuthService {
  void dispose() {}
}

class UserService {
  void dispose() {}
}

void testPreferMultiProvider() {
  // BAD: Nested Providers
  // expect_lint: prefer_multi_provider
  final bad1 = Provider<AuthService>(
    create: (_) => AuthService(),
    child: Provider<UserService>(
      create: (_) => UserService(),
      child: Container(),
    ),
  );

  // GOOD: Using MultiProvider
  final good1 = MultiProvider(
    providers: [
      Provider<AuthService>(create: (_) => AuthService()),
      Provider<UserService>(create: (_) => UserService()),
    ],
    child: Container(),
  );
}

void testAvoidInstantiatingInValueProvider() {
  // BAD: Creating new instance in Provider.value
  final bad1 = Provider.value(
    // expect_lint: avoid_instantiating_in_value_provider
    value: AuthService(), // New instance - not managed!
    child: Container(),
  );

  final existingService = AuthService();

  // GOOD: Using existing instance in value
  final good1 = Provider.value(
    value: existingService,
    child: Container(),
  );

  // GOOD: Creating new instance with create
  final good2 = Provider<AuthService>(
    create: (_) => AuthService(),
    child: Container(),
  );
}

void testDisposeProviders() {
  // BAD: Provider without dispose
  // expect_lint: dispose_providers
  final bad1 = Provider<AuthService>(
    create: (_) => AuthService(),
    child: Container(),
  );

  // GOOD: Provider with dispose callback
  final good1 = Provider<AuthService>(
    create: (_) => AuthService(),
    dispose: (_, service) => service.dispose(),
    child: Container(),
  );

  // GOOD: ChangeNotifierProvider auto-disposes
  final good2 = ChangeNotifierProvider<ValueNotifier<int>>(
    create: (_) => ValueNotifier(0),
    child: Container(),
  );
}
