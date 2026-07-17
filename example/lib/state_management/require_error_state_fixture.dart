// ignore_for_file: unused_element, must_be_immutable, undefined_class
// ignore_for_file: undefined_identifier
// Test fixture for: require_error_state
// The rule reports a sealed `...State` hierarchy that has no error variant. It
// is whole-file (any Error/Failure state anywhere satisfies it), so the
// compliant example lives in require_error_state_good.dart.
import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: sealed state hierarchy with no Error/Failure variant.
// expect_lint: require_error_state
sealed class UserState {}

class UserLoading extends UserState {}

class UserLoaded extends UserState {
  UserLoaded(this.name);
  final String name;
}
