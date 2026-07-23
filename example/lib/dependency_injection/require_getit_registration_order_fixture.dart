// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_identifier, undefined_method, undefined_function
// ignore_for_file: undefined_class, non_type_as_type_argument
// ignore_for_file: creation_with_non_type, avoid_dynamic_calls

/// Fixture for `require_getit_registration_order` lint rule.

dynamic getIt;

// BAD: UserService is registered using AuthService before AuthService itself
// is registered, so the locator cannot resolve the dependency at that point.
// expect_lint: require_getit_registration_order
void setupBad() {
  getIt.registerSingleton<UserService>(UserService(getIt<AuthService>()));
  getIt.registerSingleton<AuthService>(AuthServiceImpl());
}

// GOOD: the dependency is registered before the service that needs it.
void setupGood() {
  getIt.registerSingleton<AuthService>(AuthServiceImpl());
  getIt.registerSingleton<UserService>(UserService(getIt<AuthService>()));
}
