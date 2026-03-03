// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_bloc_event_in_constructor` lint rule.
/// Quick fix: Remove add() call from constructor (DeleteNodeFix on ExpressionStatement).

import 'package:bloc/bloc.dart';

// BAD: add() in constructor — LINT
// expect_lint: avoid_bloc_event_in_constructor
class BadCounterBloc extends Bloc<int, int> {
  BadCounterBloc() : super(0) {
    add(1);
  }
}

// GOOD: no add() in constructor
class GoodCounterBloc extends Bloc<int, int> {
  GoodCounterBloc() : super(0);
}

void main() {}
