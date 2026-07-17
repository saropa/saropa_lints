// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_identifier, undefined_method, undefined_function
// ignore_for_file: undefined_class, creation_with_non_type, avoid_dynamic_calls

/// Fixture for `require_hive_adapter_registration_order` lint rule.

dynamic Hive;

// BAD: openBox is called before registerAdapter, which throws HiveError at
// runtime because the adapter is not registered when the box opens.
// expect_lint: require_hive_adapter_registration_order
void initHiveBad() {
  Hive.openBox('data');
  Hive.registerAdapter(MyAdapter());
}

// GOOD: all adapters are registered before any box is opened.
void initHiveGood() {
  Hive.registerAdapter(MyAdapter());
  Hive.openBox('data');
}
