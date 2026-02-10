# Review before publishing


1. Disabled Tests

These were temporarily disabled until we figure out unit testings

  error - No associated positional super constructor parameter - example_core\lib\code_quality\prefer_redirecting_superclass_constructor_fixture.dart:118:24 - super_formal_parameter_without_associated_positional
  error - A constant constructor can't call a non-constant super constructor of '_good554_UpdateEvent' - example_packages\lib\packages\avoid_bloc_event_mutation_fixture.dart:125:9 - const_constructor_with_non_const_super
  error - The implicitly invoked unnamed constructor from 'Bloc<MyEvent, MyState>' has required parameters - example_packages\lib\packages\require_bloc_initial_state_fixture.dart:111:3 - implicit_super_initializer_missing_arguments

NOTE: find them with this code

``` dart
// HACK: TODO restore when available to testing
```