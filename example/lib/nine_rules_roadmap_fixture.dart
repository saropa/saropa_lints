// ignore_for_file: avoid_print, depend_on_referenced_packages, unused_element, unused_local_variable
// Fixture for 9 roadmap-implemented rules: bad/good and false-positive cases.
// Enable the rules in analysis_options to test.

import 'dart:developer' as developer;

// -----------------------------------------------------------------------------
// avoid_cascades
// -----------------------------------------------------------------------------
void avoidCascadesBad() {
  final list = <int>[]
    ..add(1)
    ..add(2); // LINT: avoid_cascades
}

void avoidCascadesGood() {
  final list = <int>[];
  list.add(1);
  list.add(2);
}

// -----------------------------------------------------------------------------
// prefer_fold_over_reduce
// -----------------------------------------------------------------------------
void preferFoldBad() {
  final numbers = <int>[1, 2, 3];
  final sum = numbers.reduce((a, b) => a + b); // LINT: prefer_fold_over_reduce
}

void preferFoldGood() {
  final numbers = <int>[1, 2, 3];
  final sum = numbers.fold(0, (a, b) => a + b);
}

// -----------------------------------------------------------------------------
// avoid_expensive_log_string_construction
// -----------------------------------------------------------------------------
void avoidExpensiveLogBad(int id, String action) {
  developer.log('User $id did $action'); // LINT: avoid_expensive_log_string_construction
}

void avoidExpensiveLogGood(int id, String action) {
  const message = 'static';
  developer.log(message);
}

// -----------------------------------------------------------------------------
// avoid_returning_this
// -----------------------------------------------------------------------------
class AvoidReturningThisBad {
  int _x = 0;
  AvoidReturningThisBad setX(int x) {
    _x = x;
    return this; // LINT: avoid_returning_this
  }
}

class AvoidReturningThisGood {
  int _x = 0;
  void setX(int x) {
    _x = x;
  }
}

// -----------------------------------------------------------------------------
// avoid_cubits (requires bloc package; fixture may not trigger without it)
// -----------------------------------------------------------------------------
// class CounterCubit extends Cubit<int> {
//   CounterCubit() : super(0);
//   void increment() => emit(state + 1);
// } // LINT: avoid_cubits when bloc is dependency

// -----------------------------------------------------------------------------
// prefer_expression_body_getters
// -----------------------------------------------------------------------------
class PreferExpressionBodyGettersBad {
  int _x = 0;
  int get value {
    return _x; // LINT: prefer_expression_body_getters
  }
}

class PreferExpressionBodyGettersGood {
  int _x = 0;
  int get value => _x;
}

// -----------------------------------------------------------------------------
// prefer_final_fields_always
// -----------------------------------------------------------------------------
class PreferFinalFieldsAlwaysBad {
  int x = 0; // LINT: prefer_final_fields_always
  String name = ''; // LINT
}

class PreferFinalFieldsAlwaysGood {
  final int x = 0;
  final String name;
  PreferFinalFieldsAlwaysGood(this.name);
}

// -----------------------------------------------------------------------------
// prefer_block_body_setters
// -----------------------------------------------------------------------------
class PreferBlockBodySettersBad {
  int _x = 0;
  set value(int x) => _x = x; // LINT: prefer_block_body_setters
}

class PreferBlockBodySettersGood {
  int _x = 0;
  set value(int x) {
    _x = x;
  }
}

// -----------------------------------------------------------------------------
// avoid_riverpod_string_provider_name (requires riverpod; example pattern)
// -----------------------------------------------------------------------------
// final badProvider = Provider((ref) => 0, name: 'myProvider'); // LINT when riverpod
// final goodProvider = Provider((ref) => 0);
