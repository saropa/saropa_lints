// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_cubit_usage` lint rule.

// BAD: Cubit when Bloc preferred
// expect_lint: avoid_cubit_usage
class BadCounterCubit {} // use Bloc<Event, State> instead

// GOOD: Bloc with events
class GoodCounterBloc {}

void main() {}
