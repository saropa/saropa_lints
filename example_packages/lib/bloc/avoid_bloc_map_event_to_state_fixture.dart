// ignore_for_file: unused_local_variable, unused_element, undefined_class
// ignore_for_file: non_constant_identifier_names, must_be_immutable

/// Fixture for `avoid_bloc_map_event_to_state` lint rule.
///
/// bloc 8.0 removed the `mapEventToState` override in favor of `on<Event>`
/// handlers. The rule flags a Bloc subclass that still overrides it. Gated to
/// the `bloc_8` pack.
library;

import 'package:bloc/bloc.dart';

class CounterEvent {}

class Increment extends CounterEvent {}

// BAD: Bloc subclass still overriding the removed mapEventToState API.
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0);

  @override
  Stream<int> mapEventToState(CounterEvent event) async* {
    // LINT: mapEventToState was removed in bloc 8.0 — use on<Event> handlers
    if (event is Increment) {
      yield state + 1;
    }
  }
}

// GOOD: bloc 8.0 style with on<Event> handlers, no mapEventToState.
class GoodCounterBloc extends Bloc<CounterEvent, int> {
  GoodCounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
  }
}

// GOOD: a Cubit never had mapEventToState; an unrelated method of that name on
// a non-Bloc class must not be flagged.
class NotABloc {
  Stream<int> mapEventToState(CounterEvent event) async* {
    yield 0;
  }
}
